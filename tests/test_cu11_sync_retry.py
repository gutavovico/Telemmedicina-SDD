"""CU11 · tarea 6.7: reintento de ítems en ERROR sin duplicar (criterio 8)."""
import pytest

from app.modules.medical_records.laboratory_sync.models import SincronizacionLaboratorio, SincronizacionLaboratorioItem
from cu11_support import Cu11Http, cantidad_de_archivos, construir_mundo, pdf_bytes, usar_storage_temporal
from cu11_sync_support import (
    URL_SYNC,
    auditorias,
    crear_fuente_db,
    item,
    manifiesto,
    por_externo,
    post_lote,
    post_reintento,
    resultado_de,
    total_documentos_lab,
    total_resultados,
)

EXE = (b"MZ\x90\x00binario", "application/octet-stream")


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


def reintentar(mundo, id_sync, items, usuario=None, **kwargs):
    return post_reintento(mundo, usuario or mundo.p["admin1"], id_sync, items, **kwargs)


def lote_con_un_archivo_invalido(mundo):
    """EXT-1 y EXT-3 bien; EXT-2 con un .exe: COMPLETADA_CON_ERRORES."""
    return enviar(
        mundo, [item("EXT-1"), item("EXT-2", archivo="malo.exe"), item("EXT-3")], archivos={"malo.exe": EXE}
    )


def estado_de(mundo, id_sync):
    return mundo.env.uno(SincronizacionLaboratorio, SincronizacionLaboratorio.id_sincronizacion == id_sync)


def item_db(mundo, id_sync, id_externo):
    return mundo.env.uno(
        SincronizacionLaboratorioItem,
        SincronizacionLaboratorioItem.id_sincronizacion == id_sync,
        SincronizacionLaboratorioItem.id_externo == id_externo,
    )


def test_reintento_exitoso_tras_corregir_el_archivo(mundo):
    inicial = lote_con_un_archivo_invalido(mundo)
    id_sync = inicial["id_sincronizacion"]
    assert inicial["estado"] == "COMPLETADA_CON_ERRORES" and inicial["con_error"] == 1

    respuesta = reintentar(mundo, id_sync, [item("EXT-2", archivo="corregido.pdf")], archivos={"corregido.pdf": pdf_bytes(b"corregido")})
    assert respuesta.status_code == 200, respuesta.text
    cuerpo = respuesta.json()
    por = por_externo(cuerpo)
    assert por["EXT-2"]["resultado"] == "INCORPORADO" and por["EXT-2"]["codigo_error"] is None and por["EXT-2"]["intento"] == 2
    assert por["EXT-1"]["intento"] == 1 and por["EXT-3"]["intento"] == 1       # los demás ítems no se tocan
    assert cuerpo["id_sincronizacion"] == id_sync
    assert (cuerpo["incorporados"], cuerpo["pendientes"], cuerpo["duplicados"], cuerpo["con_error"]) == (3, 0, 0, 0)
    assert cuerpo["estado"] == "COMPLETADA" and cuerpo["reintentos"] == 1 and cuerpo["total_items"] == 3
    assert total_resultados(mundo) == 3 and total_documentos_lab(mundo) == 3 and cantidad_de_archivos(mundo.almacen) == 3
    resultado = resultado_de(mundo, "EXT-2")
    assert resultado.id_sincronizacion == id_sync and resultado.registrado_por == mundo.p["admin1"].id_usuario
    assert resultado.nombre_archivo == "corregido.pdf"
    # se audita el reintento y la creación del resultado
    assert len(auditorias(mundo, "REINTENTAR_SINCRONIZACION_LABORATORIO", "sincronizaciones_laboratorio")) == 1
    assert len(auditorias(mundo, "CREAR_RESULTADO_LABORATORIO")) == 3


def test_el_reintento_puede_terminar_como_pendiente_segun_la_correspondencia(mundo):
    inicial = enviar(mundo, [item("EXT-1", ci="9999999", archivo="malo.exe")], archivos={"malo.exe": EXE})
    assert inicial["estado"] == "FALLIDA"
    cuerpo = reintentar(mundo, inicial["id_sincronizacion"], [item("EXT-1", ci="9999999")]).json()
    fila = por_externo(cuerpo)["EXT-1"]
    assert fila["resultado"] == "PENDIENTE_REVISION" and fila["detalle"] == "PACIENTE_NO_ENCONTRADO" and fila["intento"] == 2
    assert (cuerpo["pendientes"], cuerpo["con_error"], cuerpo["estado"]) == (1, 0, "COMPLETADA")
    assert resultado_de(mundo, "EXT-1").estado == "PENDIENTE_REVISION" and total_documentos_lab(mundo) == 0


