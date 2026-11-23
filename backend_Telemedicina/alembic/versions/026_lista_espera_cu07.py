"""CU07 lista de espera: tabla, indices y permisos waitlist:*.

Aditiva y reversible: no altera tablas existentes. Crea `lista_espera` con
aislamiento por clinica y siembra de forma idempotente los permisos
`waitlist:read` y `waitlist:write` por nombre de rol (ADMIN, MEDICO,
RECEPCION, PACIENTE), siguiendo el patron de las migraciones 006, 017 y 025.

Revision ID: cu07_lista_espera_026
Revises: cu11_resultados_laboratorio_025
"""
from alembic import op
import sqlalchemy as sa

revision = "cu07_lista_espera_026"
down_revision = "cu11_resultados_laboratorio_025"
branch_labels = depends_on = None

_PK = sa.BigInteger().with_variant(sa.Integer, "sqlite")

PERMISOS_CU07 = [
    ("waitlist:read", "Consultar lista de espera y posicion", "waitlist", "read"),
    ("waitlist:write", "Inscribirse, salir y gestionar reasignaciones de lista de espera", "waitlist", "write"),
]

MATRIZ_ROLES_PERMISOS = {
    "ADMIN": ["waitlist:read", "waitlist:write"],
    "MEDICO": ["waitlist:read", "waitlist:write"],
    "RECEPCION": ["waitlist:read", "waitlist:write"],
    "PACIENTE": ["waitlist:read", "waitlist:write"],
}

ESTADOS = ("EN_ESPERA", "OFRECIDO", "CONFIRMADO", "RECHAZADO", "CANCELADO", "EXPIRADO")


def _lit(value):
    """Literal SQL de una constante de esta migracion (nunca recibe entrada de usuario)."""
    return "'" + str(value).replace("'", "''") + "'"


def sembrar_permisos():
    """Inserta permisos y asignaciones solo si no existen (idempotente)."""
    for nombre, descripcion, modulo, accion in PERMISOS_CU07:
        op.execute(
            "INSERT INTO permisos (nombre, descripcion, modulo, accion, estado) "
            f"SELECT {_lit(nombre)}, {_lit(descripcion)}, {_lit(modulo)}, {_lit(accion)}, 'ACTIVO' "
            f"WHERE NOT EXISTS (SELECT 1 FROM permisos WHERE nombre = {_lit(nombre)})"
        )
    for rol, permisos in MATRIZ_ROLES_PERMISOS.items():
        for nombre in permisos:
            op.execute(
                "INSERT INTO rol_permisos (id_rol, id_permiso) "
                "SELECT r.id_rol, p.id_permiso FROM roles r, permisos p "
                f"WHERE UPPER(r.nombre) = {_lit(rol)} AND p.nombre = {_lit(nombre)} "
                "AND NOT EXISTS (SELECT 1 FROM rol_permisos rp "
                "WHERE rp.id_rol = r.id_rol AND rp.id_permiso = p.id_permiso)"
            )


def retirar_permisos():
    nombres = ", ".join(_lit(p[0]) for p in PERMISOS_CU07)
    op.execute(
        "DELETE FROM rol_permisos WHERE id_permiso IN "
        f"(SELECT id_permiso FROM permisos WHERE nombre IN ({nombres}))"
    )
    op.execute(f"DELETE FROM permisos WHERE nombre IN ({nombres})")


def upgrade():
    op.create_table(
        "lista_espera",
        sa.Column("id_lista_espera", _PK, primary_key=True, autoincrement=True),
        sa.Column("id_clinica", sa.BigInteger(), sa.ForeignKey("clinicas.id_clinica", ondelete="CASCADE"), nullable=False),
        sa.Column("id_paciente", sa.BigInteger(), sa.ForeignKey("pacientes.id_paciente", ondelete="CASCADE"), nullable=False),
        sa.Column("id_medico", sa.BigInteger(), sa.ForeignKey("medicos.id_medico", ondelete="SET NULL"), nullable=True),
        sa.Column(
            "id_especialidad",
            sa.BigInteger(),
            sa.ForeignKey("especialidades.id_especialidad", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("fecha_deseada", sa.Date(), nullable=True),
        sa.Column("estado", sa.String(20), nullable=False, server_default="EN_ESPERA"),
        sa.Column("prioridad", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("motivo", sa.Text(), nullable=True),
        sa.Column("id_cita_ofrecida", sa.BigInteger(), sa.ForeignKey("citas.id_cita", ondelete="SET NULL"), nullable=True),
        sa.Column("fecha_ofrecimiento", sa.DateTime(timezone=True), nullable=True),
        sa.Column("fecha_respuesta", sa.DateTime(timezone=True), nullable=True),
        sa.Column("fecha_creacion", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.CheckConstraint(
            "estado IN ('EN_ESPERA', 'OFRECIDO', 'CONFIRMADO', 'RECHAZADO', 'CANCELADO', 'EXPIRADO')",
            name="ck_lista_espera_estado",
        ),
        sa.CheckConstraint("prioridad >= 0 AND prioridad <= 5", name="ck_lista_espera_prioridad"),
    )
    op.create_index("ix_lista_espera_id_clinica", "lista_espera", ["id_clinica"])
    op.create_index("ix_lista_espera_id_paciente", "lista_espera", ["id_paciente"])
    op.create_index("ix_lista_espera_id_medico", "lista_espera", ["id_medico"])
    op.create_index("ix_lista_espera_id_especialidad", "lista_espera", ["id_especialidad"])
    op.create_index("ix_lista_espera_estado", "lista_espera", ["estado"])
    op.create_index("ix_lista_espera_fecha_deseada", "lista_espera", ["fecha_deseada"])
    op.create_index("ix_lista_espera_clinica_estado", "lista_espera", ["id_clinica", "estado"])

    sembrar_permisos()


def downgrade():
    retirar_permisos()
    op.drop_index("ix_lista_espera_clinica_estado", table_name="lista_espera")
    op.drop_index("ix_lista_espera_fecha_deseada", table_name="lista_espera")
    op.drop_index("ix_lista_espera_estado", table_name="lista_espera")
    op.drop_index("ix_lista_espera_id_especialidad", table_name="lista_espera")
    op.drop_index("ix_lista_espera_id_medico", table_name="lista_espera")
    op.drop_index("ix_lista_espera_id_paciente", table_name="lista_espera")
    op.drop_index("ix_lista_espera_id_clinica", table_name="lista_espera")
    op.drop_table("lista_espera")
