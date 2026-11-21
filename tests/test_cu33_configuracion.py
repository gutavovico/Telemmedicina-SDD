"""Pruebas HTTP aisladas: app mínima, SQLite en memoria y storage temporal."""
from io import BytesIO, StringIO
from pathlib import Path
from types import SimpleNamespace
import importlib.util

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from PIL import Image
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool
from alembic.migration import MigrationContext
from alembic.operations import Operations

from app.core.config import settings
from app.core.database import get_db
from app.modules.auth.dependencies import get_current_user
from app.modules.auth.models import Clinica, Usuario, Rol, Auditoria
from app.modules.appointments.models import ServicioMedico
from app.modules.medical_records.models import Paciente  # registra relaciones de citas
from app.modules.medical_records.hce import models as hce_models
from app.modules.tenants.models import Sede, HorarioSede, TemaAdministrador
from app.modules.tenants.entity_configuration.router import router

BASE = "/api/v1/tenant/configuracion"
SERV = dict(nombre="Consulta", modalidad="PRESENCIAL", duracion_minutos=30,
            hora_inicio="08:00", hora_fin="16:00", costo="10.00")


@pytest.fixture
def api(monkeypatch, tmp_path):
    monkeypatch.setattr(settings, "STORAGE_BACKEND", "local")
    monkeypatch.setattr(settings, "STORAGE_LOCAL_DIR", str(tmp_path))
    engine = create_engine("sqlite://", poolclass=StaticPool, connect_args={"check_same_thread": False})
    for model in (Clinica, Rol, Usuario, Auditoria, ServicioMedico, Sede, HorarioSede, TemaAdministrador):
        model.__table__.create(engine)
    with engine.begin() as conn:
        conn.execute(Clinica.__table__.insert(), [
            {"id_clinica": i, "nombre": str(i), "color_principal": "#123456"} for i in (1, 2)
        ])
        conn.execute(Usuario.__table__.insert(), [
            {"id_usuario": i, "id_clinica": 1, "nombres": "Prueba", "apellidos": str(i),
             "correo": f"usuario{i}@example.com", "password_hash": "ficticio"} for i in (10, 11)
        ])
    app = FastAPI()
    app.include_router(router)
    user = SimpleNamespace(id_usuario=10, id_clinica=1, rol="ADMIN", estado="ACTIVO",
                           rol_rel=SimpleNamespace(estado="ACTIVO", id_clinica=1))
    def db():
        with Session(engine) as session:
            yield session
    app.dependency_overrides[get_db] = db
    app.dependency_overrides[get_current_user] = lambda: user
    with TestClient(app) as client:
        yield client, user
    engine.dispose()


def test_catalogo_aislado(api):
    c, u = api
    sede = dict(nombre="Central", ubicacion="Piso 2")
    assert c.post(BASE+"/sedes", json=sede, headers={"X-Tenant-ID":"2"}).status_code == 201
    assert c.post(BASE+"/servicios", json=SERV).status_code == 201
    assert c.put(BASE+"/servicios/1", json=dict(SERV, costo="0.00")).status_code == 200
    assert c.put(BASE+"/sedes/1", json=dict(sede, nombre="Norte")).status_code == 200
    assert c.put(BASE+"/sedes/1", json=dict(sede, id_clinica=2)).status_code == 422
    u.id_clinica = u.rol_rel.id_clinica = 2
    assert c.get(BASE).json()["sedes"] == []
    assert c.get(BASE).json()["servicios"] == []
    assert c.put(BASE+"/sedes/1", json=sede).status_code == 404
    assert c.patch(BASE+"/servicios/1/desactivar").status_code == 404
    assert c.put(BASE+"/sedes/1/horarios/1", json={"intervalos":[]}).status_code == 404


@pytest.mark.parametrize("rol,cid,estado", [("SUPERADMIN",None,"ACTIVO"),("MEDICO",1,"ACTIVO"),("ADMIN",1,"INACTIVO")])
def test_autorizacion(api, rol, cid, estado):
    c,u = api
    u.rol, u.id_clinica, u.rol_rel.estado = rol,cid,estado
    assert c.get(BASE, headers={"X-Tenant-ID":"1"}).status_code == 403


