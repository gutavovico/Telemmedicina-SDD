"""Dependencias CU16: RBAC granular prescriptions:* vía SQL crudo.

Reutiliza los helpers de CU12 (robustos ante la divergencia del esquema
de roles en Neon) y añade fábricas propias del dominio de recetas.
"""
from typing import Optional

from fastapi import Depends, Header, HTTPException, status
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.modules.appointments.doctor_entity_links.dependencies import (
    resolve_active_medical_link,
)
from app.modules.auth.dependencies import get_current_user
from app.modules.auth.models import Usuario
from app.modules.medical_records.clinical_documents.dependencies import (
    get_role_name,
    user_has_permission,
)


PERMISO_ISSUE = "prescriptions:issue"
PERMISO_READ = "prescriptions:read"
PERMISO_DOWNLOAD = "prescriptions:download"
PERMISO_CANCEL = "prescriptions:cancel"
PERMISO_CATALOG_WRITE = "prescriptions:catalog:write"


def require_prescription_permission(permiso: str):
    """Dependency factory: exige el permiso granular prescriptions:* dado."""
    def checker(
        current_user: Usuario = Depends(get_current_user),
        db: Session = Depends(get_db),
        x_tenant_id: Optional[str] = Header(None, alias="X-Tenant-ID"),
    ) -> Usuario:
        contexto = resolve_active_medical_link(db, current_user, x_tenant_id)
        permitido = (
            permiso in contexto.permisos
            if contexto is not None
            else user_has_permission(db, current_user.id_rol, permiso)
        )
        if not permitido:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Permiso denegado. Se requiere el permiso '{permiso}'.",
            )
        return current_user
    return checker


def require_prescription_roles(allowed_roles):
    """Dependency factory por rol vía SQL crudo (compatible con Neon y tests).

    Autoriza exclusivamente por nombre normalizado del rol y permisos RBAC
    persistidos; nunca por IDs fijos de rol. Un ID numérico 1 no otorga
    privilegios administrativos por sí solo.
    """
    def checker(
        current_user: Usuario = Depends(get_current_user),
        db: Session = Depends(get_db),
        x_tenant_id: Optional[str] = Header(None, alias="X-Tenant-ID"),
    ) -> Usuario:
        contexto = resolve_active_medical_link(db, current_user, x_tenant_id)
        if contexto is not None:
            role_names = [rol.upper() for rol in contexto.roles]
        else:
            role_names = [(get_role_name(db, current_user.id_rol) or "").upper()]
        allowed_upper = [r.upper() for r in allowed_roles]
        if not any(role in allowed_upper for role in role_names):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=(
                    "Permiso denegado. Se requiere uno de los siguientes roles: "
                    + ", ".join(allowed_roles)
                ),
            )
        return current_user
    return checker


def is_admin_user(db: Session, current_user: Usuario) -> bool:
    """Determina administración por nombre normalizado del rol, nunca por ID fijo."""
    return (get_role_name(db, current_user.id_rol) or "").upper() == "ADMIN"


__all__ = [
    "PERMISO_ISSUE",
    "PERMISO_READ",
    "PERMISO_DOWNLOAD",
    "PERMISO_CANCEL",
    "PERMISO_CATALOG_WRITE",
    "require_prescription_permission",
    "require_prescription_roles",
    "is_admin_user",
]
