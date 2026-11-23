"""CU11 · tarea 3.13: la bitácora de CU21 muestra los eventos de CU11 sin cambios (criterio 9)."""
import pytest

from app.modules.auth.models import Auditoria
from cu11_support import (
    URL,
    Cu11Http,
    construir_mundo,
    crear_pendiente_db,
    post_manual,
    usar_storage_temporal,
)

BITACORA = "/api/v1/audit-log"


@pytest.fixture(scope="module")
def env():
    entorno = Cu11Http()
    entorno.install()
    yield entorno
    entorno.uninstall()


@pytest.fixture()
def mundo(env, tmp_path, monkeypatch):
    return construir_mundo(env, usar_storage_temporal(monkeypatch, tmp_path))


def bitacora(mundo, persona, **consulta):
    mundo.env.como(mundo.p[persona])
    return mundo.client.get(BITACORA, params=consulta)


def test_la_carga_manual_aparece_en_la_bitacora_de_su_clinica_y_no_en_la_de_otra(mundo):
    creado = post_manual(mundo, mundo.p["recepcion1"]).json()

    respuesta = bitacora(mundo, "admin1", tabla_afectada="resultados_laboratorio")
    assert respuesta.status_code == 200, respuesta.text
    eventos = respuesta.json()["data"]
    assert len(eventos) == 1
    evento = eventos[0]
    assert evento["accion"] == "CREAR_RESULTADO_LABORATORIO"
    assert evento["tabla_afectada"] == "resultados_laboratorio"
    assert evento["registro_id"] == creado["id_resultado"]
    assert evento["id_usuario"] == mundo.p["recepcion1"].id_usuario
    assert evento["id_clinica"] == 1

    # filtrado por acción y por registro
    assert bitacora(mundo, "admin1", accion="CREAR_RESULTADO_LABORATORIO").json()["total"] == 1
    assert bitacora(mundo, "admin1", tabla_afectada="resultados_laboratorio", registro_id=creado["id_resultado"]).json()["total"] == 1

    # la bitácora de la otra clínica no la ve
    ajena = bitacora(mundo, "admin2", tabla_afectada="resultados_laboratorio")
    assert ajena.status_code == 200 and ajena.json()["total"] == 0
    detalle_cruzado = bitacora_detalle(mundo, "admin2", evento["id_auditoria"])
    assert detalle_cruzado.status_code == 404


def bitacora_detalle(mundo, persona, id_auditoria):
    mundo.env.como(mundo.p[persona])
    return mundo.client.get(f"{BITACORA}/{id_auditoria}")


def test_todas_las_operaciones_de_escritura_y_la_descarga_dejan_traza(mundo):
    creado = post_manual(mundo, mundo.p["medico1"]).json()
    mundo.env.como(mundo.p["medico1"])
    assert mundo.client.get(f"{URL}/{creado['id_resultado']}/archivo").status_code == 200
    with mundo.env.SessionLocal() as db:
        pendiente = crear_pendiente_db(db, 1, mundo.p["admin1"].id_usuario, mundo.datos["fuente"].id_fuente)
    assert mundo.client.post(
        f"{URL}/{pendiente.id_resultado}/resolver",
        json={"accion": "ASIGNAR", "id_paciente": mundo.datos["pac1"].id_paciente, "codigo_examen": "HEMOGRAMA"},
    ).status_code == 200
    assert mundo.client.post(f"{URL}/{creado['id_resultado']}/anular", json={"motivo": "Error de carga"}).status_code == 200

    acciones = {e["accion"] for e in bitacora(mundo, "admin1", tabla_afectada="resultados_laboratorio").json()["data"]}
    assert acciones == {
        "CREAR_RESULTADO_LABORATORIO", "DESCARGAR_RESULTADO_LABORATORIO",
        "RESOLVER_RESULTADO_LABORATORIO", "ANULAR_RESULTADO_LABORATORIO",
    }
    assert mundo.env.contar(Auditoria, Auditoria.tabla_afectada == "resultados_laboratorio") == 4
