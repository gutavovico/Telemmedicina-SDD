"""Endpoints de fuentes y sincronización de laboratorio (CU11, bloque B).

Contrato: ``openspec/contracts/resultados-laboratorio.md`` secciones 4.1 a 4.7. Endpoints síncronos (``def``)
con la sesión ``get_db`` existente (excepción CU11 de AGENTS.md sección 5). Todos exigen ``lab_results:sync`` y la
clínica sale únicamente de la sesión: ni el cuerpo, ni el manifiesto, ni ``X-Tenant-ID`` la determinan.
"""
from datetime import date
from typing import List, Literal, Optional

from anyio import from_thread
from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, Request, UploadFile, status
from sqlalchemy.orm import Session

from app.core.body_limit import ContentLengthLimitedRoute
from app.core.database import get_db
from app.modules.medical_records.laboratory_sync import service
from app.modules.medical_records.laboratory_sync.dependencies import Contexto, requerir_sync
from app.modules.medical_records.laboratory_sync.schemas import (
    EstadoSincronizacion,
    FuenteLaboratorioCreateRequest,
    FuenteLaboratorioListResponse,
    FuenteLaboratorioResponse,
    FuenteLaboratorioUpdateRequest,
    SincronizacionListResponse,
    SincronizacionResponse,
)


def _http(exc) -> HTTPException:
    """Traduce errores de dominio al formato ``{"detail": {"codigo", "mensaje"}}`` del contrato."""
    return HTTPException(status_code=exc.status_code, detail={"codigo": exc.codigo, "mensaje": exc.mensaje})


class RutaDeLote(ContentLengthLimitedRoute):
    """Rechaza por ``Content-Length`` (más de 100 MB) antes de leer el cuerpo: ``422 LOTE_INVALIDO``."""

    max_content_length = service.TOPE_PETICION_BYTES

    def exceeded_error(self, content_length: int) -> Exception:
        return _http(service.lote_invalido("La petición supera el tamaño máximo de 100 MB."))


def rechazar_campos_de_clinica(request: Request) -> None:
    """422 si el multipart trae ``id_clinica``/``tenant_id`` como parte propia (Tenant Injection)."""
    formulario = from_thread.run(request.form)
    for campo in service.CAMPOS_DE_CLINICA:
        if campo in formulario:
            raise _http(service.lote_invalido(f"El campo '{campo}' no es aceptado: la clínica la determina la sesión."))


fuentes_router = APIRouter(prefix="/api/v1/fuentes-laboratorio", tags=["Fuentes de Laboratorio (CU11)"])
sincronizaciones_router = APIRouter(
    prefix="/api/v1/sincronizaciones-laboratorio",
    tags=["Sincronización de Laboratorio (CU11)"],
    route_class=RutaDeLote,
)


# --------------------------------------------------------------------------- #
# 4.1 a 4.3 Fuentes
# --------------------------------------------------------------------------- #
@fuentes_router.get(
    "",
    response_model=FuenteLaboratorioListResponse,
    summary="Listar fuentes de laboratorio de la clínica",
)
def listar_fuentes(
    activa: Optional[Literal["SI", "NO"]] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    ctx: Contexto = Depends(requerir_sync),
    db: Session = Depends(get_db),
):
    return service.listar_fuentes(db, ctx, activa=activa, page=page, page_size=page_size)


@fuentes_router.post(
    "",
    response_model=FuenteLaboratorioResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Crear una fuente de laboratorio",
)
def crear_fuente(
    datos: FuenteLaboratorioCreateRequest,
    ctx: Contexto = Depends(requerir_sync),
    db: Session = Depends(get_db),
):
    try:
        return service.crear_fuente(db, ctx, codigo=datos.codigo, nombre=datos.nombre)
    except service.SincronizacionError as exc:
        raise _http(exc) from exc


@fuentes_router.patch(
    "/{id_fuente}",
    response_model=FuenteLaboratorioResponse,
    summary="Modificar el nombre o activar/desactivar una fuente",
)
def actualizar_fuente(
    id_fuente: int,
    datos: FuenteLaboratorioUpdateRequest,
    ctx: Contexto = Depends(requerir_sync),
    db: Session = Depends(get_db),
):
    try:
        return service.actualizar_fuente(db, ctx, id_fuente, nombre=datos.nombre, activa=datos.activa)
    except service.SincronizacionError as exc:
        raise _http(exc) from exc


# --------------------------------------------------------------------------- #
# 4.4 a 4.7 Sincronizaciones
# --------------------------------------------------------------------------- #
@sincronizaciones_router.post(
    "",
    response_model=SincronizacionResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Ingestar un lote de resultados de una fuente",
    description=(
        "multipart/form-data: `manifiesto` (JSON con `fuente` e `items`, hasta 50) y `archivos` (el nombre de cada "
        "parte debe coincidir con `items[].nombre_archivo`). Idempotente por (clínica, fuente, id_externo)."
    ),
)
def ejecutar_sincronizacion(
    manifiesto: Optional[str] = Form(None),
    archivos: List[UploadFile] = File(default_factory=list),
    ctx: Contexto = Depends(requerir_sync),
    _clinica: None = Depends(rechazar_campos_de_clinica),
    db: Session = Depends(get_db),
):
    try:
        datos = service.parsear_manifiesto(manifiesto)
        partes = service.indexar_archivos(archivos)
        return service.ejecutar_lote(db, ctx, datos, partes)
    except service.SincronizacionError as exc:
        raise _http(exc) from exc


@sincronizaciones_router.get(
    "",
    response_model=SincronizacionListResponse,
    summary="Listar sincronizaciones de la clínica (sin ítems)",
)
def listar_sincronizaciones(
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    id_fuente: Optional[int] = Query(None, ge=1),
    estado: Optional[EstadoSincronizacion] = Query(None),
    fecha_desde: Optional[date] = Query(None),
    fecha_hasta: Optional[date] = Query(None),
    ctx: Contexto = Depends(requerir_sync),
    db: Session = Depends(get_db),
):
    return service.listar_sincronizaciones(
        db, ctx, page=page, page_size=page_size, id_fuente=id_fuente, estado=estado,
        fecha_desde=fecha_desde, fecha_hasta=fecha_hasta,
    )


@sincronizaciones_router.get(
    "/{id_sincronizacion}",
    response_model=SincronizacionResponse,
    summary="Detalle de una sincronización con el resultado de cada ítem",
)
def obtener_sincronizacion(
    id_sincronizacion: int,
    ctx: Contexto = Depends(requerir_sync),
    db: Session = Depends(get_db),
):
    try:
        return service.obtener_sincronizacion(db, ctx, id_sincronizacion)
    except service.SincronizacionError as exc:
        raise _http(exc) from exc


@sincronizaciones_router.post(
    "/{id_sincronizacion}/reintentos",
    response_model=SincronizacionResponse,
    summary="Reintentar los ítems en ERROR de una sincronización",
    description="multipart/form-data: `manifiesto` solo con los ítems a reintentar y `archivos` corregidos.",
)
def reintentar_sincronizacion(
    id_sincronizacion: int,
    manifiesto: Optional[str] = Form(None),
    archivos: List[UploadFile] = File(default_factory=list),
    ctx: Contexto = Depends(requerir_sync),
    _clinica: None = Depends(rechazar_campos_de_clinica),
    db: Session = Depends(get_db),
):
    try:
        datos = service.parsear_manifiesto(manifiesto)
        partes = service.indexar_archivos(archivos)
        return service.reintentar(db, ctx, id_sincronizacion, datos, partes)
    except service.SincronizacionError as exc:
        raise _http(exc) from exc
