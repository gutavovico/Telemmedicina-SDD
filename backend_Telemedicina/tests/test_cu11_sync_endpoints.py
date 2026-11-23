"""CU11 · tarea 6.6: endpoints de sincronización (``POST/GET /api/v1/sincronizaciones-laboratorio``)."""
from datetime import date, timedelta

import pytest

from app.modules.medical_records.laboratory_sync.models import SincronizacionLaboratorio
from cu11_support import Cu11Http, construir_mundo, usar_storage_temporal
from cu11_sync_support import (
    URL_SYNC,
    auditorias,
    crear_fuente_db,
    item,
    manifiesto,
    nada_creado,
    post_lote,
    total_sincronizaciones,
)

CAMPOS_CABECERA = {
    "id_sincronizacion", "id_fuente", "fuente_codigo", "tipo", "estado", "total_items", "incorporados",
    "pendientes", "duplicados", "con_error", "reintentos", "id_usuario", "proceso", "iniciado_en", "finalizado_en",
}
CAMPOS_ITEM = {"id_externo", "resultado", "id_resultado", "codigo_error", "detalle", "intento"}


@pytest.fixture(scope="module")
def env():
    entorno = Cu11Http()
    entorno.install()
    yield entorno
    entorno.uninstall()


@pytest.fixture()
def mundo(env, tmp_path, monkeypatch):
    return construir_mundo(env, usar_storage_temporal(monkeypatch, tmp_path))


def enviar(mundo, items, **kwargs):
    respuesta = post_lote(mundo, mundo.p["admin1"], items, **kwargs)
    assert respuesta.status_code == 201, respuesta.text
    return respuesta.json()


def test_lote_valido_responde_201_con_el_esquema_del_contrato(mundo):
    respuesta = post_lote(mundo, mundo.p["admin1"], [item("EXT-1"), item("EXT-2", ci="9999999")])
    assert respuesta.status_code == 201, respuesta.text
    cuerpo = respuesta.json()
    assert set(cuerpo) == CAMPOS_CABECERA | {"items"}
    assert all(set(i) == CAMPOS_ITEM for i in cuerpo["items"])
    assert cuerpo["items"][0] == {
        "id_externo": "EXT-1", "resultado": "INCORPORADO", "id_resultado": cuerpo["items"][0]["id_resultado"],
        "codigo_error": None, "detalle": None, "intento": 1,
    }
    assert "archivo_url" not in respuesta.text and "id_clinica" not in respuesta.text
    assert total_sincronizaciones(mundo) == 1
    assert len(auditorias(mundo, "EJECUTAR_SINCRONIZACION_LABORATORIO")) == 1


def test_listado_paginado_sin_items_y_ordenado_de_lo_nuevo_a_lo_viejo(mundo):
    primera = enviar(mundo, [item("A-1")])
    segunda = enviar(mundo, [item("B-1", ci="9999999")])
    tercera = enviar(mundo, [item("C-1", archivo="x.exe")], archivos={"x.exe": (b"MZ\x90\x00", "application/octet-stream")})
    mundo.env.como(mundo.p["admin1"])

    todo = mundo.client.get(URL_SYNC)
    assert todo.status_code == 200
    cuerpo = todo.json()
    assert cuerpo["total"] == 3 and cuerpo["page"] == 1 and cuerpo["page_size"] == 10 and cuerpo["total_pages"] == 1
    assert [s["id_sincronizacion"] for s in cuerpo["items"]] == [
        tercera["id_sincronizacion"], segunda["id_sincronizacion"], primera["id_sincronizacion"],
    ]
    assert all(set(s) == CAMPOS_CABECERA for s in cuerpo["items"])            # sin ``items`` por ítem
    assert cuerpo["items"][0]["fuente_codigo"] == "LAB-CENTRAL"

    pagina = mundo.client.get(URL_SYNC, params={"page": 2, "page_size": 2}).json()
    assert pagina["total"] == 3 and pagina["total_pages"] == 2
    assert [s["id_sincronizacion"] for s in pagina["items"]] == [primera["id_sincronizacion"]]


