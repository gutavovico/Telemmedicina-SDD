"""CU11 · tareas 2.1, 2.2 y 2.4: cabeza única, upgrade/downgrade y paridad modelos-migración.

La migración se ejecuta sobre SQLite en memoria (nunca contra una base compartida). Además se genera
el SQL de PostgreSQL en modo offline (``--sql``) para revisar el DDL que verá Neon.
"""
import io

import pytest
from alembic import command
from alembic.autogenerate import compare_metadata
from alembic.config import Config
from alembic.migration import MigrationContext
from alembic.script import ScriptDirectory
from sqlalchemy import CheckConstraint, inspect, select, text

from app.core.database import Base
from app.modules.auth.models import Permiso
from cu11_support import (
    RAIZ,
    TABLAS_CU11,
    cargar_migracion_025,
    correr_en_migracion,
    engine_previo_a_cu11,
)

REVISION = "cu11_resultados_laboratorio_025"
REVISION_PREVIA = "cu36_billing_overages_024"


def _config():
    config = Config(str(RAIZ / "alembic.ini"))
    config.set_main_option("script_location", str(RAIZ / "alembic"))
    return config


def test_una_sola_cabeza_y_la_revision_cuelga_de_la_cabeza_previa():
    script = ScriptDirectory.from_config(_config())
    cabezas = script.get_heads()
    assert len(cabezas) == 1
    revision = script.get_revision(REVISION)
    assert revision is not None
    assert revision.down_revision == REVISION_PREVIA
    assert script.get_revision(REVISION_PREVIA) is not None
    # la 025 forma parte de la cadena que termina en la cabeza única
    historial = {r.revision for r in script.iterate_revisions(cabezas[0], "base")}
    assert REVISION in historial and REVISION_PREVIA in historial


def test_upgrade_y_downgrade_sobre_sqlite_desechable():
    migracion = cargar_migracion_025()
    engine = engine_previo_a_cu11()
    assert not set(TABLAS_CU11) & set(inspect(engine).get_table_names())

    correr_en_migracion(engine, migracion.upgrade)
    inspector = inspect(engine)
    assert set(TABLAS_CU11) <= set(inspector.get_table_names())
    indices = {i["name"] for i in inspector.get_indexes("resultados_laboratorio")}
    assert {
        "uq_resultado_lab_manual_hash",
        "ix_resultados_lab_id_clinica",
        "ix_resultados_lab_clinica_paciente_estado",
        "ix_resultados_lab_clinica_estado_registro",
        "ix_resultados_lab_clinica_fecha",
    } <= indices
    with engine.connect() as conexion:
        nombres = set(conexion.execute(text("SELECT nombre FROM permisos WHERE nombre LIKE 'lab_results:%'")).scalars())
    assert nombres == {"lab_results:create", "lab_results:read", "lab_results:review", "lab_results:sync"}

    correr_en_migracion(engine, migracion.downgrade)
    inspector = inspect(engine)
    assert not set(TABLAS_CU11) & set(inspector.get_table_names())
    assert {"clinicas", "pacientes", "ordenes_laboratorio", "documentos_clinicos", "permisos"} <= set(
        inspector.get_table_names()
    )
    with engine.connect() as conexion:
        assert conexion.execute(text("SELECT count(*) FROM permisos WHERE nombre LIKE 'lab_results:%'")).scalar_one() == 0
        assert conexion.execute(text("SELECT count(*) FROM rol_permisos")).scalar_one() == 0

    # reversible y repetible
    correr_en_migracion(engine, migracion.upgrade)
    assert set(TABLAS_CU11) <= set(inspect(engine).get_table_names())


def test_modelos_y_migracion_producen_el_mismo_esquema():
    """Equivale a `alembic check` restringido a las tablas de CU11."""
    migracion = cargar_migracion_025()
    engine = engine_previo_a_cu11()
    correr_en_migracion(engine, migracion.upgrade)

    def solo_cu11(objeto, nombre, tipo, reflejado, comparado_con):
        if tipo == "table":
            return nombre in TABLAS_CU11
        tabla = getattr(objeto, "table", None)
        return tabla is not None and tabla.name in TABLAS_CU11

    with engine.connect() as conexion:
        contexto = MigrationContext.configure(
            conexion, opts={"include_object": solo_cu11, "compare_type": False, "compare_server_default": False}
        )
        diferencias = compare_metadata(contexto, Base.metadata)
        assert diferencias == [], f"El modelo y la migración difieren: {diferencias}"

        inspector = inspect(conexion)
        for nombre in TABLAS_CU11:
            esperadas = {
                c.name for c in Base.metadata.tables[nombre].constraints if isinstance(c, CheckConstraint) and c.name
            }
            reales = {c["name"] for c in inspector.get_check_constraints(nombre)}
            assert esperadas == reales, f"CHECK distintos en {nombre}: {esperadas ^ reales}"


def test_sql_offline_de_postgresql_es_aditivo_y_contiene_las_restricciones():
    """Genera el SQL (modo `--sql`) de la revisión 025 para PostgreSQL y revisa lo esencial."""
    buffer = io.StringIO()
    config = _config()
    config.output_buffer = buffer
    command.upgrade(config, f"{REVISION_PREVIA}:{REVISION}", sql=True)
    sql = buffer.getvalue()
    compacto = " ".join(sql.split())

    for tabla in TABLAS_CU11:
        assert f"CREATE TABLE {tabla}" in compacto
    assert "id_resultado BIGSERIAL NOT NULL" in compacto
    assert "datos_correspondencia JSONB" in compacto
    assert (
        "CREATE UNIQUE INDEX uq_resultado_lab_manual_hash ON resultados_laboratorio (id_clinica, id_paciente, hash_archivo) "
        "WHERE origen = 'MANUAL' AND estado = 'INCORPORADO'"
    ) in compacto
    assert "CONSTRAINT uq_resultado_lab_fuente_externo UNIQUE (id_clinica, id_fuente, id_externo)" in compacto
    assert "CONSTRAINT ck_resultado_pendiente_sin_expediente CHECK" in compacto
    assert "INSERT INTO permisos" in compacto and "INSERT INTO rol_permisos" in compacto
    assert f"UPDATE alembic_version SET version_num='{REVISION}' WHERE alembic_version.version_num = '{REVISION_PREVIA}'" in compacto

    # aditiva: no altera ni borra nada existente
    mayusculas = compacto.upper()
    assert "DROP " not in mayusculas
    assert "ALTER TABLE" not in mayusculas
    assert "TRUNCATE" not in mayusculas
    assert "UPDATE PACIENTES" not in mayusculas
