"""CU11 · cierre (grupo 8): los logs no incluyen contenido clínico ni rutas internas del servidor.

Las excepciones de SQLAlchemy traen los parámetros de la sentencia (CI, datos de correspondencia) y las de
almacenamiento pueden traer rutas locales. El servicio solo registra la CLASE de la excepción.
"""
import logging

import pytest
from sqlalchemy.exc import IntegrityError

from app.modules.medical_records.clinical_documents.storage import storage as storage_singleton
from app.modules.medical_records.laboratory_results import service as results_service
from app.modules.medical_records.laboratory_sync import service as sync_service
from cu11_support import Cu11Http, construir_mundo, post_manual, usar_storage_temporal
from cu11_sync_support import item, post_lote, por_externo

CI_SENSIBLE = "9876543"
RUTA_LOCAL = r"C:\servidor\privado\uploads\documentos\secreto.pdf"


@pytest.fixture(scope="module")
def env():
    entorno = Cu11Http()
    entorno.install()
    yield entorno
    entorno.uninstall()


@pytest.fixture()
def mundo(env, tmp_path, monkeypatch):
    return construir_mundo(env, usar_storage_temporal(monkeypatch, tmp_path))


def assert_log_limpio(caplog, *prohibidos):
    texto = "\n".join(f"{r.getMessage()}\n{r.exc_text or ''}" for r in caplog.records)
    for prohibido in prohibidos:
        assert prohibido not in texto, f"el log contiene {prohibido!r}"
    return texto


def test_descripcion_segura_solo_incluye_clases():
    causa = RuntimeError(f"parámetros: ('{CI_SENSIBLE}',) en {RUTA_LOCAL}")
    error = IntegrityError("INSERT ...", {"ci": CI_SENSIBLE}, causa)
    texto = results_service.descripcion_segura(error)
    assert texto == "IntegrityError (RuntimeError)"
    assert results_service.descripcion_segura(OSError(RUTA_LOCAL)) == "OSError"


def test_el_fallo_inesperado_de_un_item_no_registra_parametros_ni_rutas(mundo, monkeypatch, caplog):
    original = sync_service._insertar_resultado

    def falla_con_datos_sensibles(db, ctx, **kwargs):
        original(db, ctx, **kwargs)
        raise IntegrityError(
            "INSERT INTO resultados_laboratorio ...", {"datos_correspondencia": {"ci": CI_SENSIBLE}},
            RuntimeError(f"({CI_SENSIBLE}) {RUTA_LOCAL}"),
        )

    monkeypatch.setattr(sync_service, "_insertar_resultado", falla_con_datos_sensibles)
    with caplog.at_level(logging.DEBUG):
        respuesta = post_lote(mundo, mundo.p["admin1"], [item("EXT-1", ci=CI_SENSIBLE)])
    assert respuesta.status_code == 201
    fila = por_externo(respuesta.json())["EXT-1"]
    assert fila["codigo_error"] == "ERROR_INTERNO"
    texto = assert_log_limpio(caplog, CI_SENSIBLE, RUTA_LOCAL, "INSERT INTO")
    assert "EXT-1" in texto and "IntegrityError (RuntimeError)" in texto
    assert CI_SENSIBLE not in respuesta.text and RUTA_LOCAL not in respuesta.text


def test_el_fallo_de_almacenamiento_de_un_item_no_registra_rutas(mundo, monkeypatch, caplog):
    def falla(*args, **kwargs):
        raise OSError(f"No se pudo escribir {RUTA_LOCAL}")

    monkeypatch.setattr(storage_singleton, "store", falla)
    with caplog.at_level(logging.DEBUG):
        respuesta = post_lote(mundo, mundo.p["admin1"], [item("EXT-1")])
    assert por_externo(respuesta.json())["EXT-1"]["codigo_error"] == "ALMACENAMIENTO_FALLIDO"
    texto = assert_log_limpio(caplog, RUTA_LOCAL, "No se pudo escribir")
    assert "OSError" in texto
    assert RUTA_LOCAL not in respuesta.text


def test_el_fallo_de_almacenamiento_de_la_carga_manual_no_registra_rutas(mundo, monkeypatch, caplog):
    def falla(*args, **kwargs):
        raise OSError(f"No se pudo escribir {RUTA_LOCAL}")

    monkeypatch.setattr(storage_singleton, "store", falla)
    with caplog.at_level(logging.DEBUG):
        respuesta = post_manual(mundo, mundo.p["admin1"])
    assert respuesta.status_code == 500
    assert respuesta.json()["detail"] == {"codigo": "ALMACENAMIENTO_FALLIDO", "mensaje": "No se pudo guardar el archivo."}
    assert_log_limpio(caplog, RUTA_LOCAL, "No se pudo escribir")
    assert RUTA_LOCAL not in respuesta.text


def test_la_compensacion_que_falla_no_registra_rutas(monkeypatch, caplog):
    def falla(clave):
        raise OSError(f"sin permiso sobre {RUTA_LOCAL}")

    monkeypatch.setattr(storage_singleton, "delete", falla)
    with caplog.at_level(logging.DEBUG):
        results_service._borrar_archivo("documentos/ab/cd/resultado-lab-1-uuid.pdf")
    texto = assert_log_limpio(caplog, RUTA_LOCAL, "sin permiso sobre")
    assert "OSError" in texto
