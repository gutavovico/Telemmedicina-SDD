from fastapi import Depends, HTTPException
from app.modules.auth.dependencies import get_current_user
from app.modules.auth.models import Usuario


def es_administrador_entidad(user: Usuario) -> bool:
    return user.id_clinica is not None and str(user.rol or '').strip().upper() in (
        'ADMIN', 'ADMINISTRADOR', 'ADMINISTRACION',
    )


def require_entity_admin(user: Usuario = Depends(get_current_user)):
    if not es_administrador_entidad(user):
        raise HTTPException(403, 'Se requiere el administrador de la entidad')
    return user
