"""Regresión de integración CU29 para roles ADMIN tenant-scoped.

Simula el seed legacy defectuoso: dos usuarios administrativos de distintas
clínicas comparten un único rol ``ADMIN`` global. La reparación debe asignar
roles tenant-scoped, copiar permisos y ser idempotente.
"""
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session

from app.core.database import Base
from app.modules.auth.models import Clinica, Permiso, Rol, RolPermiso, Usuario
from scripts.cu29_admin_roles import reparar_roles_admin_demo


def test_repara_roles_admin_demo_y_es_idempotente():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)

    with Session(engine) as db:
        db.add_all(
            [
                Clinica(id_clinica=1, nombre="Clínica Uno", estado="ACTIVO"),
                Clinica(id_clinica=2, nombre="Clínica Dos", estado="ACTIVO"),
            ]
        )
        db.add_all(
            [
                Rol(
                    id_rol=1,
                    id_clinica=None,
                    nombre="ADMIN",
                    descripcion="Administrador del Sistema y Tenant",
                    estado="ACTIVO",
                ),
                Rol(
                    id_rol=2,
                    id_clinica=None,
                    nombre="Super Administrador",
                    estado="ACTIVO",
                ),
                Permiso(
                    id_permiso=1,
                    nombre="VER_USUARIOS",
                    modulo="users",
                    accion="read",
                    estado="ACTIVO",
                ),
                Permiso(
                    id_permiso=2,
                    nombre="EDITAR_USUARIOS",
                    modulo="users",
                    accion="write",
                    estado="ACTIVO",
                ),
            ]
        )
        db.add(RolPermiso(id_rol=1, id_permiso=1))
        db.add(RolPermiso(id_rol=1, id_permiso=2))
        db.add_all(
            [
                Usuario(
                    id_usuario=1,
                    id_clinica=1,
                    id_rol=1,
                    nombres="Admin",
                    apellidos="Central",
                    correo="admin@telemedicina.com",
                    password_hash="hash",
                    estado="activo",
                ),
                Usuario(
                    id_usuario=2,
                    id_clinica=2,
                    id_rol=1,
                    nombres="Admin",
                    apellidos="Norte",
                    correo="admin.norte@telemedicina.com",
                    password_hash="hash",
                    estado="activo",
                ),
            ]
        )
        db.commit()

        primera = reparar_roles_admin_demo(db)
        db.commit()

        assert len(primera.roles_creados) == 1
        assert primera.permisos_copiados == 2
        assert primera.usuarios_asignados == {
            "admin@telemedicina.com": 1,
            "admin.norte@telemedicina.com": primera.usuarios_asignados[
                "admin.norte@telemedicina.com"
            ],
        }

        roles = db.scalars(
            select(Rol)
            .where(Rol.nombre.in_(["ADMIN", "ADMINISTRADOR"]))
            .order_by(Rol.id_rol)
        ).all()
        assert len(roles) == 2
        assert {rol.id_clinica for rol in roles} == {1, 2}
        assert all(rol.id_clinica is not None for rol in roles)
        assert {rol.nombre for rol in roles} == {"ADMIN", "ADMINISTRADOR"}

        admin_central = db.get(Usuario, 1)
        admin_norte = db.get(Usuario, 2)
        assert admin_central.id_rol == 1
        assert admin_central.rol_rel.id_clinica == 1
        assert admin_norte.id_rol == admin_norte.rol_rel.id_rol
        assert admin_norte.rol_rel.id_clinica == 2

        permisos_norte = db.scalars(
            select(RolPermiso.id_permiso).where(
                RolPermiso.id_rol == admin_norte.id_rol
            )
        ).all()
        assert set(permisos_norte) == {1, 2}

        segunda = reparar_roles_admin_demo(db)
        db.commit()
        assert segunda.roles_creados == []
        assert segunda.permisos_copiados == 0
        assert len(
            db.scalars(
                select(Rol).where(Rol.nombre.in_(["ADMIN", "ADMINISTRADOR"]))
            ).all()
        ) == 2
        assert (
            len(
                db.scalars(
                    select(RolPermiso).where(
                        RolPermiso.id_rol == admin_norte.id_rol
                    )
                ).all()
            )
            == 2
        )

    engine.dispose()
