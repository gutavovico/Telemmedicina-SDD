"""CU11 · tarea 3.9: resolución de pendientes y anulación (criterios 5 y 9)."""
from datetime import date

import pytest
from sqlalchemy import select

from app.modules.auth.models import Auditoria
from app.modules.medical_records.clinical_documents.models import DocumentoClinico
from app.modules.medical_records.clinical_documents.storage import storage
from app.modules.medical_records.laboratory_orders.models import OrdenLaboratorio
from app.modules.medical_records.laboratory_results import service
from app.modules.medical_records.laboratory_results.models import ResultadoLaboratorio
from cu11_support import (
    URL,
    Cu11Http,
    cantidad_de_archivos,
    construir_mundo,
    crear_pendiente_db,
    crear_resultado_db,
    pdf_bytes,
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
    m = construir_mundo(env, usar_storage_temporal(monkeypatch, tmp_path))
    clave, _ = storage.store("pendiente.pdf", pdf_bytes(b"pendiente"), "application/pdf")
    with env.SessionLocal() as db:
        m.pendiente = crear_pendiente_db(
            db, 1, m.p["admin1"].id_usuario, m.datos["fuente"].id_fuente, archivo_url=clave
        )
    m.id = m.pendiente.id_resultado
    return m


def accion(mundo, persona, id_resultado, ruta, cuerpo):
    mundo.env.como(mundo.p[persona])
    return mundo.client.post(f"{URL}/{id_resultado}/{ruta}", json=cuerpo)


def asignar(mundo, persona="medico1", id_resultado=None, **cuerpo):
    datos = {"accion": "ASIGNAR", "id_paciente": mundo.datos["pac1"].id_paciente, "codigo_examen": "HEMOGRAMA"}
    datos.update(cuerpo)
    return accion(mundo, persona, id_resultado or mundo.id, "resolver", datos)


def estado_actual(mundo, id_resultado=None):
    return mundo.env.uno(ResultadoLaboratorio, ResultadoLaboratorio.id_resultado == (id_resultado or mundo.id))


def documentos_lab(mundo):
    return mundo.env.contar(DocumentoClinico, DocumentoClinico.tipo_documento == "RESULTADO_LAB")


# ----------------------------------- resolver: ASIGNAR ---------------------------------- #
def test_un_pendiente_no_tiene_documento_clinico_hasta_resolverse(mundo):
    assert estado_actual(mundo).estado == "PENDIENTE_REVISION" and documentos_lab(mundo) == 0


def test_asignar_incorpora_indexa_documento_y_audita(mundo):
    respuesta = asignar(mundo, "medico1")
    assert respuesta.status_code == 200, respuesta.text
    cuerpo = respuesta.json()
    assert cuerpo["estado"] == "INCORPORADO" and cuerpo["id_paciente"] == mundo.datos["pac1"].id_paciente
    assert cuerpo["id_examen"] == mundo.datos["examen"].id_examen and cuerpo["nombre_examen"] == "Hemograma completo"
    assert cuerpo["id_documento"] is not None
    assert cuerpo["resuelto_por"] == mundo.p["medico1"].id_usuario and cuerpo["resuelto_en"] is not None
    assert cuerpo["datos_correspondencia"]["ci"] == "9999999"  # el revisor conserva los datos crudos
    assert cuerpo["origen"] == "SINCRONIZADO" and cuerpo["id_externo"] == "EXT-PEND-1"

    resultado = estado_actual(mundo)
    documento = mundo.env.uno(DocumentoClinico, DocumentoClinico.id_documento == resultado.id_documento)
    assert documento.tipo_documento == "RESULTADO_LAB" and documento.estado == "ACTIVO"
    assert documento.id_clinica == 1 and documento.id_paciente == resultado.id_paciente
    assert documento.metadatos["id_resultado_laboratorio"] == mundo.id
    assert documento.archivo_url == resultado.archivo_url

    traza = mundo.env.uno(Auditoria, Auditoria.accion == "RESOLVER_RESULTADO_LABORATORIO")
    assert traza.registro_id == mundo.id and traza.id_clinica == 1
    assert traza.datos_anteriores["estado"] == "PENDIENTE_REVISION" and traza.datos_nuevos["estado"] == "INCORPORADO"

    # ahora sí aparece en el expediente del paciente
    mundo.env.como(mundo.p["medico1"])
    expediente = mundo.client.get(f"/api/v1/pacientes/{mundo.datos['pac1'].id_paciente}/resultados-laboratorio")
    assert [i["id_resultado"] for i in expediente.json()["items"]] == [mundo.id]


def test_asignar_con_orden_valida(mundo):
    respuesta = asignar(mundo, id_orden=mundo.datos["orden"].id_orden)
    assert respuesta.status_code == 200 and respuesta.json()["id_orden"] == mundo.datos["orden"].id_orden


def test_asignar_a_paciente_de_otra_clinica_o_sin_clinica_da_404_y_sigue_pendiente(mundo):
    for id_paciente in (mundo.datos["pac2"].id_paciente, mundo.datos["pac_sin_clinica"].id_paciente, 999999):
        respuesta = asignar(mundo, id_paciente=id_paciente)
        assert respuesta.status_code == 404, id_paciente
        assert respuesta.json()["detail"]["codigo"] == "PACIENTE_NO_ENCONTRADO"
        assert "Luis" not in respuesta.text and "Norte" not in respuesta.text
    assert estado_actual(mundo).estado == "PENDIENTE_REVISION" and documentos_lab(mundo) == 0


def test_asignar_con_examen_u_orden_invalidos(mundo):
    assert asignar(mundo, codigo_examen="GLUCOSA").status_code == 404  # solo existe en la clínica 2
    assert asignar(mundo, codigo_examen="NO_EXISTE").json()["detail"]["codigo"] == "EXAMEN_NO_ENCONTRADO"
    with mundo.env.SessionLocal() as db:
        otra = OrdenLaboratorio(
            id_clinica=2, id_paciente=mundo.datos["pac2"].id_paciente, id_medico=mundo.datos["medico"].id_usuario,
            examenes=[{"codigo": "HEMOGRAMA"}], fecha_orden=date(2026, 11, 1), estado="FIRMADA")
        ajena = OrdenLaboratorio(
            id_clinica=1, id_paciente=mundo.p["pac_propio"].id_paciente, id_medico=mundo.datos["medico"].id_usuario,
            examenes=[{"codigo": "HEMOGRAMA"}], fecha_orden=date(2026, 11, 1), estado="FIRMADA")
        borrador = OrdenLaboratorio(
            id_clinica=1, id_paciente=mundo.datos["pac1"].id_paciente, id_medico=mundo.datos["medico"].id_usuario,
            examenes=[{"codigo": "HEMOGRAMA"}], fecha_orden=date(2026, 11, 1), estado="BORRADOR")
        db.add_all([otra, ajena, borrador])
        db.commit()
        ids = (otra.id_orden, ajena.id_orden, borrador.id_orden)
    esperado = [(404, "ORDEN_NO_ENCONTRADA"), (409, "ORDEN_PACIENTE_NO_COINCIDE"), (409, "ORDEN_NO_FIRMADA")]
    for id_orden, (http, codigo) in zip(ids, esperado):
        respuesta = asignar(mundo, id_orden=id_orden)
        assert respuesta.status_code == http and respuesta.json()["detail"]["codigo"] == codigo
    assert estado_actual(mundo).estado == "PENDIENTE_REVISION" and documentos_lab(mundo) == 0


def test_si_falla_la_auditoria_al_asignar_no_cambia_nada(mundo, monkeypatch):
    def auditoria_rota(*args, **kwargs):
        raise RuntimeError("auditoría caída")

    monkeypatch.setattr(service, "registrar_auditoria", auditoria_rota)
    assert asignar(mundo).status_code == 500
    resultado = estado_actual(mundo)
    assert resultado.estado == "PENDIENTE_REVISION" and resultado.id_paciente is None and resultado.id_documento is None
    assert documentos_lab(mundo) == 0


# ---------------------------------- resolver: DESCARTAR --------------------------------- #
def test_descartar_con_motivo(mundo):
    respuesta = accion(mundo, "medico1", mundo.id, "resolver", {"accion": "DESCARTAR", "motivo": "Corresponde a otra institución"})
    assert respuesta.status_code == 200
    cuerpo = respuesta.json()
    assert cuerpo["estado"] == "ANULADO" and cuerpo["motivo_resolucion"] == "Corresponde a otra institución"
    assert cuerpo["resuelto_por"] == mundo.p["medico1"].id_usuario and cuerpo["id_documento"] is None
    assert documentos_lab(mundo) == 0
    assert mundo.env.contar(Auditoria, Auditoria.accion == "RESOLVER_RESULTADO_LABORATORIO") == 1


@pytest.mark.parametrize("cuerpo", [
    {"accion": "DESCARTAR"},
    {"accion": "DESCARTAR", "motivo": ""},
    {"accion": "DESCARTAR", "motivo": "ab"},
    {"accion": "DESCARTAR", "motivo": "m" * 501},
    {"accion": "ASIGNAR"},
    {"accion": "ASIGNAR", "id_paciente": 1},
    {"accion": "ASIGNAR", "codigo_examen": "HEMOGRAMA"},
    {"accion": "OTRA"},
    {"accion": "DESCARTAR", "motivo": "válido", "id_clinica": 2},
    {"accion": "DESCARTAR", "motivo": "válido", "tenant_id": 2},
])
def test_cuerpos_invalidos_de_resolver_dan_422_sin_cambios(mundo, cuerpo):
    respuesta = accion(mundo, "medico1", mundo.id, "resolver", cuerpo)
    assert respuesta.status_code == 422
    assert estado_actual(mundo).estado == "PENDIENTE_REVISION"


# ------------------------------ transiciones no permitidas ------------------------------ #
def test_resolver_un_resultado_que_no_esta_pendiente_da_409(mundo):
    with mundo.env.SessionLocal() as db:
        incorporado = crear_resultado_db(db, 1, mundo.datos["pac1"].id_paciente, mundo.datos["examen"].id_examen,
                                         mundo.p["admin1"].id_usuario, hash_archivo="a" * 64)
        anulado = crear_resultado_db(db, 1, mundo.datos["pac1"].id_paciente, mundo.datos["examen"].id_examen,
                                     mundo.p["admin1"].id_usuario, hash_archivo="b" * 64, estado="ANULADO")
    for objetivo in (incorporado, anulado):
        respuesta = asignar(mundo, id_resultado=objetivo.id_resultado)
        assert respuesta.status_code == 409 and respuesta.json()["detail"]["codigo"] == "ESTADO_NO_PERMITIDO"
        respuesta = accion(mundo, "medico1", objetivo.id_resultado, "resolver", {"accion": "DESCARTAR", "motivo": "no aplica"})
        assert respuesta.status_code == 409
    assert estado_actual(mundo, incorporado.id_resultado).estado == "INCORPORADO"
    assert estado_actual(mundo, anulado.id_resultado).estado == "ANULADO"


def test_resolver_dos_veces_el_mismo_pendiente_da_409_la_segunda(mundo):
    assert asignar(mundo).status_code == 200
    segunda = asignar(mundo)
    assert segunda.status_code == 409 and segunda.json()["detail"]["codigo"] == "ESTADO_NO_PERMITIDO"
    assert documentos_lab(mundo) == 1


def test_anular_un_pendiente_o_un_anulado_da_409(mundo):
    respuesta = accion(mundo, "medico1", mundo.id, "anular", {"motivo": "Cargado por error"})
    assert respuesta.status_code == 409 and respuesta.json()["detail"]["codigo"] == "ESTADO_NO_PERMITIDO"
    accion(mundo, "medico1", mundo.id, "resolver", {"accion": "DESCARTAR", "motivo": "No corresponde"})
    assert accion(mundo, "medico1", mundo.id, "anular", {"motivo": "Cargado por error"}).status_code == 409


# ----------------------------------------- anular --------------------------------------- #
def test_anular_un_incorporado_anula_resultado_y_documento_sin_borrar_el_archivo(mundo):
    creado = post_manual(mundo, mundo.p["medico1"]).json()
    archivos = cantidad_de_archivos(mundo.almacen)
    respuesta = accion(mundo, "medico1", creado["id_resultado"], "anular", {"motivo": "Resultado en paciente equivocado"})
    assert respuesta.status_code == 200
    cuerpo = respuesta.json()
    assert cuerpo["estado"] == "ANULADO" and cuerpo["motivo_resolucion"] == "Resultado en paciente equivocado"
    assert cuerpo["resuelto_por"] == mundo.p["medico1"].id_usuario
    documento = mundo.env.uno(DocumentoClinico, DocumentoClinico.id_documento == creado["id_documento"])
    assert documento.estado == "ANULADO"
    assert cantidad_de_archivos(mundo.almacen) == archivos  # baja lógica: el archivo se conserva
    traza = mundo.env.uno(Auditoria, Auditoria.accion == "ANULAR_RESULTADO_LABORATORIO")
    assert traza.registro_id == creado["id_resultado"] and traza.datos_nuevos["estado"] == "ANULADO"
    # ya no aparece en el expediente
    mundo.env.como(mundo.p["medico1"])
    expediente = mundo.client.get(f"/api/v1/pacientes/{mundo.datos['pac1'].id_paciente}/resultados-laboratorio")
    assert expediente.json()["total"] == 0


@pytest.mark.parametrize("cuerpo", [{}, {"motivo": ""}, {"motivo": "ab"}, {"motivo": "m" * 501},
                                    {"motivo": "válido", "id_clinica": 2}])
def test_anular_con_cuerpo_invalido_da_422(mundo, cuerpo):
    creado = post_manual(mundo, mundo.p["medico1"]).json()
    assert accion(mundo, "medico1", creado["id_resultado"], "anular", cuerpo).status_code == 422
    assert estado_actual(mundo, creado["id_resultado"]).estado == "INCORPORADO"


# ------------------------------------ permisos y clínica --------------------------------- #
@pytest.mark.parametrize("persona", ["recepcion1", "paciente1", "sin_permisos1", "global"])
def test_sin_lab_results_review_da_403(mundo, persona):
    cuerpo_resolver = {"accion": "DESCARTAR", "motivo": "No corresponde"}
    assert accion(mundo, persona, mundo.id, "resolver", cuerpo_resolver).status_code == 403
    assert accion(mundo, persona, mundo.id, "anular", {"motivo": "No corresponde"}).status_code == 403
    assert estado_actual(mundo).estado == "PENDIENTE_REVISION"


def test_sin_sesion_da_401(mundo):
    mundo.env.anonimo()
    assert mundo.client.post(f"{URL}/{mundo.id}/resolver", json={"accion": "DESCARTAR", "motivo": "abc"}).status_code == 401
    assert mundo.client.post(f"{URL}/{mundo.id}/anular", json={"motivo": "abc"}).status_code == 401


def test_revisor_de_otra_clinica_recibe_404(mundo):
    assert asignar(mundo, "admin2").status_code == 404
    assert accion(mundo, "admin2", mundo.id, "resolver", {"accion": "DESCARTAR", "motivo": "No corresponde"}).status_code == 404
    assert accion(mundo, "admin2", mundo.id, "anular", {"motivo": "No corresponde"}).status_code == 404
    assert estado_actual(mundo).estado == "PENDIENTE_REVISION"


def test_no_existe_eliminacion_fisica(mundo):
    mundo.env.como(mundo.p["admin1"])
    respuesta = mundo.client.delete(f"{URL}/{mundo.id}")
    assert respuesta.status_code in (404, 405)
    assert estado_actual(mundo) is not None
    paths = mundo.client.get("/openapi.json").json()["paths"]
    for ruta, operaciones in paths.items():
        if "resultados-laboratorio" in ruta:
            assert "delete" not in operaciones, ruta