def test_un_reintento_que_sigue_fallando_incrementa_el_intento_sin_crear_nada(mundo):
    inicial = enviar(mundo, [item("EXT-1", archivo="malo.exe")], archivos={"malo.exe": EXE})
    cuerpo = reintentar(mundo, inicial["id_sincronizacion"], [item("EXT-1", archivo="aun-malo.exe")], archivos={"aun-malo.exe": EXE}).json()
    fila = por_externo(cuerpo)["EXT-1"]
    assert fila["resultado"] == "ERROR" and fila["codigo_error"] == "ARCHIVO_TIPO_NO_PERMITIDO" and fila["intento"] == 2
    assert (cuerpo["estado"], cuerpo["con_error"], cuerpo["reintentos"]) == ("FALLIDA", 1, 1)
    assert total_resultados(mundo) == 0 and cantidad_de_archivos(mundo.almacen) == 0


def test_varios_reintentos_acumulan_los_contadores(mundo):
    inicial = enviar(
        mundo, [item("EXT-1", archivo="a.exe"), item("EXT-2", archivo="b.exe")], archivos={"a.exe": EXE, "b.exe": EXE}
    )
    id_sync = inicial["id_sincronizacion"]
    primero = reintentar(mundo, id_sync, [item("EXT-1")]).json()
    assert (primero["estado"], primero["con_error"], primero["incorporados"], primero["reintentos"]) == ("COMPLETADA_CON_ERRORES", 1, 1, 1)
    segundo = reintentar(mundo, id_sync, [item("EXT-2")]).json()
    assert (segundo["estado"], segundo["con_error"], segundo["incorporados"], segundo["reintentos"]) == ("COMPLETADA", 0, 2, 2)


def test_reintentar_un_item_ya_integrado_responde_422_y_no_crea_nada(mundo):
    inicial = lote_con_un_archivo_invalido(mundo)
    antes = (total_resultados(mundo), cantidad_de_archivos(mundo.almacen))
    respuesta = reintentar(mundo, inicial["id_sincronizacion"], [item("EXT-1")])
    assert respuesta.status_code == 422
    assert respuesta.json()["detail"]["codigo"] == "ITEM_NO_REINTENTABLE" and "EXT-1" in respuesta.json()["detail"]["mensaje"]
    assert (total_resultados(mundo), cantidad_de_archivos(mundo.almacen)) == antes
    assert item_db(mundo, inicial["id_sincronizacion"], "EXT-1").intento == 1
    assert estado_de(mundo, inicial["id_sincronizacion"]).reintentos == 0


def test_la_peticion_mezclada_se_rechaza_completa_antes_de_procesar_nada(mundo):
    inicial = lote_con_un_archivo_invalido(mundo)
    id_sync = inicial["id_sincronizacion"]
    respuesta = reintentar(mundo, id_sync, [item("EXT-2"), item("EXT-1")])        # EXT-2 sí es reintentable; EXT-1 no
    assert respuesta.status_code == 422 and respuesta.json()["detail"]["codigo"] == "ITEM_NO_REINTENTABLE"
    assert item_db(mundo, id_sync, "EXT-2").resultado == "ERROR" and item_db(mundo, id_sync, "EXT-2").intento == 1
    assert total_resultados(mundo) == 2


@pytest.mark.parametrize("externo", ["EXT-NUNCA-ENVIADO", "ext-2"])
def test_un_id_externo_que_no_pertenece_a_la_sincronizacion_no_es_reintentable(mundo, externo):
    inicial = lote_con_un_archivo_invalido(mundo)
    respuesta = reintentar(mundo, inicial["id_sincronizacion"], [item(externo)])
    assert respuesta.status_code == 422 and respuesta.json()["detail"]["codigo"] == "ITEM_NO_REINTENTABLE"
    assert total_resultados(mundo) == 2


def test_un_item_ya_reintentado_con_exito_deja_de_ser_reintentable(mundo):
    inicial = lote_con_un_archivo_invalido(mundo)
    assert reintentar(mundo, inicial["id_sincronizacion"], [item("EXT-2")]).status_code == 200
    otra_vez = reintentar(mundo, inicial["id_sincronizacion"], [item("EXT-2")])
    assert otra_vez.status_code == 422 and otra_vez.json()["detail"]["codigo"] == "ITEM_NO_REINTENTABLE"
    assert total_resultados(mundo) == 3


def test_reintentar_un_contenido_distinto_con_el_archivo_original_queda_duplicado(mundo):
    enviar(mundo, [item("EXT-1")], archivos={"EXT-1.pdf": pdf_bytes(b"original")})
    segundo = enviar(mundo, [item("EXT-1")], archivos={"EXT-1.pdf": pdf_bytes(b"distinto")})
    assert por_externo(segundo)["EXT-1"]["codigo_error"] == "CONTENIDO_DISTINTO"
    cuerpo = reintentar(mundo, segundo["id_sincronizacion"], [item("EXT-1")], archivos={"EXT-1.pdf": pdf_bytes(b"original")}).json()
    fila = por_externo(cuerpo)["EXT-1"]
    assert fila["resultado"] == "DUPLICADO" and fila["intento"] == 2 and fila["id_resultado"] == resultado_de(mundo, "EXT-1").id_resultado
    assert (cuerpo["duplicados"], cuerpo["con_error"], cuerpo["estado"]) == (1, 0, "COMPLETADA")
    assert total_resultados(mundo) == 1


