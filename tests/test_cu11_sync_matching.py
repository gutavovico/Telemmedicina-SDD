"""CU11 · tarea 6.3: procesamiento por ítem y correspondencia (criterios 3 y 5).

Un resultado solo queda ``INCORPORADO`` con paciente (CI + complemento, MISMA clínica), estudio activo del
catálogo de la clínica y, si trae orden, una orden firmada del mismo paciente que incluya el estudio. Todo lo
demás queda ``PENDIENTE_REVISION``: sin paciente, sin documento clínico, con motivo y con los datos crudos.
"""
import pytest
from sqlalchemy import select

from app.modules.medical_records.clinical_documents.models import DocumentoClinico
from app.modules.medical_records.laboratory_results.models import ResultadoLaboratorio
from app.modules.medical_records.models import Paciente
from cu11_support import (
    Cu11Http,
    cantidad_de_archivos,
    construir_mundo,
    jpg_bytes,
    pdf_bytes,
    png_bytes,
    usar_storage_temporal,
)
from cu11_sync_support import (
    crear_examen_db,
    crear_orden_db,
    crear_paciente,
    item,
    por_externo,
    post_lote,
    resultado_de,
    total_documentos_lab,
    total_resultados,
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


def enviar_uno(mundo, it, **kwargs):
    respuesta = post_lote(mundo, mundo.p["admin1"], [it], **kwargs)
    assert respuesta.status_code == 201, respuesta.text
    return respuesta.json(), respuesta.json()["items"][0]


def verificar_pendiente(mundo, cuerpo, externo, motivo):
    fila = por_externo(cuerpo)[externo]
    assert fila["resultado"] == "PENDIENTE_REVISION" and fila["detalle"] == motivo
    assert fila["id_resultado"] is not None and fila["codigo_error"] is None
    resultado = resultado_de(mundo, externo)
    assert resultado.estado == "PENDIENTE_REVISION" and resultado.motivo_pendiente == motivo
    assert resultado.id_paciente is None            # jamás asociado a un expediente
    assert resultado.id_documento is None           # sin documento clínico
    assert resultado.origen == "SINCRONIZADO"
    assert resultado.datos_correspondencia is not None
    return resultado


# --------------------------------------------------------------------------- #
# Correspondencia válida
# --------------------------------------------------------------------------- #
def test_correspondencia_valida_incorpora_e_indexa_el_documento(mundo):
    cuerpo, fila = enviar_uno(mundo, item("EXT-1", observaciones="Muestra en ayunas"))
    assert fila["resultado"] == "INCORPORADO" and fila["detalle"] is None and fila["codigo_error"] is None
    assert cuerpo["estado"] == "COMPLETADA" and cuerpo["incorporados"] == 1

    resultado = resultado_de(mundo, "EXT-1")
    assert resultado.estado == "INCORPORADO" and resultado.origen == "SINCRONIZADO"
    assert resultado.id_clinica == 1 and resultado.id_paciente == mundo.datos["pac1"].id_paciente
    assert resultado.id_examen == mundo.datos["examen"].id_examen
    assert resultado.codigo_examen == "HEMOGRAMA" and resultado.nombre_examen == "Hemograma completo"
    assert resultado.id_fuente == mundo.datos["fuente"].id_fuente and resultado.id_externo == "EXT-1"
    assert resultado.id_sincronizacion == cuerpo["id_sincronizacion"]
    assert resultado.registrado_por == mundo.p["admin1"].id_usuario and resultado.registrado_en is not None
    assert resultado.motivo_pendiente is None and resultado.datos_correspondencia is None
    assert resultado.observaciones == "Muestra en ayunas"
    assert resultado.content_type == "application/pdf" and resultado.hash_archivo and resultado.tamano_bytes > 0

    documento = mundo.env.uno(DocumentoClinico, DocumentoClinico.id_documento == resultado.id_documento)
    assert documento.tipo_documento == "RESULTADO_LAB" and documento.estado == "ACTIVO"
    assert documento.id_paciente == resultado.id_paciente and documento.id_clinica == 1
    assert documento.archivo_url == resultado.archivo_url          # el archivo se guarda una sola vez
    assert documento.metadatos["id_resultado_laboratorio"] == resultado.id_resultado
    assert cantidad_de_archivos(mundo.almacen) == 1


def test_el_codigo_del_estudio_se_normaliza(mundo):
    _, fila = enviar_uno(mundo, item("EXT-1", codigo="  hemograma "))
    assert fila["resultado"] == "INCORPORADO"
    assert resultado_de(mundo, "EXT-1").codigo_examen == "HEMOGRAMA"


@pytest.mark.parametrize(
    "archivo,datos,tipo",
    [("a.pdf", pdf_bytes(b"x"), "application/pdf"), ("a.jpg", jpg_bytes(b"x"), "image/jpeg"), ("a.png", png_bytes(b"x"), "image/png")],
)
def test_cada_formato_se_guarda_con_el_content_type_de_su_firma(mundo, archivo, datos, tipo):
    _, fila = enviar_uno(mundo, item("EXT-1", archivo=archivo), archivos={archivo: (datos, tipo)})
    assert fila["resultado"] == "INCORPORADO"
    assert resultado_de(mundo, "EXT-1").content_type == tipo


# --------------------------------------------------------------------------- #
# Paciente
# --------------------------------------------------------------------------- #
def test_paciente_inexistente_queda_pendiente_con_la_ci_recibida_en_los_datos_crudos(mundo):
    cuerpo, _ = enviar_uno(mundo, item("EXT-1", ci="9999999", complemento="B", id_orden=None))
    resultado = verificar_pendiente(mundo, cuerpo, "EXT-1", "PACIENTE_NO_ENCONTRADO")
    assert resultado.datos_correspondencia == {
        "ci": "9999999", "complemento": "B", "codigo_examen": "HEMOGRAMA", "id_orden": None,
    }
    assert cuerpo["estado"] == "COMPLETADA" and cuerpo["pendientes"] == 1 and cuerpo["incorporados"] == 0
    assert total_documentos_lab(mundo) == 0
    assert cantidad_de_archivos(mundo.almacen) == 1        # el archivo del pendiente sí se conserva para revisarlo


def test_la_ci_que_existe_solo_en_otra_clinica_queda_pendiente_sin_asociarse(mundo):
    cuerpo, _ = enviar_uno(mundo, item("EXT-1", ci="2222222"))           # CI de Luis Norte (clínica 2)
    resultado = verificar_pendiente(mundo, cuerpo, "EXT-1", "PACIENTE_NO_ENCONTRADO")
    assert resultado.id_clinica == 1
    assert total_documentos_lab(mundo) == 0
    assert "Luis" not in str(cuerpo) and "Norte" not in str(cuerpo)       # sin filtrar datos de la otra clínica


def test_un_paciente_con_id_clinica_nulo_nunca_coincide(mundo):
    """Los pacientes 1 y 2 de Neon no tienen clínica: se comportan como inexistentes."""
    cuerpo, _ = enviar_uno(mundo, item("EXT-1", ci="3333333", complemento=""))
    verificar_pendiente(mundo, cuerpo, "EXT-1", "PACIENTE_NO_ENCONTRADO")
    # el mismo paciente sin clínica no recibe ningún resultado de ninguna clínica
    assert mundo.env.contar(ResultadoLaboratorio, ResultadoLaboratorio.id_paciente == mundo.datos["pac_sin_clinica"].id_paciente) == 0


def test_complemento_nulo_en_la_base_coincide_con_cadena_vacia_recibida(mundo):
    id_paciente = crear_paciente(mundo, 1, "4444444", complemento=None)
    with mundo.env.SessionLocal() as db:
        assert db.execute(select(Paciente.complemento).where(Paciente.id_paciente == id_paciente)).scalar_one() is None
    for externo, complemento in (("EXT-VACIO", ""), ("EXT-NULO", None)):
        _, fila = enviar_uno(mundo, item(externo, ci="4444444", complemento=complemento))
        assert fila["resultado"] == "INCORPORADO", externo


def test_complemento_distinto_no_coincide(mundo):
    crear_paciente(mundo, 1, "4444444", complemento="1A")
    cuerpo, _ = enviar_uno(mundo, item("EXT-1", ci="4444444", complemento=""))
    verificar_pendiente(mundo, cuerpo, "EXT-1", "PACIENTE_NO_ENCONTRADO")
    _, fila = enviar_uno(mundo, item("EXT-2", ci="4444444", complemento="1A"))
    assert fila["resultado"] == "INCORPORADO"


def test_paciente_ambiguo_queda_pendiente_sin_elegir_ninguno(mundo):
    """Con ``complemento`` NULL la restricción única no impide dos filas con la misma CI en la clínica."""
    crear_paciente(mundo, 1, "7777777", complemento=None, nombres="Uno")
    crear_paciente(mundo, 1, "7777777", complemento=None, nombres="Dos")
    assert mundo.env.contar(Paciente, Paciente.ci == "7777777", Paciente.complemento.is_(None)) == 2
    cuerpo, _ = enviar_uno(mundo, item("EXT-1", ci="7777777"))
    verificar_pendiente(mundo, cuerpo, "EXT-1", "PACIENTE_AMBIGUO")
    assert "Uno" not in str(cuerpo) and "Dos" not in str(cuerpo)


def test_nunca_se_corresponde_por_nombre_ni_por_aproximacion(mundo):
    crear_paciente(mundo, 1, "5550000", complemento="")
    cuerpo, _ = enviar_uno(mundo, item("EXT-1", ci="555000"))             # CI casi igual
    verificar_pendiente(mundo, cuerpo, "EXT-1", "PACIENTE_NO_ENCONTRADO")
    cuerpo2, _ = enviar_uno(mundo, item("EXT-2", ci="55500000"))
    verificar_pendiente(mundo, cuerpo2, "EXT-2", "PACIENTE_NO_ENCONTRADO")


# --------------------------------------------------------------------------- #
# Estudio
# --------------------------------------------------------------------------- #
def test_estudio_inexistente_queda_pendiente_aunque_el_paciente_exista(mundo):
    cuerpo, _ = enviar_uno(mundo, item("EXT-1", codigo="NO-EXISTE"))
    resultado = verificar_pendiente(mundo, cuerpo, "EXT-1", "EXAMEN_NO_VALIDO")
    assert resultado.id_examen is None and resultado.codigo_examen == "NO-EXISTE"
    assert resultado.datos_correspondencia["ci"] == "1111111"


def test_estudio_inactivo_o_de_otra_clinica_queda_pendiente(mundo):
    crear_examen_db(mundo, 1, "GLUCEMIA", activo="NO")
    cuerpo, _ = enviar_uno(mundo, item("EXT-1", codigo="GLUCEMIA"))
    verificar_pendiente(mundo, cuerpo, "EXT-1", "EXAMEN_NO_VALIDO")
    cuerpo2, _ = enviar_uno(mundo, item("EXT-2", codigo="GLUCOSA"))      # existe solo en la clínica 2
    verificar_pendiente(mundo, cuerpo2, "EXT-2", "EXAMEN_NO_VALIDO")


def test_el_paciente_inexistente_prevalece_sobre_el_estudio_invalido(mundo):
    cuerpo, _ = enviar_uno(mundo, item("EXT-1", ci="9999999", codigo="NO-EXISTE"))
    verificar_pendiente(mundo, cuerpo, "EXT-1", "PACIENTE_NO_ENCONTRADO")


# --------------------------------------------------------------------------- #
# Orden
# --------------------------------------------------------------------------- #
def test_orden_valida_firmada_del_mismo_paciente_con_el_estudio_incorpora(mundo):
    id_orden = mundo.datos["orden"].id_orden
    _, fila = enviar_uno(mundo, item("EXT-1", id_orden=id_orden))
    assert fila["resultado"] == "INCORPORADO"
    resultado = resultado_de(mundo, "EXT-1")
    assert resultado.id_orden == id_orden
    documento = mundo.env.uno(DocumentoClinico, DocumentoClinico.id_documento == resultado.id_documento)
    assert documento.metadatos["id_orden"] == id_orden


def test_orden_de_otro_paciente_queda_pendiente_orden_paciente_no_coincide(mundo):
    otro = crear_paciente(mundo, 1, "8888888")
    id_orden = crear_orden_db(mundo, 1, otro, ["HEMOGRAMA"])
    cuerpo, _ = enviar_uno(mundo, item("EXT-1", id_orden=id_orden))
    resultado = verificar_pendiente(mundo, cuerpo, "EXT-1", "ORDEN_PACIENTE_NO_COINCIDE")
    assert resultado.id_orden is None                                      # el pendiente no se enlaza a ninguna orden
    assert resultado.datos_correspondencia["id_orden"] == id_orden


def test_ordenes_no_validas_quedan_pendientes_con_orden_no_valida(mundo):
    pac1 = mundo.datos["pac1"].id_paciente
    casos = {
        "EXT-INEXISTENTE": 987654,
        "EXT-NO-FIRMADA": crear_orden_db(mundo, 1, pac1, ["HEMOGRAMA"], estado="BORRADOR"),
        "EXT-ANULADA": crear_orden_db(mundo, 1, pac1, ["HEMOGRAMA"], estado="ANULADA"),
        "EXT-SIN-ESTUDIO": crear_orden_db(mundo, 1, pac1, ["GLUCEMIA"]),
        "EXT-OTRA-CLINICA": crear_orden_db(mundo, 2, mundo.datos["pac2"].id_paciente, ["HEMOGRAMA"]),
    }
    items = [item(externo, id_orden=id_orden) for externo, id_orden in casos.items()]
    respuesta = post_lote(mundo, mundo.p["admin1"], items)
    assert respuesta.status_code == 201, respuesta.text
    for externo in casos:
        verificar_pendiente(mundo, respuesta.json(), externo, "ORDEN_NO_VALIDA")
    assert total_documentos_lab(mundo) == 0


def test_el_estudio_invalido_prevalece_sobre_la_orden(mundo):
    id_orden = mundo.datos["orden"].id_orden
    cuerpo, _ = enviar_uno(mundo, item("EXT-1", codigo="NO-EXISTE", id_orden=id_orden))
    verificar_pendiente(mundo, cuerpo, "EXT-1", "EXAMEN_NO_VALIDO")


# --------------------------------------------------------------------------- #
# Un pendiente no aparece en ningún expediente
# --------------------------------------------------------------------------- #
def test_un_pendiente_no_aparece_en_el_expediente_ni_en_cu12_pero_si_para_el_revisor(mundo):
    cuerpo, _ = enviar_uno(mundo, item("EXT-1", ci="9999999"))
    id_resultado = por_externo(cuerpo)["EXT-1"]["id_resultado"]
    mundo.env.como(mundo.p["medico1"])
    pac1 = mundo.datos["pac1"].id_paciente
    assert mundo.client.get(f"/api/v1/pacientes/{pac1}/resultados-laboratorio").json()["total"] == 0
    assert mundo.client.get("/api/v1/resultados-laboratorio").json()["total"] == 0          # solo INCORPORADO por defecto
    pendientes = mundo.client.get("/api/v1/resultados-laboratorio", params={"estado": "PENDIENTE_REVISION"}).json()
    assert [r["id_resultado"] for r in pendientes["items"]] == [id_resultado]
    detalle = mundo.client.get(f"/api/v1/resultados-laboratorio/{id_resultado}").json()
    assert detalle["datos_correspondencia"]["ci"] == "9999999" and detalle["id_paciente"] is None
    # un usuario sin lab_results:review no ve el pendiente ni sus datos crudos
    mundo.env.como(mundo.p["recepcion1"])
    assert mundo.client.get(f"/api/v1/resultados-laboratorio/{id_resultado}").status_code == 404
    assert mundo.client.get("/api/v1/resultados-laboratorio", params={"estado": "PENDIENTE_REVISION"}).status_code == 403
    assert total_documentos_lab(mundo) == 0


def test_un_pendiente_resuelto_se_incorpora_con_el_flujo_del_bloque_a(mundo):
    cuerpo, _ = enviar_uno(mundo, item("EXT-1", ci="9999999"))
    id_resultado = por_externo(cuerpo)["EXT-1"]["id_resultado"]
    mundo.env.como(mundo.p["medico1"])
    respuesta = mundo.client.post(
        f"/api/v1/resultados-laboratorio/{id_resultado}/resolver",
        json={"accion": "ASIGNAR", "id_paciente": mundo.datos["pac1"].id_paciente, "codigo_examen": "HEMOGRAMA"},
    )
    assert respuesta.status_code == 200, respuesta.text
    assert respuesta.json()["estado"] == "INCORPORADO" and respuesta.json()["id_documento"] is not None
    assert respuesta.json()["origen"] == "SINCRONIZADO" and respuesta.json()["id_externo"] == "EXT-1"
    assert total_documentos_lab(mundo) == 1


# --------------------------------------------------------------------------- #
# Archivos inválidos: aislados del resto del lote (criterio 3)
# --------------------------------------------------------------------------- #
def test_un_archivo_exe_no_frena_el_lote(mundo):
    items = [item("EXT-1"), item("EXT-2", archivo="virus.exe"), item("EXT-3")]
    respuesta = post_lote(mundo, mundo.p["admin1"], items, archivos={"virus.exe": (b"MZ\x90\x00binario", "application/octet-stream")})
    assert respuesta.status_code == 201, respuesta.text
    cuerpo = respuesta.json()
    por = por_externo(cuerpo)
    assert por["EXT-1"]["resultado"] == "INCORPORADO" and por["EXT-3"]["resultado"] == "INCORPORADO"
    assert por["EXT-2"]["resultado"] == "ERROR" and por["EXT-2"]["codigo_error"] == "ARCHIVO_TIPO_NO_PERMITIDO"
    assert por["EXT-2"]["id_resultado"] is None and por["EXT-2"]["detalle"]
    assert cuerpo["estado"] == "COMPLETADA_CON_ERRORES" and cuerpo["con_error"] == 1 and cuerpo["incorporados"] == 2
    assert resultado_de(mundo, "EXT-2") is None                        # sin resultado
    assert cantidad_de_archivos(mundo.almacen) == 2                    # sin archivo del ítem fallido


@pytest.mark.parametrize(
    "archivo,contenido,codigo",
    [
        ("falso.pdf", (b"no es un pdf", "application/pdf"), "ARCHIVO_FIRMA_INVALIDA"),
        ("foto.png", (pdf_bytes(), "image/png"), "ARCHIVO_FIRMA_INVALIDA"),
        ("vacio.pdf", (b"", "application/pdf"), "ARCHIVO_VACIO"),
        ("grande.pdf", (b"%PDF-" + b"0" * (10 * 1024 * 1024), "application/pdf"), "ARCHIVO_TAMANO_EXCEDIDO"),
        ("texto.txt", (b"hola", "text/plain"), "ARCHIVO_TIPO_NO_PERMITIDO"),
        ("tipo.pdf", (pdf_bytes(), "text/html"), "ARCHIVO_TIPO_NO_PERMITIDO"),
        ("contradice.pdf", (pdf_bytes(), "image/jpeg"), "ARCHIVO_FIRMA_INVALIDA"),
    ],
)
def test_cada_archivo_invalido_queda_en_error_sin_persistir_nada_y_sin_afectar_al_resto(mundo, archivo, contenido, codigo):
    items = [item("EXT-OK"), item("EXT-MAL", archivo=archivo)]
    respuesta = post_lote(mundo, mundo.p["admin1"], items, archivos={archivo: contenido})
    assert respuesta.status_code == 201, respuesta.text
    por = por_externo(respuesta.json())
    assert por["EXT-OK"]["resultado"] == "INCORPORADO"
    assert por["EXT-MAL"]["resultado"] == "ERROR" and por["EXT-MAL"]["codigo_error"] == codigo
    assert total_resultados(mundo) == 1 and cantidad_de_archivos(mundo.almacen) == 1


def test_un_nombre_de_archivo_con_ruta_nunca_forma_parte_de_la_clave_de_almacenamiento(mundo):
    nombre = "../../etc/passwd.pdf"
    _, fila = enviar_uno(mundo, item("EXT-1", archivo=nombre), archivos={nombre: pdf_bytes(b"ruta")})
    assert fila["resultado"] == "INCORPORADO"
    resultado = resultado_de(mundo, "EXT-1")
    assert ".." not in resultado.archivo_url and resultado.archivo_url.startswith("documentos/")
    assert "/" not in resultado.nombre_archivo and ".." not in resultado.nombre_archivo
    assert not (mundo.almacen.parent / "etc").exists()
