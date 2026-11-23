from datetime import datetime, timezone
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_serializer


class APIModel(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    @field_serializer("*", when_used="json")
    def utc_datetime_as_z(self, value):
        if isinstance(value, datetime):
            value = value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value.astimezone(timezone.utc)
            return value.isoformat().replace("+00:00", "Z")
        return value


class PlanResumen(APIModel):
    id_version_plan: int
    plan_id: int
    numero: int
    nombre: str


class ConsumoServicio(APIModel):
    recurso: Literal["MEDICOS", "SEDES", "CONSULTAS"]
    nombre: str
    unidad: str
    limite_incluido: str | None
    consumo_validado: str | None
    saldo_disponible: str | None
    porcentaje_uso: str | None
    unidades_excedidas: str | None
    tarifa_excedente: str | None
    subtotal_estimado: str | None
    estado_medicion: Literal["LISTO", "MEDICION_NO_DISPONIBLE", "SIN_TARIFA", "ILIMITADO"]


class ResumenCiclo(APIModel):
    id_ciclo: str
    id_suscripcion: str
    plan: PlanResumen
    inicio: datetime
    fin_exclusivo: datetime
    moneda: Literal["BOB"] = "BOB"
    estado: Literal["ABIERTO", "CERRADO", "REVISION_REQUERIDA"]
    actualizado_en: datetime
    servicios: list[ConsumoServicio]
    total_excedente_estimado: str
    liquidacion_id: str | None


class AvisoConsumo(APIModel):
    id_aviso: str
    id_ciclo: str
    recurso: str
    tipo: Literal["UMBRAL", "LIMITE", "EXCEDENTE"]
    umbral_porcentaje: str | None
    titulo: str
    mensaje: str
    creado_en: datetime
    leido_en: datetime | None


class AvisosPage(APIModel):
    items: list[AvisoConsumo]
    total: int


class RenglonLiquidacion(APIModel):
    recurso: str
    unidad: str
    consumo_validado: str
    limite_aplicado: str
    unidades_excedidas: str
    tarifa_aplicada: str
    subtotal: str
    versiones_plan_consideradas: list[int]
    regla: Literal["MAYOR_LIMITE_MENOR_TARIFA"] = "MAYOR_LIMITE_MENOR_TARIFA"


class LiquidacionExcedentes(APIModel):
    id_liquidacion: str
    id_ciclo: str
    id_suscripcion: str
    version: int
    renglones: list[RenglonLiquidacion]
    total: str
    moneda: Literal["BOB"] = "BOB"
    estado: Literal["PENDIENTE_PAGO", "PAGADA", "REVISION_REQUERIDA", "ANULADA"]
    emitida_en: datetime
    pagada_en: datetime | None
    motivo_revision: str | None
    comprobante_disponible: bool


class LiquidacionesPage(APIModel):
    items: list[LiquidacionExcedentes]
    total: int


class IntentoPagoExcedentes(APIModel):
    id_pago_excedente: str
    id_liquidacion: str
    estado: Literal["PENDIENTE", "PAGADO", "FALLIDO", "EXPIRADO"]
    monto: str
    moneda: Literal["BOB"] = "BOB"
    checkout_url: str | None
    expira_en: datetime | None
    creado_en: datetime
    confirmado_en: datetime | None


class PagosPage(APIModel):
    items: list[IntentoPagoExcedentes]
    total: int


class CheckoutExcedentes(APIModel):
    id_pago_excedente: str
    id_liquidacion: str
    monto: str
    moneda: Literal["BOB"] = "BOB"
    checkout_url: str
    expira_en: datetime
    estado: Literal["PENDIENTE"]


class EstadoPagoExcedentes(APIModel):
    id_pago_excedente: str
    id_liquidacion: str
    estado_pago: Literal["PENDIENTE", "PAGADO", "FALLIDO", "EXPIRADO"]
    estado_liquidacion: Literal["PENDIENTE_PAGO", "PAGADA", "REVISION_REQUERIDA", "ANULADA"]
    confirmado_en: datetime | None
    checkout_url: str | None


class ComprobanteExcedentes(APIModel):
    id_liquidacion: str
    id_pago_excedente: str
    id_ciclo: str
    fecha_pago: datetime
    moneda: Literal["BOB"] = "BOB"
    renglones: list[RenglonLiquidacion]
    total: str
    referencia_stripe: str
    documento_url: str | None = None


class IdempotencyKeyHeader(BaseModel):
    value: str = Field(min_length=16, max_length=64)
