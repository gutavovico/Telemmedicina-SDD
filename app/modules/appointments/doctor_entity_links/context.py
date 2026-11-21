"""Contexto médico efectivo y reutilizable para CU29.

Este módulo evita que los servicios síncronos recalculen la autoridad a partir
de ``Usuario.id_rol``. La autoridad de un médico con vínculos CU29 proviene
exclusivamente del vínculo ``ACTIVO`` de la entidad seleccionada.
"""
from dataclasses import dataclass
from typing import List, Optional, Tuple

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.modules.appointments.doctor_entity_links.compat import cu29_tables_available
from app.modules.appointments.doctor_entity_links.models import (
    VinculacionMedicoEntidad,
    VinculacionMedicoRol,
)
from app.modules.auth.models import Permiso, Rol, RolPermiso, Usuario


@dataclass
class MedicalContext:
    link: VinculacionMedicoEntidad
    roles: List[str]
    rol_principal: Optional[str]
    permisos: List[str]


def _links_usuario(db: Session, id_usuario: int) -> List[VinculacionMedicoEntidad]:
    if not cu29_tables_available(db):
        return []
    return list(
        db.scalars(
            select(VinculacionMedicoEntidad)
            .where(VinculacionMedicoEntidad.id_usuario == id_usuario)
            .order_by(VinculacionMedicoEntidad.id_vinculacion)
        ).all()
    )


def effective_roles_and_permissions(
    db: Session, link: VinculacionMedicoEntidad
) -> Tuple[List[str], Optional[str], List[str]]:
    filas = db.execute(
        select(Rol, VinculacionMedicoRol.es_principal)
        .join(VinculacionMedicoRol, VinculacionMedicoRol.id_rol == Rol.id_rol)
        .where(VinculacionMedicoRol.id_vinculacion == link.id_vinculacion)
        .order_by(Rol.nombre)
    ).all()
    roles = [fila[0].nombre for fila in filas]
    principal = next((fila[0].nombre for fila in filas if fila[1]), None)
    if not roles:
        return [], None, []

    permisos: List[str] = []
    filas_permisos = db.execute(
        select(Permiso)
        .join(RolPermiso, RolPermiso.id_permiso == Permiso.id_permiso)
        .where(RolPermiso.id_rol.in_([fila[0].id_rol for fila in filas]))
        .order_by(Permiso.nombre)
    ).scalars().all()
    for permiso in filas_permisos:
        if (getattr(permiso, "estado", "ACTIVO") or "ACTIVO").upper() != "ACTIVO":
            continue
        if permiso.nombre and permiso.nombre not in permisos:
            permisos.append(permiso.nombre)
        codigo = f"{permiso.modulo}.{permiso.accion}"
        if codigo not in permisos:
            permisos.append(codigo)
    return roles, principal, permisos


def _contexto_de_vinculo(
    db: Session, link: VinculacionMedicoEntidad
) -> MedicalContext:
    roles, principal, permisos = effective_roles_and_permissions(db, link)
    return MedicalContext(
        link=link,
        roles=roles,
        rol_principal=principal,
        permisos=permisos,
    )


def resolve_active_medical_link_for_tenant(
    db: Session,
    current_user: Usuario,
    tenant_id: int,
) -> Optional[MedicalContext]:
    """Resuelve el contexto de una entidad concreta para un usuario.

    ``None`` significa que la cuenta es legacy y no tiene vínculos CU29. Si la
    cuenta sí tiene vínculos, la entidad debe corresponder a uno ``ACTIVO``;
    una suspensión o una entidad ajena producen ``403`` y nunca recurren al rol
    global de ``Usuario``.
    """
    links = _links_usuario(db, current_user.id_usuario)
    if not links:
        return None

    link = next(
        (
            item
            for item in links
            if int(item.id_clinica) == int(tenant_id)
            and item.estado == "ACTIVO"
        ),
        None,
    )
    if link is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No existe un vínculo médico activo para la entidad seleccionada",
        )
    return _contexto_de_vinculo(db, link)


def resolve_active_medical_link(
    db: Session,
    current_user: Usuario,
    x_tenant_id: Optional[str] = None,
) -> Optional[MedicalContext]:
    """Resuelve el vínculo ``ACTIVO`` según la entidad seleccionada.

    Sin encabezado se usa ``Usuario.id_clinica`` únicamente cuando sea
    compatible con un vínculo activo. Si no lo es, un único vínculo activo
    determina el contexto; con varios se exige ``X-Tenant-ID``.
    """
    links = _links_usuario(db, current_user.id_usuario)
    if not links:
        return None

    header_tenant: Optional[int] = None
    if x_tenant_id not in (None, ""):
        try:
            header_tenant = int(x_tenant_id)
        except (TypeError, ValueError):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Encabezado X-Tenant-ID inválido",
            )

    if header_tenant is not None:
        link = next(
            (
                item
                for item in links
                if int(item.id_clinica) == header_tenant
                and item.estado == "ACTIVO"
            ),
            None,
        )
    else:
        activos = [item for item in links if item.estado == "ACTIVO"]
        compatible = next(
            (
                item
                for item in activos
                if current_user.id_clinica is not None
                and int(item.id_clinica) == int(current_user.id_clinica)
            ),
            None,
        )
        if compatible is not None:
            link = compatible
        elif len(activos) == 1:
            link = activos[0]
        elif not activos:
            link = None
        else:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Seleccione una entidad con X-Tenant-ID entre sus vínculos activos",
            )

    if link is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No existe un vínculo médico activo para la entidad seleccionada",
        )
    return _contexto_de_vinculo(db, link)


__all__ = [
    "MedicalContext",
    "effective_roles_and_permissions",
    "resolve_active_medical_link",
    "resolve_active_medical_link_for_tenant",
]
