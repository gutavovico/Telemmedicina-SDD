"""Configuración institucional. Sin asignaciones sobre el catálogo histórico."""
from alembic import op
import sqlalchemy as sa

revision = "cu33_configuracion_025"
down_revision = "cu36_billing_overages_024"
branch_labels = None
depends_on = None


def upgrade():
    for name in ("color_principal", "color_secundario"):
        op.add_column("clinicas", sa.Column(name, sa.String(7)))
    op.add_column("clinicas", sa.Column("direccion_acceso", sa.String(253)))
    op.create_unique_constraint("uq_clinicas_direccion_acceso", "clinicas", ["direccion_acceso"])
    op.create_table("sedes",
        sa.Column("id", sa.BigInteger, primary_key=True),
        sa.Column("id_clinica", sa.BigInteger, sa.ForeignKey("clinicas.id_clinica"), nullable=False),
        sa.Column("nombre", sa.String(150), nullable=False),
        sa.Column("ubicacion", sa.String(250), nullable=False),
        sa.Column("activa", sa.Boolean, nullable=False))
    op.create_index("ix_sedes_id_clinica", "sedes", ["id_clinica"])
    op.create_table("horarios_sede",
        sa.Column("id", sa.BigInteger, primary_key=True),
        sa.Column("id_sede", sa.BigInteger, sa.ForeignKey("sedes.id"), nullable=False),
        sa.Column("dia", sa.Integer, nullable=False),
        sa.Column("apertura", sa.Time, nullable=False),
        sa.Column("cierre", sa.Time, nullable=False),
        sa.CheckConstraint("dia BETWEEN 1 AND 7 AND apertura < cierre", name="ck_horarios_sede_intervalo"))
    # Native range operator classes avoid requiring the btree_gist extension.
    # Single-point ranges represent equality for the site and weekday.
    op.execute("""
        ALTER TABLE horarios_sede ADD CONSTRAINT ex_horarios_sede_solapamiento
        EXCLUDE USING gist (
            int8range(id_sede, id_sede, '[]') WITH &&,
            int4range(dia, dia, '[]') WITH &&,
            numrange(extract(epoch FROM apertura), extract(epoch FROM cierre), '[)') WITH &&
        )
    """)
    op.create_index("ix_horarios_sede_dia", "horarios_sede", ["id_sede", "dia"])


def downgrade():
    op.drop_table("horarios_sede")
    op.drop_table("sedes")
    op.drop_constraint("uq_clinicas_direccion_acceso", "clinicas", type_="unique")
    for name in ("direccion_acceso", "color_secundario", "color_principal"):
        op.drop_column("clinicas", name)
