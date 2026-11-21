"""CU11 · tarea 6.1: fuentes de laboratorio (criterio 4).

Unicidad por clínica, normalización del código, permiso ``lab_results:sync`` (solo ADMIN), aislamiento
(404 ante una fuente de otra clínica), auditoría y ausencia de borrado.
"""
import pytest

from app.modules.medical_records.laboratory_sync.models import FuenteLaboratorio
from cu11_support import Cu11Http, construir_mundo, usar_storage_temporal
from cu11_sync_support import URL_FUENTES, auditorias, crear_fuente_db


@pytest.fixture(scope="module")
def env():
    entorno = Cu11Http()
    entorno.install()
    yield entorno
    entorno.uninstall()


@pytest.fixture()
def mundo(env, tmp_path, monkeypatch):
    return construir_mundo(env, usar_storage_temporal(monkeypatch, tmp_path))


def crear(mundo, usuario, codigo="lab-central-2", nombre="Laboratorio Central Dos", **extra):
    mundo.env.como(usuario)
    return mundo.client.post(URL_FUENTES, json={"codigo": codigo, "nombre": nombre, **extra})


def test_crear_fuente_normaliza_el_codigo_queda_activa_y_se_audita(mundo):
    respuesta = crear(mundo, mundo.p["admin1"], codigo="  lab-nuevo_1 ")
    assert respuesta.status_code == 201, respuesta.text
    cuerpo = respuesta.json()
    assert cuerpo["codigo"] == "LAB-NUEVO_1"
    assert cuerpo["activa"] == "SI"
    assert cuerpo["nombre"] == "Laboratorio Central Dos"
    assert cuerpo["created_at"] and cuerpo["updated_at"]
    assert "id_clinica" not in cuerpo
    fila = mundo.env.uno(FuenteLaboratorio, FuenteLaboratorio.id_fuente == cuerpo["id_fuente"])
    assert fila.id_clinica == 1  # la clínica sale de la sesión
    trazas = auditorias(mundo, "CREAR_FUENTE_LABORATORIO", "fuentes_laboratorio")
    assert len(trazas) == 1
    assert trazas[0].id_clinica == 1 and trazas[0].registro_id == cuerpo["id_fuente"]
    assert trazas[0].id_usuario == mundo.p["admin1"].id_usuario


def test_codigo_repetido_en_la_misma_clinica_responde_409(mundo):
    # la fuente LAB-CENTRAL ya existe en la clínica 1 (semilla); también sin distinguir mayúsculas
    for codigo in ("LAB-CENTRAL", "lab-central"):
        respuesta = crear(mundo, mundo.p["admin1"], codigo=codigo)
        assert respuesta.status_code == 409
        assert respuesta.json()["detail"]["codigo"] == "FUENTE_DUPLICADA"
    assert mundo.env.contar(FuenteLaboratorio, FuenteLaboratorio.id_clinica == 1) == 1


def test_el_mismo_codigo_en_otra_clinica_es_valido(mundo):
    respuesta = crear(mundo, mundo.p["admin2"], codigo="LAB-CENTRAL")
    assert respuesta.status_code == 201, respuesta.text
    assert mundo.env.contar(FuenteLaboratorio, FuenteLaboratorio.codigo == "LAB-CENTRAL") == 2
    assert mundo.env.uno(FuenteLaboratorio, FuenteLaboratorio.id_fuente == respuesta.json()["id_fuente"]).id_clinica == 2


@pytest.mark.parametrize(
    "cuerpo",
    [
        {"codigo": "A", "nombre": "Nombre válido"},                      # código corto
        {"codigo": "X" * 51, "nombre": "Nombre válido"},                 # código largo
        {"codigo": "LAB CENTRAL", "nombre": "Nombre válido"},            # espacio
        {"codigo": "LAB.CENTRAL", "nombre": "Nombre válido"},            # punto
        {"codigo": "LAB-ÑÚ", "nombre": "Nombre válido"},                 # no ASCII
        {"codigo": "LAB-OK", "nombre": "ab"},                            # nombre corto
        {"codigo": "LAB-OK", "nombre": "n" * 201},                       # nombre largo
        {"codigo": "LAB-OK"},                                            # falta nombre
        {"nombre": "Nombre válido"},                                     # falta código
        {"codigo": "LAB-OK", "nombre": "Nombre válido", "id_clinica": 2},
        {"codigo": "LAB-OK", "nombre": "Nombre válido", "tenant_id": 2},
        {"codigo": "LAB-OK", "nombre": "Nombre válido", "activa": "NO"},
    ],
)
def test_validacion_de_la_creacion_responde_422_en_forma_de_lista(mundo, cuerpo):
    mundo.env.como(mundo.p["admin1"])
    respuesta = mundo.client.post(URL_FUENTES, json=cuerpo)
    assert respuesta.status_code == 422
    assert isinstance(respuesta.json()["detail"], list)
    assert mundo.env.contar(FuenteLaboratorio, FuenteLaboratorio.id_clinica == 1) == 1


