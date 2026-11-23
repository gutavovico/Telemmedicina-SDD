from fastapi import Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.tenant_status import canonical_tenant_status
from app.modules.auth.models import Clinica, Usuario
from app.modules.tenants.subscription_changes.dependencies import es_administrador_entidad, require_entity_admin


def puede_configurar(user: Usuario, clinica: Clinica | None) -> bool:
    rol = user.rol_rel
    return (
        es_administrador_entidad(user) and clinica is not None
        and clinica.id_clinica == user.id_clinica and rol is not None
        and rol.id_clinica in (None, user.id_clinica)
        and all(canonical_tenant_status(v) == "ACTIVE" for v in (user.estado, rol.estado, clinica.estado))
    )


def administrador(user: Usuario = Depends(require_entity_admin), db: Session = Depends(get_db)):
    if not puede_configurar(user, db.get(Clinica, user.id_clinica)):
        raise HTTPException(403, "Se requiere administración activa de la propia entidad")
    return user
