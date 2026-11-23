"""Endpoints de resultados de laboratorio (CU11, bloque A).

Contrato: ``openspec/contracts/resultados-laboratorio.md`` secciones 3.1 a 3.8. Endpoints síncronos (``def``)
con la sesión ``get_db`` existente (excepción CU11 de AGENTS.md sección 5). Las rutas fijas (``/me``) se
declaran antes que ``/{id_resultado}``. No existe ningún endpoint de borrado: las bajas son lógicas.
"""
from datetime import date
from typing import List, Literal, Optional
from urllib.parse import quote

from anyio import from_thread
from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, Request, Response, UploadFile, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.modules.medical_records.laboratory_results import files, service
from app.modules.medical_records.laboratory_results.dependencies import (
    PERMISO_CREATE,
    PERMISO_DESCARGA,
    PERMISO_READ,
    PERMISO_REVIEW,
    Contexto,
    requerir_permisos,
)
from app.modules.medical_records.laboratory_results.schemas import (
    AnularResultadoRequest,
    ResolverPendienteRequest,
    ResultadoLaboratorioListResponse,
    ResultadoLaboratorioResponse,
)

router = APIRouter(prefix="/api/v1/resultados-laboratorio", tags=["Resultados de Laboratorio (CU11)"])
# Expediente del paciente: mismo patrón que `/api/v1/pacientes/{id_paciente}/documentos` de CU12.
pacientes_router = APIRouter(prefix="/api/v1/pacientes", tags=["Resultados de Laboratorio (CU11)"])

Estado = Literal["INCORPORADO", "PENDIENTE_REVISION", "ANULADO"]
Origen = Literal["MANUAL", "SINCRONIZADO"]


def _http(exc) -> HTTPException:
    """Traduce errores de dominio al formato ``{"detail": {"codigo", "mensaje"}}`` del contrato."""
    return HTTPException(
        status_code=exc.status_code,
        detail={"codigo": exc.codigo, "mensaje": exc.mensaje},
    )


def _error_validacion(campo: str, mensaje: str) -> HTTPException:
    """422 con la misma forma que los errores de validación de FastAPI."""
    return HTTPException(
        status_code=422,
        detail=[{"type": "value_error", "loc": ["body", campo], "msg": mensaje}],
    )


CAMPOS_PROHIBIDOS = ("id_clinica", "tenant_id", "estado", "origen")


def rechazar_campos_prohibidos(request: Request) -> None:
    """422 si el formulario trae campos que solo decide el servidor (Tenant Injection o estado forzado).

    No se declaran como parámetros para que no figuren como campos aceptados en OpenAPI. El formulario ya
    fue leído por FastAPI; ``request.form()`` devuelve el resultado en caché.
    """
    formulario = from_thread.run(request.form)
    for nombre in CAMPOS_PROHIBIDOS:
        if nombre in formulario:
            raise _error_validacion(nombre, f"El campo '{nombre}' no es aceptado: lo determina el servidor.")


