"""Lógica de negocio de resultados de laboratorio (CU11, bloque A).

Sesión síncrona acotada por la excepción CU11 de AGENTS.md sección 5: solo ``select()/execute()/scalars()``.
Toda consulta y mutación filtra por ``id_clinica`` de la sesión con una igualdad simple (nunca coincide con
``NULL``; el único ``COALESCE`` permitido en CU11 es el de ``pacientes.complemento``, en sincronización).
Las consultas a tablas ajenas (``pacientes``, ``examenes_laboratorio``, ``ordenes_laboratorio``) seleccionan
columnas concretas para no depender de que el esquema real coincida columna a columna con el modelo ORM.
"""
import json
import logging
import math
from dataclasses import dataclass
from datetime import date, datetime, timezone
from typing import Any, Dict, List, Optional, Sequence

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.audit import registrar_auditoria
from app.modules.auth.models import Usuario
from app.modules.medical_records.clinical_documents.models import DocumentoClinico
from app.modules.medical_records.clinical_documents.storage import storage
from app.modules.medical_records.laboratory_orders.models import ExamenLaboratorio, OrdenLaboratorio
from app.modules.medical_records.laboratory_results import files
from app.modules.medical_records.laboratory_results.dependencies import (
    PERMISO_DESCARGA,
    PERMISO_REVIEW,
    ROL_PACIENTE,
    Contexto,
    tiene_permiso,
)
from app.modules.medical_records.laboratory_results.models import ResultadoLaboratorio
from app.modules.medical_records.laboratory_sync.models import FuenteLaboratorio
from app.modules.medical_records.models import Paciente

logger = logging.getLogger(__name__)


def descripcion_segura(exc: BaseException) -> str:
    """Clase de la excepción (y de la causa del driver) para el log; NUNCA su mensaje.

    El mensaje de una excepción de SQLAlchemy incluye los parámetros de la sentencia (CI, datos de
    correspondencia, observaciones) y el de una falla de almacenamiento puede incluir rutas locales: ni el
    contenido clínico ni las rutas internas del servidor deben llegar a los logs.
    """
    causa = getattr(exc, "orig", None)
    return type(exc).__name__ + (f" ({type(causa).__name__})" if causa is not None else "")

TABLA_AUDITORIA = "resultados_laboratorio"


class ResultadoError(Exception):
    """Error de dominio: se responde con ``{"detail": {"codigo", "mensaje"}}``."""

    def __init__(self, status_code: int, codigo: str, mensaje: str):
        super().__init__(mensaje)
        self.status_code = status_code
        self.codigo = codigo
        self.mensaje = mensaje


@dataclass(frozen=True)
class Permisos:
    review: bool
    descarga: bool


def permisos_efectivos(db: Session, ctx: Contexto) -> Permisos:
    return Permisos(
        review=tiene_permiso(db, ctx.id_rol, PERMISO_REVIEW),
        descarga=tiene_permiso(db, ctx.id_rol, PERMISO_DESCARGA),
    )


def hoy() -> date:
    return date.today()


# --------------------------------------------------------------------------- #
# Correspondencia: paciente, estudio y orden (siempre dentro de la clínica)
# --------------------------------------------------------------------------- #
def buscar_paciente(db: Session, id_clinica: int, id_paciente: int):
    """Paciente de la clínica de la sesión; uno de otra clínica, o con ``id_clinica`` NULL, no existe."""
    fila = db.execute(
        select(Paciente.id_paciente, Paciente.nombres, Paciente.apellidos).where(
            Paciente.id_paciente == id_paciente,
            Paciente.id_clinica == id_clinica,
        )
    ).first()
    if fila is None:
        raise ResultadoError(404, "PACIENTE_NO_ENCONTRADO", "Paciente no encontrado.")
    return fila