def test_direccion_marca(api):
    c,u = api
    marca = {"principal":"#aa0000", "secundario":"#00bbcc"}
    assert c.put(BASE+"/identidad", json=marca).status_code == 200
    assert c.put(BASE+"/direccion", json={"valor":" HTTPS://SALUD.EXAMPLE:443/ "}).status_code == 200
    assert c.put(BASE+"/direccion", json={"valor":"https://salud.example/ruta"}).status_code == 422
    image = BytesIO()
    Image.new("RGB",(4,4)).save(image,format="PNG")
    assert c.put(BASE+"/logo", files={"archivo":("cliente.jpg",image.getvalue())}).status_code == 200
    data = c.get(BASE).json()
    assert data["identidad"]["principal"] == "#AA0000"
    assert data["identidad"]["logo"].startswith("marcas/1/")
    assert data["direccion"] == "salud.example"
    assert c.get("/api/v1/tenant/marca/logo").content == image.getvalue()
    for body in (b"falso", b"x"*(2*1024*1024+1)):
        assert c.put(BASE+"/logo", files={"archivo":("x.png",body)}).status_code == 422
    u.id_clinica = u.rol_rel.id_clinica = 2
    assert c.put(BASE+"/direccion", json={"valor":"https://salud.example"}).status_code == 409
    assert c.get(BASE).json()["direccion"] is None
    assert c.get("/api/v1/tenant/marca/logo").status_code == 404


def test_tema_personal_por_usuario_y_clinica(api):
    c, user = api
    primero = {"principal": "#FFFFFF", "secundario": "#FFFFFF"}
    segundo = {"principal": "#000000", "secundario": "#112233"}
    assert c.get(BASE).json()["identidad"]["principal"] == "#003667"
    assert c.put(BASE + "/identidad", json=primero).status_code == 200
    assert c.put(BASE + "/identidad", json={**primero, "id_usuario": 11}).status_code == 422

    user.id_usuario = 11
    assert c.get(BASE).json()["identidad"]["principal"] == "#003667"
    assert c.put(BASE + "/identidad", json=segundo).status_code == 200
    assert c.get(BASE).json()["identidad"]["principal"] == segundo["principal"]
    user.id_usuario = 10
    assert c.get(BASE).json()["identidad"]["principal"] == primero["principal"]

    user.rol = "MEDICO"
    assert c.put(BASE + "/identidad", json=segundo).status_code == 403
    user.rol = "ADMIN"
    user.id_clinica = user.rol_rel.id_clinica = 2
    assert c.get(BASE).json()["identidad"]["principal"] == "#003667"


@pytest.mark.parametrize("costo", ["-1", "0.001", "NaN", "Infinity", "100000000.00"])
def test_tarifas_invalidas(api,costo):
    assert api[0].post(BASE+"/servicios", json=dict(SERV, costo=costo)).status_code == 422


def test_horarios_y_baja(api):
    c,_ = api
    c.post(BASE+"/sedes", json=dict(nombre="Sede",ubicacion="Centro")).raise_for_status()
    c.post(BASE+"/servicios", json=SERV).raise_for_status()
    dia = BASE+"/sedes/1/horarios/1"
    franjas = [dict(apertura="08:00",cierre="12:00"), dict(apertura="12:00",cierre="16:00")]
    assert c.put(dia,json={"intervalos":franjas}).status_code == 200
    for inicio in ("11:00","22:00"):
        assert c.put(dia,json={"intervalos":[franjas[0],dict(franjas[1],apertura=inicio)]}).status_code == 422
    c.patch(BASE+"/sedes/1/desactivar").raise_for_status()
    c.patch(BASE+"/servicios/1/desactivar").raise_for_status()
    assert c.put(dia,json={"intervalos":[]}).status_code == 409
    data = c.get(BASE).json()
    assert not data["sedes"][0]["activa"]
    assert data["servicios"][0]["estado"] == "inactivo"
    assert [h["id_sede"] for h in data["horarios"]] == [1,1]


def test_migracion_postgres_offline():
    path = Path(__file__).resolve().parents[1]/"alembic/versions/025_cu33_configuracion_entidad.py"
    spec = importlib.util.spec_from_file_location("cu33_migration",path)
    migration = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(migration)
    buf = StringIO()
    context = MigrationContext.configure(dialect_name="postgresql", opts={"as_sql":True,"output_buffer":buf})
    with Operations.context(context):
        migration.upgrade()
    ddl = buf.getvalue()
    for token in ("CREATE TABLE sedes", "CREATE TABLE horarios_sede", "UNIQUE (direccion_acceso)", "REFERENCES sedes", "EXCLUDE USING gist"):
        assert token in ddl
