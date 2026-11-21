import re
from datetime import time
from decimal import Decimal
from typing import Annotated, Literal
from urllib.parse import urlsplit

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

Color = Annotated[str, Field(pattern=r"^#[0-9a-fA-F]{6}$")]
LABEL = r"[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?"


class Entrada(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)


class Identidad(Entrada):
    principal: Color
    secundario: Color


class Direccion(Entrada):
    valor: str = Field(min_length=1, max_length=270)

    @field_validator("valor")
    @classmethod
    def normalizar(cls, value):
        if any(ord(ch) < 33 or ord(ch) > 126 for ch in value):
            raise ValueError("La dirección solo admite caracteres DNS y no puede contener espacios")
        value = value.lower()
        if re.fullmatch(LABEL, value):
            return value
        url = urlsplit(value)
        host = (url.hostname or "").removesuffix(".")
        if (url.scheme != "https" or url.netloc not in (host, host + ".", host + ":443")
                or url.path not in ("", "/") or "?" in value or "#" in value
                or len(host) > 253 or not re.fullmatch(rf"{LABEL}(?:\.{LABEL})+", host)
                or host.split(".")[-1].isdigit()):
            raise ValueError("Indique un subdominio o una URL HTTPS sin ruta ni credenciales")
        return host


class DatosSede(Entrada):
    nombre: str = Field(min_length=1, max_length=150)
    ubicacion: str = Field(min_length=1, max_length=250)


class Intervalo(Entrada):
    apertura: time
    cierre: time

    @model_validator(mode="after")
    def validar(self):
        if self.apertura.tzinfo or self.cierre.tzinfo or self.apertura >= self.cierre:
            raise ValueError("La apertura debe ser anterior al cierre en el mismo día local")
        return self


class Horarios(Entrada):
    intervalos: list[Intervalo]

    @field_validator("intervalos")
    @classmethod
    def ordenar(cls, value):
        orden = sorted(value, key=lambda i: i.apertura)
        if any(a.cierre > b.apertura for a, b in zip(orden, orden[1:])):
            raise ValueError("Los intervalos del día se superponen")
        return orden


class DatosServicio(Entrada):
    nombre: str = Field(min_length=1, max_length=100)
    modalidad: Literal["PRESENCIAL", "TELECONSULTA"]
    duracion_minutos: int = Field(gt=0, le=1440)
    hora_inicio: time
    hora_fin: time
    costo: Decimal = Field(ge=0, le=Decimal("99999999.99"), allow_inf_nan=False)

    @field_validator("costo")
    @classmethod
    def validar_precision(cls, value):
        if value.as_tuple().exponent < -2:
            raise ValueError("La tarifa admite hasta dos decimales")
        return value

    @model_validator(mode="after")
    def validar_franja(self):
        Intervalo(apertura=self.hora_inicio, cierre=self.hora_fin)
        return self
