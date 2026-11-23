"""Lógica de fuentes y sincronización por lote de laboratorio (CU11, bloque B).

Sesión síncrona acotada por la excepción CU11 de AGENTS.md sección 5: solo ``select()/execute()/scalars()``.
La clínica sale siempre del contexto de la sesión; toda consulta y mutación filtra con una igualdad simple sobre
``id_clinica`` (nunca coincide con ``NULL``; el único ``COALESCE`` permitido es el de ``pacientes.complemento``).

Aislamiento por ítem (design.md D3): cada ítem se escribe dentro de un ``SAVEPOINT`` (``begin_nested``) y se
confirma al terminar, de modo que el fallo de un ítem (incluida la violación de la restricción única por una
carrera) deshace solo ese ítem y nunca aborta el lote ni los ítems ya integrados. Los ítems en ``ERROR`` no
crean fila en ``resultados_laboratorio``; el archivo solo se almacena después de validar y se borra si la
escritura falla (nunca queda un archivo sin fila ni una fila sin archivo).
"""
import json
import logging
import math
from dataclasses import dataclass
from datetime import date, datetime, time, timedelta, timezone
from typing import Any, Dict, Optional, Sequence

from pydantic import ValidationError
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.audit import registrar_auditoria
from app.modules.medical_records.clinical_documents.storage import storage
from app.modules.medical_records.laboratory_results import files
from app.modules.medical_records.laboratory_results.dependencies import Contexto
from app.modules.medical_records.laboratory_results.models import ResultadoLaboratorio
from app.modules.medical_records.laboratory_results.service import (
    ResultadoError,
    _auditar as auditar_resultado,
    _borrar_archivo as borrar_archivo,
    _documento_para as documento_para_resultado,
    buscar_examen,
    descripcion_segura,
    hoy,
    validar_orden,
)
from app.modules.medical_records.laboratory_sync.models import (
    FuenteLaboratorio,
    SincronizacionLaboratorio,
    SincronizacionLaboratorioItem,
)
from app.modules.medical_records.laboratory_sync.schemas import MAX_ITEMS_POR_LOTE, ItemManifiesto, Manifiesto
from app.modules.medical_records.models import Paciente

logger = logging.getLogger(__name__)

# Tope por petición (contrato 1.1, ``LOTE_INVALIDO``); lo aplica la ruta por ``Content-Length``.
TOPE_PETICION_BYTES = 100 * 1024 * 1024
TABLA_FUENTES = "fuentes_laboratorio"
TABLA_SINCRONIZACIONES = "sincronizaciones_laboratorio"
CAMPOS_DE_CLINICA = ("id_clinica", "tenant_id")

# Código de ítem que el contrato no cataloga: fallo inesperado aislado en un ítem (se registra en el log).
CODIGO_ERROR_INTERNO = "ERROR_INTERNO"


class SincronizacionError(ResultadoError):
    """Error de dominio: se responde con ``{"detail": {"codigo", "mensaje"}}``."""


def lote_invalido(mensaje: str) -> SincronizacionError:
    return SincronizacionError(422, "LOTE_INVALIDO", mensaje)


# --------------------------------------------------------------------------- #
# Fuentes de laboratorio (6.1)
# --------------------------------------------------------------------------- #
def _total_paginas(total: int, page_size: int) -> int:
    return max(1, math.ceil(total / page_size))


def _fuente_o_404(db: Session, id_clinica: int, id_fuente: int) -> FuenteLaboratorio:
    fuente = db.execute(
        select(FuenteLaboratorio).where(
            FuenteLaboratorio.id_fuente == id_fuente,
            FuenteLaboratorio.id_clinica == id_clinica,
        )
    ).scalar_one_or_none()
    if fuente is None:
        raise SincronizacionError(404, "FUENTE_NO_ENCONTRADA", "Fuente de laboratorio no encontrada.")
    return fuente


def _auditar(
    db: Session,
    ctx: Contexto,
    tabla: str,
    registro_id: int,
    accion: str,
    descripcion: str,
    anteriores: Optional[Dict[str, Any]] = None,
    nuevos: Optional[Dict[str, Any]] = None,
) -> None:
    """Traza en la misma transacción que el cambio de datos (no hace commit)."""
    registrar_auditoria(
        db,
        id_usuario=ctx.id_usuario,
        id_clinica=ctx.id_clinica,
        tabla_afectada=tabla,
        registro_id=registro_id,
        accion=accion,
        descripcion=descripcion,
        datos_anteriores=anteriores,
        datos_nuevos=nuevos,
    )