def buscar_examen(db: Session, id_clinica: int, codigo_examen: str):
    """Examen activo del catálogo de la clínica, identificado por su ``codigo``."""
    codigo = (codigo_examen or "").strip().upper()
    fila = db.execute(
        select(ExamenLaboratorio.id_examen, ExamenLaboratorio.codigo, ExamenLaboratorio.nombre).where(
            func.upper(ExamenLaboratorio.codigo) == codigo,
            ExamenLaboratorio.id_clinica == id_clinica,
            ExamenLaboratorio.activo == "SI",
        )
    ).first()
    if fila is None:
        raise ResultadoError(404, "EXAMEN_NO_ENCONTRADO", "Examen no encontrado en el catálogo de la clínica.")
    return fila


def _codigos_de_orden(examenes: Any) -> List[str]:
    if isinstance(examenes, str):
        try:
            examenes = json.loads(examenes)
        except ValueError:
            return []
    codigos = []
    for elemento in examenes or []:
        if isinstance(elemento, dict) and elemento.get("codigo"):
            codigos.append(str(elemento["codigo"]).strip().upper())
    return codigos


def validar_orden(db: Session, id_clinica: int, id_orden: int, id_paciente: int, codigo_examen: str):
    """Orden de CU10 de la misma clínica y paciente, ``FIRMADA`` y que incluya el estudio."""
    orden = db.execute(
        select(
            OrdenLaboratorio.id_orden,
            OrdenLaboratorio.id_paciente,
            OrdenLaboratorio.estado,
            OrdenLaboratorio.examenes,
        ).where(
            OrdenLaboratorio.id_orden == id_orden,
            OrdenLaboratorio.id_clinica == id_clinica,
        )
    ).first()
    if orden is None:
        raise ResultadoError(404, "ORDEN_NO_ENCONTRADA", "Orden de laboratorio no encontrada.")
    if orden.id_paciente != id_paciente:
        raise ResultadoError(409, "ORDEN_PACIENTE_NO_COINCIDE", "La orden pertenece a otro paciente.")
    if orden.estado != "FIRMADA":
        raise ResultadoError(409, "ORDEN_NO_FIRMADA", "La orden no está firmada.")
    if codigo_examen.strip().upper() not in _codigos_de_orden(orden.examenes):
        raise ResultadoError(409, "ORDEN_SIN_EXAMEN", "La orden no incluye el estudio indicado.")
    return orden


# --------------------------------------------------------------------------- #
# Documento clínico (índice en el expediente) y auditoría
# --------------------------------------------------------------------------- #
def _documento_para(resultado: ResultadoLaboratorio, id_usuario: int, nombre_paciente: str) -> DocumentoClinico:
    titulo = f"Resultado de laboratorio - {resultado.nombre_examen or resultado.codigo_examen} - {nombre_paciente}"
    return DocumentoClinico(
        id_clinica=resultado.id_clinica,
        id_paciente=resultado.id_paciente,
        tipo_documento="RESULTADO_LAB",
        titulo=titulo[:200],
        descripcion=f"Estudio {resultado.codigo_examen}. Laboratorio de origen: {resultado.laboratorio_origen}.",
        archivo_url=resultado.archivo_url,
        hash_archivo=resultado.hash_archivo,
        firmado_por=id_usuario,
        fecha_documento=resultado.fecha_realizacion,
        metadatos={
            "id_resultado_laboratorio": resultado.id_resultado,
            "id_orden": resultado.id_orden,
            "codigo_examen": resultado.codigo_examen,
            "laboratorio_origen": resultado.laboratorio_origen,
            "content_type": resultado.content_type,
            "origen": resultado.origen,
        },
        estado="ACTIVO",
    )


def _auditar(
    db: Session,
    ctx: Contexto,
    resultado: ResultadoLaboratorio,
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
        tabla_afectada=TABLA_AUDITORIA,
        registro_id=resultado.id_resultado,
        accion=accion,
        descripcion=descripcion,
        datos_anteriores=anteriores,
        datos_nuevos=nuevos,
    )


def _borrar_archivo(clave: Optional[str]) -> None:
    """Compensación: nunca deja un archivo sin fila que lo referencie."""
    if not clave:
        return
    try:
        if not storage.delete(clave):
            logger.warning("No se pudo borrar el archivo huérfano %s", clave)
    except Exception as exc:  # noqa: BLE001 - la compensación no debe ocultar el error original
        logger.error("Error al borrar el archivo huérfano %s: %s", clave, descripcion_segura(exc))


