"""CU11 · tarea 3.7: consulta de resultados en el expediente (criterios 5, 7 y 9)."""
from datetime import date

import pytest

from app.modules.medical_records.clinical_documents.models import DocumentoClinico
from cu11_support import (
    URL,
    Cu11Http,
    construir_mundo,
    crear_pendiente_db,
    crear_resultado_db,
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
    almacen = usar_storage_temporal(monkeypatch, tmp_path)
    m = construir_mundo(env, almacen)
    pac1 = m.datos["pac1"].id_paciente
    ex = m.datos["examen"].id_examen
    admin = m.p["admin1"].id_usuario
    fuente = m.datos["fuente"].id_fuente
    with env.SessionLocal() as db:
        m.r1 = crear_resultado_db(db, 1, pac1, ex, admin, observaciones="obs-1", hash_archivo="1" * 64,
                                  laboratorio_origen="Lab Central", fecha_realizacion=date(2026, 11, 10))
        m.r2 = crear_resultado_db(db, 1, pac1, ex, admin, codigo_examen="GLUCOSA", hash_archivo="2" * 64,
                                  laboratorio_origen="Lab Norte", fecha_realizacion=date(2026, 10, 1))
        m.r3 = crear_resultado_db(db, 1, m.p["pac_propio"].id_paciente, ex, admin, hash_archivo="3" * 64,
                                  observaciones="obs-propio")
        m.r4 = crear_resultado_db(db, 1, m.p["pac_ajeno"].id_paciente, ex, admin, hash_archivo="4" * 64)
        m.r5 = crear_resultado_db(db, 1, pac1, ex, admin, hash_archivo="5" * 64, estado="ANULADO")
        m.r6 = crear_pendiente_db(db, 1, admin, fuente)
        m.r7 = crear_resultado_db(db, 1, pac1, ex, admin, hash_archivo="7" * 64, origen="SINCRONIZADO",
                                  id_fuente=fuente, id_externo="EXT-7", fecha_realizacion=date(2026, 11, 5))
        m.r8 = crear_resultado_db(db, 2, m.datos["pac2"].id_paciente, m.examen2.id_examen, m.p["admin2"].id_usuario,
                                  hash_archivo="8" * 64)
    return m


def ids(respuesta):
    return {item["id_resultado"] for item in respuesta.json()["items"]}


def get(mundo, persona, ruta, **kw):
    mundo.env.como(mundo.p[persona])
    return mundo.client.get(ruta, **kw)


# ----------------------------------------- listado --------------------------------------- #
def test_medico_lista_solo_incorporados_de_su_clinica(mundo):
    respuesta = get(mundo, "medico1", URL)
    assert respuesta.status_code == 200
    cuerpo = respuesta.json()
    esperados = {mundo.r1.id_resultado, mundo.r2.id_resultado, mundo.r3.id_resultado,
                 mundo.r4.id_resultado, mundo.r7.id_resultado}
    assert ids(respuesta) == esperados and cuerpo["total"] == 5
    assert cuerpo["page"] == 1 and cuerpo["page_size"] == 10 and cuerpo["total_pages"] == 1
    primero = cuerpo["items"][0]
    assert "observaciones" not in primero and "datos_correspondencia" not in primero and "archivo_url" not in primero
    assert primero["id_clinica"] == 1


def test_estados_pendiente_y_anulado_exigen_review(mundo):
    for persona in ("medico1", "admin1"):
        pendientes = get(mundo, persona, f"{URL}?estado=PENDIENTE_REVISION")
        assert pendientes.status_code == 200 and ids(pendientes) == {mundo.r6.id_resultado}
        anulados = get(mundo, persona, f"{URL}?estado=ANULADO")
        assert anulados.status_code == 200 and ids(anulados) == {mundo.r5.id_resultado}
    for persona in ("recepcion1", "paciente1"):
        assert get(mundo, persona, f"{URL}?estado=PENDIENTE_REVISION").status_code == 403
        assert get(mundo, persona, f"{URL}?estado=ANULADO").status_code == 403


def test_filtros_y_paginacion(mundo):
    pac1 = mundo.datos["pac1"].id_paciente
    assert ids(get(mundo, "medico1", f"{URL}?codigo_examen=glucosa")) == {mundo.r2.id_resultado}
    assert ids(get(mundo, "medico1", f"{URL}?laboratorio_origen=norte")) == {mundo.r2.id_resultado}
    assert ids(get(mundo, "medico1", f"{URL}?origen=SINCRONIZADO")) == {mundo.r7.id_resultado}
    assert ids(get(mundo, "medico1", f"{URL}?id_fuente={mundo.datos['fuente'].id_fuente}")) == {mundo.r7.id_resultado}
    assert ids(get(mundo, "medico1", f"{URL}?id_paciente={pac1}")) == {
        mundo.r1.id_resultado, mundo.r2.id_resultado, mundo.r7.id_resultado}
    assert ids(get(mundo, "medico1", f"{URL}?id_paciente={pac1}&fecha_desde=2026-11-01")) == {
        mundo.r1.id_resultado, mundo.r7.id_resultado}
    assert ids(get(mundo, "medico1", f"{URL}?id_paciente={pac1}&fecha_hasta=2026-10-31")) == {mundo.r2.id_resultado}
    pagina = get(mundo, "medico1", f"{URL}?page_size=2&page=3")
    assert pagina.json()["total"] == 5 and pagina.json()["total_pages"] == 3 and len(pagina.json()["items"]) == 1


@pytest.mark.parametrize("consulta", ["page=0", "page_size=101", "estado=OTRO", "origen=OTRO", "fecha_desde=ayer", "id_paciente=0"])
def test_parametros_invalidos_dan_422(mundo, consulta):
    assert get(mundo, "medico1", f"{URL}?{consulta}").status_code == 422


# ------------------------------ alcance del paciente / me ------------------------------- #
def test_paciente_solo_ve_lo_propio_aunque_envie_otro_id(mundo):
    otro = mundo.p["pac_ajeno"].id_paciente
    respuesta = get(mundo, "paciente1", f"{URL}?id_paciente={otro}")
    assert respuesta.status_code == 200 and ids(respuesta) == {mundo.r3.id_resultado}
    assert ids(get(mundo, "paciente1", URL)) == {mundo.r3.id_resultado}


def test_me_devuelve_los_resultados_del_paciente_autenticado(mundo):
    assert ids(get(mundo, "paciente1", f"{URL}/me")) == {mundo.r3.id_resultado}
    assert ids(get(mundo, "paciente1b", f"{URL}/me")) == {mundo.r4.id_resultado}


def test_me_sin_perfil_de_paciente_en_la_clinica_da_404(mundo):
    for persona in ("medico1", "paciente_sin_clinica"):  # staff, y cuenta cuyo paciente tiene id_clinica NULL
        respuesta = get(mundo, persona, f"{URL}/me")
        assert respuesta.status_code == 404, persona
        assert respuesta.json()["detail"]["codigo"] == "PACIENTE_NO_ENCONTRADO"


# ------------------------------------- expediente --------------------------------------- #
def test_expediente_muestra_solo_incorporados_del_paciente(mundo):
    pac1 = mundo.datos["pac1"].id_paciente
    # un pendiente cuyos datos crudos mencionan la CI de pac1 no debe aparecer en su expediente
    with mundo.env.SessionLocal() as db:
        crear_pendiente_db(db, 1, mundo.p["admin1"].id_usuario, mundo.datos["fuente"].id_fuente,
                           id_externo="EXT-CI-PAC1", hash_archivo="a" * 64,
                           datos_correspondencia={"ci": "1111111", "complemento": "", "codigo_examen": "HEMOGRAMA"})
    respuesta = get(mundo, "medico1", f"/api/v1/pacientes/{pac1}/resultados-laboratorio")
    assert respuesta.status_code == 200
    assert ids(respuesta) == {mundo.r1.id_resultado, mundo.r2.id_resultado, mundo.r7.id_resultado}
    assert all(item["estado"] == "INCORPORADO" for item in respuesta.json()["items"])
    assert mundo.env.contar(DocumentoClinico, DocumentoClinico.id_paciente == pac1,
                            DocumentoClinico.tipo_documento == "RESULTADO_LAB") == 0  # los resultados de prueba no indexan


def test_expediente_de_paciente_de_otra_clinica_o_sin_clinica_da_404(mundo):
    for id_paciente in (mundo.datos["pac2"].id_paciente, mundo.datos["pac_sin_clinica"].id_paciente, 999999):
        respuesta = get(mundo, "medico1", f"/api/v1/pacientes/{id_paciente}/resultados-laboratorio")
        assert respuesta.status_code == 404, id_paciente


def test_paciente_solo_accede_a_su_propio_expediente(mundo):
    propio = mundo.p["pac_propio"].id_paciente
    ajeno = mundo.p["pac_ajeno"].id_paciente
    assert ids(get(mundo, "paciente1", f"/api/v1/pacientes/{propio}/resultados-laboratorio")) == {mundo.r3.id_resultado}
    assert get(mundo, "paciente1", f"/api/v1/pacientes/{ajeno}/resultados-laboratorio").status_code == 404
    assert get(mundo, "paciente1", f"/api/v1/pacientes/{mundo.datos['pac1'].id_paciente}/resultados-laboratorio").status_code == 404


def test_recepcion_ve_el_expediente_solo_con_metadatos(mundo):
    pac1 = mundo.datos["pac1"].id_paciente
    respuesta = get(mundo, "recepcion1", f"/api/v1/pacientes/{pac1}/resultados-laboratorio")
    assert respuesta.status_code == 200 and respuesta.json()["total"] == 3
    assert all(item["hash_archivo"] is None for item in respuesta.json()["items"])


# -------------------------------------- detalle ----------------------------------------- #
def test_medico_ve_detalle_completo(mundo):
    cuerpo = get(mundo, "medico1", f"{URL}/{mundo.r1.id_resultado}").json()
    assert cuerpo["observaciones"] == "obs-1" and cuerpo["hash_archivo"] == "1" * 64
    assert cuerpo["datos_correspondencia"] is None and "archivo_url" not in cuerpo
    assert cuerpo["paciente_nombre"] == "Carlos Mamani" and cuerpo["registrado_por_nombre"] == "Admin Uno"


def test_revisor_ve_pendiente_con_datos_de_correspondencia_y_otros_no(mundo):
    id_pendiente = mundo.r6.id_resultado
    cuerpo = get(mundo, "medico1", f"{URL}/{id_pendiente}").json()
    assert cuerpo["estado"] == "PENDIENTE_REVISION" and cuerpo["id_paciente"] is None
    assert cuerpo["motivo_pendiente"] == "PACIENTE_NO_ENCONTRADO"
    assert cuerpo["datos_correspondencia"]["ci"] == "9999999"
    assert get(mundo, "recepcion1", f"{URL}/{id_pendiente}").status_code == 404
    assert get(mundo, "paciente1", f"{URL}/{id_pendiente}").status_code == 404
    assert get(mundo, "recepcion1", f"{URL}/{mundo.r5.id_resultado}").status_code == 404  # anulado


def test_recepcion_recibe_metadatos_sin_datos_clinicos(mundo):
    cuerpo = get(mundo, "recepcion1", f"{URL}/{mundo.r1.id_resultado}").json()
    assert cuerpo["codigo_examen"] == "HEMOGRAMA" and cuerpo["laboratorio_origen"] == "Lab Central"
    assert cuerpo["observaciones"] is None and cuerpo["hash_archivo"] is None and cuerpo["datos_correspondencia"] is None


def test_paciente_ve_su_detalle_pero_no_el_de_otros(mundo):
    propio = get(mundo, "paciente1", f"{URL}/{mundo.r3.id_resultado}")
    assert propio.status_code == 200 and propio.json()["observaciones"] == "obs-propio"
    assert get(mundo, "paciente1", f"{URL}/{mundo.r1.id_resultado}").status_code == 404  # otro paciente, misma clínica
    assert get(mundo, "paciente1", f"{URL}/{mundo.r4.id_resultado}").status_code == 404


def test_acceso_cruzado_entre_clinicas_da_404_indistinguible_de_inexistente(mundo):
    de_otra = get(mundo, "admin2", f"{URL}/{mundo.r1.id_resultado}")
    inexistente = get(mundo, "admin2", f"{URL}/987654")
    assert de_otra.status_code == inexistente.status_code == 404
    assert de_otra.json() == inexistente.json()
    assert get(mundo, "admin1", f"{URL}/{mundo.r8.id_resultado}").status_code == 404
    assert ids(get(mundo, "admin2", URL)) == {mundo.r8.id_resultado}


# ------------------------------------ autenticación ------------------------------------- #
def test_sin_token_da_401_y_sin_permiso_de_lectura_da_403(mundo):
    for ruta in (URL, f"{URL}/me", f"{URL}/{mundo.r1.id_resultado}", "/api/v1/pacientes/1/resultados-laboratorio"):
        mundo.env.anonimo()
        assert mundo.client.get(ruta).status_code == 401, ruta
        assert get(mundo, "sin_permisos1", ruta).status_code == 403, ruta
    assert get(mundo, "global", URL).status_code == 403  # cuenta sin clínica