def listar_fuentes(db: Session, ctx: Contexto, *, activa: Optional[str], page: int, page_size: int) -> Dict[str, Any]:
    condiciones = [FuenteLaboratorio.id_clinica == ctx.id_clinica]
    if activa:
        condiciones.append(FuenteLaboratorio.activa == activa)
    total = db.execute(select(func.count()).select_from(FuenteLaboratorio).where(*condiciones)).scalar_one()
    filas = list(
        db.execute(
            select(FuenteLaboratorio)
            .where(*condiciones)
            .order_by(FuenteLaboratorio.codigo.asc(), FuenteLaboratorio.id_fuente.asc())
            .limit(page_size)
            .offset((page - 1) * page_size)
        ).scalars()
    )
    return {
        "items": filas,
        "total": total,
        "page": page,
        "page_size": page_size,
        "total_pages": _total_paginas(total, page_size),
    }


def _codigo_repetido() -> SincronizacionError:
    return SincronizacionError(409, "FUENTE_DUPLICADA", "Ya existe una fuente con ese código en la clínica.")


def crear_fuente(db: Session, ctx: Contexto, *, codigo: str, nombre: str) -> FuenteLaboratorio:
    existe = db.execute(
        select(FuenteLaboratorio.id_fuente).where(
            FuenteLaboratorio.id_clinica == ctx.id_clinica,
            FuenteLaboratorio.codigo == codigo,
        )
    ).first()
    if existe is not None:
        raise _codigo_repetido()
    fuente = FuenteLaboratorio(id_clinica=ctx.id_clinica, codigo=codigo, nombre=nombre, activa="SI")
    try:
        db.add(fuente)
        db.flush()
        _auditar(
            db, ctx, TABLA_FUENTES, fuente.id_fuente, "CREAR_FUENTE_LABORATORIO",
            f"Fuente de laboratorio {codigo} creada",
            nuevos={"codigo": codigo, "nombre": nombre, "activa": "SI"},
        )
        db.commit()
    except IntegrityError:
        db.rollback()
        # La restricción única (id_clinica, codigo) es la garantía real frente a altas simultáneas.
        raise _codigo_repetido() from None
    except Exception:
        db.rollback()
        raise
    db.refresh(fuente)
    return fuente


def actualizar_fuente(
    db: Session, ctx: Contexto, id_fuente: int, *, nombre: Optional[str], activa: Optional[str]
) -> FuenteLaboratorio:
    fuente = _fuente_o_404(db, ctx.id_clinica, id_fuente)
    anteriores = {"nombre": fuente.nombre, "activa": fuente.activa}
    try:
        if nombre is not None:
            fuente.nombre = nombre
        if activa is not None:
            fuente.activa = activa
        db.flush()
        _auditar(
            db, ctx, TABLA_FUENTES, fuente.id_fuente, "ACTUALIZAR_FUENTE_LABORATORIO",
            f"Fuente de laboratorio {fuente.codigo} actualizada",
            anteriores=anteriores,
            nuevos={"nombre": fuente.nombre, "activa": fuente.activa},
        )
        db.commit()
    except Exception:
        db.rollback()
        raise
    db.refresh(fuente)
    return fuente


# --------------------------------------------------------------------------- #
# Manifiesto (6.2)
# --------------------------------------------------------------------------- #
def _resumen_errores(error: ValidationError) -> str:
    """Mensaje sin eco de los valores recibidos: solo ruta del campo y regla incumplida."""
    partes = []
    for detalle in error.errors()[:5]:
        ruta = ".".join(str(p) for p in detalle.get("loc", ()))
        partes.append(f"{ruta}: {detalle.get('msg', 'valor inválido')}")
    return "Manifiesto inválido. " + "; ".join(partes)


