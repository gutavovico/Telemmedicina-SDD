













"""Dependencias de autorización y contexto médico para CU29.

`require_entity_admin` es deliberadamente distinto de ``require_admin``: este
último admite superadministradores globales y no se reutiliza para CU29.
"""
from typing import Optional

from fastapi import Depends, Header, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.multitenancy import is_super_admin
from app.modules.auth.dependencies import get_current_user
from app.modules.auth.models import Usuario
from app.modules.appointments.doctor_entity_links.context import (
    MedicalContext,
    resolve_active_medical_link,
)

ADMIN_ROLE_NAMES = {"ADMIN", "ADMINISTRADOR", "ADMINISTRACION"}
TABLAS_CU29 = (
    "vinculaciones_medico_entidad",
    "vinculacion_medico_rol",
    "vinculacion_medico_especialidad",
)



def _nombre_rol(user: Usuario) -> str:
    rol = getattr(user, "rol_rel", None)
    if rol is not None and getattr(rol, "nombre", None):
        return str(rol.nombre).strip().upper()
    valor = getattr(user, "rol", None)
    if isinstance(valor, str):
        return valor.strip().upper()
    return ""


def require_entity_admin(
    current_user: Usuario = Depends(get_current_user),
) -> Usuario:
    """Exige ADMIN activo, tenant-scoped y con ``Usuario.id_clinica``.

    El superadministrador global siempre recibe 403, incluso si envía
    ``X-Tenant-ID``. La entidad administrada se deriva solo de la cuenta.
    """
    if is_super_admin(current_user):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="El superadministrador global no administra vínculos de entidad",
        )
    if current_user.id_clinica is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="La cuenta administrativa no está asociada a una entidad",
        )
    if (current_user.estado or "").lower() != "activo":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="La cuenta administrativa está inactiva o suspendida",
        )

    rol = getattr(current_user, "rol_rel", None)
    nombre = _nombre_rol(current_user)
    if nombre not in ADMIN_ROLE_NAMES:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Se requiere el rol ADMIN de la entidad",
        )
    if rol is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="El rol administrativo no pudo validarse",
        )
    if (getattr(rol, "estado", "ACTIVO") or "ACTIVO").upper() != "ACTIVO":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="El rol administrativo está inactivo",
        )
    rol_clinica = getattr(rol, "id_clinica", None)
    if rol_clinica is None or int(rol_clinica) != int(current_user.id_clinica):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="El rol administrativo pertenece a otra entidad",
        )
    return current_user


def require_active_medical_link(
    x_tenant_id: Optional[str] = Header(None, alias="X-Tenant-ID"),
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
) -> Usuario:
    """Guard para operaciones clínicas de un médico con vínculos CU29.

    Las cuentas legacy sin vínculos conservan su autorización anterior hasta
    la migración de todos los guards operativos (tarea 3.21).
    """
    contexto = resolve_active_medical_link(db, current_user, x_tenant_id)
    if contexto is not None and contexto.link.id_medico is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="El médico debe completar su perfil antes de usar funciones clínicas",
        )
    return current_user
