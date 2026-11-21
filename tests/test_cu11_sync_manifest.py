"""CU11 · tarea 6.2: parseo y validación del manifiesto y del lote (criterios 4 y 9).

Todo defecto del manifiesto, de la fuente o del tamaño de la petición rechaza el lote COMPLETO sin crear
nada (ni sincronización, ni ítems, ni resultados, ni documentos, ni archivos).
"""
import pytest

from cu11_support import Cu11Http, construir_mundo, pdf_bytes, usar_storage_temporal
from cu11_sync_support import (
    URL_SYNC,
    crear_fuente_db,
    item,
    manifiesto,
    nada_creado,
    por_externo,
    post_lote,
    total_resultados,
)

LIMITE_100_MB = 100 * 1024 * 1024


@pytest.fixture(scope="module")
def env():
    entorno = Cu11Http()
    entorno.install()
    yield entorno
    entorno.uninstall()


@pytest.fixture()
def mundo(env, tmp_path, monkeypatch):
    return construir_mundo(env, usar_storage_temporal(monkeypatch, tmp_path))


def assert_lote_invalido(respuesta, mundo):
    assert respuesta.status_code == 422, respuesta.text
    assert respuesta.json()["detail"]["codigo"] == "LOTE_INVALIDO"
    assert nada_creado(mundo)


def test_control_positivo_un_lote_valido_se_acepta(mundo):
    respuesta = post_lote(mundo, mundo.p["admin1"], [item("EXT-1")])
    assert respuesta.status_code == 201, respuesta.text
    assert respuesta.json()["items"][0]["resultado"] == "INCORPORADO"


@pytest.mark.parametrize(
    "raw",
    [
        "esto no es json",
        "",
        "   ",
        "[]",
        '"texto"',
        "null",
        "{}",                                                     # sin fuente ni items
        '{"fuente": "LAB-CENTRAL"}',                               # sin items
        '{"fuente": "LAB-CENTRAL", "items": []}',                  # lote vacío
        '{"fuente": "LAB-CENTRAL", "items": {}}',                  # items no es lista
        '{"fuente": "LAB-CENTRAL", "items": ["x"]}',               # ítem no es objeto
        '{"fuente": "", "items": [{"id_externo": "A"}]}',          # fuente vacía
        '{"fuente": 7, "items": []}',
    ],
)
def test_manifiesto_malformado_o_vacio_rechaza_el_lote(mundo, raw):
    respuesta = post_lote(mundo, mundo.p["admin1"], [], raw=raw)
    assert_lote_invalido(respuesta, mundo)


def test_falta_la_parte_manifiesto(mundo):
    mundo.env.como(mundo.p["admin1"])
    respuesta = mundo.client.post(URL_SYNC, files=[("archivos", ("a.pdf", pdf_bytes(), "application/pdf"))])
    assert_lote_invalido(respuesta, mundo)


@pytest.mark.parametrize(
    "cambio",
    [
        {"id_externo": ""},
        {"id_externo": "x" * 101},
        {"ci": ""},
        {"ci": "1" * 21},
        {"complemento": "C" * 11},
        {"codigo_examen": ""},
        {"codigo_examen": "E" * 51},
        {"laboratorio_origen": ""},
        {"laboratorio_origen": "L" * 201},
        {"fecha_realizacion": "no-es-fecha"},
        {"fecha_realizacion": "2999-01-01"},                      # fecha futura
        {"nombre_archivo": ""},
        {"id_orden": 0},
        {"id_orden": "abc"},
        {"observaciones": "o" * 2001},
        {"ci": 1111111},                                          # número en lugar de texto
    ],
)
def test_un_item_invalido_rechaza_el_lote_completo(mundo, cambio):
    valido = item("EXT-OK")
    invalido = {**item("EXT-MAL"), **cambio}
    respuesta = post_lote(mundo, mundo.p["admin1"], [valido, invalido])
    assert_lote_invalido(respuesta, mundo)


@pytest.mark.parametrize("campo", ["falta_ci", "falta_codigo", "falta_fecha", "falta_laboratorio", "falta_archivo", "falta_id"])
def test_campos_obligatorios_del_item(mundo, campo):
    quitar = {
        "falta_ci": "ci", "falta_codigo": "codigo_examen", "falta_fecha": "fecha_realizacion",
        "falta_laboratorio": "laboratorio_origen", "falta_archivo": "nombre_archivo", "falta_id": "id_externo",
    }[campo]
    roto = item("EXT-MAL")
    roto.pop(quitar)
    assert_lote_invalido(post_lote(mundo, mundo.p["admin1"], [item("EXT-OK"), roto]), mundo)


