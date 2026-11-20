from datetime import date, datetime
from typing import List, Optional

from pydantic import BaseModel, Field, model_validator


class InscripcionEsperaCreate(BaseModel):
    """Payload de inscripcion. El paciente se resuelve de la sesion."""

    id_paciente: Optional[int] = Field(None, gt=0)
    id_medico: Optional[int] = Field(None, gt=0)
    id_especialidad: Optional[int] = Field(None, gt=0)
    fecha_deseada: Optional[date] = None
    prioridad: int = Field(0, ge=0, le=5)
    motivo: Optional[str] = Field(None, max_length=500)

    @model_validator(mode="after")
    def _al_menos_uno(self):
        if self.id_medico is None and self.id_especialidad is None:
            raise ValueError("Debes indicar id_medico o id_especialidad")
        return self


class OfrecerTurnoCommand(BaseModel):
    """Oferta manual de un cupo liberado por parte del staff."""

    fecha: date
    hora_inicio: str = Field(..., pattern=r"^\d{2}:\d{2}(:\d{2})?$")
    hora_fin: Optional[str] = Field(None, pattern=r"^\d{2}:\d{2}(:\d{2})?$")
    id_medico: Optional[int] = Field(None, gt=0)


class InscripcionEsperaResponse(BaseModel):
    id_lista_espera: int
    id_paciente: int
    paciente_nombre: str
    id_medico: Optional[int] = None
    medico_nombre: Optional[str] = None
    id_especialidad: Optional[int] = None
    especialidad_nombre: Optional[str] = None
    fecha_deseada: Optional[str] = None
    estado: str
    prioridad: int
    posicion: int
    motivo: Optional[str] = None
    id_cita_ofrecida: Optional[int] = None
    fecha_creacion: Optional[datetime] = None


class ListaEsperaPageResponse(BaseModel):
    total: int
    page: int
    page_size: int
    items: List[InscripcionEsperaResponse]
