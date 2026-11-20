"""CU11 · tarea 6.5: registro de la sincronización, contadores, estado y errores aislados (criterios 3, 8 y 9)."""
import json

import pytest

from app.modules.medical_records.clinical_documents.models import DocumentoClinico
from app.modules.medical_records.clinical_documents.storage import storage as storage_singleton
from app.modules.medical_records.laboratory_sync import service as sync_service
from app.modules.medical_records.laboratory_sync.models import SincronizacionLaboratorio, SincronizacionLaboratorioItem
from cu11_support import Cu11Http, cantidad_de_archivos, construir_mundo, pdf_bytes, usar_storage_temporal
from cu11_sync_support import (
    URL_SYNC,
    auditorias,
    item,
    por_externo,
    post_lote,
    resultado_de,
    total_documentos_lab,
    total_items,
    total_resultados,
)

BITACORA = "/api/v1/audit-log"
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


def test_cabecera_completa_de_una_sincronizacion_sin_errores(mundo):
    cuerpo = enviar(mundo, [item("EXT-1"), item("EXT-2")])
    assert cuerpo["estado"] == "COMPLETADA" and cuerpo["tipo"] == "LOTE"
    assert (cuerpo["total_items"], cuerpo["incorporados"], cuerpo["pendientes"], cuerpo["duplicados"], cuerpo["con_error"]) == (2, 2, 0, 0, 0)
    assert cuerpo["reintentos"] == 0
    assert cuerpo["id_fuente"] == mundo.datos["fuente"].id_fuente and cuerpo["fuente_codigo"] == "LAB-CENTRAL"
    assert cuerpo["id_usuario"] == mundo.p["admin1"].id_usuario and cuerpo["proceso"] is None
    assert cuerpo["iniciado_en"] and cuerpo["finalizado_en"]
    assert [i["id_externo"] for i in cuerpo["items"]] == ["EXT-1", "EXT-2"]
    assert all(i["intento"] == 1 and i["codigo_error"] is None for i in cuerpo["items"])
    assert "id_clinica" not in cuerpo


def test_informe_del_lote_con_un_incorporado_un_pendiente_un_duplicado_y_un_error(mundo):
    enviar(mundo, [item("EXT-DUP")])                                  # lote previo: EXT-DUP ya integrado
    items = [item("EXT-OK"), item("EXT-PEND", ci="9999999"), item("EXT-DUP"), item("EXT-ERR", archivo="virus.exe")]
    cuerpo = enviar(mundo, items, archivos={"virus.exe": EXE})
    por = por_externo(cuerpo)
    assert por["EXT-OK"]["resultado"] == "INCORPORADO" and por["EXT-OK"]["id_resultado"] is not None
    assert por["EXT-PEND"]["resultado"] == "PENDIENTE_REVISION" and por["EXT-PEND"]["detalle"] == "PACIENTE_NO_ENCONTRADO"
    assert por["EXT-DUP"]["resultado"] == "DUPLICADO" and por["EXT-DUP"]["id_resultado"] == resultado_de(mundo, "EXT-DUP").id_resultado
    assert por["EXT-ERR"]["resultado"] == "ERROR" and por["EXT-ERR"]["codigo_error"] == "ARCHIVO_TIPO_NO_PERMITIDO"
    assert (cuerpo["incorporados"], cuerpo["pendientes"], cuerpo["duplicados"], cuerpo["con_error"]) == (1, 1, 1, 1)
    assert cuerpo["total_items"] == 4 and cuerpo["estado"] == "COMPLETADA_CON_ERRORES"
    # el detalle consultado después es idéntico al de la respuesta
    mundo.env.como(mundo.p["admin1"])
    detalle = mundo.client.get(f"{URL_SYNC}/{cuerpo['id_sincronizacion']}").json()
    sin_marcas = lambda d: {k: v for k, v in d.items() if k not in ("iniciado_en", "finalizado_en")}  # noqa: E731
    assert sin_marcas(detalle) == sin_marcas(cuerpo)


def test_todos_los_items_en_error_dejan_la_sincronizacion_fallida(mundo):
    items = [item("EXT-1", archivo="a.exe"), item("EXT-2", archivo="b.exe")]
    cuerpo = enviar(mundo, items, archivos={"a.exe": EXE, "b.exe": EXE})
    assert cuerpo["estado"] == "FALLIDA" and cuerpo["con_error"] == 2 and cuerpo["incorporados"] == 0
    assert total_resultados(mundo) == 0 and cantidad_de_archivos(mundo.almacen) == 0 and total_items(mundo) == 2
    # una FALLIDA igual deja constancia: cabecera y auditoría
    assert [a.accion for a in auditorias(mundo)] == ["EJECUTAR_SINCRONIZACION_LABORATORIO"]


