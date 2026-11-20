"""Validación de archivos de resultados de laboratorio (CU11).

Reglas del contrato (``openspec/contracts/resultados-laboratorio.md`` sección 2.1): extensión
``.pdf``/``.jpg``/``.jpeg``/``.png``, tamaño de 1 byte a 10 MiB, firma (magic bytes) que corresponda a la
extensión y ``content_type`` derivado de la firma detectada. El nombre original se sanea y solo se conserva
como metadato: la clave de almacenamiento la genera el sistema.
"""
import hashlib
import re
import unicodedata
import uuid
from dataclasses import dataclass
from typing import BinaryIO, Optional

TAMANO_MAXIMO_BYTES = 10 * 1024 * 1024
TAMANO_BLOQUE = 64 * 1024
MAX_LONGITUD_NOMBRE = 255

CONTENT_TYPE_PDF = "application/pdf"
CONTENT_TYPE_JPEG = "image/jpeg"
CONTENT_TYPE_PNG = "image/png"

EXTENSIONES_PERMITIDAS = {
    ".pdf": CONTENT_TYPE_PDF,
    ".jpg": CONTENT_TYPE_JPEG,
    ".jpeg": CONTENT_TYPE_JPEG,
    ".png": CONTENT_TYPE_PNG,
}

FIRMAS = (
    (CONTENT_TYPE_PDF, b"%PDF-"),
    (CONTENT_TYPE_JPEG, b"\xff\xd8\xff"),
    (CONTENT_TYPE_PNG, b"\x89PNG\r\n\x1a\n"),
)

# Tipos que algunos clientes declaran para los mismos formatos, y tipos genéricos que no contradicen nada.
ALIAS_CONTENT_TYPE = {
    "image/jpg": CONTENT_TYPE_JPEG,
    "image/pjpeg": CONTENT_TYPE_JPEG,
    "application/x-pdf": CONTENT_TYPE_PDF,
}
CONTENT_TYPES_GENERICOS = {"application/octet-stream", "binary/octet-stream", ""}

_CARACTERES_NO_PERMITIDOS = re.compile(r"[^\w.\- ()]", re.UNICODE)


class ArchivoError(Exception):
    """Error de validación de archivo; siempre se responde ``422`` con un código del contrato."""

    status_code = 422

    def __init__(self, codigo: str, mensaje: str):
        super().__init__(mensaje)
        self.codigo = codigo
        self.mensaje = mensaje


@dataclass(frozen=True)
class ArchivoValidado:
    contenido: bytes
    content_type: str
    extension: str
    sha256: str
    tamano: int
    nombre: str  # nombre original saneado (solo metadato)


def sanear_nombre(nombre: Optional[str]) -> str:
    """Quita rutas, caracteres de control y símbolos peligrosos; nunca devuelve una ruta."""
    texto = unicodedata.normalize("NFKC", str(nombre or ""))
    texto = texto.replace("\x00", "")
    texto = re.split(r"[\\/]", texto)[-1]
    texto = "".join(c for c in texto if c.isprintable())
    texto = _CARACTERES_NO_PERMITIDOS.sub("_", texto)
    texto = re.sub(r"\s+", " ", texto).strip(" .")
    if not texto:
        return ""
    if len(texto) > MAX_LONGITUD_NOMBRE:
        base, punto, ext = texto.rpartition(".")
        if punto and len(ext) <= 10:
            texto = base[: MAX_LONGITUD_NOMBRE - len(ext) - 1] + "." + ext
        else:
            texto = texto[:MAX_LONGITUD_NOMBRE]
    return texto


def _extension(nombre_saneado: str) -> str:
    punto = nombre_saneado.rfind(".")
    return nombre_saneado[punto:].lower() if punto > 0 else ""


def detectar_content_type(cabecera: bytes) -> Optional[str]:
    for content_type, firma in FIRMAS:
        if cabecera.startswith(firma):
            return content_type
    return None


def leer_y_validar(
    archivo: BinaryIO,
    nombre: Optional[str],
    content_type_declarado: Optional[str] = None,
) -> ArchivoValidado:
    """Valida extensión, tipo declarado, tamaño y firma; devuelve el contenido listo para almacenar."""
    nombre_saneado = sanear_nombre(nombre)
    extension = _extension(nombre_saneado)
    if extension not in EXTENSIONES_PERMITIDAS:
        raise ArchivoError(
            "ARCHIVO_TIPO_NO_PERMITIDO",
            "Solo se permiten archivos PDF, JPG o PNG (extensiones .pdf, .jpg, .jpeg, .png).",
        )

    declarado = (content_type_declarado or "").split(";")[0].strip().lower()
    declarado = ALIAS_CONTENT_TYPE.get(declarado, declarado)
    if declarado not in CONTENT_TYPES_GENERICOS and declarado not in set(EXTENSIONES_PERMITIDAS.values()):
        raise ArchivoError(
            "ARCHIVO_TIPO_NO_PERMITIDO",
            "El tipo de contenido declarado no es PDF, JPG ni PNG.",
        )

    bloques = []
    total = 0
    while True:
        bloque = archivo.read(TAMANO_BLOQUE)
        if not bloque:
            break
        total += len(bloque)
        if total > TAMANO_MAXIMO_BYTES:
            raise ArchivoError(
                "ARCHIVO_TAMANO_EXCEDIDO",
                "El archivo supera el tamaño máximo de 10 MB.",
            )
        bloques.append(bloque)
    if total == 0:
        raise ArchivoError("ARCHIVO_VACIO", "El archivo está vacío.")
    contenido = b"".join(bloques)

    detectado = detectar_content_type(contenido[:8])
    if detectado is None or detectado != EXTENSIONES_PERMITIDAS[extension]:
        raise ArchivoError(
            "ARCHIVO_FIRMA_INVALIDA",
            "El contenido del archivo no corresponde a su extensión.",
        )
    if declarado not in CONTENT_TYPES_GENERICOS and declarado != detectado:
        raise ArchivoError(
            "ARCHIVO_FIRMA_INVALIDA",
            "El tipo de contenido declarado no corresponde al contenido del archivo.",
        )

    return ArchivoValidado(
        contenido=contenido,
        content_type=detectado,
        extension=extension,
        sha256=hashlib.sha256(contenido).hexdigest(),
        tamano=total,
        nombre=nombre_saneado,
    )


def nombre_para_almacenamiento(id_clinica: int, extension: str) -> str:
    """Nombre generado por el sistema (``resultado-lab-<id_clinica>-<uuid>.<ext>``); nunca deriva del cliente."""
    return f"resultado-lab-{int(id_clinica)}-{uuid.uuid4().hex}{extension}"
