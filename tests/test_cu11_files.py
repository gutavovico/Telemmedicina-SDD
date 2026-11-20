"""CU11 · tarea 3.2: validación de archivos (criterio 3). Pruebas unitarias de ``files.py``."""
import hashlib
import io

import pytest

from app.modules.medical_records.laboratory_results import files
from cu11_support import jpg_bytes, pdf_bytes, png_bytes


def validar(contenido, nombre, declarado=None):
    return files.leer_y_validar(io.BytesIO(contenido), nombre, declarado)


@pytest.mark.parametrize("contenido,nombre,esperado", [
    (pdf_bytes(), "hemograma.pdf", "application/pdf"),
    (jpg_bytes(), "foto.jpg", "image/jpeg"),
    (jpg_bytes(), "foto.JPEG", "image/jpeg"),
    (png_bytes(), "imagen.png", "image/png"),
])
def test_formatos_validos_derivan_el_content_type_de_la_firma(contenido, nombre, esperado):
    validado = validar(contenido, nombre)
    assert validado.content_type == esperado
    assert validado.tamano == len(contenido)
    assert validado.sha256 == hashlib.sha256(contenido).hexdigest()
    assert validado.contenido == contenido


@pytest.mark.parametrize("nombre", ["resultado.exe", "resultado.docx", "resultado.txt", "resultado", "", None, ".pdf.exe"])
def test_extension_no_permitida(nombre):
    with pytest.raises(files.ArchivoError) as exc:
        validar(pdf_bytes(), nombre)
    assert exc.value.codigo == "ARCHIVO_TIPO_NO_PERMITIDO" and exc.value.status_code == 422


def test_pdf_con_firma_falsa():
    with pytest.raises(files.ArchivoError) as exc:
        validar(b"esto no es un pdf", "resultado.pdf")
    assert exc.value.codigo == "ARCHIVO_FIRMA_INVALIDA"


def test_firma_de_otro_formato_con_extension_distinta():
    with pytest.raises(files.ArchivoError) as exc:
        validar(png_bytes(), "resultado.pdf")
    assert exc.value.codigo == "ARCHIVO_FIRMA_INVALIDA"
    with pytest.raises(files.ArchivoError) as exc:
        validar(pdf_bytes(), "foto.jpg")
    assert exc.value.codigo == "ARCHIVO_FIRMA_INVALIDA"


def test_archivo_vacio():
    with pytest.raises(files.ArchivoError) as exc:
        validar(b"", "vacio.pdf")
    assert exc.value.codigo == "ARCHIVO_VACIO"


def test_tamano_maximo_exacto_es_valido_y_un_byte_mas_se_rechaza():
    base = pdf_bytes()
    exacto = base + b"0" * (files.TAMANO_MAXIMO_BYTES - len(base))
    assert len(exacto) == 10 * 1024 * 1024
    assert validar(exacto, "max.pdf").tamano == files.TAMANO_MAXIMO_BYTES
    with pytest.raises(files.ArchivoError) as exc:
        validar(exacto + b"0", "max.pdf")
    assert exc.value.codigo == "ARCHIVO_TAMANO_EXCEDIDO"


def test_el_corte_por_tamano_no_lee_el_archivo_completo():
    class Infinito(io.RawIOBase):
        leidos = 0

        def readable(self):
            return True

        def read(self, n=-1):
            n = 65536 if n is None or n < 0 else n
            Infinito.leidos += n
            return b"%PDF-" + b"0" * (n - 5) if Infinito.leidos == n else b"0" * n

    with pytest.raises(files.ArchivoError) as exc:
        files.leer_y_validar(Infinito(), "enorme.pdf", None)
    assert exc.value.codigo == "ARCHIVO_TAMANO_EXCEDIDO"
    assert Infinito.leidos <= files.TAMANO_MAXIMO_BYTES + files.TAMANO_BLOQUE


@pytest.mark.parametrize("declarado", ["text/html", "application/zip", "image/gif"])
def test_content_type_declarado_no_permitido(declarado):
    with pytest.raises(files.ArchivoError) as exc:
        validar(pdf_bytes(), "resultado.pdf", declarado)
    assert exc.value.codigo == "ARCHIVO_TIPO_NO_PERMITIDO"


def test_content_type_declarado_que_contradice_el_contenido():
    with pytest.raises(files.ArchivoError) as exc:
        validar(pdf_bytes(), "resultado.pdf", "image/png")
    assert exc.value.codigo == "ARCHIVO_FIRMA_INVALIDA"


@pytest.mark.parametrize("declarado", [None, "", "application/octet-stream", "application/pdf; charset=binary"])
def test_content_type_generico_o_coincidente_se_acepta(declarado):
    assert validar(pdf_bytes(), "resultado.pdf", declarado).content_type == "application/pdf"


def test_alias_de_jpeg_declarado_por_algunos_clientes():
    assert validar(jpg_bytes(), "foto.jpg", "image/jpg").content_type == "image/jpeg"


@pytest.mark.parametrize("original,esperado", [
    ("../../etc/passwd.pdf", "passwd.pdf"),
    ("..\\..\\windows\\system32\\resultado.pdf", "resultado.pdf"),
    ("/var/www/resultado.pdf", "resultado.pdf"),
    ('re"sul;ta<do>.pdf', "re_sul_ta_do_.pdf"),
    ("   .resultado.pdf  ", "resultado.pdf"),
    ("resultado\x00.pdf", "resultado.pdf"),
    ("análisis clínico (1).pdf", "análisis clínico (1).pdf"),
])
def test_saneo_de_nombres(original, esperado):
    assert files.sanear_nombre(original) == esperado


def test_nombre_con_ruta_se_acepta_pero_se_conserva_solo_saneado():
    validado = validar(pdf_bytes(), "../../x.pdf")
    assert validado.nombre == "x.pdf"


def test_nombre_muy_largo_se_trunca_conservando_la_extension():
    saneado = files.sanear_nombre("a" * 400 + ".pdf")
    assert len(saneado) <= 255 and saneado.endswith(".pdf")


def test_clave_de_almacenamiento_generada_no_deriva_del_cliente():
    nombre = files.nombre_para_almacenamiento(3, ".png")
    assert nombre.startswith("resultado-lab-3-") and nombre.endswith(".png")
    assert nombre != files.nombre_para_almacenamiento(3, ".png")
    assert "/" not in nombre and "\\" not in nombre and ".." not in nombre
