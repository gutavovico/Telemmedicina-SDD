"""CU11 · tarea 3.8: descarga del archivo con el tipo de contenido real (criterio 7 y 9)."""
import hashlib

import pytest

from app.modules.auth.models import Auditoria
from app.modules.medical_records.laboratory_results import service
from app.modules.medical_records.laboratory_results.models import ResultadoLaboratorio
from cu11_support import (
    URL,
    Cu11Http,
    construir_mundo,
    crear_pendiente_db,
    jpg_bytes,
    pdf_bytes,
    png_bytes,
    post_manual,
    usar_storage_temporal,
)


@pytest.fixture(scope="module")
def env():
    entorno = Cu11Http()
    entorno.install()
    yield entorno
    entorno.uninstall()


@pytest.fixture()
def mundo(env, tmp_path, monkeypatch):
    return construir_mundo(env, usar_storage_temporal(monkeypatch, tmp_path))


def crear(mundo, persona="medico1", nombre="hemograma.pdf", contenido=None, tipo="application/pdf", **campos):
    respuesta = post_manual(
        mundo, mundo.p[persona], archivo=(nombre, contenido if contenido is not None else pdf_bytes(), tipo), campos=campos
    )
    assert respuesta.status_code == 201, respuesta.text
    return respuesta.json()["id_resultado"]


def descargar(mundo, persona, id_resultado):
    mundo.env.como(mundo.p[persona])
    return mundo.client.get(f"{URL}/{id_resultado}/archivo")


def auditorias(mundo):
    return mundo.env.contar(Auditoria, Auditoria.accion == "DESCARGAR_RESULTADO_LABORATORIO")


@pytest.mark.parametrize("nombre,contenido,tipo", [
    ("informe.pdf", pdf_bytes(b"uno"), "application/pdf"),
    ("foto.jpg", jpg_bytes(b"dos"), "image/jpeg"),
    ("imagen.png", png_bytes(b"tres"), "image/png"),
])
def test_descarga_con_content_type_real_y_contenido_identico(mundo, nombre, contenido, tipo):
    id_resultado = crear(mundo, nombre=nombre, contenido=contenido, tipo=tipo)
    respuesta = descargar(mundo, "medico1", id_resultado)
    assert respuesta.status_code == 200
    assert respuesta.headers["content-type"] == tipo
    assert hashlib.sha256(respuesta.content).hexdigest() == hashlib.sha256(contenido).hexdigest()
    assert respuesta.content == contenido
    assert respuesta.headers["x-content-type-options"] == "nosniff"
    disposicion = respuesta.headers["content-disposition"]
    assert disposicion.startswith("attachment;") and f'filename="{nombre}"' in disposicion
    traza = mundo.env.uno(Auditoria, Auditoria.accion == "DESCARGAR_RESULTADO_LABORATORIO")
    assert traza.tabla_afectada == "resultados_laboratorio" and traza.registro_id == id_resultado
    assert traza.id_clinica == 1 and traza.id_usuario == mundo.p["medico1"].id_usuario
    assert auditorias(mundo) == 1


def test_nombre_con_caracteres_especiales_no_rompe_la_cabecera(mundo):
    id_resultado = crear(mundo, nombre="análisis ñandú (1).pdf")
    disposicion = descargar(mundo, "medico1", id_resultado).headers["content-disposition"]
    assert "\r" not in disposicion and "\n" not in disposicion
    assert "filename*=UTF-8''" in disposicion and 'filename="an' in disposicion


def test_administrador_y_paciente_propio_descargan(mundo):
    id_resultado = crear(mundo)
    assert descargar(mundo, "admin1", id_resultado).status_code == 200
    propio = crear(mundo, contenido=pdf_bytes(b"propio"), id_paciente=str(mundo.p["pac_propio"].id_paciente))
    assert descargar(mundo, "paciente1", propio).status_code == 200


def test_recepcion_no_descarga_aunque_pueda_leer_metadatos(mundo):
    id_resultado = crear(mundo)
    mundo.env.como(mundo.p["recepcion1"])
    assert mundo.client.get(f"{URL}/{id_resultado}").status_code == 200  # metadatos
    respuesta = descargar(mundo, "recepcion1", id_resultado)
    assert respuesta.status_code == 403 and "documents:read:lab_results" in respuesta.text
    assert pdf_bytes()[:8] not in respuesta.content
    assert auditorias(mundo) == 0


def test_paciente_no_descarga_resultados_de_otros(mundo):
    de_otro = crear(mundo)  # resultado de pac1, no de paciente1
    de_ajeno = crear(mundo, contenido=pdf_bytes(b"ajeno"), id_paciente=str(mundo.p["pac_ajeno"].id_paciente))
    assert descargar(mundo, "paciente1", de_otro).status_code == 404
    assert descargar(mundo, "paciente1", de_ajeno).status_code == 404
    assert auditorias(mundo) == 0


def test_resultado_anulado_o_pendiente_no_se_descarga(mundo):
    anulado = crear(mundo)
    mundo.env.como(mundo.p["medico1"])
    assert mundo.client.post(f"{URL}/{anulado}/anular", json={"motivo": "Error de carga"}).status_code == 200
    assert descargar(mundo, "medico1", anulado).status_code == 404
    with mundo.env.SessionLocal() as db:
        pendiente = crear_pendiente_db(db, 1, mundo.p["admin1"].id_usuario, mundo.datos["fuente"].id_fuente)
    for persona in ("medico1", "admin1"):  # incluso quien puede revisar
        assert descargar(mundo, persona, pendiente.id_resultado).status_code == 404
    assert auditorias(mundo) == 0


def test_otra_clinica_e_inexistente_dan_404_identico(mundo):
    id_resultado = crear(mundo)
    de_otra = descargar(mundo, "admin2", id_resultado)
    inexistente = descargar(mundo, "admin2", 987654)
    assert de_otra.status_code == inexistente.status_code == 404
    assert de_otra.json() == inexistente.json()
    assert auditorias(mundo) == 0


def test_sin_permisos_o_sin_sesion(mundo):
    id_resultado = crear(mundo)
    assert descargar(mundo, "sin_permisos1", id_resultado).status_code == 403
    assert descargar(mundo, "global", id_resultado).status_code == 403
    mundo.env.anonimo()
    assert mundo.client.get(f"{URL}/{id_resultado}/archivo").status_code == 401


def test_archivo_ausente_del_almacenamiento_da_404_sin_auditoria(mundo):
    id_resultado = crear(mundo)
    for archivo in mundo.almacen.rglob("*"):
        if archivo.is_file():
            archivo.unlink()
    respuesta = descargar(mundo, "medico1", id_resultado)
    assert respuesta.status_code == 404 and respuesta.json()["detail"]["codigo"] == "ARCHIVO_NO_ENCONTRADO"
    assert auditorias(mundo) == 0


def test_si_falla_la_auditoria_no_se_entrega_el_archivo(mundo, monkeypatch):
    id_resultado = crear(mundo)

    def auditoria_rota(*args, **kwargs):
        raise RuntimeError("auditoría caída")

    monkeypatch.setattr(service, "registrar_auditoria", auditoria_rota)
    respuesta = descargar(mundo, "medico1", id_resultado)
    assert respuesta.status_code == 500
    assert b"%PDF" not in respuesta.content
    assert mundo.env.contar(ResultadoLaboratorio) == 1
