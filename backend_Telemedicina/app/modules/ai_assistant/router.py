"""Router REST para el Asistente Inteligente de Tratamiento (CU18).

Prefijo oficial: /api/v1/asistencia-tratamiento
"""
from typing import Optional
from fastapi import APIRouter, Depends, Query, Request, status
from fastapi.responses import JSONResponse
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.modules.ai_assistant import schemas, service
from app.modules.ai_assistant.service import AssistanceError
from app.modules.ai_assistant.dependencies import (
    _obtener_nombre_rol,
    require_assistance_user,
    require_patient_actor,
    validar_acceso_historial_paciente,
)
from app.modules.auth.models import Usuario
from app.modules.medical_records.models import Paciente

router = APIRouter(
    prefix="/api/v1/asistencia-tratamiento",
    tags=["Asistencia Inteligente de Tratamiento (CU18)"],
)


async def assistance_error_handler(request: Request, exc: AssistanceError):
    headers = {}
    if exc.status_code == 429:
        headers["Retry-After"] = "3600"
    return JSONResponse(
        status_code=exc.status_code,
        content={"detail": exc.message, "code": exc.code},
        headers=headers if headers else None,
    )


def _client_ip(request: Request) -> Optional[str]:
    forwarded = request.headers.get("X-Forwarded-For")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else None


@router.post(
    "/evaluar",
    response_model=schemas.EvaluacionTratamientoResponse,
    summary="Solicitar evaluación bajo demanda del tratamiento activo",
)
def solicitar_evaluacion(
    request: Request,
    payload: Optional[schemas.EvaluarTratamientoRequest] = None,
    db: Session = Depends(get_db),
    actor: tuple = Depends(require_patient_actor),
):
    current_user, paciente = actor
    forzar = payload.forzar_recalculo if payload else False
    return service.evaluar_tratamiento(
        db,
        id_clinica=current_user.id_clinica,
        id_paciente=paciente.id_paciente,
        id_usuario=current_user.id_usuario,
        forzar_recalculo=forzar,
        ip_origen=_client_ip(request),
    )


@router.get(
    "/historial",
    response_model=schemas.HistorialEvaluacionResponse,
    summary="Listar el historial paginado de evaluaciones de un paciente",
)
def consultar_historial(
    id_paciente: Optional[int] = Query(default=None, description="Requerido para médicos; se ignora/fuerza el propio para pacientes"),
    page: int = Query(default=1, ge=1, description="Número de página"),
    limit: int = Query(default=10, ge=1, le=50, description="Cantidad por página"),
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_assistance_user),
):
    target_id_paciente = validar_acceso_historial_paciente(db, current_user, id_paciente)
    return service.listar_historial(
        db,
        id_clinica=current_user.id_clinica,
        id_paciente=target_id_paciente,
        page=page,
        limit=limit,
    )


@router.get(
    "/evaluaciones/{id_evaluacion}",
    response_model=schemas.EvaluacionTratamientoResponse,
    summary="Obtener el detalle completo de una evaluación",
)
def obtener_detalle_evaluacion(
    id_evaluacion: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_assistance_user),
):
    resultado = service.obtener_evaluacion_por_id(
        db,
        id_evaluacion=id_evaluacion,
        id_clinica=current_user.id_clinica,
    )
    rol = _obtener_nombre_rol(current_user)
    if rol == "PACIENTE":
        stmt_p = select(Paciente).where(
            Paciente.id_usuario == current_user.id_usuario,
            (Paciente.id_clinica == current_user.id_clinica) | (Paciente.id_clinica.is_(None)),
        )
        paciente_propio = db.execute(stmt_p).scalars().first()
        if not paciente_propio or resultado.id_paciente != paciente_propio.id_paciente:
            raise AssistanceError(
                message="Evaluación no encontrada",
                code="EVALUATION_NOT_FOUND",
                status_code=status.HTTP_404_NOT_FOUND,
            )
    elif rol == "MEDICO":
        validar_acceso_historial_paciente(db, current_user, resultado.id_paciente)
    else:
        raise AssistanceError(
            message="Rol no autorizado para acceder al detalle de la evaluación",
            code="PERMISSION_DENIED",
            status_code=status.HTTP_403_FORBIDDEN,
        )
    return resultado


@router.get(
    "/interacciones/catalogo",
    response_model=schemas.CatalogoInteraccionesResponse,
    summary="Consultar el catálogo referencial de interacciones farmacológicas",
)
def consultar_catalogo_interacciones(
    principio_activo: Optional[str] = Query(default=None, description="Filtrar por principio activo"),
    severidad: Optional[str] = Query(default=None, description="Filtrar por severidad: LEVE | MODERADA | GRAVE"),
    page: int = Query(default=1, ge=1, description="Número de página"),
    limit: int = Query(default=20, ge=1, le=100, description="Cantidad por página"),
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_assistance_user),
):
    return service.listar_catalogo_interacciones(
        db,
        principio_activo=principio_activo,
        severidad=severidad,
        page=page,
        limit=limit,
    )
