"""Dependencias de CU11: clínica estricta de la sesión y permisos ``lab_results:*``.

La clínica efectiva es siempre ``Usuario.id_clinica`` de la sesión autenticada. NO se usa
``get_required_tenant_id`` (devuelve la clínica 1 para ``id_rol == 4`` sin clínica) ni se acepta un
``tenant_id``/``id_clinica`` del cliente; el encabezado ``X-Tenant-ID`` se ignora por completo.
Las consultas seleccionan columnas concretas (no el modelo ``Rol`` completo), porque el esquema real de
``roles`` en Neon difiere del modelo ORM (ver ``clinical_documents/dependencies.py``).
"""
from dataclasses import dataclass
from typing import Optional

from fastapi import Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.modules.auth.dependencies import get_current_user
from app.modules.auth.models import Permiso, Rol, RolPermiso, Usuario

PERMISO_CREATE = "lab_results:create"
PERMISO_READ = "lab_results:read"
PERMISO_REVIEW = "lab_results:review"
PERMISO_SYNC = "lab_results:sync"
PERMISO_DESCARGA = "documents:read:lab_results"  # permiso de CU12 que RECEPCION no posee

ROL_PACIENTE = "PACIENTE"


@dataclass(frozen=True)
class Contexto:
    """Identidad ya resuelta de la petición (valores simples, sin objetos ORM expirables)."""

    id_usuario: int
    id_clinica: int
    id_rol: Optional[int]
    rol: Optional[str]


def tiene_permiso(db: Session, id_rol: Optional[int], permiso: str) -> bool:
    if id_rol is None:
        return False
    fila = db.execute(
        select(RolPermiso.id_rol)
        .join(Permiso, Permiso.id_permiso == RolPermiso.id_permiso)
        .where(
            RolPermiso.id_rol == id_rol,
            Permiso.nombre == permiso,
            Permiso.estado == "ACTIVO",
        )
        .limit(1)
    ).first()
    return fila is not None


def nombre_rol(db: Session, id_rol: Optional[int]) -> Optional[str]:
    if id_rol is None:
        return None
    nombre = db.execute(select(Rol.nombre).where(Rol.id_rol == id_rol)).scalar_one_or_none()
    return nombre.upper() if nombre else None


def contexto_clinica(
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Contexto:
    """Exige una sesión asociada a una clínica; una cuenta global sin clínica recibe 403."""
    if current_user.id_clinica is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="La cuenta autenticada no está asociada a una clínica",
        )
    return Contexto(
        id_usuario=int(current_user.id_usuario),
        id_clinica=int(current_user.id_clinica),
        id_rol=current_user.id_rol,
        rol=nombre_rol(db, current_user.id_rol),
    )


def requerir_permisos(*permisos: str):
    """Dependencia que exige TODOS los permisos indicados además de la clínica de la sesión."""

    def verificador(
        ctx: Contexto = Depends(contexto_clinica),
        db: Session = Depends(get_db),
    ) -> Contexto:
        for permiso in permisos:
            if not tiene_permiso(db, ctx.id_rol, permiso):
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail=f"Permiso denegado. Se requiere el permiso '{permiso}'.",
                )
        return ctx

    return verificador
