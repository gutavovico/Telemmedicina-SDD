"""Dependencias de autorización y resolución de contexto para el Asistente de Tratamiento (CU18).

Asegura el aislamiento multitenant y el control de acceso estricto RBAC.
"""
from typing import Optional, Tuple
from fastapi import Depends, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.modules.ai_assistant.service import AssistanceError
from app.modules.appointments.models import Medico
from app.modules.auth.dependencies import get_current_user
from app.modules.auth.models import Usuario
from app.modules.medical_records.models import Paciente
from app.modules.medical_records.tratamientos.models import Tratamiento


def _obtener_nombre_rol(user: Usuario) -> str:
    """Extrae el nombre en mayúsculas del rol del usuario."""
    if isinstance(user.rol, str):
        return user.rol.strip().upper()
    rol_rel = getattr(user, "rol_rel", None)
    if rol_rel and getattr(rol_rel, "nombre", None):
        return rol_rel.nombre.strip().upper()
    if user.id_rol == 1:
        return "ADMIN"
    if user.id_rol == 2:
        return "MEDICO"
    if user.id_rol == 4:
        return "PACIENTE"
    return ""


def require_assistance_user(
    current_user: Usuario = Depends(get_current_user),
) -> Usuario:
    """Permite el acceso exclusivamente a roles asistenciales autorizados (PACIENTE, MEDICO).

    Roles administrativos (ADMIN, ADMINISTRADOR, SUPERADMIN) y otros roles
    (RECEPCION, FARMACIA) reciben 403 Forbidden en todos los endpoints del CU18.
    """
    if current_user.id_clinica is None:
        raise AssistanceError(
            message="El usuario debe pertenecer a una clínica activa",
            code="PERMISSION_DENIED",
            status_code=status.HTTP_403_FORBIDDEN,
        )

    rol = _obtener_nombre_rol(current_user)
    if rol not in ["PACIENTE", "MEDICO"]:
        raise AssistanceError(
            message="Rol no autorizado para el servicio de asistencia de tratamiento",
            code="PERMISSION_DENIED",
            status_code=status.HTTP_403_FORBIDDEN,
        )
    return current_user


def require_patient_actor(
    current_user: Usuario = Depends(require_assistance_user),
    db: Session = Depends(get_db),
) -> Tuple[Usuario, Paciente]:
    """Exige que el usuario sea un PACIENTE activo y resuelve su perfil clínico."""
    rol = _obtener_nombre_rol(current_user)
    if rol != "PACIENTE":
        raise AssistanceError(
            message="Solo pacientes pueden solicitar la evaluación asistida de tratamiento",
            code="PERMISSION_DENIED",
            status_code=status.HTTP_403_FORBIDDEN,
        )

    stmt = select(Paciente).where(
        Paciente.id_usuario == current_user.id_usuario,
        (Paciente.id_clinica == current_user.id_clinica) | (Paciente.id_clinica.is_(None)),
    )
    paciente = db.execute(stmt).scalars().first()
    if not paciente:
        raise AssistanceError(
            message="No se encontró un perfil de paciente asociado a este usuario",
            code="PATIENT_NOT_FOUND",
            status_code=status.HTTP_404_NOT_FOUND,
        )
    return current_user, paciente


def validar_acceso_historial_paciente(
    db: Session,
    current_user: Usuario,
    id_paciente_solicitado: Optional[int],
) -> int:
    """
    Resuelve y valida el `id_paciente` para listar historial o consultar detalle:
    - PACIENTE: solo su propio historial (si pide otro id_paciente: 403 Forbidden).
    - MEDICO: solo pacientes de su misma clínica que tengan al menos un tratamiento
      (Tratamiento.id_medico = perfil del médico autenticado) a su cargo.
      Paciente inexistente, de otra clínica o sin relación con ese médico: 404 Not Found (no revelar existencia).
    - ADMIN, recepción u otros roles: 403 Forbidden.
    """
    rol = _obtener_nombre_rol(current_user)

    if rol == "PACIENTE":
        stmt_p = select(Paciente).where(
            Paciente.id_usuario == current_user.id_usuario,
            (Paciente.id_clinica == current_user.id_clinica) | (Paciente.id_clinica.is_(None)),
        )
        paciente_propio = db.execute(stmt_p).scalars().first()
        if not paciente_propio:
            raise AssistanceError(
                message="Perfil de paciente no encontrado",
                code="PATIENT_NOT_FOUND",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        if id_paciente_solicitado is not None and id_paciente_solicitado != paciente_propio.id_paciente:
            raise AssistanceError(
                message="No tiene autorización para acceder al historial de otro paciente",
                code="PERMISSION_DENIED",
                status_code=status.HTTP_403_FORBIDDEN,
            )
        return paciente_propio.id_paciente

    if rol == "MEDICO":
        if id_paciente_solicitado is None:
            raise AssistanceError(
                message="Debe especificar el parámetro id_paciente",
                code="PATIENT_ID_REQUIRED",
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        # 1. Resolver el perfil médico del usuario en la clínica activa
        stmt_med = select(Medico).where(
            Medico.id_usuario == current_user.id_usuario,
            (Medico.id_clinica == current_user.id_clinica) | (Medico.id_clinica.is_(None)),
        )
        medico = db.execute(stmt_med).scalars().first()
        if not medico:
            raise AssistanceError(
                message="Paciente no encontrado en esta clínica",
                code="PATIENT_NOT_FOUND",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        # 2. Validar que el paciente exista y pertenezca a la misma clínica
        stmt_p = select(Paciente).where(
            Paciente.id_paciente == id_paciente_solicitado,
            Paciente.id_clinica == current_user.id_clinica,
        )
        paciente = db.execute(stmt_p).scalars().first()
        if not paciente:
            raise AssistanceError(
                message="Paciente no encontrado en esta clínica",
                code="PATIENT_NOT_FOUND",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        # 3. Validar relación asistencial: el médico debe tener al menos un tratamiento a su cargo (CU17)
        stmt_trat = select(Tratamiento.id_tratamiento).where(
            Tratamiento.id_clinica == current_user.id_clinica,
            Tratamiento.id_paciente == paciente.id_paciente,
            Tratamiento.id_medico == medico.id_medico,
        )
        tiene_tratamiento = db.execute(stmt_trat).first()
        if not tiene_tratamiento:
            raise AssistanceError(
                message="Paciente no encontrado en esta clínica",
                code="PATIENT_NOT_FOUND",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        return paciente.id_paciente

    raise AssistanceError(
        message="Rol no autorizado para acceder al historial de evaluaciones",
        code="PERMISSION_DENIED",
        status_code=status.HTTP_403_FORBIDDEN,
    )