@pytest.mark.parametrize(
    "total,con_error,esperado",
    [(3, 0, "COMPLETADA"), (3, 1, "COMPLETADA_CON_ERRORES"), (3, 2, "COMPLETADA_CON_ERRORES"), (3, 3, "FALLIDA"), (1, 1, "FALLIDA")],
)
def test_regla_del_estado_de_cierre(total, con_error, esperado):
    assert sync_service.estado_de_lote(total, con_error) == esperado


def test_fallo_de_almacenamiento_de_un_item_no_deja_resultado_ni_archivo_y_no_frena_el_lote(mundo, monkeypatch):
    original = storage_singleton.store
    llamadas = []

    def falla_la_segunda(nombre, contenido, content_type="application/pdf"):
        llamadas.append(nombre)
        if len(llamadas) == 2:
            raise OSError("disco lleno")
        return original(nombre, contenido, content_type)

    monkeypatch.setattr(storage_singleton, "store", falla_la_segunda)
    cuerpo = enviar(mundo, [item("EXT-1"), item("EXT-2"), item("EXT-3")])
    por = por_externo(cuerpo)
    assert por["EXT-2"]["resultado"] == "ERROR" and por["EXT-2"]["codigo_error"] == "ALMACENAMIENTO_FALLIDO"
    assert por["EXT-1"]["resultado"] == "INCORPORADO" and por["EXT-3"]["resultado"] == "INCORPORADO"
    assert resultado_de(mundo, "EXT-2") is None and total_resultados(mundo) == 2
    assert cantidad_de_archivos(mundo.almacen) == 2 and total_documentos_lab(mundo) == 2
    assert "disco lleno" not in str(cuerpo)                           # sin detalles internos
    assert cuerpo["estado"] == "COMPLETADA_CON_ERRORES"


def test_fallo_de_base_de_datos_tras_guardar_el_archivo_lo_borra_y_deshace_resultado_documento_y_auditoria(mundo, monkeypatch):
    original = sync_service.auditar_resultado

    def falla_en_el_segundo(db, ctx, resultado, accion, *args, **kwargs):
        if resultado.id_externo == "EXT-2":
            raise RuntimeError("la auditoría falló")
        return original(db, ctx, resultado, accion, *args, **kwargs)

    monkeypatch.setattr(sync_service, "auditar_resultado", falla_en_el_segundo)
    cuerpo = enviar(mundo, [item("EXT-1"), item("EXT-2"), item("EXT-3")])
    por = por_externo(cuerpo)
    assert por["EXT-2"]["resultado"] == "ERROR" and por["EXT-2"]["codigo_error"] == "ERROR_INTERNO"
    assert "auditoría" not in str(por["EXT-2"])
    assert resultado_de(mundo, "EXT-2") is None                        # el SAVEPOINT deshizo resultado y documento
    assert total_resultados(mundo) == 2 and total_documentos_lab(mundo) == 2
    assert cantidad_de_archivos(mundo.almacen) == 2                     # sin archivo huérfano
    # cada resultado creado tiene su traza (atómica con el dato) y el fallido ninguna
    creaciones = [a for a in auditorias(mundo, "CREAR_RESULTADO_LABORATORIO")]
    assert len(creaciones) == 2


def test_el_item_fallido_por_error_interno_se_puede_reintentar(mundo, monkeypatch):
    original = sync_service._insertar_resultado
    estado = {"falla": True}

    def falla_una_vez(db, ctx, **kwargs):
        if kwargs["item"].id_externo == "EXT-2" and estado["falla"]:
            estado["falla"] = False
            raise RuntimeError("fallo transitorio")
        return original(db, ctx, **kwargs)

    monkeypatch.setattr(sync_service, "_insertar_resultado", falla_una_vez)
    cuerpo = enviar(mundo, [item("EXT-1"), item("EXT-2")])
    assert por_externo(cuerpo)["EXT-2"]["resultado"] == "ERROR"
    mundo.env.como(mundo.p["admin1"])
    reintento = mundo.client.post(
        f"{URL_SYNC}/{cuerpo['id_sincronizacion']}/reintentos",
        data={"manifiesto": '{"fuente": "LAB-CENTRAL", "items": [' + json.dumps(item("EXT-2")) + "]}"},
        files=[("archivos", ("EXT-2.pdf", pdf_bytes(b"EXT-2"), "application/pdf"))],
    )
    assert reintento.status_code == 200, reintento.text
    assert por_externo(reintento.json())["EXT-2"]["resultado"] == "INCORPORADO"
    assert total_resultados(mundo) == 2 and cantidad_de_archivos(mundo.almacen) == 2