# --------------------------------------------------------------------------- #
# 3.1 Carga manual
# --------------------------------------------------------------------------- #
@router.post(
    "",
    response_model=ResultadoLaboratorioResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Carga manual de un resultado de laboratorio",
    description="multipart/form-data: archivo PDF/JPG/PNG (máx. 10 MB) más paciente, estudio, fecha y laboratorio de origen.",
)
def crear_resultado(
    archivo: UploadFile = File(...),
    id_paciente: int = Form(...),
    codigo_examen: str = Form(...),
    fecha_realizacion: date = Form(...),
    laboratorio_origen: str = Form(...),
    id_orden: Optional[int] = Form(None),
    observaciones: Optional[str] = Form(None),
    ctx: Contexto = Depends(requerir_permisos(PERMISO_CREATE)),
    _prohibidos: None = Depends(rechazar_campos_prohibidos),
    db: Session = Depends(get_db),
):
    codigo_examen = codigo_examen.strip()
    laboratorio_origen = laboratorio_origen.strip()
    if not codigo_examen or len(codigo_examen) > 50:
        raise _error_validacion("codigo_examen", "El código del estudio es obligatorio (máximo 50 caracteres).")
    if not laboratorio_origen or len(laboratorio_origen) > 200:
        raise _error_validacion("laboratorio_origen", "El laboratorio de origen es obligatorio (máximo 200 caracteres).")
    if id_paciente < 1:
        raise _error_validacion("id_paciente", "El paciente es obligatorio.")
    if id_orden is not None and id_orden < 1:
        raise _error_validacion("id_orden", "El identificador de la orden no es válido.")
    if fecha_realizacion > service.hoy():
        raise _error_validacion("fecha_realizacion", "La fecha de realización no puede ser posterior a la fecha actual.")
    if observaciones is not None:
        observaciones = observaciones.strip() or None
        if observaciones is not None and len(observaciones) > 2000:
            raise _error_validacion("observaciones", "Las observaciones admiten hasta 2000 caracteres.")

    try:
        validado = files.leer_y_validar(archivo.file, archivo.filename, archivo.content_type)
    except files.ArchivoError as exc:
        raise _http(exc) from exc

    try:
        resultado = service.crear_manual(
            db, ctx,
            id_paciente=id_paciente,
            codigo_examen=codigo_examen,
            fecha_realizacion=fecha_realizacion,
            laboratorio_origen=laboratorio_origen,
            id_orden=id_orden,
            observaciones=observaciones,
            archivo=validado,
        )
    except service.ResultadoError as exc:
        raise _http(exc) from exc
    return service.respuesta_de(db, ctx, resultado)


# --------------------------------------------------------------------------- #
# 3.2 Listado de la clínica
# --------------------------------------------------------------------------- #
@router.get(
    "",
    response_model=ResultadoLaboratorioListResponse,
    summary="Listar resultados de la clínica",
    description="Por defecto solo INCORPORADO; PENDIENTE_REVISION y ANULADO exigen lab_results:review.",
)
def listar_resultados(
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    id_paciente: Optional[int] = Query(None, ge=1),
    codigo_examen: Optional[str] = Query(None, max_length=50),
    laboratorio_origen: Optional[str] = Query(None, max_length=200),
    origen: Optional[Origen] = Query(None),
    id_fuente: Optional[int] = Query(None, ge=1),
    fecha_desde: Optional[date] = Query(None),
    fecha_hasta: Optional[date] = Query(None),
    estado: Optional[Estado] = Query(None),
    ctx: Contexto = Depends(requerir_permisos(PERMISO_READ)),
    db: Session = Depends(get_db),
):
    try:
        return service.listar(
            db, ctx, page=page, page_size=page_size, estado=estado, id_paciente=id_paciente,
            codigo_examen=codigo_examen, laboratorio_origen=laboratorio_origen, origen=origen,
            id_fuente=id_fuente, fecha_desde=fecha_desde, fecha_hasta=fecha_hasta,
        )
    except service.ResultadoError as exc:
        raise _http(exc) from exc


# --------------------------------------------------------------------------- #
# 3.4 Resultados del paciente autenticado (antes que /{id_resultado})
# --------------------------------------------------------------------------- #
@router.get(
    "/me",
    response_model=ResultadoLaboratorioListResponse,
    summary="Resultados incorporados del paciente autenticado",
)
def listar_mis_resultados(
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    codigo_examen: Optional[str] = Query(None, max_length=50),
    fecha_desde: Optional[date] = Query(None),
    fecha_hasta: Optional[date] = Query(None),
    ctx: Contexto = Depends(requerir_permisos(PERMISO_READ)),
    db: Session = Depends(get_db),
):
    try:
        return service.listar_propios(
            db, ctx, page=page, page_size=page_size, codigo_examen=codigo_examen,
            fecha_desde=fecha_desde, fecha_hasta=fecha_hasta,
        )
    except service.ResultadoError as exc:
        raise _http(exc) from exc


