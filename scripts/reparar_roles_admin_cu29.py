"""Repara los roles administrativos demo requeridos por CU29.

Uso desde ``backend_Telemedicina``::

    .\\venv\\Scripts\\python.exe scripts\\reparar_roles_admin_cu29.py --dry-run
    .\\venv\\Scripts\\python.exe scripts\\reparar_roles_admin_cu29.py

La operación es idempotente y transaccional. ``--dry-run`` muestra el plan sin
persistir cambios.
"""
from __future__ import annotations

import argparse
import os
import sys

sys.path.insert(0, os.path.realpath(os.path.join(os.path.dirname(__file__), "..")))

from sqlalchemy import func

from app.core.database import SessionLocal
from app.modules.auth.models import Rol, Usuario
from scripts.cu29_admin_roles import (
    plan_reparar_roles_admin_demo,
    reparar_roles_admin_demo,
)


def _estado_actual(db) -> None:
    roles = (
        db.query(Rol)
        .filter(Rol.nombre.in_(["ADMIN", "ADMINISTRADOR", "Super Administrador"]))
        .order_by(Rol.id_rol)
        .all()
    )
    print("Roles administrativos actuales:")
    for rol in roles:
        print(
            f"  id_rol={rol.id_rol} nombre={rol.nombre} "
            f"id_clinica={rol.id_clinica} estado={rol.estado}"
        )

    print("Usuarios administrativos demo actuales:")
    usuarios = (
        db.query(Usuario)
        .filter(
            Usuario.correo.in_(
                ["admin@telemedicina.com", "admin.norte@telemedicina.com"]
            )
        )
        .order_by(Usuario.id_usuario)
        .all()
    )
    for usuario in usuarios:
        rol = usuario.rol_rel
        print(
            f"  {usuario.correo}: id_clinica={usuario.id_clinica} "
            f"id_rol={usuario.id_rol} rol={getattr(rol, 'nombre', None)} "
            f"rol_clinica={getattr(rol, 'id_clinica', None)}"
        )


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Repara roles ADMIN tenant-scoped para las cuentas demo de CU29."
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Muestra el plan y revierte los cambios sin confirmarlos.",
    )
    args = parser.parse_args()

    db = SessionLocal()
    try:
        print("Estado inicial:")
        _estado_actual(db)
        if args.dry_run:
            plan = plan_reparar_roles_admin_demo(db)
            print("Plan de reparación (sin cambios):")
            print(f"  roles a crear: {plan.roles_a_crear or 'ninguno'}")
            print(f"  permisos a copiar: {plan.permisos_a_copiar}")
            for correo, id_rol in plan.usuarios_a_asignar.items():
                print(f"  {correo} -> id_rol={id_rol}")
            db.rollback()
            print("DRY RUN: no se guardaron cambios.")
        else:
            resultado = reparar_roles_admin_demo(db)
            print("Plan de reparación:")
            print(f"  roles a crear: {resultado.roles_creados or 'ninguno'}")
            print(f"  permisos a copiar: {resultado.permisos_copiados}")
            for correo, id_rol in resultado.usuarios_asignados.items():
                print(f"  {correo} -> id_rol={id_rol}")
            db.commit()
            print("Reparación aplicada correctamente.")
    except Exception:
        db.rollback()
        print("ERROR: la reparación fue revertida; no se guardaron cambios.")
        raise
    finally:
        db.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