def parsear_manifiesto(texto: Optional[str]) -> Manifiesto:
    """Parsea y valida el manifiesto; cualquier defecto rechaza el lote completo (``LOTE_INVALIDO``)."""
    if texto is None or not texto.strip():
        raise lote_invalido("Falta el manifiesto del lote.")
    try:
        crudo = json.loads(texto)
    except ValueError:
        raise lote_invalido("El manifiesto no es un JSON válido.") from None
    if not isinstance(crudo, dict):
        raise lote_invalido("El manifiesto debe ser un objeto JSON con 'fuente' e 'items'.")
    for campo in CAMPOS_DE_CLINICA:
        if campo in crudo:
            raise lote_invalido(f"El campo '{campo}' no es aceptado: la clínica la determina la sesión.")
    items = crudo.get("items")
    if isinstance(items, list):
        if len(items) > MAX_ITEMS_POR_LOTE:
            raise lote_invalido(f"El lote admite como máximo {MAX_ITEMS_POR_LOTE} ítems.")
        for posicion, item in enumerate(items):
            if isinstance(item, dict):
                for campo in CAMPOS_DE_CLINICA:
                    if campo in item:
                        raise lote_invalido(
                            f"items.{posicion}: el campo '{campo}' no es aceptado: la clínica la determina la sesión."
                        )
    try:
        manifiesto = Manifiesto.model_validate(crudo)
    except ValidationError as exc:
        raise lote_invalido(_resumen_errores(exc)) from None

    vistos = set()
    limite = hoy()
    for posicion, item in enumerate(manifiesto.items):
        if item.id_externo in vistos:
            raise lote_invalido("El manifiesto repite un id_externo dentro del lote.")
        vistos.add(item.id_externo)
        if item.fecha_realizacion > limite:
            raise lote_invalido(
                f"items.{posicion}.fecha_realizacion: la fecha de realización no puede ser posterior a la fecha actual."
            )
    return manifiesto


def indexar_archivos(partes: Sequence[Any]) -> Dict[str, Any]:
    """Partes ``archivos`` por nombre. Dos partes con el mismo nombre son ambiguas: se rechaza el lote."""
    indice: Dict[str, Any] = {}
    for parte in partes or []:
        nombre = parte.filename or ""
        if nombre in indice:
            raise lote_invalido("Dos archivos del lote comparten el mismo nombre; el manifiesto no puede referenciarlos.")
        indice[nombre] = parte
    return indice


def _fuente_activa(db: Session, id_clinica: int, codigo: str) -> FuenteLaboratorio:
    fuente = db.execute(
        select(FuenteLaboratorio).where(
            FuenteLaboratorio.id_clinica == id_clinica,
            FuenteLaboratorio.codigo == codigo,
        )
    ).scalar_one_or_none()
    if fuente is None:
        raise SincronizacionError(404, "FUENTE_NO_ENCONTRADA", "Fuente de laboratorio no encontrada.")
    if fuente.activa != "SI":
        raise SincronizacionError(409, "FUENTE_INACTIVA", "La fuente de laboratorio está inactiva.")
    return fuente


# --------------------------------------------------------------------------- #
# Correspondencia (6.3): paciente por CI + complemento, estudio y orden, siempre dentro de la clínica
# --------------------------------------------------------------------------- #
@dataclass(frozen=True)
class Correspondencia:
    paciente: Any  # fila (id_paciente, nombres, apellidos) o None
    examen: Any  # fila (id_examen, codigo, nombre) o None
    motivo: Optional[str]  # motivo de PENDIENTE_REVISION; None si la correspondencia es única y válida

    @property
    def incorporable(self) -> bool:
        return self.motivo is None


def _corresponder(db: Session, id_clinica: int, item: ItemManifiesto) -> Correspondencia:
    """Primera falla fija el motivo (paciente, luego estudio, luego orden). Nunca usa nombre ni aproximación."""
    complemento = item.complemento or ""
    # Igualdad simple sobre id_clinica: un paciente con id_clinica NULL o de otra clínica nunca coincide.
    pacientes = db.execute(
        select(Paciente.id_paciente, Paciente.nombres, Paciente.apellidos)
        .where(
            Paciente.ci == item.ci,
            func.coalesce(Paciente.complemento, "") == complemento,
            Paciente.id_clinica == id_clinica,
        )
        .limit(2)
    ).all()
    motivo: Optional[str] = None
    paciente = None
    if not pacientes:
        motivo = "PACIENTE_NO_ENCONTRADO"
    elif len(pacientes) > 1:
        motivo = "PACIENTE_AMBIGUO"
    else:
        paciente = pacientes[0]

    examen = None
    try:
        examen = buscar_examen(db, id_clinica, item.codigo_examen)
    except ResultadoError:
        if motivo is None:
            motivo = "EXAMEN_NO_VALIDO"

    if motivo is None and item.id_orden is not None:
        try:
            validar_orden(db, id_clinica, item.id_orden, paciente.id_paciente, item.codigo_examen)
        except ResultadoError as exc:
            motivo = "ORDEN_PACIENTE_NO_COINCIDE" if exc.codigo == "ORDEN_PACIENTE_NO_COINCIDE" else "ORDEN_NO_VALIDA"
    return Correspondencia(paciente=paciente, examen=examen, motivo=motivo)


