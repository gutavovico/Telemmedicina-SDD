from datetime import date
from typing import Annotated, List, Optional

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.modules.auth.dependencies import get_required_tenant_id, require_roles
from app.modules.auth.models import Usuario
from . import service
from .schemas import (
    InscripcionEsperaCreate,
    InscripcionEsperaResponse,
    ListaEsperaPageResponse,
    OfrecerTurnoCommand,
)

router = APIRouter(prefix="/lista-espera", tags=["Lista de espera (CU07)"])

Db = Annotated[Session, Depends(get_db)]
Tenant = Annotated[int, Depends(get_required_tenant_id)]
UsuarioListaEspera = Annotated[
    Usuario,
    Depends(
        require_roles(
            ["PACIENTE", "MEDICO", "M\u00c9DICO", "RECEPCION", "RECEPCI\u00d3N", "ADMIN"]
        )
    ),
]
StaffListaEspera = Annotated[
    Usuario,
    Depends(require_roles(["MEDICO", "M\u00c9DICO", "RECEPCION", "RECEPCI\u00d3N", "ADMIN"])),
]


@router.post("", response_model=InscripcionEsperaResponse, status_code=status.HTTP_201_CREATED)
def inscribirse(datos: InscripcionEsperaCreate, db: Db, user: UsuarioListaEspera, tenant_id: Tenant):
    return service.crear_inscripcion(db, datos, user, tenant_id)


@router.get("/mi-espera", response_model=List[InscripcionEsperaResponse])
def mis_inscripciones(db: Db, user: UsuarioListaEspera, tenant_id: Tenant):
    return service.mis_inscripciones(db, user, tenant_id)


@router.get("", response_model=ListaEsperaPageResponse)
def listar(
    db: Db,
    user: UsuarioListaEspera,
    tenant_id: Tenant,
    estado: Optional[str] = Query(None),
    id_medico: Optional[int] = Query(None, gt=0),
    id_especialidad: Optional[int] = Query(None, gt=0),
    fecha_deseada: Optional[date] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=100),
):
    total, items = service.listar_inscripciones(
        db,
        user,
        tenant_id,
        estado=estado,
        id_medico=id_medico,
        id_especialidad=id_especialidad,
        fecha_deseada=fecha_deseada,
        page=page,
        page_size=page_size,
    )
    return ListaEsperaPageResponse(
        total=total,
        page=page,
        page_size=page_size,
        items=[service.serializar(db, entrada) for entrada in items],
    )


@router.delete("/{id_lista_espera}", response_model=InscripcionEsperaResponse)
def salir(id_lista_espera: int, db: Db, user: UsuarioListaEspera, tenant_id: Tenant):
    return service.salir(db, id_lista_espera, user, tenant_id)


@router.post("/{id_lista_espera}/confirmar", response_model=InscripcionEsperaResponse)
def confirmar(id_lista_espera: int, db: Db, user: UsuarioListaEspera, tenant_id: Tenant):
    return service.confirmar(db, id_lista_espera, user, tenant_id)


@router.post("/{id_lista_espera}/rechazar", response_model=InscripcionEsperaResponse)
def rechazar(id_lista_espera: int, db: Db, user: UsuarioListaEspera, tenant_id: Tenant):
    return service.rechazar(db, id_lista_espera, user, tenant_id)


@router.post("/{id_lista_espera}/ofrecer", response_model=InscripcionEsperaResponse)
def ofrecer(
    id_lista_espera: int,
    datos: OfrecerTurnoCommand,
    db: Db,
    user: StaffListaEspera,
    tenant_id: Tenant,
):
    return service.ofrecer_manual(db, id_lista_espera, datos, user, tenant_id)