# --------------------------------------------------------------------------- #
# Carga manual
# --------------------------------------------------------------------------- #
def _hay_duplicado_manual(db: Session, id_clinica: int, id_paciente: int, sha256: str) -> bool:
    return db.execute(
        select(ResultadoLaboratorio.id_resultado)
        .where(
            ResultadoLaboratorio.id_clinica == id_clinica,
            ResultadoLaboratorio.id_paciente == id_paciente,
            ResultadoLaboratorio.hash_archivo == sha256,
            ResultadoLaboratorio.origen == "MANUAL",
            ResultadoLaboratorio.estado == "INCORPORADO",
        )
        .limit(1)
    ).first() is not None


def _error_duplicado() -> ResultadoError:
    return ResultadoError(
        409, "RESULTADO_DUPLICADO",
        "Ya existe un resultado incorporado con el mismo archivo para este paciente.",
    )


def crear_manual(
    db: Session,
    ctx: Contexto,
    *,
    id_paciente: int,
    codigo_examen: str,
    fecha_realizacion: date,
    laboratorio_origen: str,
    id_orden: Optional[int],
    observaciones: Optional[str],
    archivo: files.ArchivoValidado,
) -> ResultadoLaboratorio:
    """Valida correspondencia, guarda el archivo y crea resultado + documento + auditoría en una transacción."""
    id_clinica = ctx.id_clinica
    paciente = buscar_paciente(db, id_clinica, id_paciente)
    examen = buscar_examen(db, id_clinica, codigo_examen)
    codigo = str(examen.codigo).strip().upper()
    if id_orden is not None:
        validar_orden(db, id_clinica, id_orden, paciente.id_paciente, codigo)
    if _hay_duplicado_manual(db, id_clinica, paciente.id_paciente, archivo.sha256):
        raise _error_duplicado()

    nombre_paciente = f"{paciente.nombres} {paciente.apellidos}"
    clave: Optional[str] = None
    try:
        try:
            clave, _ = storage.store(
                files.nombre_para_almacenamiento(id_clinica, archivo.extension),
                archivo.contenido,
                archivo.content_type,
            )
        except Exception as exc:  # noqa: BLE001
            logger.error("Falló el almacenamiento del resultado de laboratorio: %s", descripcion_segura(exc))
            raise ResultadoError(500, "ALMACENAMIENTO_FALLIDO", "No se pudo guardar el archivo.") from exc

        resultado = ResultadoLaboratorio(
            id_clinica=id_clinica,
            id_paciente=paciente.id_paciente,
            id_orden=id_orden,
            id_examen=examen.id_examen,
            codigo_examen=codigo,
            nombre_examen=examen.nombre,
            laboratorio_origen=laboratorio_origen,
            fecha_realizacion=fecha_realizacion,
            observaciones=observaciones,
            estado="INCORPORADO",
            origen="MANUAL",
            nombre_archivo=archivo.nombre,
            archivo_url=clave,
            hash_archivo=archivo.sha256,
            content_type=archivo.content_type,
            tamano_bytes=archivo.tamano,
            registrado_por=ctx.id_usuario,
        )
        db.add(resultado)
        db.flush()
        documento = _documento_para(resultado, ctx.id_usuario, nombre_paciente)
        db.add(documento)
        db.flush()
        resultado.id_documento = documento.id_documento
        _auditar(
            db, ctx, resultado, "CREAR_RESULTADO_LABORATORIO",
            f"Resultado {codigo} cargado manualmente",
            nuevos={
                "estado": "INCORPORADO", "origen": "MANUAL", "id_paciente": paciente.id_paciente,
                "codigo_examen": codigo, "id_orden": id_orden, "hash_archivo": archivo.sha256,
                "content_type": archivo.content_type, "tamano_bytes": archivo.tamano,
            },
        )
        db.commit()
    except IntegrityError:
        db.rollback()
        _borrar_archivo(clave)
        # La restricción de la base de datos es la garantía real frente a cargas simultáneas.
        if _hay_duplicado_manual(db, id_clinica, paciente.id_paciente, archivo.sha256):
            raise _error_duplicado()
        raise
    except Exception:
        db.rollback()
        _borrar_archivo(clave)
        raise
    db.refresh(resultado)
    return resultado


