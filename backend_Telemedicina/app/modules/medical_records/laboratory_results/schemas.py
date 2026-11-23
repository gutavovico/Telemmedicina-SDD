"""Esquemas Pydantic v2 de CU11 (contrato ``openspec/contracts/resultados-laboratorio.md`` sección 2).

Ningún esquema de entrada acepta ``id_clinica`` ni ``tenant_id``: los modelos de entrada usan
``extra="forbid"`` y cualquier campo de clínica en el cuerpo responde ``422``.
"""
from datetime import date, datetime
from typing import Any, Dict, List, Literal, Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

EstadoResultado = Literal["INCORPORADO", "PENDIENTE_REVISION", "ANULADO"]
OrigenResultado = Literal["MANUAL", "SINCRONIZADO"]


class ResultadoLaboratorioResumen(BaseModel):
    """Elemento de listado: sin ``observaciones`` ni ``datos_correspondencia``."""

    id_resultado: int
    id_clinica: int
    estado: EstadoResultado
    origen: OrigenResultado
    id_paciente: Optional[int] = None
    paciente_nombre: Optional[str] = None
    id_orden: Optional[int] = None
    id_examen: Optional[int] = None
    codigo_examen: str
    nombre_examen: Optional[str] = None
    laboratorio_origen: str
    fecha_realizacion: date
    nombre_archivo: str
    content_type: str
    tamano_bytes: int
    hash_archivo: Optional[str] = None
    id_documento: Optional[int] = None
    id_fuente: Optional[int] = None
    fuente_codigo: Optional[str] = None
    id_externo: Optional[str] = None
    id_sincronizacion: Optional[int] = None
    motivo_pendiente: Optional[str] = None
    registrado_por: Optional[int] = None
    registrado_por_nombre: Optional[str] = None
    proceso: Optional[str] = None
    registrado_en: Optional[datetime] = None
    resuelto_por: Optional[int] = None
    resuelto_en: Optional[datetime] = None
    motivo_resolucion: Optional[str] = None


class ResultadoLaboratorioResponse(ResultadoLaboratorioResumen):
    """Detalle completo (``ResultadoLaboratorio`` del contrato)."""

    observaciones: Optional[str] = None
    datos_correspondencia: Optional[Dict[str, Any]] = None


class ResultadoLaboratorioListResponse(BaseModel):
    items: List[ResultadoLaboratorioResumen]
    total: int
    page: int
    page_size: int
    total_pages: int


class ResolverPendienteRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    accion: Literal["ASIGNAR", "DESCARTAR"]
    id_paciente: Optional[int] = Field(None, ge=1)
    codigo_examen: Optional[str] = Field(None, min_length=1, max_length=50)
    id_orden: Optional[int] = Field(None, ge=1)
    motivo: Optional[str] = Field(None, min_length=3, max_length=500)

    @field_validator("codigo_examen", "motivo")
    @classmethod
    def _recortar(cls, valor: Optional[str]) -> Optional[str]:
        return valor.strip() if isinstance(valor, str) else valor

    @model_validator(mode="after")
    def _campos_segun_accion(self):
        if self.accion == "ASIGNAR":
            if self.id_paciente is None or not self.codigo_examen:
                raise ValueError("ASIGNAR requiere id_paciente y codigo_examen.")
        else:
            if not self.motivo or len(self.motivo) < 3:
                raise ValueError("DESCARTAR requiere un motivo de 3 a 500 caracteres.")
        return self


class AnularResultadoRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    motivo: str = Field(..., min_length=3, max_length=500)

    @field_validator("motivo")
    @classmethod
    def _recortar(cls, valor: str) -> str:
        valor = valor.strip()
        if len(valor) < 3:
            raise ValueError("El motivo debe tener al menos 3 caracteres.")
        return valor