# --------------------------------------------------------------------------- #
# Procesamiento de un ítem (6.3, 6.4, 6.5)
# --------------------------------------------------------------------------- #
class ItemError(Exception):
    """Fallo controlado de un ítem: queda ``ERROR`` con código y detalle, sin resultado ni archivo."""

    def __init__(self, codigo: str, detalle: str):
        super().__init__(detalle)
        self.codigo = codigo
        self.detalle = detalle


@dataclass(frozen=True)
class Veredicto:
    resultado: str  # INCORPORADO | PENDIENTE_REVISION | DUPLICADO | ERROR
    id_resultado: Optional[int] = None
    codigo_error: Optional[str] = None
    detalle: Optional[str] = None


def _validar_archivo(partes: Dict[str, Any], item: ItemManifiesto) -> files.ArchivoValidado:
    parte = partes.get(item.nombre_archivo)
    if parte is None:
        raise ItemError("ARCHIVO_AUSENTE", "El archivo indicado en el manifiesto no vino en el lote.")
    try:
        parte.file.seek(0)  # varios ítems pueden referenciar la misma parte
    except Exception:  # noqa: BLE001 - un flujo no reposicionable se lee desde donde esté
        pass
    try:
        return files.leer_y_validar(parte.file, item.nombre_archivo, parte.content_type)
    except files.ArchivoError as exc:
        raise ItemError(exc.codigo, exc.mensaje) from None


def _buscar_existente(db: Session, id_clinica: int, id_fuente: int, id_externo: str):
    """Resultado ya registrado con la clave de idempotencia ``(clínica, fuente, id_externo)``, en cualquier estado."""
    return db.execute(
        select(ResultadoLaboratorio.id_resultado, ResultadoLaboratorio.hash_archivo)
        .where(
            ResultadoLaboratorio.id_clinica == id_clinica,
            ResultadoLaboratorio.id_fuente == id_fuente,
            ResultadoLaboratorio.id_externo == id_externo,
        )
        .limit(1)
    ).first()


def _veredicto_de_existente(existente, validado: files.ArchivoValidado) -> Veredicto:
    if existente.hash_archivo == validado.sha256:
        return Veredicto("DUPLICADO", id_resultado=existente.id_resultado)
    return Veredicto(
        "ERROR",
        codigo_error="CONTENIDO_DISTINTO",
        detalle="El id_externo ya está registrado con un archivo de contenido distinto.",
    )


def _almacenar(id_clinica: int, validado: files.ArchivoValidado) -> str:
    try:
        clave, _ = storage.store(
            files.nombre_para_almacenamiento(id_clinica, validado.extension),
            validado.contenido,
            validado.content_type,
        )
        return clave
    except Exception as exc:  # noqa: BLE001
        logger.error("Falló el almacenamiento de un ítem de sincronización: %s", descripcion_segura(exc))
        raise ItemError("ALMACENAMIENTO_FALLIDO", "No se pudo guardar el archivo.") from None


