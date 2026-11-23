"""CU11 · tarea 3.11: aislamiento por clínica en cada entidad referenciada (criterios 1, 7 y 9).

Dos clínicas y pacientes con ``id_clinica`` NULL (como los pacientes 1 y 2 de Neon). Todo acceso cruzado,
y todo acceso a un paciente sin clínica, debe comportarse como "no existe" (404) sin filtrar datos.
"""
from datetime import date

import pytest

from app.modules.medical_records.laboratory_orders.models import OrdenLaboratorio
from app.modules.medical_records.laboratory_results.models import ResultadoLaboratorio
from cu11_support import (
    URL,
    Cu11Http,
    cantidad_de_archivos,
    construir_mundo,
    crear_pendiente_db,
    crear_resultado_db,
    post_manual,
    usar_storage_temporal,
)

DATOS_DE_LA_CLINICA_2 = ("Luis", "Norte", "2222222", "70000002", "GLUCOSA")


@pytest.fixture(scope="module")
def env():
    entorno = Cu11Http()
    entorno.install()
    yield entorno
    entorno.uninstall()


@pytest.fixture()
def mundo(env, tmp_path, monkeypatch):
    return construir_mundo(env, usar_storage_temporal(monkeypatch, tmp_path))


def _orden(mundo, id_clinica, id_paciente, codigo):
    with mundo.env.SessionLocal() as db:
        orden = OrdenLaboratorio(
            id_clinica=id_clinica, id_paciente=id_paciente, id_medico=mundo.datos["medico"].id_usuario,
            examenes=[{"codigo": codigo, "nombre": codigo}], fecha_orden=date(2026, 11, 1), estado="FIRMADA",
        )
        db.add(orden)
        db.commit()
        return orden.id_orden


def _resultado_de_la_clinica_2(mundo):
    respuesta = post_manual(
        mundo, mundo.p["admin2"],
        campos={"id_paciente": str(mundo.datos["pac2"].id_paciente), "codigo_examen": "GLUCOSA"},
    )
    assert respuesta.status_code == 201, respuesta.text
    return respuesta.json()["id_resultado"]


def test_control_positivo_la_clinica_2_puede_cargar_con_sus_propios_datos(mundo):
    respuesta = post_manual(
        mundo, mundo.p["admin2"],
        campos={"id_paciente": str(mundo.datos["pac2"].id_paciente), "codigo_examen": "GLUCOSA"},
    )
    assert respuesta.status_code == 201 and respuesta.json()["id_clinica"] == 2


@pytest.mark.parametrize("entidad", ["paciente", "examen", "orden"])
def test_la_clinica_2_no_puede_referenciar_entidades_de_la_clinica_1(mundo, entidad):
    campos = {"id_paciente": str(mundo.datos["pac2"].id_paciente), "codigo_examen": "GLUCOSA"}
    if entidad == "paciente":
        campos["id_paciente"] = str(mundo.datos["pac1"].id_paciente)
    elif entidad == "examen":
        campos["codigo_examen"] = "HEMOGRAMA"  # solo existe en el catálogo de la clínica 1
    else:
        campos["id_orden"] = str(mundo.datos["orden"].id_orden)  # orden de la clínica 1
    respuesta = post_manual(mundo, mundo.p["admin2"], campos=campos)
    assert respuesta.status_code == 404, respuesta.text
    assert mundo.env.contar(ResultadoLaboratorio) == 0 and cantidad_de_archivos(mundo.almacen) == 0
    for dato in ("Carlos", "Mamani", "1111111", "Hemograma completo"):
        assert dato not in respuesta.text