def test_listar_devuelve_solo_las_fuentes_de_la_clinica_con_filtro_y_paginacion(mundo):
    crear_fuente_db(mundo, 1, "LAB-INACTIVA", activa="NO")
    crear_fuente_db(mundo, 2, "LAB-NORTE", nombre="Fuente exclusiva del Norte")
    mundo.env.como(mundo.p["admin1"])

    todas = mundo.client.get(URL_FUENTES)
    assert todas.status_code == 200
    cuerpo = todas.json()
    assert cuerpo["total"] == 2 and cuerpo["page"] == 1 and cuerpo["page_size"] == 10 and cuerpo["total_pages"] == 1
    assert [f["codigo"] for f in cuerpo["items"]] == ["LAB-CENTRAL", "LAB-INACTIVA"]
    assert "LAB-NORTE" not in todas.text and "Norte" not in todas.text

    activas = mundo.client.get(URL_FUENTES, params={"activa": "SI"}).json()
    assert [f["codigo"] for f in activas["items"]] == ["LAB-CENTRAL"]
    inactivas = mundo.client.get(URL_FUENTES, params={"activa": "NO"}).json()
    assert [f["codigo"] for f in inactivas["items"]] == ["LAB-INACTIVA"]

    pagina = mundo.client.get(URL_FUENTES, params={"page": 2, "page_size": 1}).json()
    assert pagina["total"] == 2 and pagina["total_pages"] == 2
    assert [f["codigo"] for f in pagina["items"]] == ["LAB-INACTIVA"]


@pytest.mark.parametrize("params", [{"page": 0}, {"page_size": 0}, {"page_size": 101}, {"activa": "TAL VEZ"}])
def test_listar_valida_los_parametros(mundo, params):
    mundo.env.como(mundo.p["admin1"])
    assert mundo.client.get(URL_FUENTES, params=params).status_code == 422


def test_modificar_nombre_y_desactivar_se_audita_y_no_toca_el_codigo(mundo):
    id_fuente = mundo.datos["fuente"].id_fuente
    mundo.env.como(mundo.p["admin1"])
    renombrada = mundo.client.patch(f"{URL_FUENTES}/{id_fuente}", json={"nombre": "Laboratorio Renombrado"})
    assert renombrada.status_code == 200, renombrada.text
    assert renombrada.json()["nombre"] == "Laboratorio Renombrado"
    assert renombrada.json()["codigo"] == "LAB-CENTRAL" and renombrada.json()["activa"] == "SI"

    desactivada = mundo.client.patch(f"{URL_FUENTES}/{id_fuente}", json={"activa": "NO"})
    assert desactivada.status_code == 200 and desactivada.json()["activa"] == "NO"
    reactivada = mundo.client.patch(f"{URL_FUENTES}/{id_fuente}", json={"activa": "SI"})
    assert reactivada.json()["activa"] == "SI"

    trazas = auditorias(mundo, "ACTUALIZAR_FUENTE_LABORATORIO", "fuentes_laboratorio")
    assert len(trazas) == 3
    assert trazas[0].datos_anteriores["nombre"] == "Laboratorio Central"
    assert trazas[0].datos_nuevos["nombre"] == "Laboratorio Renombrado"
    assert trazas[1].datos_nuevos["activa"] == "NO"


@pytest.mark.parametrize(
    "cuerpo",
    [
        {},                                       # sin ningún campo
        {"codigo": "OTRO-CODIGO"},                # el código no se modifica
        {"id_clinica": 2, "nombre": "Nombre nuevo"},
        {"tenant_id": 2, "nombre": "Nombre nuevo"},
        {"activa": "QUIZAS"},
        {"nombre": "ab"},
    ],
)
def test_patch_no_permite_cambiar_clinica_ni_codigo_ni_valores_invalidos(mundo, cuerpo):
    id_fuente = mundo.datos["fuente"].id_fuente
    mundo.env.como(mundo.p["admin1"])
    respuesta = mundo.client.patch(f"{URL_FUENTES}/{id_fuente}", json=cuerpo)
    assert respuesta.status_code == 422
    fuente = mundo.env.uno(FuenteLaboratorio, FuenteLaboratorio.id_fuente == id_fuente)
    assert (fuente.id_clinica, fuente.codigo, fuente.nombre, fuente.activa) == (
        1, "LAB-CENTRAL", "Laboratorio Central", "SI",
    )
    assert auditorias(mundo, "ACTUALIZAR_FUENTE_LABORATORIO") == []