# --------------------------------------------------------------------------- #
# Consulta
# --------------------------------------------------------------------------- #
def _id_paciente_propio(db: Session, ctx: Contexto) -> int:
    """Paciente enlazado a la cuenta, dentro de la clínica de la sesión."""
    id_paciente = db.execute(
        select(Paciente.id_paciente).where(
            Paciente.id_usuario == ctx.id_usuario,
            Paciente.id_clinica == ctx.id_clinica,
        )
    ).scalar_one_or_none()
    if id_paciente is None:
        raise ResultadoError(404, "PACIENTE_NO_ENCONTRADO", "El usuario no tiene perfil de paciente en su clínica.")
    return id_paciente


def _denegar_estado() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail=f"Permiso denegado. Se requiere el permiso '{PERMISO_REVIEW}'.",
    )


def _nombres_pacientes(db: Session, id_clinica: int, ids: Sequence[int]) -> Dict[int, str]:
    ids = [i for i in set(ids) if i is not None]
    if not ids:
        return {}
    filas = db.execute(
        select(Paciente.id_paciente, Paciente.nombres, Paciente.apellidos).where(
            Paciente.id_paciente.in_(ids), Paciente.id_clinica == id_clinica
        )
    ).all()
    return {f.id_paciente: f"{f.nombres} {f.apellidos}" for f in filas}


def _nombres_usuarios(db: Session, id_clinica: int, ids: Sequence[int]) -> Dict[int, str]:
    ids = [i for i in set(ids) if i is not None]
    if not ids:
        return {}
    filas = db.execute(
        select(Usuario.id_usuario, Usuario.nombres, Usuario.apellidos).where(
            Usuario.id_usuario.in_(ids), Usuario.id_clinica == id_clinica
        )
    ).all()
    return {f.id_usuario: f"{f.nombres} {f.apellidos}" for f in filas}


def _codigos_fuentes(db: Session, id_clinica: int, ids: Sequence[int]) -> Dict[int, str]:
    ids = [i for i in set(ids) if i is not None]
    if not ids:
        return {}
    filas = db.execute(
        select(FuenteLaboratorio.id_fuente, FuenteLaboratorio.codigo).where(
            FuenteLaboratorio.id_fuente.in_(ids), FuenteLaboratorio.id_clinica == id_clinica
        )
    ).all()
    return {f.id_fuente: f.codigo for f in filas}


def construir_respuestas(
    db: Session, ctx: Contexto, permisos: Permisos, resultados: Sequence[ResultadoLaboratorio], detalle: bool
) -> List[Dict[str, Any]]:
    """Diccionarios listos para los esquemas de respuesta, con la redacción por permisos del contrato.

    RECEPCION (sin ``documents:read:lab_results``) no recibe ``observaciones`` ni ``hash_archivo``;
    ``datos_correspondencia`` solo se entrega con ``lab_results:review``. ``archivo_url`` nunca se expone.
    """
    id_clinica = ctx.id_clinica
    pacientes = _nombres_pacientes(db, id_clinica, [r.id_paciente for r in resultados])
    usuarios = _nombres_usuarios(db, id_clinica, [r.registrado_por for r in resultados])
    fuentes = _codigos_fuentes(db, id_clinica, [r.id_fuente for r in resultados])
    salida = []
    for r in resultados:
        item = {
            "id_resultado": r.id_resultado,
            "id_clinica": r.id_clinica,
            "estado": r.estado,
            "origen": r.origen,
            "id_paciente": r.id_paciente,
            "paciente_nombre": pacientes.get(r.id_paciente),
            "id_orden": r.id_orden,
            "id_examen": r.id_examen,
            "codigo_examen": r.codigo_examen,
            "nombre_examen": r.nombre_examen,
            "laboratorio_origen": r.laboratorio_origen,
            "fecha_realizacion": r.fecha_realizacion,
            "nombre_archivo": r.nombre_archivo,
            "content_type": r.content_type,
            "tamano_bytes": r.tamano_bytes,
            "hash_archivo": r.hash_archivo if permisos.descarga else None,
            "id_documento": r.id_documento,
            "id_fuente": r.id_fuente,
            "fuente_codigo": fuentes.get(r.id_fuente),
            "id_externo": r.id_externo,
            "id_sincronizacion": r.id_sincronizacion,
            "motivo_pendiente": r.motivo_pendiente,
            "registrado_por": r.registrado_por,
            "registrado_por_nombre": usuarios.get(r.registrado_por),
            "proceso": r.proceso,
            "registrado_en": r.registrado_en,
            "resuelto_por": r.resuelto_por,
            "resuelto_en": r.resuelto_en,
            "motivo_resolucion": r.motivo_resolucion,
        }
        if detalle:
            item["observaciones"] = r.observaciones if permisos.descarga else None
            item["datos_correspondencia"] = r.datos_correspondencia if permisos.review else None
        salida.append(item)
    return salida