@pytest.mark.parametrize("entidad", ["paciente", "examen", "orden"])
def test_la_clinica_1_no_puede_referenciar_entidades_de_la_clinica_2(mundo, entidad):
    campos = {}
    if entidad == "paciente":
        campos["id_paciente"] = str(mundo.datos["pac2"].id_paciente)
    elif entidad == "examen":
        campos["codigo_examen"] = "GLUCOSA"
    else:
        campos["id_orden"] = str(_orden(mundo, 2, mundo.datos["pac2"].id_paciente, "HEMOGRAMA"))
    respuesta = post_manual(mundo, mundo.p["admin1"], campos=campos)
    assert respuesta.status_code == 404, respuesta.text
    assert mundo.env.contar(ResultadoLaboratorio) == 0 and cantidad_de_archivos(mundo.almacen) == 0
    for dato in DATOS_DE_LA_CLINICA_2:
        assert dato not in respuesta.text


def test_un_resultado_de_la_clinica_2_es_invisible_e_intocable_desde_la_clinica_1(mundo):
    id_resultado = _resultado_de_la_clinica_2(mundo)
    mundo.env.como(mundo.p["admin1"])
    assert mundo.client.get(f"{URL}/{id_resultado}").status_code == 404
    assert mundo.client.get(f"{URL}/{id_resultado}/archivo").status_code == 404
    assert mundo.client.post(f"{URL}/{id_resultado}/anular", json={"motivo": "intento cruzado"}).status_code == 404
    assert mundo.client.post(f"{URL}/{id_resultado}/resolver",
                             json={"accion": "DESCARTAR", "motivo": "intento cruzado"}).status_code == 404
    assert mundo.client.get(URL).json()["total"] == 0
    assert mundo.client.get(f"/api/v1/pacientes/{mundo.datos['pac2'].id_paciente}/resultados-laboratorio").status_code == 404
    assert mundo.env.uno(ResultadoLaboratorio, ResultadoLaboratorio.id_resultado == id_resultado).estado == "INCORPORADO"


def test_un_resultado_de_la_clinica_1_es_invisible_e_intocable_desde_la_clinica_2(mundo):
    creado = post_manual(mundo, mundo.p["admin1"]).json()["id_resultado"]
    mundo.env.como(mundo.p["admin2"])
    assert mundo.client.get(f"{URL}/{creado}").status_code == 404
    assert mundo.client.get(f"{URL}/{creado}/archivo").status_code == 404
    assert mundo.client.post(f"{URL}/{creado}/anular", json={"motivo": "intento cruzado"}).status_code == 404
    assert mundo.client.get(URL).json()["total"] == 0
    assert mundo.client.get(f"/api/v1/pacientes/{mundo.datos['pac1'].id_paciente}/resultados-laboratorio").status_code == 404


def test_un_pendiente_de_otra_clinica_no_se_resuelve_ni_se_lista(mundo):
    with mundo.env.SessionLocal() as db:
        fuente2 = crear_pendiente_db(db, 1, mundo.p["admin1"].id_usuario, mundo.datos["fuente"].id_fuente)
    mundo.env.como(mundo.p["admin2"])
    cuerpo = {"accion": "ASIGNAR", "id_paciente": mundo.datos["pac2"].id_paciente, "codigo_examen": "GLUCOSA"}
    assert mundo.client.post(f"{URL}/{fuente2.id_resultado}/resolver", json=cuerpo).status_code == 404
    assert mundo.client.get(f"{URL}?estado=PENDIENTE_REVISION").json()["total"] == 0


# ------------------------------ pacientes con id_clinica NULL ---------------------------- #
def test_paciente_sin_clinica_no_recibe_resultados_por_carga_manual(mundo):
    huerfanos = (mundo.datos["pac_sin_clinica"].id_paciente, mundo.p["pac_huerfano"].id_paciente)
    for persona in ("admin1", "medico1", "admin2"):
        for id_paciente in huerfanos:
            respuesta = post_manual(mundo, mundo.p[persona], campos={"id_paciente": str(id_paciente)})
            assert respuesta.status_code == 404, (persona, id_paciente)
            assert respuesta.json()["detail"]["codigo"] == "PACIENTE_NO_ENCONTRADO"
    assert mundo.env.contar(ResultadoLaboratorio) == 0 and cantidad_de_archivos(mundo.almacen) == 0