def test_filtros_del_listado(mundo):
    otra = crear_fuente_db(mundo, 1, "LAB-OTRA")
    enviar(mundo, [item("A-1")])                                                      # LAB-CENTRAL, COMPLETADA
    enviar(mundo, [item("B-1")], fuente="LAB-OTRA")                                   # LAB-OTRA, COMPLETADA
    enviar(mundo, [item("C-1", archivo="x.exe")], archivos={"x.exe": (b"MZ\x90\x00", "application/octet-stream")})  # FALLIDA
    mundo.env.como(mundo.p["admin1"])
    listado = lambda **p: mundo.client.get(URL_SYNC, params=p)  # noqa: E731

    assert listado(id_fuente=otra).json()["total"] == 1
    assert listado(id_fuente=mundo.datos["fuente"].id_fuente).json()["total"] == 2
    assert listado(estado="FALLIDA").json()["total"] == 1
    assert listado(estado="COMPLETADA").json()["total"] == 2
    assert listado(estado="COMPLETADA_CON_ERRORES").json()["total"] == 0
    hoy = date.today()
    assert listado(fecha_desde=str(hoy), fecha_hasta=str(hoy)).json()["total"] == 3
    assert listado(fecha_desde=str(hoy + timedelta(days=1))).json()["total"] == 0
    assert listado(fecha_hasta=str(hoy - timedelta(days=1))).json()["total"] == 0
    assert listado(id_fuente=otra, estado="FALLIDA").json()["total"] == 0


@pytest.mark.parametrize(
    "params",
    [{"page": 0}, {"page_size": 0}, {"page_size": 101}, {"estado": "INVENTADO"}, {"fecha_desde": "ayer"}, {"id_fuente": "x"}],
)
def test_parametros_invalidos_del_listado_responden_422(mundo, params):
    mundo.env.como(mundo.p["admin1"])
    assert mundo.client.get(URL_SYNC, params=params).status_code == 422


def test_detalle_con_los_items_en_orden_de_procesamiento(mundo):
    cuerpo = enviar(mundo, [item("EXT-C"), item("EXT-A", ci="9999999"), item("EXT-B")])
    mundo.env.como(mundo.p["admin1"])
    detalle = mundo.client.get(f"{URL_SYNC}/{cuerpo['id_sincronizacion']}")
    assert detalle.status_code == 200
    assert [i["id_externo"] for i in detalle.json()["items"]] == ["EXT-C", "EXT-A", "EXT-B"]
    assert detalle.json()["items"][1]["detalle"] == "PACIENTE_NO_ENCONTRADO"


def test_detalle_inexistente_responde_404(mundo):
    mundo.env.como(mundo.p["admin1"])
    respuesta = mundo.client.get(f"{URL_SYNC}/987654")
    assert respuesta.status_code == 404
    assert respuesta.json()["detail"]["codigo"] == "SINCRONIZACION_NO_ENCONTRADA"


def test_el_encabezado_x_tenant_id_nunca_cambia_la_clinica(mundo):
    enviar(mundo, [item("EXT-1")])
    mundo.env.como(mundo.p["admin2"])
    for valor in ("1", "no-numerico"):
        assert mundo.client.get(URL_SYNC, headers={"X-Tenant-ID": valor}).json()["total"] == 0
    mundo.env.como(mundo.p["admin1"])
    assert mundo.client.get(URL_SYNC, headers={"X-Tenant-ID": "2"}).json()["total"] == 1
    # y un lote enviado con X-Tenant-ID de otra clínica se procesa en la clínica de la sesión
    respuesta = post_lote(mundo, mundo.p["admin1"], [item("EXT-2")], headers={"X-Tenant-ID": "2"})
    assert respuesta.status_code == 201
    assert mundo.env.uno(SincronizacionLaboratorio, SincronizacionLaboratorio.id_sincronizacion == respuesta.json()["id_sincronizacion"]).id_clinica == 1


def test_no_existe_borrado_ni_edicion_de_sincronizaciones(mundo):
    cuerpo = enviar(mundo, [item("EXT-1")])
    mundo.env.como(mundo.p["admin1"])
    url = f"{URL_SYNC}/{cuerpo['id_sincronizacion']}"
    assert mundo.client.delete(url).status_code == 405
    assert mundo.client.put(url, json={}).status_code == 405
    assert mundo.client.patch(url, json={}).status_code == 405
    assert mundo.client.delete(URL_SYNC).status_code == 405