def test_fuente_de_otra_clinica_o_inexistente_responde_404_sin_filtrar_datos(mundo):
    id_ajena = crear_fuente_db(mundo, 2, "LAB-NORTE", nombre="Reservada del Norte")
    mundo.env.como(mundo.p["admin1"])
    for id_fuente in (id_ajena, 99999):
        respuesta = mundo.client.patch(f"{URL_FUENTES}/{id_fuente}", json={"nombre": "Intento de cambio"})
        assert respuesta.status_code == 404
        assert respuesta.json() == {"detail": {"codigo": "FUENTE_NO_ENCONTRADA", "mensaje": "Fuente de laboratorio no encontrada."}}
        assert "Norte" not in respuesta.text
    ajena = mundo.env.uno(FuenteLaboratorio, FuenteLaboratorio.id_fuente == id_ajena)
    assert ajena.nombre == "Reservada del Norte" and ajena.activa == "SI"
    # y la clínica 2 sí puede modificar la suya
    mundo.env.como(mundo.p["admin2"])
    assert mundo.client.patch(f"{URL_FUENTES}/{id_ajena}", json={"activa": "NO"}).status_code == 200


@pytest.mark.parametrize("quien", ["medico1", "recepcion1", "paciente1", "sin_permisos1"])
def test_sin_lab_results_sync_todo_responde_403(mundo, quien):
    id_fuente = mundo.datos["fuente"].id_fuente
    mundo.env.como(mundo.p[quien])
    respuestas = [
        mundo.client.get(URL_FUENTES),
        mundo.client.post(URL_FUENTES, json={"codigo": "LAB-X", "nombre": "Fuente nueva"}),
        mundo.client.patch(f"{URL_FUENTES}/{id_fuente}", json={"nombre": "Nombre nuevo"}),
    ]
    for respuesta in respuestas:
        assert respuesta.status_code == 403
        assert "lab_results:sync" in respuesta.json()["detail"]
    assert mundo.env.contar(FuenteLaboratorio) == 1


def test_sin_autenticacion_responde_401(mundo):
    mundo.env.anonimo()
    id_fuente = mundo.datos["fuente"].id_fuente
    assert mundo.client.get(URL_FUENTES).status_code == 401
    assert mundo.client.post(URL_FUENTES, json={"codigo": "LAB-X", "nombre": "Fuente nueva"}).status_code == 401
    assert mundo.client.patch(f"{URL_FUENTES}/{id_fuente}", json={"nombre": "Nombre nuevo"}).status_code == 401


def test_cuenta_sin_clinica_responde_403(mundo):
    mundo.env.como(mundo.p["global"])
    for respuesta in (
        mundo.client.get(URL_FUENTES),
        mundo.client.post(URL_FUENTES, json={"codigo": "LAB-X", "nombre": "Fuente nueva"}),
    ):
        assert respuesta.status_code == 403
        assert respuesta.json()["detail"] == "La cuenta autenticada no está asociada a una clínica"


def test_el_encabezado_x_tenant_id_nunca_cambia_la_clinica(mundo):
    crear_fuente_db(mundo, 2, "LAB-NORTE")
    mundo.env.como(mundo.p["admin1"])
    for valor in ("2", "99", "no-numerico"):
        cuerpo = mundo.client.get(URL_FUENTES, headers={"X-Tenant-ID": valor}).json()
        assert [f["codigo"] for f in cuerpo["items"]] == ["LAB-CENTRAL"]
    creada = mundo.client.post(
        URL_FUENTES, json={"codigo": "LAB-TH", "nombre": "Fuente por cabecera"}, headers={"X-Tenant-ID": "2"}
    )
    assert creada.status_code == 201
    assert mundo.env.uno(FuenteLaboratorio, FuenteLaboratorio.codigo == "LAB-TH").id_clinica == 1


def test_no_existe_ninguna_forma_de_borrar_una_fuente(mundo):
    id_fuente = mundo.datos["fuente"].id_fuente
    mundo.env.como(mundo.p["admin1"])
    assert mundo.client.delete(f"{URL_FUENTES}/{id_fuente}").status_code == 405
    assert mundo.client.put(f"{URL_FUENTES}/{id_fuente}", json={"nombre": "Nombre nuevo"}).status_code == 405
    assert mundo.env.contar(FuenteLaboratorio, FuenteLaboratorio.id_fuente == id_fuente) == 1
