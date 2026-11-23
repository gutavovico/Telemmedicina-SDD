from typing import Annotated

from fastapi import APIRouter, Depends, File, Path, Response, UploadFile
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.multitenancy import get_current_tenant
from app.modules.auth.models import Clinica, Usuario
from app.modules.appointments.models import ServicioMedico
from app.modules.tenants.models import Sede
from . import service
from .dependencies import administrador
from .schemas import DatosSede, DatosServicio, Direccion, Horarios, Identidad

router = APIRouter(prefix="/api/v1/tenant", tags=["Configuración institucional"])
config = APIRouter(prefix="/configuracion")
Db = Annotated[Session, Depends(get_db)]
Admin = Annotated[Usuario, Depends(administrador)]


@router.get("/marca/logo")
def logo_contexto(tenant: Clinica = Depends(get_current_tenant)):
    data, media_type = service.leer_logo(tenant)
    return Response(data, media_type=media_type,
                    headers={"Cache-Control": "private, no-store"})


@config.get("")
def consultar(db: Db, user: Admin, response: Response):
    response.headers["Cache-Control"] = "private, no-store"
    return service.consultar(db, user)


@config.put("/identidad")
def identidad(datos: Identidad, db: Db, user: Admin):
    return service.cambiar_colores(db, user, datos)



@config.put("/logo")
def logo(db: Db, user: Admin, archivo: UploadFile = File(...)):
    return service.guardar_logo(db, user, archivo.file.read(service.MAX_LOGO + 1))


@config.put("/direccion")
def direccion(datos: Direccion, db: Db, user: Admin):
    return service.registrar_direccion(db, user, datos)



@config.post("/sedes", status_code=201)
def crear_sedes(datos: DatosSede, db: Db, user: Admin):
    return service.catalogo(db, user, Sede, datos)


@config.put("/sedes/{clave}")
def editar_sedes(clave: int, datos: DatosSede, db: Db, user: Admin):
    return service.catalogo(db, user, Sede, datos, clave)


@config.patch("/sedes/{clave}/desactivar")
def desactivar_sedes(clave: int, db: Db, user: Admin):
    return service.desactivar_sede(db, user, clave)



@config.post("/servicios", status_code=201)
def crear_servicios(datos: DatosServicio, db: Db, user: Admin):
    return service.catalogo(db, user, ServicioMedico, datos)


@config.put("/servicios/{clave}")
def editar_servicios(clave: int, datos: DatosServicio, db: Db, user: Admin):
    return service.catalogo(db, user, ServicioMedico, datos, clave)


@config.patch("/servicios/{clave}/desactivar")
def desactivar_servicios(clave: int, db: Db, user: Admin):
    return service.desactivar_servicio(db, user, clave)



@config.put("/sedes/{clave}/horarios/{dia}")
def actualizar_horarios(clave: int, dia: Annotated[int, Path(ge=1, le=7)], datos: Horarios, db: Db, user: Admin):
    return service.horarios_dia(db, user, clave, dia, datos)


router.include_router(config)