def test_paciente_sin_clinica_no_se_asigna_al_resolver_un_pendiente(mundo):
    with mundo.env.SessionLocal() as db:
        pendiente = crear_pendiente_db(db, 1, mundo.p["admin1"].id_usuario, mundo.datos["fuente"].id_fuente)
    mundo.env.como(mundo.p["admin1"])
    for id_paciente in (mundo.datos["pac_sin_clinica"].id_paciente, mundo.p["pac_huerfano"].id_paciente):
        respuesta = mundo.client.post(
            f"{URL}/{pendiente.id_resultado}/resolver",
            json={"accion": "ASIGNAR", "id_paciente": id_paciente, "codigo_examen": "HEMOGRAMA"},
        )
        assert respuesta.status_code == 404
    assert mundo.env.uno(ResultadoLaboratorio, ResultadoLaboratorio.id_resultado == pendiente.id_resultado
                         ).estado == "PENDIENTE_REVISION"


def test_expediente_de_paciente_sin_clinica_da_404(mundo):
    mundo.env.como(mundo.p["admin1"])
    for id_paciente in (mundo.datos["pac_sin_clinica"].id_paciente, mundo.p["pac_huerfano"].id_paciente):
        assert mundo.client.get(f"/api/v1/pacientes/{id_paciente}/resultados-laboratorio").status_code == 404


def test_cuenta_de_paciente_cuyo_perfil_no_tiene_clinica_no_ve_nada(mundo):
    mundo.env.como(mundo.p["paciente_sin_clinica"])
    for ruta in (f"{URL}/me", URL):
        respuesta = mundo.client.get(ruta)
        assert respuesta.status_code == 404, ruta
    assert mundo.client.get(f"/api/v1/pacientes/{mundo.p['pac_huerfano'].id_paciente}/resultados-laboratorio").status_code == 404


def test_el_nombre_de_un_paciente_sin_clinica_no_se_revela_en_los_listados(mundo):
    """Defensa en profundidad: aunque un resultado apuntara a un paciente sin clínica, su nombre no se expone."""
    with mundo.env.SessionLocal() as db:
        crear_resultado_db(db, 1, mundo.datos["pac_sin_clinica"].id_paciente, mundo.datos["examen"].id_examen,
                           mundo.p["admin1"].id_usuario, hash_archivo="e" * 64)
    mundo.env.como(mundo.p["admin1"])
    item = mundo.client.get(URL).json()["items"][0]
    assert item["id_paciente"] == mundo.datos["pac_sin_clinica"].id_paciente
    assert item["paciente_nombre"] is None


def test_las_respuestas_de_error_no_filtran_datos_de_la_otra_clinica(mundo):
    id_resultado = _resultado_de_la_clinica_2(mundo)
    mundo.env.como(mundo.p["admin1"])
    respuestas = [
        mundo.client.get(f"{URL}/{id_resultado}"),
        mundo.client.get(f"{URL}/{id_resultado}/archivo"),
        mundo.client.post(f"{URL}/{id_resultado}/anular", json={"motivo": "intento cruzado"}),
        mundo.client.get(f"/api/v1/pacientes/{mundo.datos['pac2'].id_paciente}/resultados-laboratorio"),
    ]
    for respuesta in respuestas:
        assert respuesta.status_code == 404
        for dato in DATOS_DE_LA_CLINICA_2:
            assert dato not in respuesta.text


