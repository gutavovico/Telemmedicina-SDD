"""CU36 usage cycles, immutable overage liquidations and Stripe attempts."""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = "cu36_billing_overages_024"
down_revision = "cu35_cu18_convergencia_023"
branch_labels = depends_on = None
JSON_TYPE = sa.JSON().with_variant(postgresql.JSONB(), "postgresql")


def upgrade():
    op.create_table(
        "ciclos_consumo",
        sa.Column("id_ciclo", sa.String(36), primary_key=True),
        sa.Column("id_clinica", sa.BigInteger(), sa.ForeignKey("clinicas.id_clinica", ondelete="RESTRICT"), nullable=False),
        sa.Column("id_suscripcion", sa.String(36), sa.ForeignKey("tenant_subscriptions.id_suscripcion", ondelete="RESTRICT"), nullable=False),
        sa.Column("inicio", sa.DateTime(timezone=True), nullable=False),
        sa.Column("fin_exclusivo", sa.DateTime(timezone=True), nullable=False),
        sa.Column("estado", sa.String(24), nullable=False, server_default="ABIERTO"),
        sa.Column("actualizado_en", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("cerrado_en", sa.DateTime(timezone=True)),
        sa.Column("consulta_ids", JSON_TYPE),
        sa.Column("medicos_activos_cierre", sa.Integer()),
        sa.Column("sedes_estado", sa.String(32), nullable=False, server_default="MEDICION_NO_DISPONIBLE"),
        sa.Column("plan_versiones", JSON_TYPE),
        sa.CheckConstraint("fin_exclusivo > inicio", name="ck_ciclo_consumo_intervalo"),
        sa.UniqueConstraint("id_clinica", "id_suscripcion", "inicio", "fin_exclusivo", name="uq_ciclo_consumo_intervalo"),
    )
    op.create_index("ix_ciclo_consumo_clinica_inicio", "ciclos_consumo", ["id_clinica", "inicio"])

    op.create_table(
        "fotografias_consumo",
        sa.Column("id_fotografia", sa.BigInteger().with_variant(sa.Integer, "sqlite"), primary_key=True, autoincrement=True),
        sa.Column("id_ciclo", sa.String(36), sa.ForeignKey("ciclos_consumo.id_ciclo", ondelete="CASCADE"), nullable=False),
        sa.Column("recurso", sa.String(20), nullable=False),
        sa.Column("tomada_en", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("cantidad", sa.Integer()),
        sa.Column("ids_observados", JSON_TYPE),
        sa.Column("tipo", sa.String(16), nullable=False, server_default="LECTURA"),
    )
    op.create_index("ix_fotografia_ciclo_recurso", "fotografias_consumo", ["id_ciclo", "recurso", "tomada_en"])

    op.create_table(
        "avisos_consumo",
        sa.Column("id_aviso", sa.String(36), primary_key=True),
        sa.Column("id_clinica", sa.BigInteger(), sa.ForeignKey("clinicas.id_clinica", ondelete="RESTRICT"), nullable=False),
        sa.Column("id_ciclo", sa.String(36), sa.ForeignKey("ciclos_consumo.id_ciclo", ondelete="CASCADE"), nullable=False),
        sa.Column("recurso", sa.String(20), nullable=False),
        sa.Column("tipo", sa.String(16), nullable=False),
        sa.Column("umbral_porcentaje", sa.Numeric(7, 2)),
        sa.Column("titulo", sa.String(160), nullable=False),
        sa.Column("mensaje", sa.Text(), nullable=False),
        sa.Column("creado_en", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("leido_en", sa.DateTime(timezone=True)),
        sa.UniqueConstraint("id_clinica", "id_ciclo", "recurso", "umbral_porcentaje", name="uq_aviso_consumo_umbral"),
    )
    op.create_index("ix_aviso_consumo_clinica_creado", "avisos_consumo", ["id_clinica", "creado_en"])

    op.create_table(
        "liquidaciones_excedentes",
        sa.Column("id_liquidacion", sa.String(36), primary_key=True),
        sa.Column("id_clinica", sa.BigInteger(), sa.ForeignKey("clinicas.id_clinica", ondelete="RESTRICT"), nullable=False),
        sa.Column("id_ciclo", sa.String(36), sa.ForeignKey("ciclos_consumo.id_ciclo", ondelete="RESTRICT"), nullable=False),
        sa.Column("id_suscripcion", sa.String(36), sa.ForeignKey("tenant_subscriptions.id_suscripcion", ondelete="RESTRICT"), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("total", sa.Numeric(14, 2), nullable=False),
        sa.Column("moneda", sa.String(3), nullable=False, server_default="BOB"),
        sa.Column("estado", sa.String(24), nullable=False, server_default="PENDIENTE_PAGO"),
        sa.Column("emitida_en", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("pagada_en", sa.DateTime(timezone=True)),
        sa.Column("motivo_revision", sa.Text()),
        sa.Column("referencia_stripe", sa.String(255)),
        sa.CheckConstraint("total > 0", name="ck_liquidacion_total_positivo"),
        sa.CheckConstraint("moneda = 'BOB'", name="ck_liquidacion_moneda_bob"),
        sa.UniqueConstraint("id_clinica", "id_ciclo", name="uq_liquidacion_clinica_ciclo"),
    )
    op.create_index("ix_liquidacion_clinica_emitida", "liquidaciones_excedentes", ["id_clinica", "emitida_en"])

    op.create_table(
        "renglones_liquidacion",
        sa.Column("id_renglon", sa.BigInteger().with_variant(sa.Integer, "sqlite"), primary_key=True, autoincrement=True),
        sa.Column("id_liquidacion", sa.String(36), sa.ForeignKey("liquidaciones_excedentes.id_liquidacion", ondelete="CASCADE"), nullable=False),
        sa.Column("recurso", sa.String(20), nullable=False),
        sa.Column("unidad", sa.String(32), nullable=False),
        sa.Column("consumo_validado", sa.Numeric(14, 3), nullable=False),
        sa.Column("limite_aplicado", sa.Numeric(14, 3), nullable=False),
        sa.Column("unidades_excedidas", sa.Numeric(14, 3), nullable=False),
        sa.Column("tarifa_aplicada", sa.Numeric(14, 4), nullable=False),
        sa.Column("subtotal", sa.Numeric(14, 2), nullable=False),
        sa.Column("versiones_plan_consideradas", JSON_TYPE, nullable=False),
        sa.Column("regla", sa.String(40), nullable=False, server_default="MAYOR_LIMITE_MENOR_TARIFA"),
        sa.CheckConstraint("unidades_excedidas > 0 AND subtotal > 0", name="ck_renglon_excedente_positivo"),
        sa.CheckConstraint("tarifa_aplicada >= 0", name="ck_renglon_tarifa_no_negativa"),
        sa.UniqueConstraint("id_liquidacion", "recurso", name="uq_renglon_liquidacion_recurso"),
    )

    op.create_table(
        "pagos_excedentes",
        sa.Column("id_pago_excedente", sa.String(36), primary_key=True),
        sa.Column("id_liquidacion", sa.String(36), sa.ForeignKey("liquidaciones_excedentes.id_liquidacion", ondelete="RESTRICT"), nullable=False),
        sa.Column("id_clinica", sa.BigInteger(), sa.ForeignKey("clinicas.id_clinica", ondelete="RESTRICT"), nullable=False),
        sa.Column("id_usuario", sa.BigInteger(), sa.ForeignKey("usuarios.id_usuario", ondelete="RESTRICT"), nullable=False),
        sa.Column("monto", sa.Numeric(14, 2), nullable=False),
        sa.Column("moneda", sa.String(3), nullable=False, server_default="BOB"),
        sa.Column("estado", sa.String(16), nullable=False, server_default="PENDIENTE"),
        sa.Column("client_idempotency_key", sa.String(64), nullable=False),
        sa.Column("stripe_idempotency_key", sa.String(255), nullable=False, unique=True),
        sa.Column("stripe_session_id", sa.String(255), unique=True),
        sa.Column("stripe_payment_intent_id", sa.String(255)),
        sa.Column("checkout_url", sa.String(1000)),
        sa.Column("expira_en", sa.DateTime(timezone=True)),
        sa.Column("creado_en", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("confirmado_en", sa.DateTime(timezone=True)),
        sa.CheckConstraint("monto > 0 AND moneda = 'BOB'", name="ck_pago_excedente_monto_bob"),
        sa.UniqueConstraint("id_clinica", "client_idempotency_key", name="uq_pago_excedente_cliente_key"),
    )
    op.create_index("ix_pago_excedente_clinica_creado", "pagos_excedentes", ["id_clinica", "creado_en"])

    op.create_table(
        "eventos_stripe_excedentes",
        sa.Column("id_evento", sa.String(255), primary_key=True),
        sa.Column("tipo", sa.String(100), nullable=False),
        sa.Column("procesado_en", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("resultado", sa.String(24), nullable=False),
        sa.Column("detalle", sa.Text()),
    )


def downgrade():
    op.drop_table("eventos_stripe_excedentes")
    op.drop_index("ix_pago_excedente_clinica_creado", table_name="pagos_excedentes")
    op.drop_table("pagos_excedentes")
    op.drop_table("renglones_liquidacion")
    op.drop_index("ix_liquidacion_clinica_emitida", table_name="liquidaciones_excedentes")
    op.drop_table("liquidaciones_excedentes")
    op.drop_index("ix_aviso_consumo_clinica_creado", table_name="avisos_consumo")
    op.drop_table("avisos_consumo")
    op.drop_index("ix_fotografia_ciclo_recurso", table_name="fotografias_consumo")
    op.drop_table("fotografias_consumo")
    op.drop_index("ix_ciclo_consumo_clinica_inicio", table_name="ciclos_consumo")
    op.drop_table("ciclos_consumo")