def _insertar_resultado(
    db: Session,
    ctx: Contexto,
    *,
    id_fuente: int,
    id_sincronizacion: int,
    item: ItemManifiesto,
    corr: Correspondencia,
    validado: files.ArchivoValidado,
    clave: str,
) -> ResultadoLaboratorio:
    """Resultado (+ documento si queda INCORPORADO) + auditoría; un pendiente jamás toca un expediente."""
    incorporado = corr.incorporable
    codigo = item.codigo_examen.strip().upper()
    resultado = ResultadoLaboratorio(
        id_clinica=ctx.id_clinica,
        id_paciente=corr.paciente.id_paciente if incorporado else None,
        id_orden=item.id_orden if incorporado else None,
        id_examen=corr.examen.id_examen if corr.examen is not None else None,
        codigo_examen=codigo,
        nombre_examen=corr.examen.nombre if corr.examen is not None else None,
        laboratorio_origen=item.laboratorio_origen,
        fecha_realizacion=item.fecha_realizacion,
        observaciones=item.observaciones,
        estado="INCORPORADO" if incorporado else "PENDIENTE_REVISION",
        origen="SINCRONIZADO",
        id_fuente=id_fuente,
        id_externo=item.id_externo,
        id_sincronizacion=id_sincronizacion,
        motivo_pendiente=None if incorporado else corr.motivo,
        # Datos crudos solo del pendiente, para poder revisarlo; visibles únicamente con lab_results:review.
        datos_correspondencia=None if incorporado else {
            "ci": item.ci,
            "complemento": item.complemento or "",
            "codigo_examen": item.codigo_examen,
            "id_orden": item.id_orden,
        },
        nombre_archivo=validado.nombre,
        archivo_url=clave,
        hash_archivo=validado.sha256,
        content_type=validado.content_type,
        tamano_bytes=validado.tamano,
        registrado_por=ctx.id_usuario,
    )
    db.add(resultado)
    db.flush()
    if incorporado:
        documento = documento_para_resultado(
            resultado, ctx.id_usuario, f"{corr.paciente.nombres} {corr.paciente.apellidos}"
        )
        db.add(documento)
        db.flush()
        resultado.id_documento = documento.id_documento
        auditar_resultado(
            db, ctx, resultado, "CREAR_RESULTADO_LABORATORIO",
            f"Resultado {codigo} incorporado por sincronización",
            nuevos={
                "estado": "INCORPORADO", "origen": "SINCRONIZADO", "id_paciente": resultado.id_paciente,
                "codigo_examen": codigo, "id_orden": resultado.id_orden, "id_fuente": id_fuente,
                "id_externo": item.id_externo, "id_sincronizacion": id_sincronizacion,
                "hash_archivo": validado.sha256,
            },
        )
    else:
        auditar_resultado(
            db, ctx, resultado, "REGISTRAR_RESULTADO_PENDIENTE",
            f"Resultado {codigo} registrado como pendiente de revisión",
            nuevos={
                "estado": "PENDIENTE_REVISION", "origen": "SINCRONIZADO", "motivo_pendiente": corr.motivo,
                "codigo_examen": codigo, "id_fuente": id_fuente, "id_externo": item.id_externo,
                "id_sincronizacion": id_sincronizacion, "hash_archivo": validado.sha256,
            },
        )
    return resultado


def _guardar_item(
    db: Session,
    ctx: Contexto,
    *,
    id_sincronizacion: int,
    id_externo: str,
    veredicto: Veredicto,
    reintento: bool,
) -> None:
    """Crea (lote) o actualiza (reintento) la fila del ítem; ``intento`` solo sube en un reintento."""
    fila = db.execute(
        select(SincronizacionLaboratorioItem).where(
            SincronizacionLaboratorioItem.id_sincronizacion == id_sincronizacion,
            SincronizacionLaboratorioItem.id_clinica == ctx.id_clinica,
            SincronizacionLaboratorioItem.id_externo == id_externo,
        )
    ).scalar_one_or_none()
    if fila is None:
        fila = SincronizacionLaboratorioItem(
            id_sincronizacion=id_sincronizacion, id_clinica=ctx.id_clinica, id_externo=id_externo, intento=1,
        )
        db.add(fila)
    elif reintento:
        fila.intento = (fila.intento or 1) + 1
    fila.resultado = veredicto.resultado
    fila.id_resultado = veredicto.id_resultado
    fila.codigo_error = veredicto.codigo_error
    fila.detalle = veredicto.detalle
    fila.procesado_en = datetime.now(timezone.utc)
    db.flush()