# --------------------------------------------------------------------------- #
# Bloque B (tarea 6.8): fuentes, sincronizaciones e ítems nunca cruzan clínicas
# --------------------------------------------------------------------------- #
def _lote_de_la_clinica_2(mundo, externo="EXT-NORTE"):
    """Fuente propia de la clínica 2 y un lote con su paciente (Luis Norte, GLUCOSA)."""
    from cu11_sync_support import crear_fuente_db, item, post_lote

    id_fuente = crear_fuente_db(mundo, 2, "LAB-NORTE", nombre="Fuente exclusiva del Norte")
    respuesta = post_lote(
        mundo, mundo.p["admin2"],
        [item(externo, ci="2222222", codigo="GLUCOSA"), item("EXT-PEND-NORTE", ci="1234321", codigo="GLUCOSA")],
        fuente="LAB-NORTE",
    )
    assert respuesta.status_code == 201, respuesta.text
    return id_fuente, respuesta.json()


def test_la_clinica_1_no_ve_ni_modifica_fuentes_ni_sincronizaciones_de_la_clinica_2(mundo):
    from cu11_sync_support import URL_FUENTES, URL_SYNC

    id_fuente, lote = _lote_de_la_clinica_2(mundo)
    mundo.env.como(mundo.p["admin1"])
    assert [f["codigo"] for f in mundo.client.get(URL_FUENTES).json()["items"]] == ["LAB-CENTRAL"]
    assert mundo.client.get(URL_SYNC).json()["total"] == 0
    respuestas = [
        mundo.client.patch(f"{URL_FUENTES}/{id_fuente}", json={"activa": "NO"}),
        mundo.client.get(f"{URL_SYNC}/{lote['id_sincronizacion']}"),
    ]
    for respuesta in respuestas:
        assert respuesta.status_code == 404
        for dato in (*DATOS_DE_LA_CLINICA_2, "EXT-NORTE", "LAB-NORTE", "Fuente exclusiva"):
            assert dato not in respuesta.text
    # nada cambió en la clínica 2
    mundo.env.como(mundo.p["admin2"])
    assert mundo.client.get(f"{URL_FUENTES}").json()["items"][0]["activa"] == "SI"
    assert mundo.client.get(f"{URL_SYNC}/{lote['id_sincronizacion']}").status_code == 200


def test_la_clinica_1_no_puede_usar_la_fuente_ni_reintentar_la_sincronizacion_de_la_clinica_2(mundo):
    from cu11_sync_support import URL_SYNC, item, post_lote, post_reintento, total_resultados

    _, lote = _lote_de_la_clinica_2(mundo)
    antes = total_resultados(mundo)
    # usar el código de una fuente de otra clínica en un lote de la clínica 1
    cruzada = post_lote(mundo, mundo.p["admin1"], [item("EXT-1")], fuente="LAB-NORTE")
    assert cruzada.status_code == 404 and cruzada.json()["detail"]["codigo"] == "FUENTE_NO_ENCONTRADA"
    # reintentar la sincronización ajena (aunque el ítem exista y sea reintentable en su clínica)
    ajeno = post_reintento(mundo, mundo.p["admin1"], lote["id_sincronizacion"], [item("EXT-PEND-NORTE")], fuente="LAB-NORTE")
    assert ajeno.status_code == 404 and ajeno.json()["detail"]["codigo"] == "SINCRONIZACION_NO_ENCONTRADA"
    for respuesta in (cruzada, ajeno):
        assert "Norte" not in respuesta.text and "EXT-NORTE" not in respuesta.text
    assert total_resultados(mundo) == antes


def test_los_resultados_sincronizados_de_una_clinica_no_son_visibles_en_la_otra(mundo):
    _, lote = _lote_de_la_clinica_2(mundo)
    por = {i["id_externo"]: i for i in lote["items"]}
    id_incorporado, id_pendiente = por["EXT-NORTE"]["id_resultado"], por["EXT-PEND-NORTE"]["id_resultado"]
    assert id_incorporado and id_pendiente
    mundo.env.como(mundo.p["admin1"])                            # ADMIN de la clínica 1 (tiene review y descarga)
    for id_resultado in (id_incorporado, id_pendiente):
        assert mundo.client.get(f"{URL}/{id_resultado}").status_code == 404
        assert mundo.client.get(f"{URL}/{id_resultado}/archivo").status_code == 404
        assert mundo.client.post(
            f"{URL}/{id_resultado}/resolver",
            json={"accion": "ASIGNAR", "id_paciente": mundo.datos["pac1"].id_paciente, "codigo_examen": "HEMOGRAMA"},
        ).status_code == 404
    assert mundo.client.get(URL, params={"estado": "PENDIENTE_REVISION"}).json()["total"] == 0


