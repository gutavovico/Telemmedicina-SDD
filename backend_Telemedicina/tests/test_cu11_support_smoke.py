"""CU11 · grupo 1 (tareas 1.1 y 1.2): base de pruebas síncrona y auditoría en la misma transacción."""
import pytest
from fastapi import Depends, FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.audit import registrar_auditoria
from app.core.database import get_db
from app.main import app
from app.modules.auth.models import Auditoria, Clinica
from app.modules.medical_records.laboratory_sync.models import FuenteLaboratorio
from cu11_support import Cu11Env, seed_clinicas_roles_permisos, seed_dominio_basico


@pytest.fixture(scope="module")
def env():
    entorno = Cu11Env()
    entorno.install()
    yield entorno
    entorno.uninstall()


@pytest.fixture(autouse=True)
def limpio(env):
    env.reset()
    yield


def test_override_de_get_db_entrega_sesion_sincrona_sqlite(env):
    generador = app.dependency_overrides[get_db]()
    db = next(generador)
    try:
        assert isinstance(db, Session)
        assert db.get_bind() is env.engine
        assert db.execute(select(1)).scalar_one() == 1
    finally:
        generador.close()


def test_endpoint_sincrono_con_depends_get_db_usa_la_base_de_pruebas(env):
    """Patrón de CU11: endpoint `def` + `Depends(get_db)` + `select()/execute()/scalars()`."""
    with env.SessionLocal() as db:
        seed_clinicas_roles_permisos(db)

    mini = FastAPI()

    @mini.get("/clinicas/total")
    def total(db: Session = Depends(get_db)):
        return {
            "total": db.execute(select(func.count()).select_from(Clinica)).scalar_one(),
            "nombres": list(db.execute(select(Clinica.nombre).order_by(Clinica.id_clinica)).scalars()),
        }

    mini.dependency_overrides[get_db] = app.dependency_overrides[get_db]
    respuesta = TestClient(mini).get("/clinicas/total")
    assert respuesta.status_code == 200
    assert respuesta.json() == {"total": 2, "nombres": ["Clínica San Juan", "Clínica del Norte"]}


def test_semilla_incluye_un_paciente_sin_clinica_y_una_orden_firmada(env):
    with env.SessionLocal() as db:
        ids = seed_clinicas_roles_permisos(db)
        datos = seed_dominio_basico(db, ids)
        assert datos["pac_sin_clinica"].id_clinica is None
        assert datos["orden"].estado == "FIRMADA"
        assert datos["fuente"].activa == "SI"


def test_auditoria_misma_transaccion(env):
    """`registrar_auditoria` solo hace flush: el dato y la traza se confirman o se descartan juntos."""
    with env.SessionLocal() as db:
        ids = seed_clinicas_roles_permisos(db)
        datos = seed_dominio_basico(db, ids)
        id_admin = datos["admin"].id_usuario
        fuentes_semilla = db.execute(select(func.count()).select_from(FuenteLaboratorio)).scalar_one()

    def cuenta(modelo):
        with env.SessionLocal() as lectura:
            return lectura.execute(select(func.count()).select_from(modelo)).scalar_one()

    # rollback: se descartan ambos
    with env.SessionLocal() as db:
        db.add(FuenteLaboratorio(id_clinica=1, codigo="LAB-ROLLBACK", nombre="Descartada"))
        registrar_auditoria(
            db, id_usuario=id_admin, id_clinica=1, tabla_afectada="fuentes_laboratorio",
            accion="CREAR_FUENTE_LABORATORIO", descripcion="prueba rollback",
        )
        db.rollback()
    assert cuenta(FuenteLaboratorio) == fuentes_semilla
    assert cuenta(Auditoria) == 0

    # commit único: se persisten ambos
    with env.SessionLocal() as db:
        db.add(FuenteLaboratorio(id_clinica=1, codigo="LAB-COMMIT", nombre="Confirmada"))
        registrar_auditoria(
            db, id_usuario=id_admin, id_clinica=1, tabla_afectada="fuentes_laboratorio",
            accion="CREAR_FUENTE_LABORATORIO", descripcion="prueba commit",
        )
        db.commit()
    assert cuenta(FuenteLaboratorio) == fuentes_semilla + 1
    assert cuenta(Auditoria) == 1

    # si la auditoría falla, el cambio de datos se revierte con ella
    with env.SessionLocal() as db:
        db.add(FuenteLaboratorio(id_clinica=1, codigo="LAB-FALLA", nombre="Revertida"))
        with pytest.raises(Exception):
            registrar_auditoria(
                db, id_usuario=id_admin, id_clinica=1, tabla_afectada="fuentes_laboratorio",
                accion=None,  # NOT NULL: la inserción de auditoría falla en el flush
            )
        db.rollback()
    assert cuenta(FuenteLaboratorio) == fuentes_semilla + 1
    assert cuenta(Auditoria) == 1
