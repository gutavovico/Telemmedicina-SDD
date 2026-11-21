"""CU29: vinculación de médicos con entidades.

Revision ID: cu29_vincular_medico_025
Revises: cu36_billing_overages_024

Crea el modelo de participación multi-entidad sin retirar las columnas legacy
(`Usuario.id_clinica`, `Usuario.id_rol`, `Medico.id_clinica`). El backfill es
idempotente: cada perfil médico con clínica genera un vínculo ACTIVO una sola
vez y conserva las asignaciones heredadas.
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = "cu29_vincular_medico_025"
down_revision = "cu36_billing_overages_024"
branch_labels = depends_on = None

JSON_TYPE = sa.JSON().with_variant(postgresql.JSONB(), "postgresql")
BIGINT_PK = sa.BigInteger().with_variant(sa.Integer, "sqlite")


def _abortar_si_matriculas_duplicadas(bind) -> None:
    duplicadas = bind.execute(
        sa.text(
            """
            SELECT matricula_profesional, COUNT(*) AS total
            FROM medicos
            GROUP BY matricula_profesional
            HAVING COUNT(*) > 1
            ORDER BY matricula_profesional
            """
        )
    ).fetchall()
    if duplicadas:
        detalle = ", ".join(f"{fila[0]} ({fila[1]})" for fila in duplicadas)
        raise RuntimeError(
            "CU29 abortado: existen matrículas profesionales repetidas entre "
            f"entidades y no es posible establecer la unicidad global: {detalle}. "
            "Resuelva los duplicados y vuelva a ejecutar la migración."
        )


def _cambiar_unicidad_matricula(bind, global_unica: bool) -> None:
    dialecto = bind.dialect.name
    if dialecto == "sqlite":
        with op.batch_alter_table("medicos", recreate="always") as batch:
            if global_unica:
                batch.drop_constraint("uq_medicos_clinica_matricula", type_="unique")
                batch.create_unique_constraint(
                    "uq_medicos_matricula_profesional", ["matricula_profesional"]
                )
            else:
                batch.drop_constraint("uq_medicos_matricula_profesional", type_="unique")
                batch.create_unique_constraint(
                    "uq_medicos_clinica_matricula",
                    ["id_clinica", "matricula_profesional"],
                )
        return

    if global_unica:
        op.drop_constraint("uq_medicos_clinica_matricula", "medicos", type_="unique")
        op.create_unique_constraint(
            "uq_medicos_matricula_profesional", "medicos", ["matricula_profesional"]
        )
    else:
        op.drop_constraint("uq_medicos_matricula_profesional", "medicos", type_="unique")
        op.create_unique_constraint(
            "uq_medicos_clinica_matricula",
            "medicos",
            ["id_clinica", "matricula_profesional"],
        )


def _backfill_vinculaciones(bind) -> None:
    """Genera vínculos ACTIVO idempotentes desde Medico.id_clinica."""
    bind.execute(
        sa.text(
            """
            INSERT INTO vinculaciones_medico_entidad (
                id_clinica, id_usuario, id_medico, estado, invitado_por,
                fecha_invitacion, respondido_en, fecha_estado, usuario_estado,
                row_version
            )
            SELECT m.id_clinica, m.id_usuario, m.id_medico, 'ACTIVO', m.id_usuario,
                   CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,
                   m.id_usuario, 1
            FROM medicos m
            WHERE m.id_clinica IS NOT NULL
              AND NOT EXISTS (
                  SELECT 1 FROM vinculaciones_medico_entidad v
                  WHERE v.id_clinica = m.id_clinica
                    AND v.id_usuario = m.id_usuario
              )
            """
        )
    )

    # Rol principal heredado (global o de la misma entidad). Sin rol no se
    # inventa una asignación: el vínculo queda a la espera de CU29.
    bind.execute(
        sa.text(
            """
            INSERT INTO vinculacion_medico_rol (id_vinculacion, id_rol, es_principal)
            SELECT v.id_vinculacion, u.id_rol, TRUE
            FROM vinculaciones_medico_entidad v
            JOIN usuarios u ON u.id_usuario = v.id_usuario
            JOIN roles r ON r.id_rol = u.id_rol
            WHERE u.id_rol IS NOT NULL
              AND v.estado = 'ACTIVO'
              AND (r.id_clinica IS NULL OR r.id_clinica = v.id_clinica)
              AND NOT EXISTS (
                  SELECT 1 FROM vinculacion_medico_rol vr
                  WHERE vr.id_vinculacion = v.id_vinculacion
              )
            """
        )
    )

    # Especialidades heredadas de CU04, solo para el vínculo compatible.
    bind.execute(
        sa.text(
            """
            INSERT INTO vinculacion_medico_especialidad (
                id_vinculacion, id_especialidad, es_principal
            )
            SELECT v.id_vinculacion, me.id_especialidad, me.es_principal
            FROM vinculaciones_medico_entidad v
            JOIN medicos m ON m.id_usuario = v.id_usuario
                          AND m.id_clinica = v.id_clinica
            JOIN medico_especialidad me ON me.id_medico = m.id_medico
            WHERE NOT EXISTS (
                SELECT 1 FROM vinculacion_medico_especialidad ve
                WHERE ve.id_vinculacion = v.id_vinculacion
                  AND ve.id_especialidad = me.id_especialidad
            )
            """
        )
    )


def upgrade() -> None:
    bind = op.get_bind()
    _abortar_si_matriculas_duplicadas(bind)

    op.add_column(
        "usuarios", sa.Column("documento_identidad", sa.String(length=30), nullable=True)
    )
    op.create_index(
        "uq_usuarios_documento_identidad",
        "usuarios",
        ["documento_identidad"],
        unique=True,
        postgresql_where=sa.text("documento_identidad IS NOT NULL"),
        sqlite_where=sa.text("documento_identidad IS NOT NULL"),
    )

    _cambiar_unicidad_matricula(bind, global_unica=True)

    op.create_table(
        "vinculaciones_medico_entidad",
        sa.Column("id_vinculacion", BIGINT_PK, primary_key=True, autoincrement=True),
        sa.Column(
            "id_clinica",
            sa.BigInteger(),
            sa.ForeignKey("clinicas.id_clinica", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column(
            "id_usuario",
            sa.BigInteger(),
            sa.ForeignKey("usuarios.id_usuario", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column(
            "id_medico",
            sa.BigInteger(),
            sa.ForeignKey("medicos.id_medico", ondelete="RESTRICT"),
            nullable=True,
        ),
        sa.Column("estado", sa.String(20), nullable=False, server_default="INVITADO"),
        sa.Column(
            "invitado_por",
            sa.BigInteger(),
            sa.ForeignKey("usuarios.id_usuario", ondelete="RESTRICT"),
            nullable=True,
        ),
        sa.Column(
            "fecha_invitacion",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column("respondido_en", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "fecha_estado",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "usuario_estado",
            sa.BigInteger(),
            sa.ForeignKey("usuarios.id_usuario", ondelete="RESTRICT"),
            nullable=True,
        ),
        sa.Column("motivo_estado", sa.Text(), nullable=True),
        sa.Column("row_version", sa.Integer(), nullable=False, server_default="1"),
        sa.CheckConstraint(
            "estado IN ('INVITADO','ACTIVO','SUSPENDIDO','RECHAZADO','BAJA')",
            name="ck_vinculacion_estado",
        ),
        sa.UniqueConstraint("id_clinica", "id_usuario", name="uq_vinculacion_clinica_usuario"),
        sa.UniqueConstraint("id_clinica", "id_medico", name="uq_vinculacion_clinica_medico"),
    )
    op.create_index(
        "ix_vinculacion_clinica_estado",
        "vinculaciones_medico_entidad",
        ["id_clinica", "estado"],
    )
    op.create_index(
        "ix_vinculaciones_medico_entidad_id_clinica",
        "vinculaciones_medico_entidad",
        ["id_clinica"],
    )
    op.create_index(
        "ix_vinculaciones_medico_entidad_id_usuario",
        "vinculaciones_medico_entidad",
        ["id_usuario"],
    )
    op.create_index(
        "ix_vinculaciones_medico_entidad_id_medico",
        "vinculaciones_medico_entidad",
        ["id_medico"],
    )

    op.create_table(
        "credenciales_temporarias_medico",
        sa.Column("id_credencial", BIGINT_PK, primary_key=True, autoincrement=True),
        sa.Column(
            "id_usuario",
            sa.BigInteger(),
            sa.ForeignKey("usuarios.id_usuario", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "id_vinculacion",
            sa.BigInteger(),
            sa.ForeignKey(
                "vinculaciones_medico_entidad.id_vinculacion", ondelete="CASCADE"
            ),
            nullable=False,
        ),
        sa.Column("expira_en", sa.DateTime(timezone=True), nullable=False),
        sa.Column("usada_en", sa.DateTime(timezone=True), nullable=True),
        sa.Column("cambiada_en", sa.DateTime(timezone=True), nullable=True),
        sa.Column("row_version", sa.Integer(), nullable=False, server_default="1"),
        sa.UniqueConstraint("id_usuario", name="uq_credencial_temporal_usuario"),
    )

    op.create_table(
        "vinculacion_medico_rol",
        sa.Column(
            "id_vinculacion",
            sa.BigInteger(),
            sa.ForeignKey(
                "vinculaciones_medico_entidad.id_vinculacion", ondelete="CASCADE"
            ),
            primary_key=True,
        ),
        sa.Column(
            "id_rol",
            sa.BigInteger(),
            sa.ForeignKey("roles.id_rol", ondelete="RESTRICT"),
            primary_key=True,
        ),
        sa.Column("es_principal", sa.Boolean(), nullable=False, server_default=sa.text("FALSE")),
    )
    op.create_index(
        "uq_vinculacion_medico_rol_principal",
        "vinculacion_medico_rol",
        ["id_vinculacion"],
        unique=True,
        postgresql_where=sa.text("es_principal = TRUE"),
        sqlite_where=sa.text("es_principal = 1"),
    )

    op.create_table(
        "vinculacion_medico_especialidad",
        sa.Column(
            "id_vinculacion",
            sa.BigInteger(),
            sa.ForeignKey(
                "vinculaciones_medico_entidad.id_vinculacion", ondelete="CASCADE"
            ),
            primary_key=True,
        ),
        sa.Column(
            "id_especialidad",
            sa.BigInteger(),
            sa.ForeignKey("especialidades.id_especialidad", ondelete="RESTRICT"),
            primary_key=True,
        ),
        sa.Column("es_principal", sa.Boolean(), nullable=False, server_default=sa.text("FALSE")),
    )
    op.create_index(
        "uq_vinculacion_medico_especialidad_principal",
        "vinculacion_medico_especialidad",
        ["id_vinculacion"],
        unique=True,
        postgresql_where=sa.text("es_principal = TRUE"),
        sqlite_where=sa.text("es_principal = 1"),
    )

    op.create_table(
        "historial_vinculaciones_medico",
        sa.Column("id_historial", BIGINT_PK, primary_key=True, autoincrement=True),
        sa.Column(
            "id_vinculacion",
            sa.BigInteger(),
            sa.ForeignKey(
                "vinculaciones_medico_entidad.id_vinculacion", ondelete="RESTRICT"
            ),
            nullable=False,
        ),
        sa.Column("tipo_evento", sa.String(30), nullable=False),
        sa.Column("estado_anterior", sa.String(20), nullable=True),
        sa.Column("estado_nuevo", sa.String(20), nullable=True),
        sa.Column(
            "id_usuario_actor",
            sa.BigInteger(),
            sa.ForeignKey("usuarios.id_usuario", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column("motivo", sa.Text(), nullable=True),
        sa.Column("datos", JSON_TYPE, nullable=False, server_default=sa.text("'{}'")),
        sa.Column(
            "fecha_cambio",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.CheckConstraint(
            "tipo_evento IN ('CREACION','RESPUESTA_INVITACION','ASIGNACIONES','CAMBIO_ESTADO')",
            name="ck_historial_vinculacion_tipo",
        ),
    )
    op.create_index(
        "ix_historial_vinculaciones_medico_id_vinculacion",
        "historial_vinculaciones_medico",
        ["id_vinculacion"],
    )

    _backfill_vinculaciones(bind)


def downgrade() -> None:
    bind = op.get_bind()

    historial = bind.execute(
        sa.text("SELECT COUNT(*) FROM historial_vinculaciones_medico")
    ).scalar()
    no_respaldados = bind.execute(
        sa.text(
            """
            SELECT COUNT(*)
            FROM vinculaciones_medico_entidad v
            WHERE v.estado <> 'ACTIVO'
               OR v.respondido_en IS NULL
               OR NOT EXISTS (
                   SELECT 1 FROM medicos m
                   WHERE m.id_usuario = v.id_usuario
                     AND m.id_clinica = v.id_clinica
                     AND m.id_medico = v.id_medico
               )
            """
        )
    ).scalar()
    if historial or no_respaldados:
        raise RuntimeError(
            "CU29 downgrade abortado: existen vínculos con historial o datos "
            "posteriores al backfill. Exporte/archive la trazabilidad de "
            "vinculaciones antes de degradar; no se elimina historial clínico."
        )

    op.drop_index(
        "ix_historial_vinculaciones_medico_id_vinculacion",
        table_name="historial_vinculaciones_medico",
    )
    op.drop_table("historial_vinculaciones_medico")
    op.drop_index(
        "uq_vinculacion_medico_especialidad_principal",
        table_name="vinculacion_medico_especialidad",
    )
    op.drop_table("vinculacion_medico_especialidad")
    op.drop_index(
        "uq_vinculacion_medico_rol_principal", table_name="vinculacion_medico_rol"
    )
    op.drop_table("vinculacion_medico_rol")
    op.drop_table("credenciales_temporarias_medico")
    op.drop_index(
        "ix_vinculaciones_medico_entidad_id_medico",
        table_name="vinculaciones_medico_entidad",
    )
    op.drop_index(
        "ix_vinculaciones_medico_entidad_id_usuario",
        table_name="vinculaciones_medico_entidad",
    )
    op.drop_index(
        "ix_vinculaciones_medico_entidad_id_clinica",
        table_name="vinculaciones_medico_entidad",
    )
    op.drop_index(
        "ix_vinculacion_clinica_estado", table_name="vinculaciones_medico_entidad"
    )
    op.drop_table("vinculaciones_medico_entidad")

    _cambiar_unicidad_matricula(bind, global_unica=False)

    op.drop_index("uq_usuarios_documento_identidad", table_name="usuarios")
    op.drop_column("usuarios", "documento_identidad")
