"""Compatibilidad de esquema para CU29.

Las suites legacy construyen esquemas SQLite mínimos que aún no incluyen las
tablas de vinculación. Estas utilidades permiten que el código previo siga
funcionando durante la transición sin ocultar errores reales de la base.
"""
from sqlalchemy import select
from sqlalchemy.exc import OperationalError, ProgrammingError
from sqlalchemy.orm import Session

from app.modules.appointments.doctor_entity_links.models import (
    VinculacionMedicoEntidad,
)

_CLAVE_CACHE = "cu29_tablas_vinculacion"


def cu29_tables_available(db: Session) -> bool:
    """Indica si existen las tablas CU29 y cachea el resultado por sesión."""
    cache = db.info.get(_CLAVE_CACHE)
    if cache is not None:
        return bool(cache)
    try:
        db.execute(
            select(VinculacionMedicoEntidad.id_vinculacion).limit(1)
        ).first()
        db.info[_CLAVE_CACHE] = True
        return True
    except (OperationalError, ProgrammingError):
        db.rollback()
        db.info[_CLAVE_CACHE] = False
        return False


def has_active_medical_link(
    db: Session, id_usuario: int, id_clinica: int
) -> bool:
    """Indica si el usuario tiene un vínculo ACTIVO con la entidad indicada."""
    if not cu29_tables_available(db):
        return False
    return (
        db.scalar(
            select(VinculacionMedicoEntidad.id_vinculacion).where(
                VinculacionMedicoEntidad.id_usuario == id_usuario,
                VinculacionMedicoEntidad.id_clinica == id_clinica,
                VinculacionMedicoEntidad.estado == "ACTIVO",
            )
        )
        is not None
    )