def procesar_item(
    db: Session,
    ctx: Contexto,
    *,
    id_fuente: int,
    id_sincronizacion: int,
    item: ItemManifiesto,
    partes: Dict[str, Any],
    reintento: bool = False,
) -> Veredicto:
    """Algoritmo por ítem de design.md D3. Siempre deja el ítem registrado y NUNCA propaga el fallo del ítem."""
    clave: Optional[str] = None
    guardar = dict(id_sincronizacion=id_sincronizacion, id_externo=item.id_externo, reintento=reintento)
    try:
        validado = _validar_archivo(partes, item)
        existente = _buscar_existente(db, ctx.id_clinica, id_fuente, item.id_externo)
        if existente is not None:
            veredicto = _veredicto_de_existente(existente, validado)
            _guardar_item(db, ctx, veredicto=veredicto, **guardar)
            db.commit()
            return veredicto

        corr = _corresponder(db, ctx.id_clinica, item)
        clave = _almacenar(ctx.id_clinica, validado)
        try:
            with db.begin_nested():  # SAVEPOINT: un fallo aquí deshace solo este ítem
                resultado = _insertar_resultado(
                    db, ctx, id_fuente=id_fuente, id_sincronizacion=id_sincronizacion,
                    item=item, corr=corr, validado=validado, clave=clave,
                )
                veredicto = Veredicto(
                    "INCORPORADO" if corr.incorporable else "PENDIENTE_REVISION",
                    id_resultado=resultado.id_resultado,
                    detalle=None if corr.incorporable else corr.motivo,
                )
                _guardar_item(db, ctx, veredicto=veredicto, **guardar)
        except IntegrityError:
            # Carrera: otra transacción creó la misma clave entre la verificación y el INSERT. La restricción única
            # de la base es la garantía real; el archivo recién guardado ya no tiene fila y se borra.
            borrar_archivo(clave)
            clave = None
            existente = _buscar_existente(db, ctx.id_clinica, id_fuente, item.id_externo)
            if existente is None:
                raise
            veredicto = _veredicto_de_existente(existente, validado)
            _guardar_item(db, ctx, veredicto=veredicto, **guardar)
        db.commit()
        return veredicto
    except ItemError as exc:
        db.rollback()
        borrar_archivo(clave)
        veredicto = Veredicto("ERROR", codigo_error=exc.codigo, detalle=exc.detalle)
    except Exception as exc:  # noqa: BLE001 - aislamiento por ítem: nada de lo que falle aquí aborta el lote
        db.rollback()
        borrar_archivo(clave)
        logger.error("Falló el procesamiento del ítem %s: %s", item.id_externo, descripcion_segura(exc))
        veredicto = Veredicto("ERROR", codigo_error=CODIGO_ERROR_INTERNO, detalle="Error interno al procesar el ítem.")
    try:
        _guardar_item(db, ctx, veredicto=veredicto, **guardar)
        db.commit()
    except Exception:
        db.rollback()
        raise
    return veredicto


# --------------------------------------------------------------------------- #
# Registro de la sincronización (6.5, 6.6)
# --------------------------------------------------------------------------- #
def estado_de_lote(total: int, con_error: int) -> str:
    """``COMPLETADA`` sin errores, ``FALLIDA`` si todos fallan, ``COMPLETADA_CON_ERRORES`` en otro caso."""
    if con_error == 0:
        return "COMPLETADA"
    if con_error >= total:
        return "FALLIDA"
    return "COMPLETADA_CON_ERRORES"


def _recalcular(db: Session, sync: SincronizacionLaboratorio) -> None:
    """Contadores y estado desde los ítems (única fuente de verdad)."""
    cuentas = dict(
        db.execute(
            select(SincronizacionLaboratorioItem.resultado, func.count())
            .where(
                SincronizacionLaboratorioItem.id_sincronizacion == sync.id_sincronizacion,
                SincronizacionLaboratorioItem.id_clinica == sync.id_clinica,
            )
            .group_by(SincronizacionLaboratorioItem.resultado)
        ).all()
    )
    sync.incorporados = cuentas.get("INCORPORADO", 0)
    sync.pendientes = cuentas.get("PENDIENTE_REVISION", 0)
    sync.duplicados = cuentas.get("DUPLICADO", 0)
    sync.con_error = cuentas.get("ERROR", 0)
    sync.estado = estado_de_lote(sync.total_items, sync.con_error)
    sync.finalizado_en = datetime.now(timezone.utc)


def _sincronizacion_o_404(db: Session, id_clinica: int, id_sincronizacion: int) -> SincronizacionLaboratorio:
    sync = db.execute(
        select(SincronizacionLaboratorio).where(
            SincronizacionLaboratorio.id_sincronizacion == id_sincronizacion,
            SincronizacionLaboratorio.id_clinica == id_clinica,
        )
    ).scalar_one_or_none()
    if sync is None:
        raise SincronizacionError(404, "SINCRONIZACION_NO_ENCONTRADA", "Sincronización no encontrada.")
    return sync


