"""CU36 immutable usage-cycle, overage liquidation and payment ledger."""
import uuid

from sqlalchemy import (
    BigInteger, CheckConstraint, Column, DateTime, ForeignKey, Index, Integer,
    JSON, Numeric, String, Text, UniqueConstraint, func,
)
from sqlalchemy.dialects.postgresql import JSONB

from app.core.database import Base


_JSON = JSONB().with_variant(JSON(), "sqlite")


class CicloConsumo(Base):
    __tablename__ = "ciclos_consumo"
    id_ciclo = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    id_clinica = Column(BigInteger, ForeignKey("clinicas.id_clinica", ondelete="RESTRICT"), nullable=False)
    id_suscripcion = Column(String(36), ForeignKey("tenant_subscriptions.id_suscripcion", ondelete="RESTRICT"), nullable=False)
    inicio = Column(DateTime(timezone=True), nullable=False)
    fin_exclusivo = Column(DateTime(timezone=True), nullable=False)
    estado = Column(String(24), nullable=False, default="ABIERTO", server_default="ABIERTO")
    actualizado_en = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    cerrado_en = Column(DateTime(timezone=True), nullable=True)
    consulta_ids = Column(_JSON, nullable=True)
    medicos_activos_cierre = Column(Integer, nullable=True)
    sedes_estado = Column(String(32), nullable=False, default="MEDICION_NO_DISPONIBLE", server_default="MEDICION_NO_DISPONIBLE")
    plan_versiones = Column(_JSON, nullable=True)
    __table_args__ = (
        UniqueConstraint("id_clinica", "id_suscripcion", "inicio", "fin_exclusivo", name="uq_ciclo_consumo_intervalo"),
        CheckConstraint("fin_exclusivo > inicio", name="ck_ciclo_consumo_intervalo"),
        Index("ix_ciclo_consumo_clinica_inicio", "id_clinica", "inicio"),
    )


class FotografiaConsumo(Base):
    __tablename__ = "fotografias_consumo"
    id_fotografia = Column(BigInteger().with_variant(Integer, "sqlite"), primary_key=True, autoincrement=True)
    id_ciclo = Column(String(36), ForeignKey("ciclos_consumo.id_ciclo", ondelete="CASCADE"), nullable=False)
    recurso = Column(String(20), nullable=False)
    tomada_en = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    cantidad = Column(Integer, nullable=True)
    ids_observados = Column(_JSON, nullable=True)
    tipo = Column(String(16), nullable=False, default="LECTURA", server_default="LECTURA")
    __table_args__ = (Index("ix_fotografia_ciclo_recurso", "id_ciclo", "recurso", "tomada_en"),)


class AvisoConsumo(Base):
    __tablename__ = "avisos_consumo"
    id_aviso = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    id_clinica = Column(BigInteger, ForeignKey("clinicas.id_clinica", ondelete="RESTRICT"), nullable=False)
    id_ciclo = Column(String(36), ForeignKey("ciclos_consumo.id_ciclo", ondelete="CASCADE"), nullable=False)
    recurso = Column(String(20), nullable=False)
    tipo = Column(String(16), nullable=False)
    umbral_porcentaje = Column(Numeric(7, 2), nullable=True)
    titulo = Column(String(160), nullable=False)
    mensaje = Column(Text, nullable=False)
    creado_en = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    leido_en = Column(DateTime(timezone=True), nullable=True)
    __table_args__ = (
        UniqueConstraint("id_clinica", "id_ciclo", "recurso", "umbral_porcentaje", name="uq_aviso_consumo_umbral"),
        Index("ix_aviso_consumo_clinica_creado", "id_clinica", "creado_en"),
    )