@pytest.mark.parametrize("quien", ["medico1", "recepcion1", "paciente1", "sin_permisos1"])
def test_sin_lab_results_sync_cada_endpoint_responde_403(mundo, quien):
    cuerpo = enviar(mundo, [item("EXT-1")])
    id_sync = cuerpo["id_sincronizacion"]
    mundo.env.como(mundo.p[quien])
    respuestas = [
        mundo.client.get(URL_SYNC),
        mundo.client.get(f"{URL_SYNC}/{id_sync}"),
        post_lote(mundo, mundo.p[quien], [item("EXT-9")]),
        post_lote(mundo, mundo.p[quien], [item("EXT-1")], url=f"{URL_SYNC}/{id_sync}/reintentos"),
    ]
    for respuesta in respuestas:
        assert respuesta.status_code == 403, respuesta.text
        assert "lab_results:sync" in respuesta.json()["detail"]
    assert total_sincronizaciones(mundo) == 1


def test_sin_autenticacion_cada_endpoint_responde_401(mundo):
    cuerpo = enviar(mundo, [item("EXT-1")])
    id_sync = cuerpo["id_sincronizacion"]
    mundo.env.anonimo()
    respuestas = [
        mundo.client.get(URL_SYNC),
        mundo.client.get(f"{URL_SYNC}/{id_sync}"),
        post_lote(mundo, None, [item("EXT-9")]),
        post_lote(mundo, None, [item("EXT-1")], url=f"{URL_SYNC}/{id_sync}/reintentos"),
    ]
    assert [r.status_code for r in respuestas] == [401, 401, 401, 401]
    assert total_sincronizaciones(mundo) == 1


def test_cuenta_sin_clinica_responde_403_en_cada_endpoint(mundo):
    mundo.env.como(mundo.p["global"])
    respuestas = [
        mundo.client.get(URL_SYNC),
        mundo.client.get(f"{URL_SYNC}/1"),
        post_lote(mundo, mundo.p["global"], [item("EXT-1")]),
        post_lote(mundo, mundo.p["global"], [item("EXT-1")], url=f"{URL_SYNC}/1/reintentos"),
    ]
    for respuesta in respuestas:
        assert respuesta.status_code == 403
        assert respuesta.json()["detail"] == "La cuenta autenticada no está asociada a una clínica"
    assert nada_creado(mundo)


def test_el_openapi_publica_las_rutas_del_contrato_y_el_manifiesto_como_multipart(mundo):
    esquema = mundo.client.get("/openapi.json").json()
    rutas = esquema["paths"]
    assert set(rutas["/api/v1/sincronizaciones-laboratorio"]) == {"get", "post"}
    assert set(rutas["/api/v1/sincronizaciones-laboratorio/{id_sincronizacion}"]) == {"get"}
    assert set(rutas["/api/v1/sincronizaciones-laboratorio/{id_sincronizacion}/reintentos"]) == {"post"}
    assert set(rutas["/api/v1/fuentes-laboratorio"]) == {"get", "post"}
    assert set(rutas["/api/v1/fuentes-laboratorio/{id_fuente}"]) == {"patch"}
    cuerpo = rutas["/api/v1/sincronizaciones-laboratorio"]["post"]["requestBody"]["content"]
    assert "multipart/form-data" in cuerpo
    campos = set(esquema["components"]["schemas"][cuerpo["multipart/form-data"]["schema"]["$ref"].split("/")[-1]]["properties"])
    assert campos == {"manifiesto", "archivos"}                              # ni id_clinica ni tenant_id
    # y ninguna ruta de CU11 de este bloque declara un DELETE
    assert not any("delete" in v for k, v in rutas.items() if "laboratorio" in k)


def test_la_respuesta_de_un_lote_rechazado_no_expone_datos(mundo):
    respuesta = post_lote(mundo, mundo.p["admin1"], [], raw=manifiesto([item("EXT-1"), item("EXT-1", archivo="b.pdf")]))
    assert respuesta.status_code == 422
    assert set(respuesta.json()["detail"]) == {"codigo", "mensaje"}
