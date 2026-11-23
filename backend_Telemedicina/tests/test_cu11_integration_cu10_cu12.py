"""CU11 · tarea 3.12: puntos de integración con CU10 (órdenes) y CU12 (documentos clínicos)."""
from datetime import date

import pytest
from sqlalchemy import select

from app.modules.medical_records.clinical_documents.models import DocumentoClinico
from app.modules.medical_records.laboratory_orders.models import ExamenLaboratorio, OrdenLaboratorio
from cu11_support import (
    URL,
    Cu11Http,
    construir_mundo,
    crear_pendiente_db,
    pdf_bytes,
    post_manual,
    usar_storage_temporal,
)

ORDEN_COLUMNAS = ("id_orden", "id_clinica", "id_paciente", "id_medico", "estado", "firma_digital", "fecha_orden",
                  "archivo_url", "hash_archivo", "updated_at")
DOC_COLUMNAS = ("id_documento", "id_clinica", "id_paciente", "tipo_documento", "titulo", "archivo_url",
                "hash_archivo", "estado", "metadatos", "updated_at")


@pytest.fixture(scope="module")
def env():
    entorno = Cu11Http()
    entorno.install()
    yield entorno
    entorno.uninstall()


@pytest.fixture()
def mundo(env, tmp_path, monkeypatch):
    m = construir_mundo(env, usar_storage_temporal(monkeypatch, tmp_path))
    with env.SessionLocal() as db:
        orden = db.get(OrdenLaboratorio, m.datos["orden"].id_orden)
        orden.firma_digital = "f" * 64
        orden.archivo_url = "documentos/aa/bb/orden-lab-000001.pdf"
        orden.hash_archivo = "c" * 64
        doc_orden = DocumentoClinico(
            id_clinica=1, id_paciente=orden.id_paciente, tipo_documento="ORDEN_LAB", titulo="Orden de Laboratorio - Carlos",
            archivo_url=orden.archivo_url, hash_archivo=orden.hash_archivo, fecha_documento=date(2026, 11, 1),
            metadatos={"id_orden_laboratorio": orden.id_orden}, estado="ACTIVO", firmado_por=m.p["medico1"].id_usuario,
        )
        db.add(doc_orden)
        db.commit()
        m.id_doc_orden = doc_orden.id_documento
    return m


def instantanea(mundo):
    with mundo.env.SessionLocal() as db:
        orden = db.get(OrdenLaboratorio, mundo.datos["orden"].id_orden)
        doc = db.get(DocumentoClinico, mundo.id_doc_orden)
        examenes = [(e.id_examen, e.codigo, e.nombre, e.activo) for e in db.execute(select(ExamenLaboratorio)).scalars()]
        return (
            {c: getattr(orden, c) for c in ORDEN_COLUMNAS} | {"examenes": orden.examenes},
            {c: getattr(doc, c) for c in DOC_COLUMNAS},
            examenes,
        )


def listar_cu12(mundo, persona, **consulta):
    mundo.env.como(mundo.p[persona])
    return mundo.client.get("/api/v1/documentos", params={"tipo_documento": "RESULTADO_LAB", **consulta})


def test_la_carga_con_orden_no_altera_la_orden_ni_su_documento_orden_lab(mundo):
    antes = instantanea(mundo)
    respuesta = post_manual(mundo, mundo.p["medico1"], campos={"id_orden": str(mundo.datos["orden"].id_orden)})
    assert respuesta.status_code == 201 and respuesta.json()["id_orden"] == mundo.datos["orden"].id_orden
    assert instantanea(mundo) == antes
    orden, documento_orden, _ = antes
    assert orden["estado"] == "FIRMADA" and documento_orden["tipo_documento"] == "ORDEN_LAB"


def test_el_documento_resultado_lab_referencia_al_resultado(mundo):
    creado = post_manual(mundo, mundo.p["medico1"], campos={"id_orden": str(mundo.datos["orden"].id_orden)}).json()
    with mundo.env.SessionLocal() as db:
        documento = db.get(DocumentoClinico, creado["id_documento"])
        assert documento.tipo_documento == "RESULTADO_LAB" and documento.estado == "ACTIVO"
        assert documento.metadatos["id_resultado_laboratorio"] == creado["id_resultado"]
        assert documento.metadatos["id_orden"] == mundo.datos["orden"].id_orden
        assert documento.metadatos["content_type"] == "application/pdf"
        assert documento.id_clinica == 1 and documento.id_paciente == mundo.datos["pac1"].id_paciente
        assert documento.fecha_documento == date(2026, 11, 10)
        # el documento ORDEN_LAB sigue siendo distinto y no referencia al resultado
        orden_doc = db.get(DocumentoClinico, mundo.id_doc_orden)
        assert "id_resultado_laboratorio" not in orden_doc.metadatos


def test_cu12_lista_el_resultado_incorporado_y_deja_de_listarlo_al_anularlo(mundo):
    creado = post_manual(mundo, mundo.p["medico1"]).json()
    respuesta = listar_cu12(mundo, "admin1")
    assert respuesta.status_code == 200
    ids_documento = [d["id_documento"] for d in respuesta.json()["items"]]
    assert ids_documento == [creado["id_documento"]]
    mundo.env.como(mundo.p["medico1"])
    assert mundo.client.post(f"{URL}/{creado['id_resultado']}/anular", json={"motivo": "Error de carga"}).status_code == 200
    assert listar_cu12(mundo, "admin1").json()["items"] == []


def test_un_pendiente_no_aparece_en_los_documentos_clinicos_de_cu12(mundo):
    with mundo.env.SessionLocal() as db:
        crear_pendiente_db(db, 1, mundo.p["admin1"].id_usuario, mundo.datos["fuente"].id_fuente)
    assert listar_cu12(mundo, "admin1").json()["items"] == []
    assert mundo.env.contar(DocumentoClinico, DocumentoClinico.tipo_documento == "RESULTADO_LAB") == 0


def test_la_matriz_de_cu12_para_recepcion_sigue_igual(mundo):
    post_manual(mundo, mundo.p["medico1"])
    assert listar_cu12(mundo, "recepcion1").status_code == 403  # RECEPCION sigue sin leer RESULTADO_LAB en CU12


def test_cu12_sirve_el_archivo_del_documento_indexado_con_el_mismo_contenido(mundo):
    contenido = pdf_bytes(b"integracion")
    creado = post_manual(mundo, mundo.p["medico1"], archivo=("a.pdf", contenido, "application/pdf")).json()
    mundo.env.como(mundo.p["admin1"])
    cu12 = mundo.client.get(f"/api/v1/documentos/{creado['id_documento']}/file")
    assert cu12.status_code == 200 and cu12.content == contenido
    cu11 = mundo.client.get(f"{URL}/{creado['id_resultado']}/archivo")
    assert cu11.content == contenido