class LiquidacionExcedente(Base):
    __tablename__ = "liquidaciones_excedentes"
    id_liquidacion = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    id_clinica = Column(BigInteger, ForeignKey("clinicas.id_clinica", ondelete="RESTRICT"), nullable=False)
    id_ciclo = Column(String(36), ForeignKey("ciclos_consumo.id_ciclo", ondelete="RESTRICT"), nullable=False)
    id_suscripcion = Column(String(36), ForeignKey("tenant_subscriptions.id_suscripcion", ondelete="RESTRICT"), nullable=False)
    version = Column(Integer, nullable=False, default=1, server_default="1")
    total = Column(Numeric(14, 2), nullable=False)
    moneda = Column(String(3), nullable=False, default="BOB", server_default="BOB")
    estado = Column(String(24), nullable=False, default="PENDIENTE_PAGO", server_default="PENDIENTE_PAGO")
    emitida_en = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    pagada_en = Column(DateTime(timezone=True), nullable=True)
    motivo_revision = Column(Text, nullable=True)
    referencia_stripe = Column(String(255), nullable=True)
    __table_args__ = (
        UniqueConstraint("id_clinica", "id_ciclo", name="uq_liquidacion_clinica_ciclo"),
        CheckConstraint("total > 0", name="ck_liquidacion_total_positivo"),
        CheckConstraint("moneda = 'BOB'", name="ck_liquidacion_moneda_bob"),
        Index("ix_liquidacion_clinica_emitida", "id_clinica", "emitida_en"),
    )


class RenglonLiquidacion(Base):
    __tablename__ = "renglones_liquidacion"
    id_renglon = Column(BigInteger().with_variant(Integer, "sqlite"), primary_key=True, autoincrement=True)
    id_liquidacion = Column(String(36), ForeignKey("liquidaciones_excedentes.id_liquidacion", ondelete="CASCADE"), nullable=False)
    recurso = Column(String(20), nullable=False)
    unidad = Column(String(32), nullable=False)
    consumo_validado = Column(Numeric(14, 3), nullable=False)
    limite_aplicado = Column(Numeric(14, 3), nullable=False)
    unidades_excedidas = Column(Numeric(14, 3), nullable=False)
    tarifa_aplicada = Column(Numeric(14, 4), nullable=False)
    subtotal = Column(Numeric(14, 2), nullable=False)
    versiones_plan_consideradas = Column(_JSON, nullable=False)
    regla = Column(String(40), nullable=False, default="MAYOR_LIMITE_MENOR_TARIFA", server_default="MAYOR_LIMITE_MENOR_TARIFA")
    __table_args__ = (
        UniqueConstraint("id_liquidacion", "recurso", name="uq_renglon_liquidacion_recurso"),
        CheckConstraint("unidades_excedidas > 0 AND subtotal > 0", name="ck_renglon_excedente_positivo"),
        CheckConstraint("tarifa_aplicada >= 0", name="ck_renglon_tarifa_no_negativa"),
    )


class PagoExcedente(Base):
    __tablename__ = "pagos_excedentes"
    id_pago_excedente = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    id_liquidacion = Column(String(36), ForeignKey("liquidaciones_excedentes.id_liquidacion", ondelete="RESTRICT"), nullable=False)
    id_clinica = Column(BigInteger, ForeignKey("clinicas.id_clinica", ondelete="RESTRICT"), nullable=False)
    id_usuario = Column(BigInteger, ForeignKey("usuarios.id_usuario", ondelete="RESTRICT"), nullable=False)
    monto = Column(Numeric(14, 2), nullable=False)
    moneda = Column(String(3), nullable=False, default="BOB", server_default="BOB")
    estado = Column(String(16), nullable=False, default="PENDIENTE", server_default="PENDIENTE")
    client_idempotency_key = Column(String(64), nullable=False)
    stripe_idempotency_key = Column(String(255), nullable=False, unique=True)
    stripe_session_id = Column(String(255), nullable=True, unique=True)
    stripe_payment_intent_id = Column(String(255), nullable=True)
    checkout_url = Column(String(1000), nullable=True)
    expira_en = Column(DateTime(timezone=True), nullable=True)
    creado_en = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    confirmado_en = Column(DateTime(timezone=True), nullable=True)
    __table_args__ = (
        UniqueConstraint("id_clinica", "client_idempotency_key", name="uq_pago_excedente_cliente_key"),
        CheckConstraint("monto > 0 AND moneda = 'BOB'", name="ck_pago_excedente_monto_bob"),
        Index("ix_pago_excedente_clinica_creado", "id_clinica", "creado_en"),
    )


class EventoStripeExcedente(Base):
    __tablename__ = "eventos_stripe_excedentes"
    id_evento = Column(String(255), primary_key=True)
    tipo = Column(String(100), nullable=False)
    procesado_en = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    resultado = Column(String(24), nullable=False)
    detalle = Column(Text, nullable=True)