def test_mas_de_50_items_rechaza_el_lote(mundo):
    items = [item(f"EXT-{n}") for n in range(51)]
    assert_lote_invalido(post_lote(mundo, mundo.p["admin1"], items), mundo)


def test_exactamente_50_items_se_aceptan_con_observaciones_largas(mundo):
    """50 ítems con observaciones de 2000 caracteres (manifiesto de ~110 KB) no chocan con el límite de campos de texto."""
    items = [item(f"EXT-{n:02d}", observaciones="o" * 2000) for n in range(50)]
    respuesta = post_lote(mundo, mundo.p["admin1"], items)
    assert respuesta.status_code == 201, respuesta.text
    cuerpo = respuesta.json()
    assert cuerpo["total_items"] == 50 and cuerpo["incorporados"] == 50 and cuerpo["estado"] == "COMPLETADA"


def test_un_manifiesto_de_mas_de_1_mb_no_crea_nada(mundo):
    """Starlette limita a 1 MB los campos de texto del multipart: responde 400 (texto plano) antes de procesar nada.

    Con 50 ítems el manifiesto real pesa muy por debajo (ver la prueba de 50 ítems con observaciones largas), así
    que este rechazo solo ocurre con manifiestos fabricados; no es un ``LOTE_INVALIDO`` del contrato.
    """
    enorme = manifiesto([item("EXT-1")], relleno="r" * (1024 * 1024 + 10))
    respuesta = post_lote(mundo, mundo.p["admin1"], [item("EXT-1")], raw=enorme)
    assert respuesta.status_code == 400, respuesta.text
    assert nada_creado(mundo)


def test_id_externo_repetido_en_el_lote_rechaza_todo(mundo):
    items = [item("EXT-1"), item("EXT-2"), item("EXT-1", archivo="otro.pdf")]
    respuesta = post_lote(mundo, mundo.p["admin1"], items)
    assert_lote_invalido(respuesta, mundo)
    assert "id_externo" in respuesta.json()["detail"]["mensaje"]


@pytest.mark.parametrize("campo", ["id_clinica", "tenant_id"])
def test_campos_de_clinica_en_el_manifiesto_responden_422(mundo, campo):
    raiz = post_lote(mundo, mundo.p["admin1"], [item("EXT-1")], raw=manifiesto([item("EXT-1")], **{campo: 2}))
    assert_lote_invalido(raiz, mundo)
    dentro = {**item("EXT-1"), campo: 2}
    assert_lote_invalido(post_lote(mundo, mundo.p["admin1"], [dentro]), mundo)
    # incluso con el valor de su propia clínica o nulo: la clínica nunca viene del cliente
    assert_lote_invalido(post_lote(mundo, mundo.p["admin1"], [{**item("EXT-1"), campo: 1}]), mundo)
    assert_lote_invalido(post_lote(mundo, mundo.p["admin1"], [{**item("EXT-1"), campo: None}]), mundo)


@pytest.mark.parametrize("campo", ["id_clinica", "tenant_id"])
def test_campos_de_clinica_como_parte_del_formulario_responden_422(mundo, campo):
    respuesta = post_lote(mundo, mundo.p["admin1"], [item("EXT-1")], campos={campo: "2"})
    assert_lote_invalido(respuesta, mundo)


def test_fuente_inexistente_responde_404_y_no_crea_nada(mundo):
    respuesta = post_lote(mundo, mundo.p["admin1"], [item("EXT-1")], fuente="NO-EXISTE")
    assert respuesta.status_code == 404
    assert respuesta.json()["detail"]["codigo"] == "FUENTE_NO_ENCONTRADA"
    assert nada_creado(mundo)


def test_fuente_de_otra_clinica_responde_404_sin_filtrar_datos(mundo):
    crear_fuente_db(mundo, 2, "LAB-NORTE", nombre="Reservada del Norte")
    respuesta = post_lote(mundo, mundo.p["admin1"], [item("EXT-1")], fuente="LAB-NORTE")
    assert respuesta.status_code == 404
    assert respuesta.json()["detail"]["codigo"] == "FUENTE_NO_ENCONTRADA"
    assert "Norte" not in respuesta.text
    assert nada_creado(mundo)


def test_fuente_inactiva_responde_409_y_no_crea_nada(mundo):
    crear_fuente_db(mundo, 1, "LAB-APAGADA", activa="NO")
    respuesta = post_lote(mundo, mundo.p["admin1"], [item("EXT-1")], fuente="LAB-APAGADA")
    assert respuesta.status_code == 409
    assert respuesta.json()["detail"]["codigo"] == "FUENTE_INACTIVA"
    assert nada_creado(mundo)


