"""Router CU29: vinculaciones médico-entidad.

Las rutas literales (`/candidatos`, `/mias`) se registran antes de
`/{id_vinculacion}` para que FastAPI no las interprete como identificadores.
"""
from typing import Optional

from fastapi import APIRouter, Depends, Query, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_async_db
from app.modules.appointments.doctor_entity_links import service
from app.modules.appointments.doctor_entity_links.dependencies import require_entity_admin
from app.modules.appointments.doctor_entity_links.schemas import (
    AsignacionesVinculacion,
    CandidatoVinculacion,
    VinculacionCreate,
    VinculacionCreateResponse,
    VinculacionDetalleResponse,
    VinculacionEstadoUpdate,
    VinculacionListResponse,
    EntidadesMedicoVinculadasResponse,
    VinculacionRechazo,
    VinculacionResponse,
)
from app.modules.auth.dependencies import get_current_user
from app.modules.auth.models import Usuario

router = APIRouter(prefix="/medicos/vinculaciones", tags=["Vinculación médico-entidad (CU29)"])

ESTADOS_QUERY = "^(INVITADO|ACTIVO|SUSPENDIDO|RECHAZADO|BAJA)$"


def _ip(request: Request) -> Optional[str]:
    return request.client.host if request.client is not None else None


@router.get(
    "/candidatos",
    response_model=CandidatoVinculacion,
    summary="Buscar candidato médico por coincidencia exacta",
)
async def buscar_candidato(
    criterio: str = Query(..., pattern="^(correo|documento_identidad|matricula_profesional)$"),
    valor: str = Query(..., min_length=3, max_length=120),
    db: AsyncSession = Depends(get_async_db),
    actor: Usuario = Depends(require_entity_admin),
):
    return await service.buscar_candidato(db, criterio, valor)


@router.get(
    "/mias",
    response_model=VinculacionListResponse,
    summary="Invitaciones y participaciones del médico autenticado",
)
async def listar_mias(
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=100),
    estado: Optional[str] = Query(None, pattern=ESTADOS_QUERY),
    db: AsyncSession = Depends(get_async_db),
    actor: Usuario = Depends(get_current_user),
):
    return await service.listar_mias(db, actor, page, per_page, estado)


@router.get(
    "/mias/entidades",
    response_model=EntidadesMedicoVinculadasResponse,
    summary="Entidades con vínculo activo del médico autenticado",
)
async def listar_mias_entidades(
    db: AsyncSession = Depends(get_async_db),
    actor: Usuario = Depends(get_current_user),
):
    return await service.listar_mias_entidades(db, actor)


@router.post(
    "",
    response_model=VinculacionCreateResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Crear invitación de vinculación médico-entidad",
)
async def crear_vinculacion(
    datos: VinculacionCreate,
    request: Request,
    db: AsyncSession = Depends(get_async_db),
    actor: Usuario = Depends(require_entity_admin),
):
    return await service.crear_vinculacion(db, actor, datos, _ip(request))


@router.get(
    "",
    response_model=VinculacionListResponse,
    summary="Listar vínculos de la entidad actual",
)
async def listar_vinculaciones(
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=100),
    estado: Optional[str] = Query(None, pattern=ESTADOS_QUERY),
    q: Optional[str] = Query(None, max_length=100),
    db: AsyncSession = Depends(get_async_db),
    actor: Usuario = Depends(require_entity_admin),
):
    return await service.listar_vinculaciones(
        db, int(actor.id_clinica), page, per_page, estado, q
    )


@router.post(
    "/{id_vinculacion}/aceptar",
    response_model=VinculacionResponse,
    summary="Aceptar una invitación propia",
)
async def aceptar_invitacion(
    id_vinculacion: int,
    request: Request,
    db: AsyncSession = Depends(get_async_db),
    actor: Usuario = Depends(get_current_user),
):
    return await service.aceptar_invitacion(db, actor, id_vinculacion, _ip(request))


@router.post(
    "/{id_vinculacion}/rechazar",
    response_model=VinculacionResponse,
    summary="Rechazar una invitación propia",
)
async def rechazar_invitacion(
    id_vinculacion: int,
    datos: VinculacionRechazo,
    request: Request,
    db: AsyncSession = Depends(get_async_db),
    actor: Usuario = Depends(get_current_user),
):
    return await service.rechazar_invitacion(
        db, actor, id_vinculacion, datos, _ip(request)
    )


@router.put(
    "/{id_vinculacion}/asignaciones",
    response_model=VinculacionResponse,
    summary="Reemplazar roles y especialidades del vínculo",
)
async def reemplazar_asignaciones(
    id_vinculacion: int,
    datos: AsignacionesVinculacion,
    request: Request,
    db: AsyncSession = Depends(get_async_db),
    actor: Usuario = Depends(require_entity_admin),
):
    return await service.reemplazar_asignaciones(
        db, actor, id_vinculacion, datos, _ip(request)
    )


@router.patch(
    "/{id_vinculacion}/estado",
    response_model=VinculacionResponse,
    summary="Suspender, reactivar o dar de baja un vínculo",
)
async def cambiar_estado(
    id_vinculacion: int,
    datos: VinculacionEstadoUpdate,
    request: Request,
    db: AsyncSession = Depends(get_async_db),
    actor: Usuario = Depends(require_entity_admin),
):
    return await service.cambiar_estado(db, actor, id_vinculacion, datos, _ip(request))


@router.get(
    "/{id_vinculacion}",
    response_model=VinculacionDetalleResponse,
    summary="Detalle e historial de un vínculo",
)
async def obtener_detalle(
    id_vinculacion: int,
    db: AsyncSession = Depends(get_async_db),
    actor: Usuario = Depends(require_entity_admin),
):
    return await service.obtener_detalle(db, int(actor.id_clinica), id_vinculacion)
