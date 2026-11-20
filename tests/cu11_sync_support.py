"""Ayudas de pruebas del bloque B de CU11 (fuentes, ingestión por lote, pendientes, reintentos).

Se apoya en ``cu11_support`` (SQLite en memoria, ``get_db`` sobreescrito, dos clínicas, personas y
almacenamiento temporal). Ningún archivo sale de ``tmp_path``.
"""
import json
from datetime import date

from sqlalchemy import null, select

from app.modules.auth.models import Auditoria
from app.modules.medical_records.clinical_documents.models import DocumentoClinico
from app.modules.medical_records.laboratory_orders.models import ExamenLaboratorio, OrdenLaboratorio
from app.modules.medical_records.laboratory_results.models import ResultadoLaboratorio
from app.modules.medical_records.laboratory_sync.models import (
    FuenteLaboratorio,
    SincronizacionLaboratorio,
    SincronizacionLaboratorioItem,
)
from app.modules.medical_records.models import Paciente
from cu11_support import cantidad_de_archivos, pdf_bytes, png_bytes  # noqa: F401  (re-export para las pruebas)

URL_FUENTES = "/api/v1/fuentes-laboratorio"
URL_SYNC = "/api/v1/sincronizaciones-laboratorio"


def item(
    id_externo,
    *,
    ci="1111111",
    complemento="",
    codigo="HEMOGRAMA",
    archivo=None,
    fecha="2026-11-10",
    lab="Laboratorio Central",
    id_orden=None,
    observaciones=None,
):
    """Ítem de manifiesto válido por defecto (paciente 1 de la clínica 1, estudio HEMOGRAMA)."""
    return {
        "id_externo": id_externo,
        "ci": ci,
        "complemento": complemento,
        "codigo_examen": codigo,
        "laboratorio_origen": lab,
        "fecha_realizacion": fecha,
        "nombre_archivo": archivo or f"{id_externo}.pdf",
        "id_orden": id_orden,
        "observaciones": observaciones,
    }


def manifiesto(items, fuente="LAB-CENTRAL", **raiz):
    return json.dumps({"fuente": fuente, "items": items, **raiz})


def _partes_de_archivos(items, archivos):
    """``archivos``: ``{nombre: bytes | (bytes, content_type) | None}``; ``None`` quita la parte (archivo ausente)."""
    contenidos = {}
    for it in items:
        nombre = it.get("nombre_archivo")
        if nombre:  # los ítems rotos a propósito pueden no tener (o tener vacío) el nombre de archivo
            contenidos[nombre] = (pdf_bytes(str(it.get("id_externo", "")).encode()), "application/pdf")
    for nombre, valor in (archivos or {}).items():
        if valor is None:
            contenidos.pop(nombre, None)
        elif isinstance(valor, tuple):
            contenidos[nombre] = valor
        else:
            contenidos[nombre] = (valor, "application/pdf")
    return [("archivos", (nombre, datos, tipo)) for nombre, (datos, tipo) in contenidos.items()]


def post_lote(
    mundo,
    usuario,
    items,
    *,
    archivos=None,
    fuente="LAB-CENTRAL",
    raw=None,
    headers=None,
    campos=None,
    url=URL_SYNC,
):
    """POST multipart de un lote. ``raw`` reemplaza el manifiesto completo (para casos malformados)."""
    if usuario is not None:
        mundo.env.como(usuario)
    datos = {"manifiesto": raw if raw is not None else manifiesto(items, fuente)}
    datos.update(campos or {})
    partes = _partes_de_archivos(items if isinstance(items, list) else [], archivos)
    return mundo.client.post(url, data=datos, files=partes or None, headers=headers or {})


def post_reintento(mundo, usuario, id_sincronizacion, items, **kwargs):
    return post_lote(mundo, usuario, items, url=f"{URL_SYNC}/{id_sincronizacion}/reintentos", **kwargs)


def resultados(mundo, *condiciones):
    with mundo.env.SessionLocal() as db:
        return list(db.execute(select(ResultadoLaboratorio).where(*condiciones).order_by(ResultadoLaboratorio.id_resultado)).scalars())


def resultado_de(mundo, id_externo, id_clinica=1):
    with mundo.env.SessionLocal() as db:
        return db.execute(
            select(ResultadoLaboratorio).where(
                ResultadoLaboratorio.id_clinica == id_clinica, ResultadoLaboratorio.id_externo == id_externo
            )
        ).scalars().first()


def total_resultados(mundo):
    return mundo.env.contar(ResultadoLaboratorio)


def total_sincronizaciones(mundo):
    return mundo.env.contar(SincronizacionLaboratorio)


def total_items(mundo):
    return mundo.env.contar(SincronizacionLaboratorioItem)


def total_documentos_lab(mundo):
    return mundo.env.contar(DocumentoClinico, DocumentoClinico.tipo_documento == "RESULTADO_LAB")


def nada_creado(mundo):
    """Ni sincronización, ni ítems, ni resultados, ni documentos, ni archivos."""
    return (
        total_sincronizaciones(mundo) == 0
        and total_items(mundo) == 0
        and total_resultados(mundo) == 0
        and total_documentos_lab(mundo) == 0
        and cantidad_de_archivos(mundo.almacen) == 0
    )


def auditorias(mundo, accion=None, tabla=None):
    with mundo.env.SessionLocal() as db:
        consulta = select(Auditoria)
        if accion:
            consulta = consulta.where(Auditoria.accion == accion)
        if tabla:
            consulta = consulta.where(Auditoria.tabla_afectada == tabla)
        return list(db.execute(consulta.order_by(Auditoria.id_auditoria)).scalars())


def por_externo(cuerpo):
    """Ítems de la respuesta de una sincronización indexados por ``id_externo``."""
    return {i["id_externo"]: i for i in cuerpo["items"]}


def crear_paciente(mundo, id_clinica, ci, complemento="", nombres="Paula", apellidos="Prueba"):
    """``complemento=None`` guarda un NULL real (con ``None`` el ORM aplicaría el valor por defecto ``''``)."""
    with mundo.env.SessionLocal() as db:
        paciente = Paciente(
            id_clinica=id_clinica, nombres=nombres, apellidos=apellidos, ci=ci,
            complemento=null() if complemento is None else complemento,
            fecha_nacimiento=date(1990, 1, 1), genero="F", telefono="70009999",
        )
        db.add(paciente)
        db.commit()
        return paciente.id_paciente


def crear_fuente_db(mundo, id_clinica, codigo, activa="SI", nombre=None):
    with mundo.env.SessionLocal() as db:
        fuente = FuenteLaboratorio(id_clinica=id_clinica, codigo=codigo, nombre=nombre or f"Fuente {codigo}", activa=activa)
        db.add(fuente)
        db.commit()
        return fuente.id_fuente


def crear_orden_db(mundo, id_clinica, id_paciente, examenes, estado="FIRMADA"):
    with mundo.env.SessionLocal() as db:
        orden = OrdenLaboratorio(
            id_clinica=id_clinica, id_paciente=id_paciente, id_medico=mundo.datos["medico"].id_usuario,
            examenes=[{"codigo": c, "nombre": c} for c in examenes], fecha_orden=date(2026, 11, 1), estado=estado,
        )
        db.add(orden)
        db.commit()
        return orden.id_orden


def crear_examen_db(mundo, id_clinica, codigo, activo="SI"):
    with mundo.env.SessionLocal() as db:
        examen = ExamenLaboratorio(id_clinica=id_clinica, codigo=codigo, nombre=codigo.title(), categoria="OTROS", activo=activo)
        db.add(examen)
        db.commit()
        return examen.id_examen
