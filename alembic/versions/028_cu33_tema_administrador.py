"""Separa la apariencia personal de los datos institucionales."""

from alembic import op
import sqlalchemy as sa

revision = "cu33_tema_administrador_028"
down_revision = "cu33_catalogo_servicios_027"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "temas_administradores",
        sa.Column("id_usuario", sa.BigInteger(), sa.ForeignKey("usuarios.id_usuario", ondelete="CASCADE"), primary_key=True),
        sa.Column("id_clinica", sa.BigInteger(), sa.ForeignKey("clinicas.id_clinica", ondelete="CASCADE"), primary_key=True),
        sa.Column("color_principal", sa.String(7), nullable=False),
        sa.Column("color_secundario", sa.String(7), nullable=False),
    )
    op.create_index("ix_temas_administradores_id_clinica", "temas_administradores", ["id_clinica"])


def downgrade():
    op.drop_table("temas_administradores")