def listar(
    db: Session,
    ctx: Contexto,
    *,
    page: int,
    page_size: int,
    estado: Optional[str] = None,
    id_paciente: Optional[int] = None,
    codigo_examen: Optional[str] = None,
    laboratorio_origen: Optional[str] = None,
    origen: Optional[str] = None,
    id_fuente: Optional[int] = None,
    fecha_desde: Optional[date] = None,
    fecha_hasta: Optional[date] = None,
    solo_paciente: Optional[int] = None,
):
    """Listado paginado dentro de la clínica de la sesión, con el alcance por rol del contrato."""
    permisos = permisos_efectivos(db, ctx)
    estado_efectivo = estado or "INCORPORADO"
    if estado_efectivo != "INCORPORADO" and not permisos.review:
        raise _denegar_estado()

    id_paciente_efectivo = id_paciente
    if solo_paciente is not None:
        id_paciente_efectivo = solo_paciente
    elif ctx.rol == ROL_PACIENTE:
        id_paciente_efectivo = _id_paciente_propio(db, ctx)

    condiciones = [
        ResultadoLaboratorio.id_clinica == ctx.id_clinica,
        ResultadoLaboratorio.estado == estado_efectivo,
    ]
    if id_paciente_efectivo is not None:
        condiciones.append(ResultadoLaboratorio.id_paciente == id_paciente_efectivo)
    if codigo_examen:
        condiciones.append(func.upper(ResultadoLaboratorio.codigo_examen) == codigo_examen.strip().upper())
    if laboratorio_origen:
        condiciones.append(ResultadoLaboratorio.laboratorio_origen.ilike(f"%{laboratorio_origen.strip()}%"))
    if origen:
        condiciones.append(ResultadoLaboratorio.origen == origen)
    if id_fuente is not None:
        condiciones.append(ResultadoLaboratorio.id_fuente == id_fuente)
    if fecha_desde:
        condiciones.append(ResultadoLaboratorio.fecha_realizacion >= fecha_desde)
    if fecha_hasta:
        condiciones.append(ResultadoLaboratorio.fecha_realizacion <= fecha_hasta)

    total = db.execute(select(func.count()).select_from(ResultadoLaboratorio).where(*condiciones)).scalar_one()
    filas = list(
        db.execute(
            select(ResultadoLaboratorio)
            .where(*condiciones)
            .order_by(ResultadoLaboratorio.registrado_en.desc(), ResultadoLaboratorio.id_resultado.desc())
            .limit(page_size)
            .offset((page - 1) * page_size)
        ).scalars()
    )
    items = construir_respuestas(db, ctx, permisos, filas, detalle=False)
    return {
        "items": items,
        "total": total,
        "page": page,
        "page_size": page_size,
        "total_pages": max(1, math.ceil(total / page_size)),
    }