def test_la_auditoria_de_cierre_va_en_la_misma_transaccion_que_los_contadores(mundo, monkeypatch):
    """Si falla la auditoría del cierre se revierte el cierre: la sincronización queda EN_PROCESO (sin traza ni contadores)."""

    def falla(*args, **kwargs):
        raise RuntimeError("auditoría caída")

    monkeypatch.setattr(sync_service, "_auditar", falla)
    respuesta = post_lote(mundo, mundo.p["admin1"], [item("EXT-1")])
    assert respuesta.status_code == 500
    sync = mundo.env.uno(SincronizacionLaboratorio)
    assert sync.estado == "EN_PROCESO" and sync.incorporados == 0 and sync.finalizado_en is None
    assert auditorias(mundo, "EJECUTAR_SINCRONIZACION_LABORATORIO") == []
    assert total_resultados(mundo) == 1                                 # el ítem ya estaba confirmado (con su propia traza)


# --------------------------------------------------------------------------- #
# Trazabilidad (criterio 9)
# --------------------------------------------------------------------------- #
def test_trazabilidad_de_un_resultado_sincronizado_y_de_la_sincronizacion(mundo):
    cuerpo = enviar(mundo, [item("EXT-1"), item("EXT-2", ci="9999999")])
    admin = mundo.p["admin1"]
    resultado = resultado_de(mundo, "EXT-1")
    assert (resultado.origen, resultado.id_fuente, resultado.id_externo, resultado.id_sincronizacion) == (
        "SINCRONIZADO", mundo.datos["fuente"].id_fuente, "EXT-1", cuerpo["id_sincronizacion"],
    )
    assert resultado.registrado_por == admin.id_usuario and resultado.registrado_en is not None

    creaciones = auditorias(mundo, "CREAR_RESULTADO_LABORATORIO", "resultados_laboratorio")
    pendientes = auditorias(mundo, "REGISTRAR_RESULTADO_PENDIENTE", "resultados_laboratorio")
    ejecuciones = auditorias(mundo, "EJECUTAR_SINCRONIZACION_LABORATORIO", "sincronizaciones_laboratorio")
    assert len(creaciones) == 1 and len(pendientes) == 1 and len(ejecuciones) == 1
    assert creaciones[0].registro_id == resultado.id_resultado
    assert creaciones[0].datos_nuevos["id_sincronizacion"] == cuerpo["id_sincronizacion"]
    assert pendientes[0].datos_nuevos["motivo_pendiente"] == "PACIENTE_NO_ENCONTRADO"
    assert "9999999" not in str(pendientes[0].datos_nuevos)               # la CI cruda no se copia a la auditoría
    traza = ejecuciones[0]
    assert traza.id_clinica == 1 and traza.id_usuario == admin.id_usuario and traza.registro_id == cuerpo["id_sincronizacion"]
    assert traza.datos_nuevos["incorporados"] == 1 and traza.datos_nuevos["pendientes"] == 1


def test_la_bitacora_cu21_muestra_las_trazas_de_sincronizacion_a_su_clinica_y_no_a_otra(mundo):
    enviar(mundo, [item("EXT-1")])
    mundo.env.como(mundo.p["admin1"])
    propias = mundo.client.get(BITACORA, params={"tabla_afectada": "sincronizaciones_laboratorio"})
    assert propias.status_code == 200, propias.text
    assert propias.json()["total"] == 1
    assert propias.json()["data"][0]["accion"] == "EJECUTAR_SINCRONIZACION_LABORATORIO"
    mundo.env.como(mundo.p["admin2"])
    ajenas = mundo.client.get(BITACORA, params={"tabla_afectada": "sincronizaciones_laboratorio"})
    assert ajenas.status_code == 200 and ajenas.json()["total"] == 0


def test_los_items_guardan_clinica_y_no_se_exponen_las_claves_de_almacenamiento(mundo):
    cuerpo = enviar(mundo, [item("EXT-1")])
    assert "archivo_url" not in str(cuerpo) and "documentos/" not in str(cuerpo)
    assert mundo.env.contar(SincronizacionLaboratorioItem, SincronizacionLaboratorioItem.id_clinica == 1) == 1
    assert mundo.env.contar(DocumentoClinico, DocumentoClinico.id_clinica == 1) == 1
