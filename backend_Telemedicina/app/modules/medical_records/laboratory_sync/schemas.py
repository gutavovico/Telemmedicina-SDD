"""Esquemas Pydantic v2 de fuentes y sincronizaciones (contrato ``resultados-laboratorio.md`` 2.6 a 2.8).

Ningún esquema de entrada acepta ``id_clinica`` ni ``tenant_id``: los cuerpos JSON usan ``extra="forbid"``
(422 en forma de lista de FastAPI) y el manifiesto se revisa aparte (422 ``LOTE_INVALIDO``).
"""
import re
from datetime import date, datetime
from typing import List, Literal, Optional

from pydantic import BaseModel, ConfigDict, Field, StringConstraints, field_validator, model_validator
from typing_extensions import Annotated

MAX_ITEMS_POR_LOTE = 50

_CODIGO_FUENTE = re.compile(r"^[A-Z0-9_-]+$")


def _normalizar_codigo(valor):
    return valor.strip().upper() if isinstance(valor, str) else valor


def _validar_formato_codigo(valor: str) -> str:
    if not _CODIGO_FUENTE.match(valor):
        raise ValueError("El código solo admite letras, dígitos, guion y guion bajo.")
    return valor


# --------------------------------------------------------------------------- #
# Fuentes (2.6)
# --------------------------------------------------------------------------- #
class FuenteLaboratorioCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    codigo: str = Field(..., min_length=2, max_length=50)
    nombre: str = Field(..., min_length=3, max_length=200)

    @field_validator("codigo", mode="before")
    @classmethod
    def _codigo_antes(cls, valor):
        return _normalizar_codigo(valor)

    @field_validator("codigo")
    @classmethod
    def _codigo_despues(cls, valor: str) -> str:
        return _validar_formato_codigo(valor)

    @field_validator("nombre", mode="before")
    @classmethod
    def _nombre_antes(cls, valor):
        return valor.strip() if isinstance(valor, str) else valor


class FuenteLaboratorioUpdateRequest(BaseModel):
    """El código no se modifica (``extra="forbid"`` rechaza ``codigo`` e ``id_clinica``)."""

    model_config = ConfigDict(extra="forbid")

    nombre: Optional[str] = Field(None, min_length=3, max_length=200)
    activa: Optional[Literal["SI", "NO"]] = None

    @field_validator("nombre", mode="before")
    @classmethod
    def _nombre_antes(cls, valor):
        return valor.strip() if isinstance(valor, str) else valor

    @model_validator(mode="after")
    def _al_menos_un_campo(self):
        if self.nombre is None and self.activa is None:
            raise ValueError("Indique al menos un campo a modificar: nombre o activa.")
        return self


class FuenteLaboratorioResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id_fuente: int
    codigo: str
    nombre: str
    activa: Literal["SI", "NO"]
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None


class FuenteLaboratorioListResponse(BaseModel):
    items: List[FuenteLaboratorioResponse]
    total: int
    page: int
    page_size: int
    total_pages: int


# --------------------------------------------------------------------------- #
# Manifiesto de lote (2.7)
# --------------------------------------------------------------------------- #
def _texto(minimo: int, maximo: int):
    return Annotated[str, StringConstraints(strip_whitespace=True, min_length=minimo, max_length=maximo)]


class ItemManifiesto(BaseModel):
    """Un ítem del lote. Los campos desconocidos se ignoran; ``id_clinica``/``tenant_id`` se rechazan antes."""

    model_config = ConfigDict(extra="ignore")

    id_externo: _texto(1, 100)
    ci: _texto(1, 20)
    complemento: Optional[Annotated[str, StringConstraints(strip_whitespace=True, max_length=10)]] = None
    codigo_examen: _texto(1, 50)
    laboratorio_origen: _texto(1, 200)
    fecha_realizacion: date
    nombre_archivo: _texto(1, 255)
    id_orden: Optional[int] = Field(None, ge=1)
    observaciones: Optional[str] = Field(None, max_length=2000)


class Manifiesto(BaseModel):
    model_config = ConfigDict(extra="ignore")

    fuente: str = Field(..., min_length=2, max_length=50)
    items: List[ItemManifiesto] = Field(..., min_length=1, max_length=MAX_ITEMS_POR_LOTE)

    @field_validator("fuente", mode="before")
    @classmethod
    def _fuente_antes(cls, valor):
        return _normalizar_codigo(valor)


# --------------------------------------------------------------------------- #
# Sincronizaciones (2.8)
# --------------------------------------------------------------------------- #
ResultadoItem = Literal["INCORPORADO", "PENDIENTE_REVISION", "DUPLICADO", "ERROR"]
EstadoSincronizacion = Literal["EN_PROCESO", "COMPLETADA", "COMPLETADA_CON_ERRORES", "FALLIDA"]


class ItemSincronizacionResponse(BaseModel):
    id_externo: str
    resultado: ResultadoItem
    id_resultado: Optional[int] = None
    codigo_error: Optional[str] = None
    detalle: Optional[str] = None
    intento: int


class SincronizacionResumenResponse(BaseModel):
    """Cabecera de una sincronización (listado: sin ``items``)."""

    id_sincronizacion: int
    id_fuente: int
    fuente_codigo: Optional[str] = None
    tipo: str
    estado: EstadoSincronizacion
    total_items: int
    incorporados: int
    pendientes: int
    duplicados: int
    con_error: int
    reintentos: int
    id_usuario: Optional[int] = None
    proceso: Optional[str] = None
    iniciado_en: Optional[datetime] = None
    finalizado_en: Optional[datetime] = None


class SincronizacionResponse(SincronizacionResumenResponse):
    items: List[ItemSincronizacionResponse]


class SincronizacionListResponse(BaseModel):
    items: List[SincronizacionResumenResponse]
    total: int
    page: int
    page_size: int
    total_pages: int