def test_dos_clinicas_pueden_usar_el_mismo_codigo_de_fuente_y_el_mismo_id_externo_sin_mezclarse(mundo):
    from cu11_sync_support import crear_fuente_db, item, post_lote, resultado_de

    crear_fuente_db(mundo, 2, "LAB-CENTRAL")
    uno = post_lote(mundo, mundo.p["admin1"], [item("EXT-IGUAL")])
    dos = post_lote(mundo, mundo.p["admin2"], [item("EXT-IGUAL", ci="2222222", codigo="GLUCOSA")])
    assert uno.status_code == 201 and dos.status_code == 201
    assert uno.json()["items"][0]["resultado"] == "INCORPORADO" and dos.json()["items"][0]["resultado"] == "INCORPORADO"
    a, b = resultado_de(mundo, "EXT-IGUAL", 1), resultado_de(mundo, "EXT-IGUAL", 2)
    assert a.id_resultado != b.id_resultado and (a.id_clinica, b.id_clinica) == (1, 2)
    assert a.id_paciente == mundo.datos["pac1"].id_paciente and b.id_paciente == mundo.datos["pac2"].id_paciente
    # cada sincronización solo lista sus propios ítems
    from cu11_sync_support import URL_SYNC
    mundo.env.como(mundo.p["admin1"])
    detalle = mundo.client.get(f"{URL_SYNC}/{uno.json()['id_sincronizacion']}").json()
    assert [i["id_resultado"] for i in detalle["items"]] == [a.id_resultado]


def test_el_catalogo_y_los_pacientes_de_la_clinica_2_no_resuelven_items_de_la_clinica_1(mundo):
    """La CI de la otra clínica y su estudio exclusivo quedan pendientes: nunca se asocian ni se incorporan."""
    from cu11_sync_support import item, post_lote, por_externo, resultado_de, total_documentos_lab

    respuesta = post_lote(
        mundo, mundo.p["admin1"],
        [item("EXT-CI-AJENA", ci="2222222"), item("EXT-ESTUDIO-AJENO", codigo="GLUCOSA"), item("EXT-SIN-CLINICA", ci="3333333")],
    )
    assert respuesta.status_code == 201, respuesta.text
    por = por_externo(respuesta.json())
    assert {k: v["detalle"] for k, v in por.items()} == {
        "EXT-CI-AJENA": "PACIENTE_NO_ENCONTRADO",
        "EXT-ESTUDIO-AJENO": "EXAMEN_NO_VALIDO",
        "EXT-SIN-CLINICA": "PACIENTE_NO_ENCONTRADO",
    }
    assert all(resultado_de(mundo, k).id_paciente is None for k in por)
    assert total_documentos_lab(mundo) == 0
    assert "Luis" not in respuesta.text and "Maria" not in respuesta.text


def test_cuenta_global_sin_clinica_no_toca_fuentes_ni_sincronizaciones(mundo):
    from cu11_sync_support import URL_FUENTES, URL_SYNC, item, nada_creado, post_lote

    mundo.env.como(mundo.p["global"])
    for respuesta in (
        mundo.client.get(URL_FUENTES),
        mundo.client.get(URL_SYNC),
        mundo.client.post(URL_FUENTES, json={"codigo": "LAB-GLOBAL", "nombre": "Fuente global"}),
        post_lote(mundo, mundo.p["global"], [item("EXT-1")]),
    ):
        assert respuesta.status_code == 403
    assert mundo.env.contar(type(mundo.datos["fuente"])) == 1
    assert nada_creado(mundo)