def _datos_de_cabecera(sync: SincronizacionLaboratorio, fuente_codigo: Optional[str]) -> Dict[str, Any]:
    return {
        "id_sincronizacion": sync.id_sincronizacion,
        "id_fuente": sync.id_fuente,
        "fuente_codigo": fuente_codigo,
        "tipo": sync.tipo,
        "estado": sync.estado,
        "total_items": sync.total_items,
        "incorporados": sync.incorporados,
        "pendientes": sync.pendientes,
        "duplicados": sync.duplicados,
        "con_error": sync.con_error,
        "reintentos": sync.reintentos,
        "id_usuario": sync.id_usuario,
        "proceso": sync.proceso,
        "iniciado_en": sync.iniciado_en,
        "finalizado_en": sync.finalizado_en,
    }


def _codigos_de_fuentes(db: Session, id_clinica: int, ids: Sequence[int]) -> Dict[int, str]:
    ids = [i for i in set(ids) if i is not None]
    if not ids:
        return {}
    filas = db.execute(
        select(FuenteLaboratorio.id_fuente, FuenteLaboratorio.codigo).where(
            FuenteLaboratorio.id_fuente.in_(ids), FuenteLaboratorio.id_clinica == id_clinica
        )
    ).all()
    return {f.id_fuente: f.codigo for f in filas}


def obtener_sincronizacion(db: Session, ctx: Contexto, id_sincronizacion: int) -> Dict[str, Any]:
    """Cabecera con el detalle por ítem; la de otra clínica responde 404 indistinguible de "no existe"."""
    sync = _sincronizacion_o_404(db, ctx.id_clinica, id_sincronizacion)
    codigos = _codigos_de_fuentes(db, ctx.id_clinica, [sync.id_fuente])
    items = list(
        db.execute(
            select(SincronizacionLaboratorioItem)
            .where(
                SincronizacionLaboratorioItem.id_sincronizacion == sync.id_sincronizacion,
                SincronizacionLaboratorioItem.id_clinica == ctx.id_clinica,
            )
            .order_by(SincronizacionLaboratorioItem.id_item.asc())
        ).scalars()
    )
    respuesta = _datos_de_cabecera(sync, codigos.get(sync.id_fuente))
    respuesta["items"] = [
        {
            "id_externo": i.id_externo,
            "resultado": i.resultado,
            "id_resultado": i.id_resultado,
            "codigo_error": i.codigo_error,
            "detalle": i.detalle,
            "intento": i.intento,
        }
        for i in items
    ]
    return respuesta


def listar_sincronizaciones(
    db: Session,
    ctx: Contexto,
    *,
    page: int,
    page_size: int,
    id_fuente: Optional[int] = None,
    estado: Optional[str] = None,
    fecha_desde: Optional[date] = None,
    fecha_hasta: Optional[date] = None,
) -> Dict[str, Any]:
    condiciones = [SincronizacionLaboratorio.id_clinica == ctx.id_clinica]
    if id_fuente is not None:
        condiciones.append(SincronizacionLaboratorio.id_fuente == id_fuente)
    if estado:
        condiciones.append(SincronizacionLaboratorio.estado == estado)
    if fecha_desde:
        condiciones.append(SincronizacionLaboratorio.iniciado_en >= datetime.combine(fecha_desde, time.min))
    if fecha_hasta:
        condiciones.append(
            SincronizacionLaboratorio.iniciado_en < datetime.combine(fecha_hasta + timedelta(days=1), time.min)
        )
    total = db.execute(select(func.count()).select_from(SincronizacionLaboratorio).where(*condiciones)).scalar_one()
    filas = list(
        db.execute(
            select(SincronizacionLaboratorio)
            .where(*condiciones)
            .order_by(SincronizacionLaboratorio.iniciado_en.desc(), SincronizacionLaboratorio.id_sincronizacion.desc())
            .limit(page_size)
            .offset((page - 1) * page_size)
        ).scalars()
    )
    codigos = _codigos_de_fuentes(db, ctx.id_clinica, [s.id_fuente for s in filas])
    return {
        "items": [_datos_de_cabecera(s, codigos.get(s.id_fuente)) for s in filas],
        "total": total,
        "page": page,
        "page_size": page_size,
        "total_pages": _total_paginas(total, page_size),
    }


