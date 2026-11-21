/**
 * Modelos TypeScript para el Asistente Inteligente de Tratamiento (CU18).
 *
 * Alineados estrictamente a openspec/contracts/asistencia-tratamiento.md y RF-25.
 * Prohibido el uso de `any`.
 */

export interface EvaluarTratamientoRequest {
  forzar_recalculo?: boolean;
}

export interface MedicamentoAnalizadoDTO {
  id_medicamento?: number | null;
  nombre: string;
  principio_activo: string;
  dosis: string;
  frecuencia: string;
  via_administracion?: string | null;
}

export type SeveridadAlerta = 'GRAVE' | 'MODERADA' | 'LEVE' | string;
export type ColorAlerta = 'ROJO' | 'AMBAR' | 'AZUL' | string;

export interface AlertaInteraccionDTO {
  id_alerta?: number | null;
  principio_activo_1: string;
  principio_activo_2: string;
  medicamento_1_nombre: string;
  medicamento_2_nombre: string;
  severidad: SeveridadAlerta;
  color_alerta: ColorAlerta;
  mensaje_alerta: string;
  pauta_precaucion: string;
}

export type CategoriaRecomendacion =
  | 'HORARIO_ADMINISTRACION'
  | 'ESTILO_VIDA'
  | 'SIGNOS_ALARMA'
  | 'NUTRICION_HIDRATACION'
  | 'PRECAUCION_GENERAL'
  | string;

export type OrigenRecomendacion = 'IA_GENERATIVA' | 'REGLA_PREDEFINIDA' | string;

export interface RecomendacionTratamientoDTO {
  id_recomendacion?: number | null;
  categoria: CategoriaRecomendacion;
  titulo: string;
  detalle: string;
  origen: OrigenRecomendacion;
}

export type EstadoEvaluacion =
  | 'COMPLETADA'
  | 'DEGRADADO_REGLAS_BASE'
  | 'SIN_TRATAMIENTO_VIGENTE'
  | string;

export type NivelRiesgoGlobal = 'SIN_RIESGO' | 'BAJO' | 'MEDIO' | 'ALTO' | string;

export interface EvaluacionTratamientoResponse {
  id_evaluacion: number | null;
  id_paciente: number;
  fecha_evaluacion: string;
  estado_evaluacion: EstadoEvaluacion;
  nivel_riesgo_global: NivelRiesgoGlobal;
  total_medicamentos_analizados: number;
  total_alertas_detectadas: number;
  resumen_ejecutivo?: string | null;
  aviso_legal: string;
  medicamentos_analizados: MedicamentoAnalizadoDTO[];
  alertas: AlertaInteraccionDTO[];
  recomendaciones: RecomendacionTratamientoDTO[];
}

export interface EvaluacionResumenDTO {
  id_evaluacion: number;
  id_paciente: number;
  fecha_evaluacion: string;
  estado_evaluacion: EstadoEvaluacion;
  nivel_riesgo_global: NivelRiesgoGlobal;
  total_medicamentos_analizados: number;
  total_alertas_detectadas: number;
  resumen_ejecutivo?: string | null;
}

export interface HistorialEvaluacionResponse {
  items: EvaluacionResumenDTO[];
  total: number;
  page: number;
  limit: number;
  total_paginas: number;
}

export interface InteraccionCatalogoDTO {
  id_interaccion: number;
  principio_activo_a: string;
  principio_activo_b: string;
  severidad: SeveridadAlerta;
  mecanismo?: string | null;
  descripcion_riesgo: string;
  recomendacion_clinica: string;
  estado: string;
}

export interface CatalogoInteraccionesResponse {
  items: InteraccionCatalogoDTO[];
  total: number;
  page: number;
  limit: number;
  total_paginas: number;
}