# --------------------------------------------------------------------------- #
# 3.3 Expediente del paciente
# --------------------------------------------------------------------------- #
@pacientes_router.get(
    "/{id_paciente}/resultados-laboratorio",
    response_model=ResultadoLaboratorioListResponse,
    summary="Resultados incorporados en el expediente de un paciente",
)
def listar_resultados_del_paciente(
    id_paciente: int,
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    codigo_examen: Optional[str] = Query(None, max_length=50),
    laboratorio_origen: Optional[str] = Query(None, max_length=200),
    origen: Optional[Origen] = Query(None),
    fecha_desde: Optional[date] = Query(None),
    fecha_hasta: Optional[date] = Query(None),
    ctx: Contexto = Depends(requerir_permisos(PERMISO_READ)),
    db: Session = Depends(get_db),
):
    try:
        return service.listar_de_paciente(
            db, ctx, id_paciente, page=page, page_size=page_size, codigo_examen=codigo_examen,
            laboratorio_origen=laboratorio_origen, origen=origen,
            fecha_desde=fecha_desde, fecha_hasta=fecha_hasta,
        )
    except service.ResultadoError as exc:
        raise _http(exc) from exc


# --------------------------------------------------------------------------- #
# 3.5 Detalle
# --------------------------------------------------------------------------- #
@router.get(
    "/{id_resultado}",
    response_model=ResultadoLaboratorioResponse,
    summary="Detalle de un resultado",
)
def obtener_resultado(
    id_resultado: int,
    ctx: Contexto = Depends(requerir_permisos(PERMISO_READ)),
    db: Session = Depends(get_db),
):
    try:
        return service.detalle(db, ctx, id_resultado)
    except service.ResultadoError as exc:
        raise _http(exc) from exc


# --------------------------------------------------------------------------- #
# 3.6 Descarga del archivo
# --------------------------------------------------------------------------- #
def _content_disposition(nombre: str) -> str:
    seguro = "".join(c if (c.isascii() and (c.isalnum() or c in "._- ()")) else "_" for c in nombre) or "resultado"
    return f"attachment; filename=\"{seguro}\"; filename*=UTF-8''{quote(nombre, safe='')}"


@router.get(
    "/{id_resultado}/archivo",
    summary="Descargar el archivo de un resultado incorporado",
    description="Content-Type real (application/pdf, image/jpeg o image/png). Exige lab_results:read y documents:read:lab_results.",
    responses={200: {"content": {"application/pdf": {}, "image/jpeg": {}, "image/png": {}}}},
)
def descargar_archivo(
    id_resultado: int,
    ctx: Contexto = Depends(requerir_permisos(PERMISO_READ, PERMISO_DESCARGA)),
    db: Session = Depends(get_db),
):
    try:
        contenido, content_type, nombre = service.descargar(db, ctx, id_resultado)
    except service.ResultadoError as exc:
        raise _http(exc) from exc
    return Response(
        content=contenido,
        media_type=content_type,
        headers={
            "Content-Disposition": _content_disposition(nombre),
            "X-Content-Type-Options": "nosniff",
        },
    )


# --------------------------------------------------------------------------- #
# 3.7 y 3.8 Revisión
# --------------------------------------------------------------------------- #
@router.post(
    "/{id_resultado}/resolver",
    response_model=ResultadoLaboratorioResponse,
    summary="Resolver un resultado pendiente de revisión",
)
def resolver_resultado(
    id_resultado: int,
    datos: ResolverPendienteRequest,
    ctx: Contexto = Depends(requerir_permisos(PERMISO_REVIEW)),
    db: Session = Depends(get_db),
):
    try:
        resultado = service.resolver(
            db, ctx, id_resultado, accion=datos.accion, id_paciente=datos.id_paciente,
            codigo_examen=datos.codigo_examen, id_orden=datos.id_orden, motivo=datos.motivo,
        )
    except service.ResultadoError as exc:
        raise _http(exc) from exc
    return service.respuesta_de(db, ctx, resultado)


@router.post(
    "/{id_resultado}/anular",
    response_model=ResultadoLaboratorioResponse,
    summary="Anular (baja lógica) un resultado incorporado",
)
def anular_resultado(
    id_resultado: int,
    datos: AnularResultadoRequest,
    ctx: Contexto = Depends(requerir_permisos(PERMISO_REVIEW)),
    db: Session = Depends(get_db),
):
    try:
        resultado = service.anular(db, ctx, id_resultado, datos.motivo)
    except service.ResultadoError as exc:
        raise _http(exc) from exc
    return service.respuesta_de(db, ctx, resultado)