def test_el_reintento_de_una_sincronizacion_ajena_o_inexistente_responde_404_sin_filtrar_datos(mundo):
    inicial = lote_con_un_archivo_invalido(mundo)
    crear_fuente_db(mundo, 2, "LAB-CENTRAL")
    for id_sync in (inicial["id_sincronizacion"], 987654):
        respuesta = reintentar(mundo, id_sync, [item("EXT-2")], usuario=mundo.p["admin2"])
        assert respuesta.status_code == 404
        assert respuesta.json()["detail"]["codigo"] == "SINCRONIZACION_NO_ENCONTRADA"
        assert "EXT-2" not in respuesta.text and "LAB-CENTRAL" not in respuesta.text
    assert item_db(mundo, inicial["id_sincronizacion"], "EXT-2").intento == 1
    assert estado_de(mundo, inicial["id_sincronizacion"]).reintentos == 0
    assert total_resultados(mundo) == 2


def test_la_fuente_del_manifiesto_debe_coincidir_con_la_de_la_sincronizacion(mundo):
    inicial = lote_con_un_archivo_invalido(mundo)
    crear_fuente_db(mundo, 1, "LAB-OTRA")
    respuesta = reintentar(mundo, inicial["id_sincronizacion"], [item("EXT-2")], fuente="LAB-OTRA")
    assert respuesta.status_code == 422 and respuesta.json()["detail"]["codigo"] == "LOTE_INVALIDO"
    assert total_resultados(mundo) == 2


def test_reintento_con_la_fuente_desactivada_responde_409(mundo):
    inicial = lote_con_un_archivo_invalido(mundo)
    mundo.env.como(mundo.p["admin1"])
    assert mundo.client.patch(f"/api/v1/fuentes-laboratorio/{mundo.datos['fuente'].id_fuente}", json={"activa": "NO"}).status_code == 200
    respuesta = reintentar(mundo, inicial["id_sincronizacion"], [item("EXT-2")])
    assert respuesta.status_code == 409 and respuesta.json()["detail"]["codigo"] == "FUENTE_INACTIVA"
    assert total_resultados(mundo) == 2


@pytest.mark.parametrize(
    "raw",
    ["no es json", "{}", '{"fuente": "LAB-CENTRAL", "items": []}'],
)
def test_manifiesto_invalido_en_el_reintento_responde_422(mundo, raw):
    inicial = lote_con_un_archivo_invalido(mundo)
    respuesta = reintentar(mundo, inicial["id_sincronizacion"], [], raw=raw)
    assert respuesta.status_code == 422 and respuesta.json()["detail"]["codigo"] == "LOTE_INVALIDO"


@pytest.mark.parametrize("campo", ["id_clinica", "tenant_id"])
def test_campos_de_clinica_en_el_reintento_responden_422(mundo, campo):
    inicial = lote_con_un_archivo_invalido(mundo)
    respuesta = reintentar(
        mundo, inicial["id_sincronizacion"], [], raw=manifiesto([item("EXT-2")], **{campo: 2})
    )
    assert respuesta.status_code == 422 and respuesta.json()["detail"]["codigo"] == "LOTE_INVALIDO"
    assert reintentar(mundo, inicial["id_sincronizacion"], [item("EXT-2")], campos={campo: "2"}).status_code == 422
    assert item_db(mundo, inicial["id_sincronizacion"], "EXT-2").resultado == "ERROR"


def test_el_reintento_no_modifica_otras_sincronizaciones(mundo):
    primera = lote_con_un_archivo_invalido(mundo)
    segunda = enviar(mundo, [item("EXT-9", archivo="x.exe")], archivos={"x.exe": EXE})
    reintentar(mundo, primera["id_sincronizacion"], [item("EXT-2")])
    assert estado_de(mundo, segunda["id_sincronizacion"]).estado == "FALLIDA"
    assert estado_de(mundo, segunda["id_sincronizacion"]).reintentos == 0
    assert estado_de(mundo, primera["id_sincronizacion"]).reintentos == 1


def test_reintento_sin_permiso_o_sin_token(mundo):
    inicial = lote_con_un_archivo_invalido(mundo)
    id_sync = inicial["id_sincronizacion"]
    assert reintentar(mundo, id_sync, [item("EXT-2")], usuario=mundo.p["medico1"]).status_code == 403
    assert reintentar(mundo, id_sync, [item("EXT-2")], usuario=mundo.p["recepcion1"]).status_code == 403
    mundo.env.anonimo()
    assert post_reintento(mundo, None, id_sync, [item("EXT-2")]).status_code == 401
    assert total_resultados(mundo) == 2 and item_db(mundo, id_sync, "EXT-2").intento == 1


def test_el_reintento_a_la_url_equivocada_no_existe(mundo):
    mundo.env.como(mundo.p["admin1"])
    assert mundo.client.get(f"{URL_SYNC}/1/reintentos").status_code == 405
