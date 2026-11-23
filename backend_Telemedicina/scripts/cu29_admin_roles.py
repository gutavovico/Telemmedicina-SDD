"""Reparación idempotente de roles administrativos tenant-scoped para CU29.

El seed legacy usaba un único rol ``ADMIN`` global para los administradores
de las clínicas 1 y 2. CU29 exige que el rol administrativo y el usuario
pertezcan a la misma entidad (``Rol.id_clinica == Usuario.id_clinica``).

Este módulo conserva el rol canónico ``id_rol=1`` para la clínica demo 1 y
crea un rol ``ADMIN`` tenant-scoped para la clínica demo 2. El
``Super Administrador`` global no se modifica y sigue denegado por CU29.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Dict, Iterable, List, Optional

from sqlalchemy.orm import Session

from app.modules.auth.models import Rol, RolPermiso, Usuario


@dataclass(frozen=True)
class AdminRoleRepairResult:
    roles_creados: List[int]
    permisos_copiados: int
    usuarios_asignados: Dict[str, int]


@dataclass(frozen=True)
class AdminRoleRepairPlan:
    roles_a_crear: List[str]
    permisos_a_copiar: int
    usuarios_a_asignar: Dict[str, Optional[int]]


def _rol_exacto(db: Session, nombre: str, id_clinica: int) -> Optional[Rol]:
    return (
        db.query(Rol)
        .filter(Rol.nombre == nombre, Rol.id_clinica == id_clinica)
        .order_by(Rol.id_rol)
        .first()
    )


def _rol_por_id(db: Session, id_rol: int) -> Optional[Rol]:
    return db.query(Rol).filter(Rol.id_rol == id_rol).first()


def _copiar_permisos(db: Session, origen_id_rol: int, destino_id_rol: int) -> int:
    origen = {
        relacion.id_permiso
        for relacion in db.query(RolPermiso)
        .filter(RolPermiso.id_rol == origen_id_rol)
        .all()
    }
    existentes = {
        relacion.id_permiso
        for relacion in db.query(RolPermiso)
        .filter(RolPermiso.id_rol == destino_id_rol)
        .all()
    }
    for id_permiso in sorted(origen - existentes):
        db.add(RolPermiso(id_rol=destino_id_rol, id_permiso=id_permiso))
    return len(origen - existentes)


def plan_reparar_roles_admin_demo(db: Session) -> AdminRoleRepairPlan:
    """Calcula el plan de reparación sin insertar, actualizar ni consumir IDs."""
    admin_central = _rol_por_id(db, 1)
    admin_norte = _rol_exacto(db, "ADMINISTRADOR", 2)
    if admin_norte is None:
        admin_norte = _rol_exacto(db, "ADMIN", 2)
    roles_a_crear: List[str] = []
    if admin_central is None:
        roles_a_crear.append("ADMIN (Clínica Central, id_rol=1)")
    if admin_norte is None:
        roles_a_crear.append("ADMINISTRADOR (Clínica Norte)")

    permisos_a_copiar = 0
    if admin_central is not None and admin_norte is not None:
        origen = {
            relacion.id_permiso
            for relacion in db.query(RolPermiso)
            .filter(RolPermiso.id_rol == admin_central.id_rol)
            .all()
        }
        existentes = {
            relacion.id_permiso
            for relacion in db.query(RolPermiso)
            .filter(RolPermiso.id_rol == admin_norte.id_rol)
            .all()
        }
        permisos_a_copiar = len(origen - existentes)

    usuarios_a_asignar: Dict[str, Optional[int]] = {}
    for correo, id_clinica in (
        ("admin@telemedicina.com", 1),
        ("admin.norte@telemedicina.com", 2),
    ):
        usuario = (
            db.query(Usuario)
            .filter(Usuario.correo == correo, Usuario.id_clinica == id_clinica)
            .first()
        )
        if usuario is not None:
            usuarios_a_asignar[correo] = (
                admin_central.id_rol
                if id_clinica == 1 and admin_central is not None
                else admin_norte.id_rol
                if admin_norte is not None
                else None
            )
    return AdminRoleRepairPlan(
        roles_a_crear=roles_a_crear,
        permisos_a_copiar=permisos_a_copiar,
        usuarios_a_asignar=usuarios_a_asignar,
    )


def reparar_roles_admin_demo(db: Session) -> AdminRoleRepairResult:
    """Corrige los dos administradores demo sin ampliar su autoridad.

    - Clínica 1: conserva ``id_rol=1`` y lo convierte en rol tenant-scoped.
    - Clínica 2: crea/reutiliza un rol ``ADMIN`` con ``id_clinica=2``.
    - Copia al rol de la clínica 2 los permisos del rol canónico.
    - Asigna cada cuenta demo únicamente al rol de su propia clínica.

    La función no hace ``commit``; el llamador controla la transacción.
    """
    roles_creados: List[int] = []
    permisos_copiados = 0
    usuarios_asignados: Dict[str, int] = {}

    admin_central = _rol_por_id(db, 1)
    if admin_central is None:
        admin_central = Rol(
            id_rol=1,
            id_clinica=1,
            nombre="ADMIN",
            descripcion="Administrador de la Clínica Central",
            estado="ACTIVO",
        )
        db.add(admin_central)
        db.flush()
        roles_creados.append(admin_central.id_rol)
    else:
        admin_central.nombre = "ADMIN"
        admin_central.descripcion = "Administrador de la Clínica Central"
        admin_central.estado = "ACTIVO"
        admin_central.id_clinica = 1

    admin_norte = _rol_exacto(db, "ADMINISTRADOR", 2)
    if admin_norte is None:
        admin_norte = _rol_exacto(db, "ADMIN", 2)
    if admin_norte is None:
        admin_norte = Rol(
            id_clinica=2,
            nombre="ADMINISTRADOR",
            descripcion="Administrador de Red Médica del Norte",
            estado="ACTIVO",
        )
        db.add(admin_norte)
        db.flush()
        roles_creados.append(admin_norte.id_rol)
    else:
        admin_norte.nombre = "ADMINISTRADOR"
        admin_norte.descripcion = "Administrador de Red Médica del Norte"
        admin_norte.estado = "ACTIVO"

    db.flush()
    permisos_copiados += _copiar_permisos(
        db, admin_central.id_rol, admin_norte.id_rol
    )

    asignaciones = (
        ("admin@telemedicina.com", 1, admin_central),
        ("admin.norte@telemedicina.com", 2, admin_norte),
    )
    for correo, id_clinica, rol in asignaciones:
        usuario = (
            db.query(Usuario)
            .filter(Usuario.correo == correo, Usuario.id_clinica == id_clinica)
            .first()
        )
        if usuario is None:
            continue
        usuario.id_rol = rol.id_rol
        usuario.id_clinica = id_clinica
        usuarios_asignados[correo] = rol.id_rol

    db.flush()
    return AdminRoleRepairResult(
        roles_creados=roles_creados,
        permisos_copiados=permisos_copiados,
        usuarios_asignados=usuarios_asignados,
    )


__all__ = [
    "AdminRoleRepairPlan",
    "AdminRoleRepairResult",
    "plan_reparar_roles_admin_demo",
    "reparar_roles_admin_demo",
]