def listar_de_paciente(db: Session, ctx: Contexto, id_paciente: int, **filtros):
    """Resultados ``INCORPORADO`` en el expediente de un paciente de la clínica."""
    if ctx.rol == ROL_PACIENTE and id_paciente != _id_paciente_propio(db, ctx):
        raise ResultadoError(404, "PACIENTE_NO_ENCONTRADO", "Paciente no encontrado.")
    buscar_paciente(db, ctx.id_clinica, id_paciente)
    return listar(db, ctx, estado="INCORPORADO", solo_paciente=id_paciente, **filtros)


def listar_propios(db: Session, ctx: Contexto, **filtros):
    """Resultados ``INCORPORADO`` del paciente autenticado."""
    return listar(db, ctx, estado="INCORPORADO", solo_paciente=_id_paciente_propio(db, ctx), **filtros)


def _no_encontrado() -> ResultadoError:
    return ResultadoError(404, "RESULTADO_NO_ENCONTRADO", "Resultado no encontrado.")


def obtener_visible(db: Session, ctx: Contexto, permisos: Permisos, id_resultado: int) -> ResultadoLaboratorio:
    """Resultado de la clínica visible para el usuario; si no, 404 indistinguible de "no existe"."""
    resultado = db.execute(
        select(ResultadoLaboratorio).where(
            ResultadoLaboratorio.id_resultado == id_resultado,
            ResultadoLaboratorio.id_clinica == ctx.id_clinica,
        )
    ).scalar_one_or_none()
    if resultado is None:
        raise _no_encontrado()
    if resultado.estado != "INCORPORADO" and not permisos.review:
        raise _no_encontrado()
    if ctx.rol == ROL_PACIENTE:
        if resultado.estado != "INCORPORADO" or resultado.id_paciente != _id_paciente_propio(db, ctx):
            raise _no_encontrado()
    return resultado


def detalle(db: Session, ctx: Contexto, id_resultado: int) -> Dict[str, Any]:
    permisos = permisos_efectivos(db, ctx)
    resultado = obtener_visible(db, ctx, permisos, id_resultado)
    return construir_respuestas(db, ctx, permisos, [resultado], detalle=True)[0]


def respuesta_de(db: Session, ctx: Contexto, resultado: ResultadoLaboratorio) -> Dict[str, Any]:
    return construir_respuestas(db, ctx, permisos_efectivos(db, ctx), [resultado], detalle=True)[0]


def descargar(db: Session, ctx: Contexto, id_resultado: int):
    """Contenido, tipo real y nombre del archivo de un resultado ``INCORPORADO``; audita la descarga."""
    permisos = permisos_efectivos(db, ctx)
    resultado = obtener_visible(db, ctx, permisos, id_resultado)
    if resultado.estado != "INCORPORADO":
        raise _no_encontrado()
    contenido = storage.read(resultado.archivo_url)
    if contenido is None:
        raise ResultadoError(404, "ARCHIVO_NO_ENCONTRADO", "El archivo no se encuentra en el almacenamiento.")
    contenido_tipo = resultado.content_type
    nombre = resultado.nombre_archivo
    try:
        _auditar(
            db, ctx, resultado, "DESCARGAR_RESULTADO_LABORATORIO",
            f"Descarga del resultado {resultado.id_resultado}",
        )
        db.commit()
    except Exception:
        db.rollback()
        raise
    return contenido, contenido_tipo, nombre


# --------------------------------------------------------------------------- #
# Revisión: resolver pendientes y anular
# --------------------------------------------------------------------------- #
def _estado_no_permitido(actual: str, requerido: str) -> ResultadoError:
    return ResultadoError(
        409, "ESTADO_NO_PERMITIDO",
        f"El resultado está en estado {actual}; la operación requiere {requerido}.",
    )


def _bloquear(db: Session, ctx: Contexto, id_resultado: int) -> ResultadoLaboratorio:
    resultado = db.execute(
        select(ResultadoLaboratorio)
        .where(
            ResultadoLaboratorio.id_resultado == id_resultado,
            ResultadoLaboratorio.id_clinica == ctx.id_clinica,
        )
        .with_for_update()
    ).scalar_one_or_none()
    if resultado is None:
        raise _no_encontrado()
    return resultado


