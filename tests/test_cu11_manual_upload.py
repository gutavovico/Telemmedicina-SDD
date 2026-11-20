"""CU11 · tareas 3.4, 3.5 y 3.6: carga manual (criterios 1, 2, 3 y 9)."""
import hashlib
from datetime import date, timedelta

import pytest
from sqlalchemy import select

from app.modules.auth.models import Auditoria
from app.modules.medical_records.clinical_documents.models import DocumentoClinico
from app.modules.medical_records.laboratory_orders.models import ExamenLaboratorio, OrdenLaboratorio
from app.modules.medical_records.laboratory_results import service
from app.modules.medical_records.laboratory_results.models import ResultadoLaboratorio
from cu11_support import (
    URL,
    Cu11Http,
    cantidad_de_archivos,
    construir_mundo,
    jpg_bytes,
    pdf_bytes,
    png_bytes,
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
    almacen = usar_storage_temporal(monkeypatch, tmp_path)
    return construir_mundo(env, almacen)


def _sin_efectos(mundo):
    assert mundo.env.contar(ResultadoLaboratorio) == 0
    assert mundo.env.contar(DocumentoClinico, DocumentoClinico.tipo_documento == "RESULTADO_LAB") == 0
    assert cantidad_de_archivos(mundo.almacen) == 0


def _codigo(respuesta):
    return respuesta.json()["detail"]["codigo"]


# ----------------------------------- 201 ----------------------------------------------- #
def test_carga_exitosa_crea_resultado_documento_archivo_y_auditoria(mundo):
    contenido = pdf_bytes(b"resultado-1")
    respuesta = post_manual(
        mundo, mundo.p["recepcion1"],
        archivo=("hemograma.pdf", contenido, "application/pdf"),
        campos={"observaciones": "Muestra en ayunas"},
    )
    assert respuesta.status_code == 201, respuesta.text
    cuerpo = respuesta.json()
    assert cuerpo["estado"] == "INCORPORADO" and cuerpo["origen"] == "MANUAL"
    assert cuerpo["id_clinica"] == 1
    assert cuerpo["id_paciente"] == mundo.datos["pac1"].id_paciente
    assert cuerpo["codigo_examen"] == "HEMOGRAMA" and cuerpo["nombre_examen"] == "Hemograma completo"
    assert cuerpo["content_type"] == "application/pdf" and cuerpo["tamano_bytes"] == len(contenido)
    assert cuerpo["id_documento"] is not None
    assert cuerpo["registrado_por"] == mundo.p["recepcion1"].id_usuario
    assert cuerpo["registrado_en"] is not None and cuerpo["proceso"] is None
    assert "archivo_url" not in cuerpo and "tenant_id" not in cuerpo
    # RECEPCION no tiene documents:read:lab_results: no recibe observaciones ni hash
    assert cuerpo["observaciones"] is None and cuerpo["hash_archivo"] is None

    resultado = mundo.env.uno(ResultadoLaboratorio, ResultadoLaboratorio.id_resultado == cuerpo["id_resultado"])
    assert resultado.hash_archivo == hashlib.sha256(contenido).hexdigest()
    assert resultado.observaciones == "Muestra en ayunas"
    # el archivo se guardó una sola vez, con clave generada por el sistema y contenido idéntico
    assert cantidad_de_archivos(mundo.almacen) == 1
    ruta = next(p for p in mundo.almacen.rglob("*") if p.is_file())
    assert ruta.name.startswith("resultado-lab-1-") and "hemograma" not in ruta.name
    assert ruta.read_bytes() == contenido
    assert resultado.archivo_url.endswith(ruta.name)

    documento = mundo.env.uno(DocumentoClinico, DocumentoClinico.id_documento == resultado.id_documento)
    assert documento.tipo_documento == "RESULTADO_LAB" and documento.estado == "ACTIVO"
    assert documento.id_clinica == 1 and documento.id_paciente == resultado.id_paciente
    assert documento.archivo_url == resultado.archivo_url and documento.hash_archivo == resultado.hash_archivo
    assert documento.metadatos["id_resultado_laboratorio"] == resultado.id_resultado
    assert documento.metadatos["content_type"] == "application/pdf"

    traza = mundo.env.uno(Auditoria, Auditoria.accion == "CREAR_RESULTADO_LABORATORIO")
    assert traza.tabla_afectada == "resultados_laboratorio" and traza.registro_id == resultado.id_resultado
    assert traza.id_clinica == 1 and traza.id_usuario == mundo.p["recepcion1"].id_usuario


def test_administrador_recibe_hash_y_observaciones(mundo):
    respuesta = post_manual(mundo, mundo.p["admin1"], campos={"observaciones": "Dato clínico"})
    assert respuesta.status_code == 201
    cuerpo = respuesta.json()
    assert cuerpo["observaciones"] == "Dato clínico" and len(cuerpo["hash_archivo"]) == 64


@pytest.mark.parametrize("nombre,contenido,tipo", [
    ("foto.jpg", jpg_bytes(b"a"), "image/jpeg"),
    ("imagen.png", png_bytes(b"b"), "image/png"),
    ("informe.pdf", pdf_bytes(b"c"), "application/pdf"),
])
def test_cada_formato_guarda_el_content_type_real(mundo, nombre, contenido, tipo):
    respuesta = post_manual(mundo, mundo.p["medico1"], archivo=(nombre, contenido, tipo))
    assert respuesta.status_code == 201 and respuesta.json()["content_type"] == tipo


def test_nombre_con_ruta_se_acepta_y_se_conserva_saneado(mundo):
    respuesta = post_manual(mundo, mundo.p["medico1"], archivo=("../../x.pdf", pdf_bytes(), "application/pdf"))
    assert respuesta.status_code == 201
    assert respuesta.json()["nombre_archivo"] == "x.pdf"
    ruta = next(p for p in mundo.almacen.rglob("*") if p.is_file())
    assert ".." not in str(ruta.relative_to(mundo.almacen)) and ruta.name != "x.pdf"


# --------------------------------- correspondencia (3.4) ------------------------------- #
def test_paciente_de_otra_clinica_da_404_sin_efectos(mundo):
    respuesta = post_manual(mundo, mundo.p["medico1"], campos={"id_paciente": str(mundo.datos["pac2"].id_paciente)})
    assert respuesta.status_code == 404 and _codigo(respuesta) == "PACIENTE_NO_ENCONTRADO"
    _sin_efectos(mundo)


def test_paciente_con_id_clinica_null_se_comporta_como_inexistente(mundo):
    respuesta = post_manual(mundo, mundo.p["medico1"], campos={"id_paciente": str(mundo.datos["pac_sin_clinica"].id_paciente)})
    assert respuesta.status_code == 404 and _codigo(respuesta) == "PACIENTE_NO_ENCONTRADO"
    _sin_efectos(mundo)


def test_paciente_inexistente_da_404(mundo):
    respuesta = post_manual(mundo, mundo.p["medico1"], campos={"id_paciente": "999999"})
    assert respuesta.status_code == 404 and _codigo(respuesta) == "PACIENTE_NO_ENCONTRADO"
    _sin_efectos(mundo)


def test_examen_inexistente_de_otra_clinica_o_inactivo_da_404(mundo):
    with mundo.env.SessionLocal() as db:
        db.add(ExamenLaboratorio(id_clinica=1, codigo="INACTIVO", nombre="Inactivo", categoria="OTROS", activo="NO"))
        db.commit()
    for codigo in ("NO_EXISTE", "GLUCOSA", "INACTIVO"):  # GLUCOSA solo existe en la clínica 2
        respuesta = post_manual(mundo, mundo.p["medico1"], campos={"codigo_examen": codigo})
        assert respuesta.status_code == 404, codigo
        assert _codigo(respuesta) == "EXAMEN_NO_ENCONTRADO"
    _sin_efectos(mundo)


def test_codigo_de_examen_se_normaliza_a_mayusculas(mundo):
    respuesta = post_manual(mundo, mundo.p["medico1"], campos={"codigo_examen": " hemograma "})
    assert respuesta.status_code == 201 and respuesta.json()["codigo_examen"] == "HEMOGRAMA"


def _crear_orden(mundo, id_clinica, id_paciente, estado="FIRMADA", codigos=("HEMOGRAMA",)):
    with mundo.env.SessionLocal() as db:
        orden = OrdenLaboratorio(
            id_clinica=id_clinica, id_paciente=id_paciente, id_medico=mundo.datos["medico"].id_usuario,
            examenes=[{"codigo": c, "nombre": c, "indicaciones": None} for c in codigos],
            fecha_orden=date(2026, 11, 1), estado=estado,
        )
        db.add(orden)
        db.commit()
        return orden.id_orden


def test_orden_valida_se_vincula(mundo):
    respuesta = post_manual(mundo, mundo.p["medico1"], campos={"id_orden": str(mundo.datos["orden"].id_orden)})
    assert respuesta.status_code == 201 and respuesta.json()["id_orden"] == mundo.datos["orden"].id_orden


@pytest.mark.parametrize("caso,estado,codigo_http,codigo", [
    ("otra_clinica", None, 404, "ORDEN_NO_ENCONTRADA"),
    ("inexistente", None, 404, "ORDEN_NO_ENCONTRADA"),
    ("otro_paciente", None, 409, "ORDEN_PACIENTE_NO_COINCIDE"),
    ("borrador", "BORRADOR", 409, "ORDEN_NO_FIRMADA"),
    ("anulada", "ANULADA", 409, "ORDEN_NO_FIRMADA"),
    ("sin_estudio", "FIRMADA", 409, "ORDEN_SIN_EXAMEN"),
])
def test_ordenes_invalidas(mundo, caso, estado, codigo_http, codigo):
    pac1 = mundo.datos["pac1"].id_paciente
    if caso == "otra_clinica":
        id_orden = _crear_orden(mundo, 2, mundo.datos["pac2"].id_paciente)
    elif caso == "inexistente":
        id_orden = 987654
    elif caso == "otro_paciente":
        id_orden = _crear_orden(mundo, 1, mundo.p["pac_propio"].id_paciente)
    elif caso == "sin_estudio":
        id_orden = _crear_orden(mundo, 1, pac1, codigos=("GLUCOSA",))
    else:
        id_orden = _crear_orden(mundo, 1, pac1, estado=estado)
    respuesta = post_manual(mundo, mundo.p["medico1"], campos={"id_orden": str(id_orden)})
    assert respuesta.status_code == codigo_http, respuesta.text
    assert _codigo(respuesta) == codigo
    _sin_efectos(mundo)


# --------------------------------- validaciones (3.5) ---------------------------------- #
@pytest.mark.parametrize("campo", ["archivo", "id_paciente", "codigo_examen", "fecha_realizacion", "laboratorio_origen"])
def test_campos_obligatorios_faltantes_dan_422(mundo, campo):
    respuesta = post_manual(mundo, mundo.p["medico1"], quitar=(campo,))
    assert respuesta.status_code == 422
    assert campo in respuesta.text
    _sin_efectos(mundo)


def test_fecha_futura_da_422(mundo):
    manana = (date.today() + timedelta(days=1)).isoformat()
    respuesta = post_manual(mundo, mundo.p["medico1"], campos={"fecha_realizacion": manana})
    assert respuesta.status_code == 422 and "fecha_realizacion" in respuesta.text
    _sin_efectos(mundo)


def test_fecha_de_hoy_es_valida(mundo):
    respuesta = post_manual(mundo, mundo.p["medico1"], campos={"fecha_realizacion": date.today().isoformat()})
    assert respuesta.status_code == 201


@pytest.mark.parametrize("campos", [
    {"laboratorio_origen": "   "},
    {"codigo_examen": "X" * 51},
    {"fecha_realizacion": "no-es-fecha"},
    {"id_paciente": "abc"},
    {"observaciones": "o" * 2001},
])
def test_valores_invalidos_dan_422(mundo, campos):
    respuesta = post_manual(mundo, mundo.p["medico1"], campos=campos)
    assert respuesta.status_code == 422
    _sin_efectos(mundo)


@pytest.mark.parametrize("campo,valor", [
    ("id_clinica", "2"), ("tenant_id", "2"), ("estado", "PENDIENTE_REVISION"), ("origen", "SINCRONIZADO"),
])
def test_campos_prohibidos_en_el_cuerpo_dan_422(mundo, campo, valor):
    respuesta = post_manual(mundo, mundo.p["medico1"], campos={campo: valor})
    assert respuesta.status_code == 422 and campo in respuesta.text
    _sin_efectos(mundo)


def test_el_encabezado_x_tenant_id_no_cambia_la_clinica(mundo):
    respuesta = post_manual(mundo, mundo.p["medico1"], headers={"X-Tenant-ID": "2"})
    assert respuesta.status_code == 201 and respuesta.json()["id_clinica"] == 1
    # y no permite alcanzar datos de la clínica 2
    respuesta = post_manual(
        mundo, mundo.p["medico1"], campos={"id_paciente": str(mundo.datos["pac2"].id_paciente)},
        headers={"X-Tenant-ID": "2"},
    )
    assert respuesta.status_code == 404


@pytest.mark.parametrize("nombre,contenido,tipo,codigo", [
    ("resultado.exe", pdf_bytes(), "application/octet-stream", "ARCHIVO_TIPO_NO_PERMITIDO"),
    ("resultado.docx", pdf_bytes(), "application/msword", "ARCHIVO_TIPO_NO_PERMITIDO"),
    ("resultado.pdf", b"no es un pdf", "application/pdf", "ARCHIVO_FIRMA_INVALIDA"),
    ("resultado.pdf", b"", "application/pdf", "ARCHIVO_VACIO"),
    ("resultado.pdf", png_bytes(), "image/png", "ARCHIVO_FIRMA_INVALIDA"),
])
def test_archivos_invalidos_dan_422_con_codigo_y_sin_efectos(mundo, nombre, contenido, tipo, codigo):
    respuesta = post_manual(mundo, mundo.p["medico1"], archivo=(nombre, contenido, tipo))
    assert respuesta.status_code == 422, respuesta.text
    assert _codigo(respuesta) == codigo
    _sin_efectos(mundo)


def test_archivo_mayor_a_10_mb_da_422(mundo):
    grande = pdf_bytes() + b"0" * (10 * 1024 * 1024)
    respuesta = post_manual(mundo, mundo.p["medico1"], archivo=("grande.pdf", grande, "application/pdf"))
    assert respuesta.status_code == 422 and _codigo(respuesta) == "ARCHIVO_TAMANO_EXCEDIDO"
    _sin_efectos(mundo)


def test_las_respuestas_de_error_no_filtran_datos_de_otra_clinica(mundo):
    respuesta = post_manual(mundo, mundo.p["medico1"], campos={"id_paciente": str(mundo.datos["pac2"].id_paciente)})
    texto = respuesta.text
    for dato in ("Luis", "Norte", "2222222", "70000002"):
        assert dato not in texto


# ------------------------------- permisos y autenticación ------------------------------ #
def test_sin_token_da_401(mundo):
    mundo.env.anonimo()
    respuesta = post_manual(mundo)
    assert respuesta.status_code == 401
    _sin_efectos(mundo)


@pytest.mark.parametrize("persona", ["paciente1", "sin_permisos1"])
def test_sin_permiso_de_carga_da_403(mundo, persona):
    respuesta = post_manual(mundo, mundo.p[persona])
    assert respuesta.status_code == 403 and "lab_results:create" in respuesta.text
    _sin_efectos(mundo)


def test_cuenta_global_sin_clinica_da_403(mundo):
    respuesta = post_manual(mundo, mundo.p["global"], headers={"X-Tenant-ID": "1"})
    assert respuesta.status_code == 403
    _sin_efectos(mundo)


# ------------------------- consistencia y compensación (3.5) --------------------------- #
def test_falla_de_auditoria_no_deja_resultado_documento_ni_archivo(mundo, monkeypatch):
    def auditoria_rota(*args, **kwargs):
        raise RuntimeError("la auditoría falló")

    monkeypatch.setattr(service, "registrar_auditoria", auditoria_rota)
    respuesta = post_manual(mundo, mundo.p["medico1"])
    assert respuesta.status_code == 500
    _sin_efectos(mundo)
    assert mundo.env.contar(Auditoria) == 0


def test_falla_despues_de_guardar_el_archivo_lo_compensa(mundo, monkeypatch):
    llamadas = []
    real_store = service.storage.store

    def store_espia(*args, **kwargs):
        llamadas.append(real_store(*args, **kwargs))
        return llamadas[-1]

    monkeypatch.setattr(service.storage, "store", store_espia)
    monkeypatch.setattr(service, "_documento_para", lambda *a, **k: (_ for _ in ()).throw(RuntimeError("falló el INSERT")))
    respuesta = post_manual(mundo, mundo.p["medico1"])
    assert respuesta.status_code == 500
    assert len(llamadas) == 1  # el archivo sí se guardó...
    _sin_efectos(mundo)  # ...y se borró al fallar la transacción


def test_falla_del_almacenamiento_no_crea_filas(mundo, monkeypatch):
    def store_roto(*args, **kwargs):
        raise OSError("disco lleno")

    monkeypatch.setattr(service.storage, "store", store_roto)
    respuesta = post_manual(mundo, mundo.p["medico1"])
    assert respuesta.status_code == 500 and _codigo(respuesta) == "ALMACENAMIENTO_FALLIDO"
    _sin_efectos(mundo)


# ------------------------------- duplicados (3.6) -------------------------------------- #
def test_mismo_archivo_para_el_mismo_paciente_da_409_sin_segundo_archivo(mundo):
    contenido = pdf_bytes(b"duplicado")
    primero = post_manual(mundo, mundo.p["medico1"], archivo=("a.pdf", contenido, "application/pdf"))
    assert primero.status_code == 201
    segundo = post_manual(mundo, mundo.p["medico1"], archivo=("otro-nombre.pdf", contenido, "application/pdf"))
    assert segundo.status_code == 409 and _codigo(segundo) == "RESULTADO_DUPLICADO"
    assert mundo.env.contar(ResultadoLaboratorio) == 1
    assert mundo.env.contar(DocumentoClinico, DocumentoClinico.tipo_documento == "RESULTADO_LAB") == 1
    assert cantidad_de_archivos(mundo.almacen) == 1


def test_mismo_archivo_para_otro_paciente_es_valido(mundo):
    contenido = pdf_bytes(b"compartido")
    assert post_manual(mundo, mundo.p["medico1"], archivo=("a.pdf", contenido, "application/pdf")).status_code == 201
    otro = post_manual(
        mundo, mundo.p["medico1"], archivo=("a.pdf", contenido, "application/pdf"),
        campos={"id_paciente": str(mundo.p["pac_propio"].id_paciente)},
    )
    assert otro.status_code == 201
    assert cantidad_de_archivos(mundo.almacen) == 2  # cada resultado tiene su propio objeto


def test_se_acepta_de_nuevo_el_archivo_tras_anular_el_anterior(mundo):
    contenido = pdf_bytes(b"re-subida")
    primero = post_manual(mundo, mundo.p["medico1"], archivo=("a.pdf", contenido, "application/pdf"))
    anulado = mundo.client.post(
        f"{URL}/{primero.json()['id_resultado']}/anular", json={"motivo": "Cargado por error"},
    )
    assert anulado.status_code == 200
    segundo = post_manual(mundo, mundo.p["medico1"], archivo=("a.pdf", contenido, "application/pdf"))
    assert segundo.status_code == 201
    assert segundo.json()["id_resultado"] != primero.json()["id_resultado"]


def test_la_violacion_del_indice_unico_en_la_base_se_traduce_a_409_y_compensa(mundo, monkeypatch):
    """Carrera: la comprobación previa no ve el duplicado, pero la restricción de la base de datos lo rechaza."""
    contenido = pdf_bytes(b"carrera")
    assert post_manual(mundo, mundo.p["medico1"], archivo=("a.pdf", contenido, "application/pdf")).status_code == 201
    archivos_antes = cantidad_de_archivos(mundo.almacen)

    original = service._hay_duplicado_manual
    llamadas = {"n": 0}

    def ciego_la_primera_vez(*args, **kwargs):
        llamadas["n"] += 1
        return False if llamadas["n"] == 1 else original(*args, **kwargs)

    monkeypatch.setattr(service, "_hay_duplicado_manual", ciego_la_primera_vez)
    respuesta = post_manual(mundo, mundo.p["medico1"], archivo=("b.pdf", contenido, "application/pdf"))
    assert respuesta.status_code == 409 and _codigo(respuesta) == "RESULTADO_DUPLICADO"
    assert llamadas["n"] == 2
    assert mundo.env.contar(ResultadoLaboratorio) == 1
    assert cantidad_de_archivos(mundo.almacen) == archivos_antes  # el archivo del intento fallido se borró
