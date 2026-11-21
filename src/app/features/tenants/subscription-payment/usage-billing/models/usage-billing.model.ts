export type UsageResource = 'MEDICOS' | 'SEDES' | 'CONSULTAS';
export type NoticeType = 'UMBRAL' | 'LIMITE' | 'EXCEDENTE';
export type MeasurementState = 'LISTO' | 'MEDICION_NO_DISPONIBLE' | 'SIN_TARIFA' | 'ILIMITADO';
export type CycleState = 'ABIERTO' | 'CERRADO' | 'REVISION_REQUERIDA';
export type LiquidationState =
  | 'PENDIENTE_PAGO'
  | 'PAGADA'
  | 'REVISION_REQUERIDA'
  | 'ANULADA';
export type OverpaymentState = 'PENDIENTE' | 'PAGADO' | 'FALLIDO' | 'EXPIRADO';

export interface Page<T> {
  items: T[];
  total: number;
}

export interface PlanSummary {
  id_version_plan: number;
  plan_id: number;
  numero: number;
  nombre: string;
}

export interface UsageService {
  recurso: UsageResource;
  nombre: string;
  unidad: string;
  limite_incluido: string | null;
  consumo_validado: string | null;
  saldo_disponible: string | null;
  porcentaje_uso: string | null;
  unidades_excedidas: string | null;
  tarifa_excedente: string | null;
  subtotal_estimado: string | null;
  estado_medicion: MeasurementState;
}

export interface UsageCycle {
  id_ciclo: string;
  id_suscripcion: string;
  plan: PlanSummary;
  inicio: string;
  fin_exclusivo: string;
  moneda: 'BOB';
  estado: CycleState;
  actualizado_en: string;
  servicios: UsageService[];
  total_excedente_estimado: string;
  liquidacion_id: string | null;
}

export interface UsageNotice {
  id_aviso: string;
  id_ciclo: string;
  recurso: UsageResource;
  tipo: NoticeType;
  umbral_porcentaje: string | null;
  titulo: string;
  mensaje: string;
  creado_en: string;
  leido_en: string | null;
}

export interface LiquidationLine {
  recurso: UsageResource;
  unidad: string;
  consumo_validado: string;
  limite_aplicado: string;
  unidades_excedidas: string;
  tarifa_aplicada: string;
  subtotal: string;
  versiones_plan_consideradas: number[];
  regla: 'MAYOR_LIMITE_MENOR_TARIFA';
}

export interface OveragesLiquidation {
  id_liquidacion: string;
  id_ciclo: string;
  id_suscripcion: string;
  version: number;
  renglones: LiquidationLine[];
  total: string;
  moneda: 'BOB';
  estado: LiquidationState;
  emitida_en: string;
  pagada_en: string | null;
  motivo_revision: string | null;
  comprobante_disponible: boolean;
}

export interface OveragesPaymentAttempt {
  id_pago_excedente: string;
  id_liquidacion: string;
  estado: OverpaymentState;
  monto: string;
  moneda: 'BOB';
  checkout_url: string | null;
  expira_en: string | null;
  creado_en: string;
  confirmado_en: string | null;
}

export interface CreateOveragesCheckoutResponse {
  id_pago_excedente: string;
  id_liquidacion: string;
  monto: string;
  moneda: 'BOB';
  checkout_url: string;
  expira_en: string;
  estado: 'PENDIENTE';
}

export interface OveragesPaymentStatus {
  id_pago_excedente: string;
  id_liquidacion: string;
  estado_pago: OverpaymentState;
  estado_liquidacion: LiquidationState;
  confirmado_en: string | null;
  checkout_url: string | null;
}

export interface OveragesReceipt {
  id_liquidacion: string;
  id_pago_excedente: string;
  id_ciclo: string;
  fecha_pago: string;
  moneda: 'BOB';
  renglones: LiquidationLine[];
  total: string;
  referencia_stripe: string;
  documento_url: string | null;
}