def resolver(
    db: Session,
    ctx: Contexto,
    id_resultado: int,
    *,
    accion: str,
    id_paciente: Optional[int] = None,
    codigo_examen: Optional[str] = None,
    id_orden: Optional[int] = None,
    motivo: Optional[str] = None,
) -> ResultadoLaboratorio:
    resultado = _bloquear(db, ctx, id_resultado)
    if resultado.estado != "PENDIENTE_REVISION":
        db.rollback()
        raise _estado_no_permitido(resultado.estado, "PENDIENTE_REVISION")
    ahora = datetime.now(timezone.utc)
    try:
        if accion == "ASIGNAR":
            paciente = buscar_paciente(db, ctx.id_clinica, id_paciente)
            examen = buscar_examen(db, ctx.id_clinica, codigo_examen)
            codigo = str(examen.codigo).strip().upper()
            if id_orden is not None:
                validar_orden(db, ctx.id_clinica, id_orden, paciente.id_paciente, codigo)
            resultado.id_paciente = paciente.id_paciente
            resultado.id_examen = examen.id_examen
            resultado.codigo_examen = codigo
            resultado.nombre_examen = examen.nombre
            resultado.id_orden = id_orden
            resultado.estado = "INCORPORADO"
            resultado.resuelto_por = ctx.id_usuario
            resultado.resuelto_en = ahora
            db.flush()
            documento = _documento_para(resultado, ctx.id_usuario, f"{paciente.nombres} {paciente.apellidos}")
            db.add(documento)
            db.flush()
            resultado.id_documento = documento.id_documento
            _auditar(
                db, ctx, resultado, "RESOLVER_RESULTADO_LABORATORIO",
                f"Resultado pendiente asignado al paciente {paciente.id_paciente}",
                anteriores={"estado": "PENDIENTE_REVISION", "id_paciente": None},
                nuevos={
                    "estado": "INCORPORADO", "id_paciente": paciente.id_paciente,
                    "codigo_examen": codigo, "id_orden": id_orden, "id_documento": documento.id_documento,
                },
            )
        else:
            resultado.estado = "ANULADO"
            resultado.motivo_resolucion = motivo
            resultado.resuelto_por = ctx.id_usuario
            resultado.resuelto_en = ahora
            db.flush()
            _auditar(
                db, ctx, resultado, "RESOLVER_RESULTADO_LABORATORIO",
                "Resultado pendiente descartado",
                anteriores={"estado": "PENDIENTE_REVISION"},
                nuevos={"estado": "ANULADO", "motivo_resolucion": motivo},
            )
        db.commit()
    except Exception:
        db.rollback()
        raise
    db.refresh(resultado)
    return resultado


def anular(db: Session, ctx: Contexto, id_resultado: int, motivo: str) -> ResultadoLaboratorio:
    """Baja lógica de un resultado ``INCORPORADO`` y de su documento clínico (nunca borrado físico)."""
    resultado = _bloquear(db, ctx, id_resultado)
    if resultado.estado != "INCORPORADO":
        db.rollback()
        raise _estado_no_permitido(resultado.estado, "INCORPORADO")
    try:
        anterior = {"estado": "INCORPORADO", "id_documento": resultado.id_documento}
        resultado.estado = "ANULADO"
        resultado.motivo_resolucion = motivo
        resultado.resuelto_por = ctx.id_usuario
        resultado.resuelto_en = datetime.now(timezone.utc)
        if resultado.id_documento is not None:
            documento = db.execute(
                select(DocumentoClinico).where(
                    DocumentoClinico.id_documento == resultado.id_documento,
                    DocumentoClinico.id_clinica == ctx.id_clinica,
                )
            ).scalar_one_or_none()
            if documento is not None:
                documento.estado = "ANULADO"
        db.flush()
        _auditar(
            db, ctx, resultado, "ANULAR_RESULTADO_LABORATORIO",
            f"Resultado {resultado.id_resultado} anulado",
            anteriores=anterior,
            nuevos={"estado": "ANULADO", "motivo_resolucion": motivo},
        )
        db.commit()
    except Exception:
        db.rollback()
        raise
    db.refresh(resultado)
    return resultado
