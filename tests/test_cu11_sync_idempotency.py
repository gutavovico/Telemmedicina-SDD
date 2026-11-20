"""CU11 · tarea 6.4: idempotencia por ``(id_clinica, id_fuente, id_externo)`` (criterio 6).

Reenviar un lote no duplica nada; el mismo ``id_externo`` con otro contenido es ``CONTENIDO_DISTINTO``; otra
fuente es independiente; y la violación de la restricción única por una carrera se resuelve en la base de datos:
la carrera se simula insertando la fila entre la verificación y el INSERT (SQLite en memoria no da concurrencia
real; ver ``test_cu11_sync_postgres.py`` para la concurrencia real en PostgreSQL).
"""
import pytest
from sqlalchemy import insert

from app.modules.medical_records.clinical_documents.models import DocumentoClinico
from app.modules.medical_records.laboratory_results.models import ResultadoLaboratorio
from app.modules.medical_records.laboratory_sync import service as sync_service
from app.modules.medical_records.laboratory_sync.models import SincronizacionLaboratorio
from cu11_support import (
    Cu11Http,
    cantidad_de_archivos,
    construir_mundo,
    pdf_bytes,
    resultado_valido,
    usar_storage_temporal,
)
from cu11_sync_support import (
    auditorias,
    crear_fuente_db,
    item,
    por_externo,
    post_lote,
    resultado_de,
    resultados,
    total_documentos_lab,
    total_items,
    total_resultados,
    total_sincronizaciones,
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


def enviar(mundo, items, **kwargs):
    respuesta = post_lote(mundo, mundo.p["admin1"], items, **kwargs)
    assert respuesta.status_code == 201, respuesta.text
    return respuesta.json()


LOTE = [item("EXT-1"), item("EXT-2"), item("EXT-3")]


# --------------------------------------------------------------------------- #
# Reenvío y duplicados
# --------------------------------------------------------------------------- #
def test_reenviar_el_mismo_lote_deja_todo_duplicado_sin_filas_ni_archivos_nuevos(mundo):
    primero = enviar(mundo, LOTE)
    assert primero["incorporados"] == 3
    ids = {r.id_externo: r.id_resultado for r in resultados(mundo)}
    archivos, documentos, auditoria = cantidad_de_archivos(mundo.almacen), total_documentos_lab(mundo), len(auditorias(mundo))

    segundo = enviar(mundo, LOTE)
    por = por_externo(segundo)
    assert [por[e]["resultado"] for e in ("EXT-1", "EXT-2", "EXT-3")] == ["DUPLICADO"] * 3
    assert {e: por[e]["id_resultado"] for e in por} == ids          # apuntan al resultado ya integrado
    assert segundo["duplicados"] == 3 and segundo["incorporados"] == 0 and segundo["estado"] == "COMPLETADA"
    assert segundo["id_sincronizacion"] != primero["id_sincronizacion"]   # es otra sincronización (otro registro del lote)
    assert total_resultados(mundo) == 3
    assert total_documentos_lab(mundo) == documentos == 3
    assert cantidad_de_archivos(mundo.almacen) == archivos == 3         # no se almacenan archivos nuevos
    # ningún resultado fue modificado por el reenvío
    assert all(r.id_sincronizacion == primero["id_sincronizacion"] for r in resultados(mundo))
    # y no se auditó ninguna creación nueva (solo la traza de la nueva sincronización)
    nuevas = auditorias(mundo)[auditoria:]
    assert [a.accion for a in nuevas] == ["EJECUTAR_SINCRONIZACION_LABORATORIO"]


def test_duplicado_de_un_pendiente_no_crea_un_segundo_pendiente(mundo):
    lote = [item("EXT-PEND", ci="9999999")]
    assert enviar(mundo, lote)["pendientes"] == 1
    segundo = enviar(mundo, lote)
    assert por_externo(segundo)["EXT-PEND"]["resultado"] == "DUPLICADO"
    assert total_resultados(mundo) == 1 and cantidad_de_archivos(mundo.almacen) == 1


def test_duplicado_de_un_resultado_anulado_no_lo_reactiva(mundo):
    enviar(mundo, [item("EXT-1")])
    id_resultado = resultado_de(mundo, "EXT-1").id_resultado
    mundo.env.como(mundo.p["medico1"])
    anulado = mundo.client.post(f"/api/v1/resultados-laboratorio/{id_resultado}/anular", json={"motivo": "Cargado por error"})
    assert anulado.status_code == 200
    segundo = enviar(mundo, [item("EXT-1")])
    assert por_externo(segundo)["EXT-1"]["resultado"] == "DUPLICADO"
    assert resultado_de(mundo, "EXT-1").estado == "ANULADO"
    assert total_resultados(mundo) == 1 and total_documentos_lab(mundo) == 1


def test_mismo_id_externo_con_contenido_distinto_es_error_y_no_modifica_el_original(mundo):
    enviar(mundo, [item("EXT-1")], archivos={"EXT-1.pdf": pdf_bytes(b"contenido original")})
    original = resultado_de(mundo, "EXT-1")
    segundo = enviar(mundo, [item("EXT-1")], archivos={"EXT-1.pdf": pdf_bytes(b"contenido DISTINTO")})
    fila = por_externo(segundo)["EXT-1"]
    assert fila["resultado"] == "ERROR" and fila["codigo_error"] == "CONTENIDO_DISTINTO" and fila["id_resultado"] is None
    assert segundo["estado"] == "FALLIDA" and segundo["con_error"] == 1
    actual = resultado_de(mundo, "EXT-1")
    assert (actual.id_resultado, actual.hash_archivo, actual.archivo_url, actual.estado) == (
        original.id_resultado, original.hash_archivo, original.archivo_url, "INCORPORADO",
    )
    assert total_resultados(mundo) == 1 and cantidad_de_archivos(mundo.almacen) == 1


def test_contenido_distinto_tambien_aplica_a_un_pendiente(mundo):
    enviar(mundo, [item("EXT-1", ci="9999999")], archivos={"EXT-1.pdf": pdf_bytes(b"uno")})
    segundo = enviar(mundo, [item("EXT-1", ci="9999999")], archivos={"EXT-1.pdf": pdf_bytes(b"dos")})
    assert por_externo(segundo)["EXT-1"]["codigo_error"] == "CONTENIDO_DISTINTO"
    assert total_resultados(mundo) == 1


def test_el_mismo_id_externo_en_otra_fuente_es_un_resultado_independiente(mundo):
    id_otra = crear_fuente_db(mundo, 1, "LAB-OTRA")
    enviar(mundo, [item("EXT-1")], fuente="LAB-CENTRAL")
    segundo = enviar(mundo, [item("EXT-1")], fuente="LAB-OTRA", archivos={"EXT-1.pdf": pdf_bytes(b"otra fuente")})
    assert por_externo(segundo)["EXT-1"]["resultado"] == "INCORPORADO"
    assert total_resultados(mundo) == 2
    assert {r.id_fuente for r in resultados(mundo)} == {mundo.datos["fuente"].id_fuente, id_otra}


def test_el_mismo_id_externo_y_fuente_en_otra_clinica_es_independiente(mundo):
    """La clave incluye la clínica: la clínica 2 usa el mismo código de fuente y el mismo id_externo."""
    crear_fuente_db(mundo, 2, "LAB-CENTRAL")
    enviar(mundo, [item("EXT-1")])
    respuesta = post_lote(
        mundo, mundo.p["admin2"], [item("EXT-1", ci="2222222", codigo="GLUCOSA")],
        archivos={"EXT-1.pdf": pdf_bytes(b"clinica 2")},
    )
    assert respuesta.status_code == 201, respuesta.text
    assert por_externo(respuesta.json())["EXT-1"]["resultado"] == "INCORPORADO"
    assert total_resultados(mundo) == 2
    assert resultado_de(mundo, "EXT-1", id_clinica=2).id_paciente == mundo.datos["pac2"].id_paciente


# --------------------------------------------------------------------------- #
# Caída a mitad del lote
# --------------------------------------------------------------------------- #
def test_reenvio_del_lote_completo_tras_una_caida_a_mitad_solo_crea_lo_que_faltaba(mundo):
    enviar(mundo, LOTE[:2])                      # el cliente cayó antes de enviar el tercero
    assert total_resultados(mundo) == 2
    completo = enviar(mundo, LOTE)
    por = por_externo(completo)
    assert [por[e]["resultado"] for e in ("EXT-1", "EXT-2", "EXT-3")] == ["DUPLICADO", "DUPLICADO", "INCORPORADO"]
    assert completo["duplicados"] == 2 and completo["incorporados"] == 1
    assert total_resultados(mundo) == 3 and cantidad_de_archivos(mundo.almacen) == 3


class ProcesoMuerto(BaseException):
    """No es una ``Exception``: ningún ``except Exception`` por ítem la atrapa (simula la muerte del proceso)."""


def test_una_interrupcion_del_servidor_conserva_lo_integrado_y_el_reenvio_completa(mundo, monkeypatch):
    """Si el proceso muere a mitad del lote, lo ya confirmado persiste y la sincronización queda EN_PROCESO."""
    original = sync_service.procesar_item

    def cae_en_el_tercero(db, ctx, **kwargs):
        if kwargs["item"].id_externo == "EXT-3":
            raise ProcesoMuerto()
        return original(db, ctx, **kwargs)

    monkeypatch.setattr(sync_service, "procesar_item", cae_en_el_tercero)
    try:
        post_lote(mundo, mundo.p["admin1"], LOTE)
    except ProcesoMuerto:
        pass
    monkeypatch.setattr(sync_service, "procesar_item", original)

    assert total_resultados(mundo) == 2                       # EXT-1 y EXT-2 ya estaban confirmados
    sync = mundo.env.uno(SincronizacionLaboratorio)
    assert sync.estado == "EN_PROCESO" and sync.finalizado_en is None and sync.total_items == 3

    completo = enviar(mundo, LOTE)
    por = por_externo(completo)
    assert [por[e]["resultado"] for e in ("EXT-1", "EXT-2", "EXT-3")] == ["DUPLICADO", "DUPLICADO", "INCORPORADO"]
    assert total_resultados(mundo) == 3


# --------------------------------------------------------------------------- #
# Carrera: la restricción única de la base de datos es la garantía real
# --------------------------------------------------------------------------- #
def competidor(mundo, externo, hash_archivo):
    return resultado_valido(
        id_clinica=1, id_paciente=mundo.datos["pac1"].id_paciente, id_examen=mundo.datos["examen"].id_examen,
        registrado_por=mundo.p["admin1"].id_usuario, origen="SINCRONIZADO",
        id_fuente=mundo.datos["fuente"].id_fuente, id_externo=externo, hash_archivo=hash_archivo,
        archivo_url=f"documentos/zz/zz/competidor-{externo}.pdf",
    )


def simular_carrera(monkeypatch, mundo, externo, hash_archivo):
    """Tras la verificación (que no ve nada) otra transacción inserta la misma clave: el INSERT debe fallar."""
    original = sync_service._buscar_existente
    estado = {"competidor_insertado": False}

    def con_carrera(db, id_clinica, id_fuente, id_externo):
        encontrado = original(db, id_clinica, id_fuente, id_externo)
        if id_externo == externo and not estado["competidor_insertado"]:
            estado["competidor_insertado"] = True
            assert encontrado is None
            db.execute(insert(ResultadoLaboratorio).values(**competidor(mundo, externo, hash_archivo)))
        return encontrado

    monkeypatch.setattr(sync_service, "_buscar_existente", con_carrera)
    return estado


def test_carrera_con_el_mismo_contenido_deja_un_solo_resultado_y_el_item_duplicado(mundo, monkeypatch):
    contenido = pdf_bytes(b"carrera")
    import hashlib
    estado = simular_carrera(monkeypatch, mundo, "EXT-1", hashlib.sha256(contenido).hexdigest())
    cuerpo = enviar(mundo, [item("EXT-1")], archivos={"EXT-1.pdf": contenido})
    assert estado["competidor_insertado"] is True
    fila = por_externo(cuerpo)["EXT-1"]
    assert fila["resultado"] == "DUPLICADO" and fila["codigo_error"] is None
    assert total_resultados(mundo) == 1                       # exactamente un resultado creado
    assert fila["id_resultado"] == resultado_de(mundo, "EXT-1").id_resultado
    assert cantidad_de_archivos(mundo.almacen) == 0           # el archivo del perdedor se borró
    assert total_documentos_lab(mundo) == 0                   # ni documento ni auditoría del perdedor
    assert [a.accion for a in auditorias(mundo)] == ["EJECUTAR_SINCRONIZACION_LABORATORIO"]
    assert cuerpo["duplicados"] == 1 and cuerpo["estado"] == "COMPLETADA"


def test_carrera_con_contenido_distinto_es_contenido_distinto(mundo, monkeypatch):
    simular_carrera(monkeypatch, mundo, "EXT-1", "f" * 64)
    cuerpo = enviar(mundo, [item("EXT-1")])
    fila = por_externo(cuerpo)["EXT-1"]
    assert fila["resultado"] == "ERROR" and fila["codigo_error"] == "CONTENIDO_DISTINTO"
    assert total_resultados(mundo) == 1 and cantidad_de_archivos(mundo.almacen) == 0


def test_la_carrera_de_un_item_no_afecta_a_los_demas_items_del_lote(mundo, monkeypatch):
    """El SAVEPOINT por ítem deshace solo al perdedor; lo integrado antes y después del lote se conserva."""
    import hashlib
    contenido = pdf_bytes(b"carrera en el medio")
    simular_carrera(monkeypatch, mundo, "EXT-2", hashlib.sha256(contenido).hexdigest())
    cuerpo = enviar(mundo, LOTE, archivos={"EXT-2.pdf": contenido})
    por = por_externo(cuerpo)
    assert [por[e]["resultado"] for e in ("EXT-1", "EXT-2", "EXT-3")] == ["INCORPORADO", "DUPLICADO", "INCORPORADO"]
    assert total_resultados(mundo) == 3 and total_items(mundo) == 3 and total_sincronizaciones(mundo) == 1
    assert total_documentos_lab(mundo) == 2 and cantidad_de_archivos(mundo.almacen) == 2
    assert cuerpo["incorporados"] == 2 and cuerpo["duplicados"] == 1 and cuerpo["estado"] == "COMPLETADA"


def test_un_error_de_integridad_ajeno_a_la_clave_se_aisla_como_error_interno(mundo, monkeypatch):
    """Un IntegrityError que NO es la clave de idempotencia (nadie la ocupa) no se disfraza de duplicado."""
    original = sync_service._insertar_resultado

    def viola_un_check(db, ctx, **kwargs):
        resultado = original(db, ctx, **kwargs)
        if kwargs["item"].id_externo == "EXT-2":
            resultado.tamano_bytes = 0  # viola ck_resultado_tamano al volcar
            db.flush()
        return resultado

    monkeypatch.setattr(sync_service, "_insertar_resultado", viola_un_check)
    cuerpo = enviar(mundo, LOTE)
    por = por_externo(cuerpo)
    assert por["EXT-2"]["resultado"] == "ERROR" and por["EXT-2"]["codigo_error"] == "ERROR_INTERNO"
    assert "ck_resultado" not in str(cuerpo)                  # no se filtran detalles internos de la base
    assert por["EXT-1"]["resultado"] == "INCORPORADO" and por["EXT-3"]["resultado"] == "INCORPORADO"
    assert resultado_de(mundo, "EXT-2") is None and total_resultados(mundo) == 2
    assert cantidad_de_archivos(mundo.almacen) == 2


def test_documentos_del_perdedor_de_la_carrera_no_quedan_en_el_expediente(mundo, monkeypatch):
    import hashlib
    contenido = pdf_bytes(b"x")
    simular_carrera(monkeypatch, mundo, "EXT-1", hashlib.sha256(contenido).hexdigest())
    enviar(mundo, [item("EXT-1")], archivos={"EXT-1.pdf": contenido})
    assert mundo.env.contar(DocumentoClinico) == 0