def ejecutar_lote(db: Session, ctx: Contexto, manifiesto: Manifiesto, partes: Dict[str, Any]) -> Dict[str, Any]:
    """Procesa un lote ya validado. El rechazo del lote (fuente, manifiesto) ocurre antes y no crea nada."""
    fuente = _fuente_activa(db, ctx.id_clinica, manifiesto.fuente)
    id_fuente, codigo_fuente = fuente.id_fuente, fuente.codigo

    sync = SincronizacionLaboratorio(
        id_clinica=ctx.id_clinica,
        id_fuente=id_fuente,
        tipo="LOTE",
        estado="EN_PROCESO",
        total_items=len(manifiesto.items),
        id_usuario=ctx.id_usuario,
    )
    try:
        db.add(sync)
        db.flush()
        id_sincronizacion = sync.id_sincronizacion
        db.commit()
    except Exception:
        db.rollback()
        raise

    for item in manifiesto.items:
        procesar_item(
            db, ctx, id_fuente=id_fuente, id_sincronizacion=id_sincronizacion, item=item, partes=partes,
        )
    _cerrar(db, ctx, id_sincronizacion, codigo_fuente, "EJECUTAR_SINCRONIZACION_LABORATORIO", "Lote sincronizado")
    return obtener_sincronizacion(db, ctx, id_sincronizacion)


def _cerrar(
    db: Session, ctx: Contexto, id_sincronizacion: int, codigo_fuente: str, accion: str, descripcion: str,
    sumar_reintento: bool = False,
) -> None:
    """Recalcula contadores y estado y registra la auditoría en la MISMA transacción."""
    try:
        sync = _sincronizacion_o_404(db, ctx.id_clinica, id_sincronizacion)
        if sumar_reintento:
            sync.reintentos = (sync.reintentos or 0) + 1
        _recalcular(db, sync)
        db.flush()
        _auditar(
            db, ctx, TABLA_SINCRONIZACIONES, id_sincronizacion, accion,
            f"{descripcion} de la fuente {codigo_fuente}",
            nuevos={
                "estado": sync.estado, "total_items": sync.total_items, "incorporados": sync.incorporados,
                "pendientes": sync.pendientes, "duplicados": sync.duplicados, "con_error": sync.con_error,
                "reintentos": sync.reintentos,
            },
        )
        db.commit()
    except Exception:
        db.rollback()
        raise


def reintentar(
    db: Session, ctx: Contexto, id_sincronizacion: int, manifiesto: Manifiesto, partes: Dict[str, Any]
) -> Dict[str, Any]:
    """Reprocesa SOLO ítems ``ERROR`` de la sincronización; lo ya integrado no se duplica ni se toca."""
    sync = _sincronizacion_o_404(db, ctx.id_clinica, id_sincronizacion)
    id_fuente = sync.id_fuente
    fuente = _fuente_o_404(db, ctx.id_clinica, id_fuente)
    codigo_fuente = fuente.codigo
    if manifiesto.fuente != codigo_fuente:
        raise lote_invalido("La fuente del manifiesto no coincide con la de la sincronización.")
    if fuente.activa != "SI":
        raise SincronizacionError(409, "FUENTE_INACTIVA", "La fuente de laboratorio está inactiva.")

    en_error = set(
        db.execute(
            select(SincronizacionLaboratorioItem.id_externo).where(
                SincronizacionLaboratorioItem.id_sincronizacion == id_sincronizacion,
                SincronizacionLaboratorioItem.id_clinica == ctx.id_clinica,
                SincronizacionLaboratorioItem.resultado == "ERROR",
            )
        ).scalars()
    )
    no_reintentables = [i.id_externo for i in manifiesto.items if i.id_externo not in en_error]
    if no_reintentables:
        # Se rechaza ANTES de procesar nada: la petición no crea ningún resultado.
        raise SincronizacionError(
            422, "ITEM_NO_REINTENTABLE",
            "Solo se pueden reintentar ítems en ERROR de esta sincronización: " + ", ".join(no_reintentables[:10]),
        )

    for item in manifiesto.items:
        procesar_item(
            db, ctx, id_fuente=id_fuente, id_sincronizacion=id_sincronizacion, item=item, partes=partes,
            reintento=True,
        )
    _cerrar(
        db, ctx, id_sincronizacion, codigo_fuente, "REINTENTAR_SINCRONIZACION_LABORATORIO", "Reintento",
        sumar_reintento=True,
    )
    return obtener_sincronizacion(db, ctx, id_sincronizacion)
