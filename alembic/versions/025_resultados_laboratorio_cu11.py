"""CU11 resultados de laboratorio: tablas, restricciones y permisos lab_results:*.

Aditiva y reversible: no altera ninguna tabla existente. Crea fuentes_laboratorio,
sincronizaciones_laboratorio, resultados_laboratorio y sincronizaciones_laboratorio_items,
y siembra de forma idempotente los permisos lab_results:create|read|review|sync por nombre
de rol (ADMIN, MEDICO, RECEPCION, PACIENTE), igual que la matriz de CU12 (migracion 006).
No crea el rol LABORATORIO.

Revision ID: cu11_resultados_laboratorio_025
Revises: cu36_billing_overages_024
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "cu11_resultados_laboratorio_025"
down_revision = "cu36_billing_overages_024"
branch_labels = depends_on = None

_PK = sa.BigInteger().with_variant(sa.Integer, "sqlite")
JSON_TYPE = sa.JSON().with_variant(postgresql.JSONB(), "postgresql")

PERMISOS_CU11 = [
    ("lab_results:create", "Cargar resultados de laboratorio", "laboratory_results", "create"),
    ("lab_results:read", "Consultar resultados de laboratorio", "laboratory_results", "read"),
    ("lab_results:review", "Revisar, resolver y anular resultados de laboratorio", "laboratory_results", "review"),
    ("lab_results:sync", "Gestionar fuentes y sincronizaciones de laboratorio", "laboratory_results", "sync"),
]

MATRIZ_ROLES_PERMISOS = {
    "ADMIN": ["lab_results:create", "lab_results:read", "lab_results:review", "lab_results:sync"],
    "MEDICO": ["lab_results:create", "lab_results:read", "lab_results:review"],
    "RECEPCION": ["lab_results:create", "lab_results:read"],
    "PACIENTE": ["lab_results:read"],
}


def _lit(value):
    """Literal SQL de una constante de esta migracion (nunca recibe entrada de usuario)."""
    return "'" + str(value).replace("'", "''") + "'"


def sembrar_permisos():
    """Inserta permisos y asignaciones solo si no existen (idempotente)."""
    for nombre, descripcion, modulo, accion in PERMISOS_CU11:
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
    nombres = ", ".join(_lit(p[0]) for p in PERMISOS_CU11)
    op.execute(
        "DELETE FROM rol_permisos WHERE id_permiso IN "
        f"(SELECT id_permiso FROM permisos WHERE nombre IN ({nombres}))"
    )
    op.execute(f"DELETE FROM permisos WHERE nombre IN ({nombres})")


def upgrade():
    op.create_table(
        "fuentes_laboratorio",
        sa.Column("id_fuente", _PK, primary_key=True, autoincrement=True),
        sa.Column("id_clinica", sa.BigInteger(), sa.ForeignKey("clinicas.id_clinica"), nullable=False),
        sa.Column("codigo", sa.String(50), nullable=False),
        sa.Column("nombre", sa.String(200), nullable=False),
        sa.Column("activa", sa.String(2), nullable=False, server_default="SI"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.UniqueConstraint("id_clinica", "codigo", name="uq_fuentes_lab_clinica_codigo"),
        sa.CheckConstraint("activa IN ('SI', 'NO')", name="ck_fuentes_lab_activa"),
    )
    op.create_index("ix_fuentes_lab_id_clinica", "fuentes_laboratorio", ["id_clinica"])

    op.create_table(
        "sincronizaciones_laboratorio",
        sa.Column("id_sincronizacion", _PK, primary_key=True, autoincrement=True),
        sa.Column("id_clinica", sa.BigInteger(), sa.ForeignKey("clinicas.id_clinica"), nullable=False),
        sa.Column("id_fuente", sa.BigInteger(), sa.ForeignKey("fuentes_laboratorio.id_fuente"), nullable=False),
        sa.Column("tipo", sa.String(10), nullable=False, server_default="LOTE"),
        sa.Column("estado", sa.String(30), nullable=False),
        sa.Column("total_items", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("incorporados", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("pendientes", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("duplicados", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("con_error", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("reintentos", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("id_usuario", sa.BigInteger(), sa.ForeignKey("usuarios.id_usuario"), nullable=True),
        sa.Column("proceso", sa.String(50), nullable=True),
        sa.Column("iniciado_en", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("finalizado_en", sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint("tipo IN ('LOTE')", name="ck_sync_lab_tipo"),
        sa.CheckConstraint(
            "estado IN ('EN_PROCESO', 'COMPLETADA', 'COMPLETADA_CON_ERRORES', 'FALLIDA')",
            name="ck_sync_lab_estado",
        ),
        sa.CheckConstraint(
            "total_items >= 0 AND incorporados >= 0 AND pendientes >= 0 "
            "AND duplicados >= 0 AND con_error >= 0 AND reintentos >= 0",
            name="ck_sync_lab_contadores",
        ),
        sa.CheckConstraint("id_usuario IS NOT NULL OR proceso IS NOT NULL", name="ck_sync_lab_responsable"),
    )
    op.create_index("ix_sync_lab_id_clinica", "sincronizaciones_laboratorio", ["id_clinica"])

    op.create_table(
        "resultados_laboratorio",
        sa.Column("id_resultado", _PK, primary_key=True, autoincrement=True),
        sa.Column("id_clinica", sa.BigInteger(), sa.ForeignKey("clinicas.id_clinica"), nullable=False),
        sa.Column("id_paciente", sa.BigInteger(), sa.ForeignKey("pacientes.id_paciente"), nullable=True),
        sa.Column("id_orden", sa.BigInteger(), sa.ForeignKey("ordenes_laboratorio.id_orden"), nullable=True),
        sa.Column("id_examen", sa.BigInteger(), sa.ForeignKey("examenes_laboratorio.id_examen"), nullable=True),
        sa.Column("codigo_examen", sa.String(50), nullable=False),
        sa.Column("nombre_examen", sa.String(200), nullable=True),
        sa.Column("laboratorio_origen", sa.String(200), nullable=False),
        sa.Column("fecha_realizacion", sa.Date(), nullable=False),
        sa.Column("observaciones", sa.Text(), nullable=True),
        sa.Column("estado", sa.String(20), nullable=False),
        sa.Column("origen", sa.String(12), nullable=False),
        sa.Column("id_fuente", sa.BigInteger(), sa.ForeignKey("fuentes_laboratorio.id_fuente"), nullable=True),
        sa.Column("id_externo", sa.String(100), nullable=True),
        sa.Column(
            "id_sincronizacion", sa.BigInteger(),
            sa.ForeignKey("sincronizaciones_laboratorio.id_sincronizacion"), nullable=True,
        ),
        sa.Column("motivo_pendiente", sa.String(40), nullable=True),
        sa.Column("datos_correspondencia", JSON_TYPE, nullable=True),
        sa.Column("nombre_archivo", sa.String(255), nullable=False),
        sa.Column("archivo_url", sa.String(500), nullable=False),
        sa.Column("hash_archivo", sa.String(64), nullable=False),
        sa.Column("content_type", sa.String(50), nullable=False),
        sa.Column("tamano_bytes", sa.BigInteger(), nullable=False),
        sa.Column("id_documento", sa.BigInteger(), sa.ForeignKey("documentos_clinicos.id_documento"), nullable=True),
        sa.Column("registrado_por", sa.BigInteger(), sa.ForeignKey("usuarios.id_usuario"), nullable=True),
        sa.Column("proceso", sa.String(50), nullable=True),
        sa.Column("registrado_en", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("resuelto_por", sa.BigInteger(), sa.ForeignKey("usuarios.id_usuario"), nullable=True),
        sa.Column("resuelto_en", sa.DateTime(timezone=True), nullable=True),
        sa.Column("motivo_resolucion", sa.Text(), nullable=True),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.UniqueConstraint("id_clinica", "id_fuente", "id_externo", name="uq_resultado_lab_fuente_externo"),
        sa.CheckConstraint("estado IN ('INCORPORADO', 'PENDIENTE_REVISION', 'ANULADO')", name="ck_resultado_estado"),
        sa.CheckConstraint("origen IN ('MANUAL', 'SINCRONIZADO')", name="ck_resultado_origen"),
        sa.CheckConstraint(
            "content_type IN ('application/pdf', 'image/jpeg', 'image/png')",
            name="ck_resultado_content_type",
        ),
        sa.CheckConstraint("tamano_bytes > 0 AND tamano_bytes <= 10485760", name="ck_resultado_tamano"),
        sa.CheckConstraint(
            "estado <> 'INCORPORADO' OR (id_paciente IS NOT NULL AND id_examen IS NOT NULL)",
            name="ck_resultado_incorporado_completo",
        ),
        sa.CheckConstraint(
            "estado <> 'PENDIENTE_REVISION' OR (id_paciente IS NULL AND id_documento IS NULL)",
            name="ck_resultado_pendiente_sin_expediente",
        ),
        sa.CheckConstraint(
            "(origen = 'SINCRONIZADO' AND id_fuente IS NOT NULL AND id_externo IS NOT NULL) "
            "OR (origen = 'MANUAL' AND id_fuente IS NULL AND id_externo IS NULL)",
            name="ck_resultado_origen_fuente",
        ),
        sa.CheckConstraint("registrado_por IS NOT NULL OR proceso IS NOT NULL", name="ck_resultado_responsable"),
    )
    op.create_index(
        "uq_resultado_lab_manual_hash",
        "resultados_laboratorio",
        ["id_clinica", "id_paciente", "hash_archivo"],
        unique=True,
        postgresql_where=sa.text("origen = 'MANUAL' AND estado = 'INCORPORADO'"),
        sqlite_where=sa.text("origen = 'MANUAL' AND estado = 'INCORPORADO'"),
    )
    op.create_index("ix_resultados_lab_id_clinica", "resultados_laboratorio", ["id_clinica"])
    op.create_index(
        "ix_resultados_lab_clinica_paciente_estado", "resultados_laboratorio",
        ["id_clinica", "id_paciente", "estado"],
    )
    op.create_index(
        "ix_resultados_lab_clinica_estado_registro", "resultados_laboratorio",
        ["id_clinica", "estado", "registrado_en"],
    )
    op.create_index(
        "ix_resultados_lab_clinica_fecha", "resultados_laboratorio", ["id_clinica", "fecha_realizacion"],
    )

    op.create_table(
        "sincronizaciones_laboratorio_items",
        sa.Column("id_item", _PK, primary_key=True, autoincrement=True),
        sa.Column(
            "id_sincronizacion", sa.BigInteger(),
            sa.ForeignKey("sincronizaciones_laboratorio.id_sincronizacion"), nullable=False,
        ),
        sa.Column("id_clinica", sa.BigInteger(), sa.ForeignKey("clinicas.id_clinica"), nullable=False),
        sa.Column("id_externo", sa.String(100), nullable=False),
        sa.Column("resultado", sa.String(20), nullable=False),
        sa.Column("id_resultado", sa.BigInteger(), sa.ForeignKey("resultados_laboratorio.id_resultado"), nullable=True),
        sa.Column("codigo_error", sa.String(50), nullable=True),
        sa.Column("detalle", sa.Text(), nullable=True),
        sa.Column("intento", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("procesado_en", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.UniqueConstraint("id_sincronizacion", "id_externo", name="uq_sync_item"),
        sa.CheckConstraint(
            "resultado IN ('INCORPORADO', 'PENDIENTE_REVISION', 'DUPLICADO', 'ERROR')",
            name="ck_sync_item_resultado",
        ),
    )
    op.create_index("ix_sync_items_lab_id_clinica", "sincronizaciones_laboratorio_items", ["id_clinica"])

    sembrar_permisos()


def downgrade():
    retirar_permisos()
    op.drop_index("ix_sync_items_lab_id_clinica", table_name="sincronizaciones_laboratorio_items")
    op.drop_table("sincronizaciones_laboratorio_items")
    for index in (
        "ix_resultados_lab_clinica_fecha",
        "ix_resultados_lab_clinica_estado_registro",
        "ix_resultados_lab_clinica_paciente_estado",
        "ix_resultados_lab_id_clinica",
        "uq_resultado_lab_manual_hash",
    ):
        op.drop_index(index, table_name="resultados_laboratorio")
    op.drop_table("resultados_laboratorio")
    op.drop_index("ix_sync_lab_id_clinica", table_name="sincronizaciones_laboratorio")
    op.drop_table("sincronizaciones_laboratorio")
    op.drop_index("ix_fuentes_lab_id_clinica", table_name="fuentes_laboratorio")
    op.drop_table("fuentes_laboratorio")
