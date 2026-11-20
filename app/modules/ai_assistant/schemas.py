"""Esquemas Pydantic v2 para el Asistente Inteligente de Tratamiento (CU18).

Alineados estrictamente con openspec/contracts/asistencia-tratamiento.md.
"""
from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field


class EvaluarTratamientoRequest(BaseModel):
    """Cuerpo opcional para solicitar reevaluación forzada."""
    model_config = ConfigDict(extra="forbid")

    forzar_recalculo: bool = Field(
        default=False,
        description="Si es True, ignora la caché de pre-evaluación de 10 minutos.",
    )


class MedicamentoAnalizadoDTO(BaseModel):
    model_config = ConfigDict(from_attributes=True, extra="forbid")

    id_medicamento: Optional[int] = Field(default=None, description="ID del catálogo de medicamentos si aplica")
    nombre: str = Field(..., description="Nombre comercial o genérico prescrito")
    principio_activo: str = Field(..., description="Principio activo normalizado")
    dosis: str = Field(..., description="Dosis prescrita")
    frecuencia: str = Field(..., description="Frecuencia de administración")
    via_administracion: Optional[str] = Field(default=None, description="Vía de administración")


class AlertaInteraccionDTO(BaseModel):
    model_config = ConfigDict(from_attributes=True, extra="forbid")

    id_alerta: Optional[int] = Field(default=None, description="Identificador único de la alerta persistida")
    principio_activo_1: str = Field(..., description="Primer principio activo")
    principio_activo_2: str = Field(..., description="Segundo principio activo")
    medicamento_1_nombre: str = Field(..., description="Nombre del primer medicamento")
    medicamento_2_nombre: str = Field(..., description="Nombre del segundo medicamento")
    severidad: str = Field(..., description="Nivel de severidad: LEVE | MODERADA | GRAVE")
    color_alerta: str = Field(..., description="Semáforo visual: ROJO | AMBAR | AZUL")
    mensaje_alerta: str = Field(..., description="Resumen clínico del riesgo")
    pauta_precaucion: str = Field(..., description="Recomendación preventiva o de monitoreo")


class RecomendacionTratamientoDTO(BaseModel):
    model_config = ConfigDict(from_attributes=True, extra="forbid")

    id_recomendacion: Optional[int] = Field(default=None, description="Identificador de la recomendación persistida")
    categoria: str = Field(
        ...,
        description="Categoría: HORARIO_ADMINISTRACION | ESTILO_VIDA | SIGNOS_ALARMA | NUTRICION_HIDRATACION | PRECAUCION_GENERAL",
    )
    titulo: str = Field(..., description="Título comprensible de la recomendación")
    detalle: str = Field(..., description="Explicación detallada orientativa")
    origen: str = Field(..., description="Fuente: IA_GENERATIVA | REGLA_PREDEFINIDA")


class EvaluacionTratamientoResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True, extra="forbid")

    id_evaluacion: Optional[int] = Field(default=None, description="ID de la evaluación persistida (null si sin tratamiento)")
    id_paciente: int = Field(..., description="ID del paciente evaluado")
    fecha_evaluacion: datetime = Field(..., description="Fecha y hora de la evaluación")
    estado_evaluacion: str = Field(
        ...,
        description="Estado: COMPLETADA | DEGRADADO_REGLAS_BASE | SIN_TRATAMIENTO_VIGENTE",
    )
    nivel_riesgo_global: str = Field(..., description="Riesgo consolidado: SIN_RIESGO | BAJO | MEDIO | ALTO")
    total_medicamentos_analizados: int = Field(..., ge=0)
    total_alertas_detectadas: int = Field(..., ge=0)
    resumen_ejecutivo: Optional[str] = Field(default=None, description="Resumen breve para el paciente")
    aviso_legal: str = Field(
        default="Esta asistencia inteligente apoya con alertas y sugerencias de autocuidado. No sustituye la valoración médica profesional ni modifica diagnósticos, dosis o prescripciones vigentes.",
        description="Aviso mandatorio RF-25",
    )
    medicamentos_analizados: List[MedicamentoAnalizadoDTO] = Field(default_factory=list)
    alertas: List[AlertaInteraccionDTO] = Field(default_factory=list)
    recomendaciones: List[RecomendacionTratamientoDTO] = Field(default_factory=list)


class EvaluacionResumenDTO(BaseModel):
    model_config = ConfigDict(from_attributes=True, extra="forbid")

    id_evaluacion: int
    id_paciente: int
    fecha_evaluacion: datetime
    estado_evaluacion: str
    nivel_riesgo_global: str
    total_medicamentos_analizados: int
    total_alertas_detectadas: int
    resumen_ejecutivo: Optional[str] = None


class HistorialEvaluacionResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    items: List[EvaluacionResumenDTO]
    total: int
    page: int
    limit: int
    total_paginas: int


class InteraccionCatalogoDTO(BaseModel):
    model_config = ConfigDict(from_attributes=True, extra="forbid")

    id_interaccion: int
    principio_activo_a: str
    principio_activo_b: str
    severidad: str
    mecanismo: Optional[str] = None
    descripcion_riesgo: str
    recomendacion_clinica: str
    estado: str


class CatalogoInteraccionesResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    items: List[InteraccionCatalogoDTO]
    total: int
    page: int
    limit: int
    total_paginas: int