def test_el_codigo_de_la_fuente_se_normaliza_a_mayusculas(mundo):
    respuesta = post_lote(mundo, mundo.p["admin1"], [item("EXT-1")], fuente="  lab-central ")
    assert respuesta.status_code == 201, respuesta.text
    assert respuesta.json()["fuente_codigo"] == "LAB-CENTRAL"


def test_peticion_de_mas_de_100_mb_se_rechaza_por_content_length_antes_de_procesar(mundo):
    """El rechazo ocurre por la cabecera, sin leer el cuerpo (el cuerpo real de la prueba es pequeño)."""
    respuesta = post_lote(
        mundo, mundo.p["admin1"], [item("EXT-1")], headers={"Content-Length": str(LIMITE_100_MB + 1)}
    )
    assert_lote_invalido(respuesta, mundo)
    assert "100 MB" in respuesta.json()["detail"]["mensaje"]


def test_el_rechazo_por_tamano_tambien_aplica_al_reintento(mundo):
    respuesta = post_lote(
        mundo, mundo.p["admin1"], [item("EXT-1")], url=f"{URL_SYNC}/1/reintentos",
        headers={"Content-Length": str(LIMITE_100_MB + 1)},
    )
    assert_lote_invalido(respuesta, mundo)


def test_el_limite_de_100_mb_es_inclusivo(mundo):
    respuesta = post_lote(
        mundo, mundo.p["admin1"], [item("EXT-1")], headers={"Content-Length": str(LIMITE_100_MB)}
    )
    assert respuesta.status_code == 201, respuesta.text


def test_dos_archivos_con_el_mismo_nombre_son_ambiguos(mundo):
    mundo.env.como(mundo.p["admin1"])
    respuesta = mundo.client.post(
        URL_SYNC,
        data={"manifiesto": manifiesto([item("EXT-1", archivo="r.pdf")])},
        files=[
            ("archivos", ("r.pdf", pdf_bytes(b"a"), "application/pdf")),
            ("archivos", ("r.pdf", pdf_bytes(b"b"), "application/pdf")),
        ],
    )
    assert_lote_invalido(respuesta, mundo)


def test_archivo_declarado_pero_ausente_no_rechaza_el_lote_solo_ese_item(mundo):
    items = [item("EXT-1"), item("EXT-2")]
    respuesta = post_lote(mundo, mundo.p["admin1"], items, archivos={"EXT-2.pdf": None})
    assert respuesta.status_code == 201, respuesta.text
    por = por_externo(respuesta.json())
    assert por["EXT-1"]["resultado"] == "INCORPORADO"
    assert por["EXT-2"]["resultado"] == "ERROR" and por["EXT-2"]["codigo_error"] == "ARCHIVO_AUSENTE"
    assert total_resultados(mundo) == 1


def test_archivos_no_referenciados_por_el_manifiesto_se_ignoran(mundo):
    mundo.env.como(mundo.p["admin1"])
    respuesta = mundo.client.post(
        URL_SYNC,
        data={"manifiesto": manifiesto([item("EXT-1")])},
        files=[
            ("archivos", ("EXT-1.pdf", pdf_bytes(b"1"), "application/pdf")),
            ("archivos", ("sobrante.pdf", pdf_bytes(b"2"), "application/pdf")),
        ],
    )
    assert respuesta.status_code == 201, respuesta.text
    assert total_resultados(mundo) == 1


def test_campos_ajenos_del_item_se_ignoran_y_no_cambian_estado_ni_origen(mundo):
    """Campos desconocidos se ignoran: el estado y el origen siempre los decide el servidor."""
    raro = {**item("EXT-1"), "estado": "ANULADO", "origen": "MANUAL"}
    respuesta = post_lote(mundo, mundo.p["admin1"], [raro])
    assert respuesta.status_code == 201, respuesta.text
    assert respuesta.json()["items"][0]["resultado"] == "INCORPORADO"


@pytest.mark.parametrize("quien", ["medico1", "recepcion1", "paciente1", "sin_permisos1"])
def test_lote_sin_permiso_de_sincronizacion_responde_403_y_no_crea_nada(mundo, quien):
    respuesta = post_lote(mundo, mundo.p[quien], [item("EXT-1")])
    assert respuesta.status_code == 403
    assert "lab_results:sync" in respuesta.json()["detail"]
    assert nada_creado(mundo)


def test_lote_sin_autenticacion_responde_401(mundo):
    mundo.env.anonimo()
    respuesta = post_lote(mundo, None, [item("EXT-1")])
    assert respuesta.status_code == 401
    assert nada_creado(mundo)


def test_cuenta_sin_clinica_responde_403(mundo):
    respuesta = post_lote(mundo, mundo.p["global"], [item("EXT-1")])
    assert respuesta.status_code == 403
    assert nada_creado(mundo)
