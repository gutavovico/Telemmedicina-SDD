"""Pruebas de la migración CU18 aislada en SQLite en memoria."""
import importlib.util
from pathlib import Path

import pytest
from alembic.migration import MigrationContext
from alembic.operations import Operations
from sqlalchemy import create_engine, inspect, text

from app.modules.ai_assistant.models import (
    AlertaInteraccion,
    EvaluacionAsistencia,
    InteraccionCatalogo,
    RecomendacionTratamiento,
)


def test_migracion_cu18_crea_tablas_semillas_y_permisos():
    ruta = Path(__file__).resolve().parents[1] / "alembic" / "versions" / "017_asistencia_tratamiento_cu18.py"
    spec = importlib.util.spec_from_file_location("migration_cu18", ruta)
    migration = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(migration)

    engine = create_engine("sqlite://")
    with engine.begin() as conn:
        conn.exec_driver_sql("PRAGMA foreign_keys=ON")
        for table, key in (
            ("clinicas", "id_clinica"),
            ("pacientes", "id_paciente"),
            ("usuarios", "id_usuario"),
        ):
            conn.exec_driver_sql(f"CREATE TABLE {table} ({key} INTEGER PRIMARY KEY)")
            conn.exec_driver_sql(f"INSERT INTO {table} ({key}) VALUES (1)")

        conn.exec_driver_sql("CREATE TABLE roles (id_rol INTEGER PRIMARY KEY, nombre TEXT NOT NULL)")
        conn.exec_driver_sql("INSERT INTO roles VALUES (1,'MEDICO'),(2,'PACIENTE'),(3,'RECEPCION')")
        conn.exec_driver_sql(
            "CREATE TABLE permisos (id_permiso INTEGER PRIMARY KEY, nombre TEXT, descripcion TEXT, modulo TEXT, accion TEXT, estado TEXT)"
        )
        conn.exec_driver_sql("CREATE TABLE rol_permisos (id_rol INTEGER, id_permiso INTEGER, PRIMARY KEY(id_rol,id_permiso))")

        migration.op = Operations(MigrationContext.configure(conn))
        migration.upgrade()

        inspector = inspect(conn)
        for model in (InteraccionCatalogo, EvaluacionAsistencia, AlertaInteraccion, RecomendacionTratamiento):
            expected_cols = {col.name for col in model.__table__.columns}
            actual_cols = {col["name"] for col in inspector.get_columns(model.__tablename__)}
            assert expected_cols == actual_cols

        # Verificar semillas farmacológicas en interacciones_catalogo
        semillas = conn.execute(
            text("SELECT principio_activo_a, principio_activo_b, severidad FROM interacciones_catalogo")
        ).all()
        assert len(semillas) >= 6
        # Par Ibuprofeno + Aspirina ordenado canónicamente
        pares = [(s[0], s[1], s[2]) for s in semillas]
        assert ("acido acetilsalicilico", "ibuprofeno", "GRAVE") in pares

        # Verificar permisos creados y asignados
        permisos_creados = conn.execute(text("SELECT nombre, modulo FROM permisos WHERE modulo='assistance'")).all()
        assert len(permisos_creados) == 2
        nombres_permisos = {p[0] for p in permisos_creados}
        assert "assistance:read" in nombres_permisos
        assert "assistance:evaluate" in nombres_permisos

        # Verificar asignación a roles
        asignaciones = conn.execute(
            text(
                "SELECT r.nombre, p.nombre FROM roles r "
                "JOIN rol_permisos rp ON rp.id_rol = r.id_rol "
                "JOIN permisos p ON p.id_permiso = rp.id_permiso "
                "WHERE p.modulo = 'assistance'"
            )
        ).all()
        asig_set = set(asignaciones)
        assert ("MEDICO", "assistance:read") in asig_set
        assert ("PACIENTE", "assistance:read") in asig_set
        assert ("PACIENTE", "assistance:evaluate") in asig_set
        assert not any(role == "RECEPCION" for role, _ in asignaciones)

        # Verificar downgrade
        migration.downgrade()
        inspector_post = inspect(conn)
        tablas_post = inspector_post.get_table_names()
        assert "interacciones_catalogo" not in tablas_post
        assert "evaluaciones_asistencia" not in tablas_post
        assert "alertas_interaccion" not in tablas_post
        assert "recomendaciones_tratamiento" not in tablas_post

    engine.dispose()

