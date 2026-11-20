"""CU18: Asistencia Inteligente de Tratamiento, Detección de Interacciones y Alertas.

Revision ID: cu18_asistencia_017
Revises: cu34_catalogo_016
Create Date: 2026-11-04
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB

revision = "cu18_asistencia_017"
down_revision = "cu34_catalogo_016"
branch_labels = None
depends_on = None

ID = sa.BigInteger().with_variant(sa.Integer(), "sqlite")
JSON_VALUE = JSONB().with_variant(sa.JSON(), "sqlite")


def upgrade():
    # 1. Catálogo global de interacciones farmacológicas
    op.create_table(
        "interacciones_catalogo",
        sa.Column("id_interaccion", ID, primary_key=True, autoincrement=True),
        sa.Column("principio_activo_a", sa.String(200), nullable=False),
        sa.Column("principio_activo_b", sa.String(200), nullable=False),
        sa.Column("severidad", sa.String(20), nullable=False),
        sa.Column("mecanismo", sa.Text(), nullable=True),
        sa.Column("descripcion_riesgo", sa.Text(), nullable=False),
        sa.Column("recomendacion_clinica", sa.Text(), nullable=False),
        sa.Column("estado", sa.String(20), nullable=False, server_default="ACTIVO"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.UniqueConstraint("principio_activo_a", "principio_activo_b", name="uq_interacciones_catalogo_par"),
        sa.CheckConstraint("severidad IN ('LEVE', 'MODERADA', 'GRAVE')", name="ck_interacciones_severidad"),
        sa.CheckConstraint("estado IN ('ACTIVO', 'INACTIVO')", name="ck_interacciones_estado"),
    )
    op.create_index("ix_interacciones_activo_a", "interacciones_catalogo", ["principio_activo_a"])
    op.create_index("ix_interacciones_activo_b", "interacciones_catalogo", ["principio_activo_b"])

    # 2. Evaluaciones de asistencia inteligente (aisladas por clínica y paciente)
    op.create_table(
        "evaluaciones_asistencia",
        sa.Column("id_evaluacion", ID, primary_key=True, autoincrement=True),
        sa.Column("id_clinica", ID, sa.ForeignKey("clinicas.id_clinica"), nullable=False),
        sa.Column("id_paciente", ID, sa.ForeignKey("pacientes.id_paciente"), nullable=False),
        sa.Column("id_usuario", ID, sa.ForeignKey("usuarios.id_usuario"), nullable=False),
        sa.Column("fecha_evaluacion", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("estado_evaluacion", sa.String(30), nullable=False),
        sa.Column("nivel_riesgo_global", sa.String(20), nullable=False),
        sa.Column("total_medicamentos_analizados", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("total_alertas_detectadas", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("resumen_ejecutivo", sa.Text(), nullable=True),
        sa.Column(
            "aviso_legal",
            sa.Text(),
            nullable=False,
            server_default="Esta asistencia inteligente apoya con alertas y sugerencias de autocuidado. No sustituye la valoración médica profesional ni modifica diagnósticos, dosis o prescripciones vigentes.",
        ),
        sa.Column("hash_prescripciones", sa.String(64), nullable=True),
        sa.Column("proveedor_ia_utilizado", sa.String(50), nullable=True),
        sa.Column("medicamentos_snapshot", JSON_VALUE, nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_evaluaciones_clinica_paciente", "evaluaciones_asistencia", ["id_clinica", "id_paciente"])
    op.create_index("ix_evaluaciones_clinica_fecha", "evaluaciones_asistencia", ["id_clinica", "fecha_evaluacion"])
    op.create_index("ix_evaluaciones_cache", "evaluaciones_asistencia", ["id_clinica", "id_paciente", "hash_prescripciones", "fecha_evaluacion"])

    # 3. Alertas de interacción detectadas
    op.create_table(
        "alertas_interaccion",
        sa.Column("id_alerta", ID, primary_key=True, autoincrement=True),
        sa.Column("id_evaluacion", ID, sa.ForeignKey("evaluaciones_asistencia.id_evaluacion", ondelete="CASCADE"), nullable=False),
        sa.Column("id_interaccion", ID, sa.ForeignKey("interacciones_catalogo.id_interaccion"), nullable=True),
        sa.Column("principio_activo_1", sa.String(200), nullable=False),
        sa.Column("principio_activo_2", sa.String(200), nullable=False),
        sa.Column("medicamento_1_nombre", sa.String(200), nullable=False),
        sa.Column("medicamento_2_nombre", sa.String(200), nullable=False),
        sa.Column("severidad", sa.String(20), nullable=False),
        sa.Column("color_alerta", sa.String(20), nullable=False),
        sa.Column("mensaje_alerta", sa.Text(), nullable=False),
        sa.Column("pauta_precaucion", sa.Text(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.CheckConstraint("severidad IN ('LEVE', 'MODERADA', 'GRAVE')", name="ck_alertas_severidad"),
    )
    op.create_index("ix_alertas_evaluacion", "alertas_interaccion", ["id_evaluacion"])

    # 4. Recomendaciones contextuales de autocuidado
    op.create_table(
        "recomendaciones_tratamiento",
        sa.Column("id_recomendacion", ID, primary_key=True, autoincrement=True),
        sa.Column("id_evaluacion", ID, sa.ForeignKey("evaluaciones_asistencia.id_evaluacion", ondelete="CASCADE"), nullable=False),
        sa.Column("categoria", sa.String(50), nullable=False),
        sa.Column("titulo", sa.String(200), nullable=False),
        sa.Column("detalle", sa.Text(), nullable=False),
        sa.Column("origen", sa.String(20), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.CheckConstraint("origen IN ('IA_GENERATIVA', 'REGLA_PREDEFINIDA')", name="ck_recomendaciones_origen"),
    )
    op.create_index("ix_recomendaciones_evaluacion", "recomendaciones_tratamiento", ["id_evaluacion"])

    # 5. Inmutabilidad en evaluaciones (trigger plpgsql en PostgreSQL)
    dialect = op.get_bind().dialect.name
    if dialect == "postgresql":
        op.execute("""CREATE OR REPLACE FUNCTION cu18_evaluacion_inmutable() RETURNS trigger AS $$
        BEGIN RAISE EXCEPTION 'Las evaluaciones de asistencia clínica son inmutables'; END; $$ LANGUAGE plpgsql""")
        op.execute("DROP TRIGGER IF EXISTS cu18_evaluacion_inmutable ON evaluaciones_asistencia")
        op.execute("CREATE TRIGGER cu18_evaluacion_inmutable BEFORE UPDATE OR DELETE ON evaluaciones_asistencia FOR EACH ROW EXECUTE FUNCTION cu18_evaluacion_inmutable()")
    elif dialect == "sqlite":
        op.execute("CREATE TRIGGER cu18_evaluacion_no_update BEFORE UPDATE ON evaluaciones_asistencia BEGIN SELECT RAISE(ABORT, 'Las evaluaciones de asistencia clínica son inmutables'); END")
        op.execute("CREATE TRIGGER cu18_evaluacion_no_delete BEFORE DELETE ON evaluaciones_asistencia BEGIN SELECT RAISE(ABORT, 'Las evaluaciones de asistencia clínica son inmutables'); END")

    # 6. Datos semilla de interacciones farmacológicas frecuentes
    semillas = [
        (
            "acido acetilsalicilico",
            "ibuprofeno",
            "GRAVE",
            "Competición por el sitio de unión a COX-1 e inhibición sinérgica de la agregación plaquetaria.",
            "Riesgo de interacción: aumento de riesgo de sangrado",
            "El uso simultáneo de AINEs como ibuprofeno con ácido acetilsalicílico incrementa significativamente el riesgo de hemorragia gastrointestinal y reduce el efecto cardioprotector de la aspirina. Consulte con su médico antes de continuar la toma combinada.",
        ),
        (
            "diclofenaco",
            "ketorolaco",
            "GRAVE",
            "Sinergia de toxicidad renal y erosión de mucosa gastrointestinal por bloqueo dual de prostaglandinas.",
            "Riesgo de interacción: toxicidad gastrointestinal y daño renal agudo",
            "Contraindicado el uso concomitante de múltiples AINEs sistémicos. Alto riesgo de úlcera péptica y hemorragia digestiva severa.",
        ),
        (
            "enalapril",
            "espironolactona",
            "MODERADA",
            "Inhibición simultánea del eje renina-angiotensina-aldosterona y retención tubular de potasio.",
            "Riesgo de interacción: elevación de potasio sérico (hiperpotasemia)",
            "Monitorear niveles de potasio sérico y función renal. Evitar suplementos de potasio y sustitutos de sal con alto contenido de potasio.",
        ),
        (
            "medio de contraste yodado",
            "metformina",
            "MODERADA",
            "Deterioro de la perfusión renal inducido por contraste que causa acumulación de metformina.",
            "Riesgo de interacción: riesgo de acidosis láctica",
            "Se recomienda suspender la metformina 48 horas previas y posteriores al estudio con contraste iodado, reanudando previa verificación de función renal normal.",
        ),
        (
            "amoxicilina",
            "metotrexato",
            "MODERADA",
            "Competencia por la secreción tubular renal de ácidos orgánicos.",
            "Riesgo de interacción: elevación de toxicidad hematológica por metotrexato",
            "Monitorizar hemograma y vigilar signos de mielosupresión o toxicidad hepática.",
        ),
        (
            "levotiroxina",
            "omeprazol",
            "LEVE",
            "El incremento del pH gástrico reduce la disolución y absorción intestinal de la tiroxina.",
            "Riesgo de interacción: absorción disminuida de hormona tiroidea",
            "Separar la toma de ambos medicamentos al menos 4 horas y realizar control periódico de TSH.",
        ),
    ]

    for pa, pb, sev, mec, desc, rec in semillas:
        # Orden canónico lexicográfico
        p1, p2 = (pa, pb) if pa < pb else (pb, pa)
        op.execute(
            sa.text(
                "INSERT INTO interacciones_catalogo "
                "(principio_activo_a, principio_activo_b, severidad, mecanismo, descripcion_riesgo, recomendacion_clinica, estado) "
                "SELECT :p1, :p2, :sev, :mec, :desc, :rec, 'ACTIVO' "
                "WHERE NOT EXISTS ("
                "  SELECT 1 FROM interacciones_catalogo WHERE principio_activo_a = :p1 AND principio_activo_b = :p2"
                ")"
            ).bindparams(p1=p1, p2=p2, sev=sev, mec=mec, desc=desc, rec=rec)
        )

    # 7. Permisos idempotentes RBAC
    permissions = {
        "assistance:read": "Consultar historial de asistencia inteligente de tratamiento",
        "assistance:evaluate": "Solicitar evaluacion asistida de tratamiento farmacologico",
    }
    for name, description in permissions.items():
        op.execute(
            sa.text(
                "INSERT INTO permisos (nombre, descripcion, modulo, accion, estado) "
                "SELECT :name, :description, 'assistance', :action, 'ACTIVO' "
                "WHERE NOT EXISTS (SELECT 1 FROM permisos WHERE nombre = :name)"
            ).bindparams(name=name, description=description, action=name.split(":", 1)[1])
        )

    for role, names in {
        "MEDICO": ("assistance:read",),
        "PACIENTE": ("assistance:read", "assistance:evaluate"),
    }.items():
        for name in names:
            op.execute(
                sa.text(
                    "INSERT INTO rol_permisos (id_rol, id_permiso) "
                    "SELECT r.id_rol, p.id_permiso FROM roles r JOIN permisos p ON p.nombre = :name "
                    "WHERE UPPER(r.nombre) = :role AND NOT EXISTS ("
                    "  SELECT 1 FROM rol_permisos rp WHERE rp.id_rol = r.id_rol AND rp.id_permiso = p.id_permiso"
                    ")"
                ).bindparams(role=role, name=name)
            )


def downgrade():
    dialect = op.get_bind().dialect.name
    if dialect == "postgresql":
        op.execute("DROP FUNCTION IF EXISTS cu18_evaluacion_inmutable() CASCADE")
    op.drop_table("recomendaciones_tratamiento")
    op.drop_table("alertas_interaccion")
    op.drop_table("evaluaciones_asistencia")
    op.drop_table("interacciones_catalogo")

