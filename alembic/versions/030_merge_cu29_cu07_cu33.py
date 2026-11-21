"""Converge la rama CU29 con la rama CU07/CU33.

Esta revisión no modifica el esquema. Existe únicamente para que Alembic tenga
una única cabeza después de aplicar las dos ramas de migraciones que parten de
``cu36_billing_overages_024``.
"""

revision = "cu29_cu07_cu33_merge_030"
down_revision = ("cu29_vincular_medico_025", "cu07_cu33_merge_029")
branch_labels = None
depends_on = None


def upgrade():
    pass


def downgrade():
    pass
