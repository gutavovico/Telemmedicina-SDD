"""Admite servicios por clínica en esquemas que tienen el catálogo fijo heredado."""

from alembic import op

revision = "cu33_catalogo_servicios_027"
down_revision = "cu11_cu33_merge_026"
branch_labels = None
depends_on = None


def upgrade():
    op.execute("""
        DO $cu33$
        DECLARE
            regla text;
            siguiente bigint;
        BEGIN
            LOCK TABLE servicios_medicos IN ACCESS EXCLUSIVE MODE;
            SELECT pg_get_expr(conbin, conrelid) INTO regla
            FROM pg_constraint
            WHERE conrelid = 'servicios_medicos'::regclass
              AND conname = 'ck_servicios_configuracion_fija' AND contype = 'c';
            IF regla IS NOT NULL THEN
                EXECUTE format(
                    'ALTER TABLE servicios_medicos ADD CONSTRAINT ck_servicios_configuracion_cu33
                     CHECK ((id_servicio NOT IN (1, 2, 3) AND id_clinica IS NOT NULL) OR (%s))',
                    regla
                );
                ALTER TABLE servicios_medicos DROP CONSTRAINT ck_servicios_configuracion_fija;
                EXECUTE format(
                    'COMMENT ON CONSTRAINT ck_servicios_configuracion_cu33 ON servicios_medicos IS %L',
                    regla
                );
            END IF;
            IF EXISTS (
                SELECT 1 FROM pg_attribute
                WHERE attrelid = 'servicios_medicos'::regclass AND attname = 'id_servicio'
                  AND NOT atthasdef AND attidentity = ''
            ) THEN
                SELECT GREATEST(COALESCE(MAX(id_servicio), 0), 3) + 1
                INTO siguiente FROM servicios_medicos;
                EXECUTE format('CREATE SEQUENCE servicios_medicos_cu33_id_seq AS bigint START WITH %s
                                OWNED BY servicios_medicos.id_servicio', siguiente);
                ALTER TABLE servicios_medicos ALTER COLUMN id_servicio
                    SET DEFAULT nextval('servicios_medicos_cu33_id_seq'::regclass);
            END IF;
        END
        $cu33$;
    """)


def downgrade():
    op.execute("""
        DO $cu33$
        DECLARE
            regla text;
        BEGIN
            LOCK TABLE servicios_medicos IN ACCESS EXCLUSIVE MODE;
            SELECT obj_description(oid, 'pg_constraint') INTO regla
            FROM pg_constraint
            WHERE conrelid = 'servicios_medicos'::regclass
              AND conname = 'ck_servicios_configuracion_cu33';
            IF regla IS NOT NULL THEN
                EXECUTE format(
                    'ALTER TABLE servicios_medicos ADD CONSTRAINT ck_servicios_configuracion_fija CHECK (%s)',
                    regla
                );
                ALTER TABLE servicios_medicos DROP CONSTRAINT ck_servicios_configuracion_cu33;
            END IF;
            IF pg_get_serial_sequence('servicios_medicos', 'id_servicio')::regclass =
                to_regclass('servicios_medicos_cu33_id_seq') THEN
                ALTER TABLE servicios_medicos ALTER COLUMN id_servicio DROP DEFAULT;
                DROP SEQUENCE servicios_medicos_cu33_id_seq;
            END IF;
        END
        $cu33$;
    """)
