"""Pruebas exhaustivas para el CU18 - Asistencia Inteligente de Tratamiento.

Cubre todos los escenarios Gherkin de la especificación:
- Escenario Principal 3C (Paciente hipertenso con Ibuprofeno + Aspirina -> Alerta Roja GRAVE)
- Escenario Criterio 5 (Tratamiento sin interacciones conocidas -> SIN_RIESGO_DETECTADO)
- Escenario Paciente sin tratamiento activo -> SIN_TRATAMIENTO_VIGENTE
- Escenario Resiliencia y degradación tolerante a fallos de IA -> DEGRADADO_REGLAS_BASE
- Escenario Rate Limiting (HTTP 429) y Caché de Pre-evaluación
- Escenario Aislamiento multitenant y RBAC (403 / 404)
- Escenario Consulta del catálogo referencial de interacciones
"""
from datetime import date, datetime, timedelta, timezone
from typing import Any, Dict, List
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base, get_db
from app.main import app
from app.modules.ai_assistant.models import (
    AlertaInteraccion,
    EvaluacionAsistencia,
    InteraccionCatalogo,
    RecomendacionTratamiento,
)
from app.modules.ai_assistant.provider import (
    ProviderTimeout,
    ProviderUnavailable,
    TreatmentAssistanceProvider,
    get_treatment_provider,
    set_treatment_provider,
)
from app.modules.auth.dependencies import get_current_user
from app.modules.auth.models import Clinica, Permiso, Rol, RolPermiso, Usuario
from app.modules.appointments.models import Cita, Medico
from app.modules.medical_records.hce.models import Consulta, Diagnostico, HistoriaClinica
from app.modules.medical_records.models import Paciente
from app.modules.medical_records.prescriptions.models import Medicamento, Receta, RecetaDetalle
from app.modules.medical_records.tratamientos.models import Tratamiento, TratamientoMedicamento


class MockSuccessAIProvider:
    """Proveedor mock que retorna recomendaciones válidas sin llamar a Groq."""

    def generate_recommendations(self, context: Dict[str, Any]) -> List[Dict[str, str]]:
        return [
            {
                "categoria": "ESTILO_VIDA",
                "titulo": "Monitoreo tensional por hipertensión",
                "detalle": "Dado su historial de hipertensión arterial, controle su presión al menos una vez al día.",
            },
            {
                "categoria": "SIGNOS_ALARMA",
                "titulo": "Signos de alarma de sangrado",
                "detalle": "Si nota heces oscuras, dolor abdominal o mareos persistentes, consulte a urgencias.",
            },
            {
                "categoria": "HORARIO_ADMINISTRACION",
                "titulo": "Separación de tomas",
                "detalle": "Tome los medicamentos con alimentos para proteger la mucosa gástrica.",
            },
        ]


class MockFailingAIProvider:
    """Proveedor mock que simula fallo por timeout o indisponibilidad."""

    def generate_recommendations(self, context: Dict[str, Any]) -> List[Dict[str, str]]:
        raise ProviderTimeout("Simulated AI timeout")


@pytest.fixture
def setup_cu18_db():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )

    target_tables = [
        Clinica.__table__,
        Rol.__table__,
        Permiso.__table__,
        RolPermiso.__table__,
        Usuario.__table__,
        Paciente.__table__,
        Medico.__table__,
        Cita.__table__,
        HistoriaClinica.__table__,
        Consulta.__table__,
        Diagnostico.__table__,
        Medicamento.__table__,
        Receta.__table__,
        RecetaDetalle.__table__,
        Tratamiento.__table__,
        TratamientoMedicamento.__table__,
        InteraccionCatalogo.__table__,
        EvaluacionAsistencia.__table__,
        AlertaInteraccion.__table__,
        RecomendacionTratamiento.__table__,
    ]
    Base.metadata.create_all(engine, tables=target_tables)

    with engine.begin() as conn:
        conn.exec_driver_sql("PRAGMA foreign_keys = OFF")
        conn.exec_driver_sql("""
            CREATE TABLE IF NOT EXISTS auditoria (
                id_auditoria INTEGER PRIMARY KEY AUTOINCREMENT,
                id_clinica BIGINT,
                id_usuario BIGINT NOT NULL,
                tabla_afectada VARCHAR(150),
                registro_id BIGINT,
                accion VARCHAR(50) NOT NULL,
                descripcion VARCHAR,
                datos_anteriores JSON,
                datos_nuevos JSON,
                direccion_ip VARCHAR(45),
                fecha_hora DATETIME DEFAULT CURRENT_TIMESTAMP NOT NULL
            )
        """)

        # Población inicial de datos
        conn.exec_driver_sql("INSERT INTO clinicas (id_clinica, nombre, estado) VALUES (1, 'Clínica Norte', 'ACTIVO'), (2, 'Clínica Sur', 'ACTIVO')")

        conn.exec_driver_sql(
            "INSERT INTO roles (id_rol, id_clinica, nombre, estado) VALUES "
            "(1, 1, 'MEDICO', 'ACTIVO'), "
            "(2, 1, 'PACIENTE', 'ACTIVO'), "
            "(3, 1, 'RECEPCION', 'ACTIVO'), "
            "(4, 2, 'MEDICO', 'ACTIVO'), "
            "(5, 2, 'PACIENTE', 'ACTIVO'), "
            "(6, 1, 'ADMIN', 'ACTIVO')"
        )

        conn.exec_driver_sql(
            """INSERT INTO usuarios
            (id_usuario, id_clinica, id_rol, nombres, apellidos, correo, password_hash, estado, notificaciones_push, notificaciones_email, notificaciones_sms)
            VALUES
            (1, 1, 1, 'Dr. Alberto', 'Médico', 'med1@test.invalid', 'x', 'activo', 1, 1, 0),
            (2, 1, 2, 'Juan', 'Pérez Hipertenso', 'pac1@test.invalid', 'x', 'activo', 1, 1, 0),
            (3, 1, 2, 'Carlos', 'Sin Riesgo', 'pac2@test.invalid', 'x', 'activo', 1, 1, 0),
            (4, 1, 2, 'María', 'Sin Tratamiento', 'pac3@test.invalid', 'x', 'activo', 1, 1, 0),
            (5, 1, 3, 'Ana', 'Recepcionista', 'recep@test.invalid', 'x', 'activo', 1, 1, 0),
            (6, 2, 4, 'Dr. Roberto', 'Clínica 2', 'med2@test.invalid', 'x', 'activo', 1, 1, 0),
            (7, 1, 6, 'Admin', 'Clínica', 'admin1@test.invalid', 'x', 'activo', 1, 1, 0),
            (8, 1, 1, 'Dr. Fernando', 'Sin Pacientes', 'medsinpac@test.invalid', 'x', 'activo', 1, 1, 0)"""
        )

        conn.exec_driver_sql(
            """INSERT INTO pacientes (id_paciente, id_clinica, id_usuario, nombres, apellidos, ci, fecha_nacimiento, genero, telefono, alergias, antecedentes_patologicos, estado)
            VALUES
            (10, 1, 2, 'Juan', 'Pérez', '123456', '1975-05-10', 'M', '70000001', 'Ninguna', 'Hipertensión arterial esencial estadio II', 'ACTIVO'),
            (11, 1, 3, 'Carlos', 'Mendoza', '654321', '1990-08-15', 'M', '70000002', 'Penicilina', 'Ninguno', 'ACTIVO'),
            (12, 1, 4, 'María', 'Gutiérrez', '987654', '1985-02-20', 'F', '70000003', 'Ninguna', 'Ninguno', 'ACTIVO')"""
        )

        conn.exec_driver_sql("INSERT INTO medicos (id_medico, id_clinica, id_usuario, matricula_profesional, estado) VALUES (20, 1, 1, 'MAT-1234', 'activo'), (21, 2, 6, 'MAT-5678', 'activo'), (22, 1, 8, 'MAT-9999', 'activo')")
        conn.exec_driver_sql("INSERT INTO citas (id_cita, id_clinica, id_paciente, id_medico, estado) VALUES (30, 1, 10, 20, 'FINALIZADA')")
        conn.exec_driver_sql("INSERT INTO historias_clinicas (id_historia, id_clinica, id_paciente, numero_historia, antecedentes_personales) VALUES (40, 1, 10, 'HC-10', 'Hipertensión arterial')")
        conn.exec_driver_sql("INSERT INTO consultas (id_consulta, id_clinica, id_historia, id_cita, id_medico, motivo_consulta, sintomas, evolucion, plan_medico) VALUES (50, 1, 40, 30, 20, 'Control TA', 'Cefalea leve', 'Tratamiento actual', 'Continuar medicación')")
        conn.exec_driver_sql("INSERT INTO diagnosticos (id_diagnostico, id_consulta, codigo_cie, descripcion, tipo) VALUES (60, 50, 'I10', 'Hipertensión esencial (primaria)', 'DEFINITIVO')")
        conn.exec_driver_sql(
            """INSERT INTO tratamientos (id_tratamiento, id_clinica, id_consulta, id_receta, id_diagnostico, id_paciente, id_medico, fecha_inicio, fecha_fin, zona_horaria, estado)
            VALUES (1, 1, 50, 70, 60, 10, 20, '2026-01-01', '2026-12-31', 'America/La_Paz', 'ACTIVO')"""
        )

        conn.exec_driver_sql(
            """INSERT INTO medicamentos (id_medicamento, nombre, principio_activo, concentracion, forma_farmaceutica, estado)
            VALUES
            (1, 'Ibuprofeno 400 mg', 'ibuprofeno', '400 mg', 'Comprimido', 'ACTIVO'),
            (2, 'Aspirina 100 mg', 'acido acetilsalicilico', '100 mg', 'Comprimido', 'ACTIVO'),
            (3, 'Paracetamol 500 mg', 'paracetamol', '500 mg', 'Comprimido', 'ACTIVO')"""
        )

        # Receta para Juan (Ibuprofeno + Aspirina)
        conn.exec_driver_sql(
            """INSERT INTO recetas (id_receta, id_clinica, id_consulta, id_medico, id_paciente, folio, codigo_verificacion_hash, firma_digital, algoritmo_firma, key_id, version_payload, hash_pdf, fecha_vencimiento, estado)
            VALUES (70, 1, 50, 20, 10, 'REC-001', 'hash001receta105', 'firma1', 'ED25519', 'key1', 1, 'hashpdf1', '2099-12-31', 'EMITIDA')"""
        )
        conn.exec_driver_sql(
            """INSERT INTO receta_detalle (id_receta_detalle, id_receta, id_medicamento, medicamento_nombre, principio_activo, dosis, frecuencia, duracion, via_administracion, cantidad, posicion)
            VALUES
            (80, 70, 1, 'Ibuprofeno 400 mg', 'ibuprofeno', '400 mg', 'Cada 8 horas', '5 días', 'ORAL', 15, 1),
            (81, 70, 2, 'Aspirina 100 mg', 'acido acetilsalicilico', '100 mg', 'Cada 24 horas', '30 días', 'ORAL', 30, 2)"""
        )

        # Receta para Carlos (solo Paracetamol)
        conn.exec_driver_sql(
            """INSERT INTO recetas (id_receta, id_clinica, id_consulta, id_medico, id_paciente, folio, codigo_verificacion_hash, firma_digital, algoritmo_firma, key_id, version_payload, hash_pdf, fecha_vencimiento, estado)
            VALUES (71, 1, 50, 20, 11, 'REC-002', 'hash002receta106', 'firma2', 'ED25519', 'key1', 1, 'hashpdf2', '2099-12-31', 'EMITIDA')"""
        )
        conn.exec_driver_sql(
            """INSERT INTO receta_detalle (id_receta_detalle, id_receta, id_medicamento, medicamento_nombre, principio_activo, dosis, frecuencia, duracion, via_administracion, cantidad, posicion)
            VALUES
            (82, 71, 3, 'Paracetamol 500 mg', 'paracetamol', '500 mg', 'Cada 8 horas', '3 días', 'ORAL', 9, 1)"""
        )

        # Semillas farmacológicas
        conn.exec_driver_sql(
            """INSERT INTO interacciones_catalogo (id_interaccion, principio_activo_a, principio_activo_b, severidad, descripcion_riesgo, recomendacion_clinica, estado)
            VALUES
            (1, 'acido acetilsalicilico', 'ibuprofeno', 'GRAVE', 'Riesgo de interacción: aumento de riesgo de sangrado', 'El uso simultáneo incrementa significativamente el riesgo de hemorragia gastrointestinal.', 'ACTIVO'),
            (2, 'diclofenaco', 'ketorolaco', 'GRAVE', 'Riesgo de interacción: toxicidad gastrointestinal y daño renal agudo', 'Contraindicado el uso concomitante de múltiples AINEs sistémicos.', 'ACTIVO'),
            (3, 'enalapril', 'espironolactona', 'MODERADA', 'Riesgo de interacción: elevación de potasio sérico (hiperpotasemia)', 'Monitorear niveles de potasio sérico.', 'ACTIVO')"""
        )

    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

    def override_get_db():
        db = TestingSessionLocal()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override_get_db

    original_provider = get_treatment_provider()
    set_treatment_provider(MockSuccessAIProvider())

    yield {
        "engine": engine,
        "Session": TestingSessionLocal,
    }

    set_treatment_provider(original_provider)
    app.dependency_overrides.clear()
    engine.dispose()


def auth_client_for_user(user_id: int, setup_cu18_db):
    """Crea un TestClient autenticado como el usuario especificado."""
    Session = setup_cu18_db["Session"]
    with Session() as db:
        usuario = db.query(Usuario).filter(Usuario.id_usuario == user_id).first()

    app.dependency_overrides[get_current_user] = lambda: usuario
    return TestClient(app)


# ============================================================================
# ESCENARIO 1: Escenario Principal 3C (HU-87)
# ============================================================================
def test_escenario_3c_paciente_hipertenso_con_ibuprofeno_y_aspirina(setup_cu18_db):
    client = auth_client_for_user(2, setup_cu18_db)  # Usuario 2: Juan (id_paciente 10)

    response = client.post("/api/v1/asistencia-tratamiento/evaluar", json={"forzar_recalculo": True})
    assert response.status_code == 200
    data = response.json()

    assert data["id_evaluacion"] is not None
    assert data["id_paciente"] == 10
    assert data["estado_evaluacion"] == "COMPLETADA"
    assert data["nivel_riesgo_global"] == "ALTO"
    assert data["total_medicamentos_analizados"] == 2
    assert data["total_alertas_detectadas"] == 1
    assert "No sustituye la valoración médica" in data["aviso_legal"]

    # Alerta detectada
    assert len(data["alertas"]) == 1
    alerta = data["alertas"][0]
    assert alerta["severidad"] == "GRAVE"
    assert alerta["color_alerta"] == "ROJO"
    assert "aumento de riesgo de sangrado" in alerta["mensaje_alerta"].lower()
    assert alerta["principio_activo_1"] == "acido acetilsalicilico"
    assert alerta["principio_activo_2"] == "ibuprofeno"

    # Recomendaciones contextuales de IA
    assert len(data["recomendaciones"]) >= 1
    recs = [r["titulo"] for r in data["recomendaciones"]]
    assert any("hipertensión" in t.lower() or "toma" in t.lower() for t in recs)

    # Verificar traza en tabla auditoria
    Session = setup_cu18_db["Session"]
    with Session() as db:
        auditorias = db.execute(
            text(
                "SELECT tabla_afectada, accion, registro_id FROM auditoria WHERE tabla_afectada = 'evaluaciones_asistencia'"
            )
        ).all()
        assert len(auditorias) == 1
        assert auditorias[0][0] == "evaluaciones_asistencia"
        assert auditorias[0][1] == "EVALUAR_TRATAMIENTO"
        assert auditorias[0][2] == data["id_evaluacion"]


# ============================================================================
# ESCENARIO 2: Criterio 5 - Tratamiento sin interacciones
# ============================================================================
def test_criterio_5_tratamiento_sin_interacciones(setup_cu18_db):
    client = auth_client_for_user(3, setup_cu18_db)  # Usuario 3: Carlos (id_paciente 11, solo Paracetamol)

    response = client.post("/api/v1/asistencia-tratamiento/evaluar", json={"forzar_recalculo": True})
    assert response.status_code == 200
    data = response.json()

    assert data["estado_evaluacion"] == "COMPLETADA"
    assert data["nivel_riesgo_global"] == "SIN_RIESGO"
    assert data["total_medicamentos_analizados"] == 1
    assert data["total_alertas_detectadas"] == 0
    assert len(data["alertas"]) == 0
    assert "No se detectaron interacciones adversas" in data["resumen_ejecutivo"]


# ============================================================================
# ESCENARIO 3: Paciente sin tratamiento activo
# ============================================================================
def test_paciente_sin_tratamiento_vigente(setup_cu18_db):
    client = auth_client_for_user(4, setup_cu18_db)  # Usuario 4: María (id_paciente 12, sin recetas)

    response = client.post("/api/v1/asistencia-tratamiento/evaluar")
    assert response.status_code == 200
    data = response.json()

    assert data["estado_evaluacion"] == "SIN_TRATAMIENTO_VIGENTE"
    assert data["nivel_riesgo_global"] == "SIN_RIESGO"
    assert data["total_medicamentos_analizados"] == 0
    assert data["total_alertas_detectadas"] == 0
    assert data["id_evaluacion"] is None
    assert "No cuenta con recetas ni medicamentos vigentes" in data["resumen_ejecutivo"]


# ============================================================================
# ESCENARIO 4: Resiliencia y degradación tolerante a fallos de IA
# ============================================================================
def test_degradacion_elegante_ante_fallo_ia(setup_cu18_db):
    set_treatment_provider(MockFailingAIProvider())
    client = auth_client_for_user(2, setup_cu18_db)

    response = client.post("/api/v1/asistencia-tratamiento/evaluar", json={"forzar_recalculo": True})
    assert response.status_code == 200
    data = response.json()

    assert data["estado_evaluacion"] == "DEGRADADO_REGLAS_BASE"
    assert data["nivel_riesgo_global"] == "ALTO"
    assert data["total_alertas_detectadas"] == 1
    assert len(data["alertas"]) == 1
    assert data["alertas"][0]["severidad"] == "GRAVE"

    # Recomendaciones base entregadas
    assert len(data["recomendaciones"]) >= 1
    assert all(r["origen"] == "REGLA_PREDEFINIDA" for r in data["recomendaciones"])
    assert any("arterial" in r["detalle"].lower() or "hipertens" in r["detalle"].lower() for r in data["recomendaciones"])


# ============================================================================
# ESCENARIO 5: Caché de Pre-evaluación y Rate Limiting (HTTP 429)
# ============================================================================
def test_cache_pre_evaluacion_y_rate_limiting(setup_cu18_db):
    client = auth_client_for_user(2, setup_cu18_db)

    # 1. Primera evaluación
    res1 = client.post("/api/v1/asistencia-tratamiento/evaluar", json={"forzar_recalculo": True})
    assert res1.status_code == 200
    id1 = res1.json()["id_evaluacion"]

    # 2. Segunda evaluación sin forzar -> devuelve caché
    res2 = client.post("/api/v1/asistencia-tratamiento/evaluar", json={"forzar_recalculo": False})
    assert res2.status_code == 200
    id2 = res2.json()["id_evaluacion"]
    assert id1 == id2  # Reutiliza el mismo registro

    # 3. Forzar 9 evaluaciones más para alcanzar 10 registros en la base de datos
    for _ in range(9):
        res = client.post("/api/v1/asistencia-tratamiento/evaluar", json={"forzar_recalculo": True})
        assert res.status_code == 200

    # 4. La 11ª evaluación supera el rate limit de 10/hora
    res_limit = client.post("/api/v1/asistencia-tratamiento/evaluar", json={"forzar_recalculo": True})
    assert res_limit.status_code == 429
    assert res_limit.json()["code"] == "RATE_LIMIT_EXCEEDED"
    assert "Retry-After" in res_limit.headers


# ============================================================================
# ESCENARIO 6: Aislamiento Multitenant y Control de Acceso RBAC
# ============================================================================
def test_rbac_y_aislamiento_multitenant(setup_cu18_db):
    # 1. Médico con paciente a su cargo -> 200 OK
    client_medico = auth_client_for_user(1, setup_cu18_db)  # Dr. Alberto (id_medico=20, clinica 1)
    res_med = client_medico.get("/api/v1/asistencia-tratamiento/historial?id_paciente=10")
    assert res_med.status_code == 200
    assert "items" in res_med.json()

    # 2. Médico sin relación -> 404 Not Found (no revelar existencia)
    # Dr. Alberto intenta consultar a Carlos (paciente 11, misma clínica pero sin tratamiento con Dr. Alberto)
    res_med_sin_rel = client_medico.get("/api/v1/asistencia-tratamiento/historial?id_paciente=11")
    assert res_med_sin_rel.status_code == 404
    assert res_med_sin_rel.json()["code"] == "PATIENT_NOT_FOUND"

    # Dr. Fernando (id_medico=22, sin tratamientos a su cargo) intenta consultar a Juan (paciente 10)
    client_med_sin_pac = auth_client_for_user(8, setup_cu18_db)
    res_med_sin_pac = client_med_sin_pac.get("/api/v1/asistencia-tratamiento/historial?id_paciente=10")
    assert res_med_sin_pac.status_code == 404
    assert res_med_sin_pac.json()["code"] == "PATIENT_NOT_FOUND"

    # 3. Médico de otra clínica (Dr. Roberto, clínica 2) intenta consultar paciente 10 -> 404 Not Found
    client_med_ajeno = auth_client_for_user(6, setup_cu18_db)
    res_med_ajeno = client_med_ajeno.get("/api/v1/asistencia-tratamiento/historial?id_paciente=10")
    assert res_med_ajeno.status_code == 404
    assert res_med_ajeno.json()["code"] == "PATIENT_NOT_FOUND"

    # 4. ADMIN -> 403 Forbidden en todos los endpoints de asistencia
    client_admin = auth_client_for_user(7, setup_cu18_db)
    res_admin_eval = client_admin.post("/api/v1/asistencia-tratamiento/evaluar")
    assert res_admin_eval.status_code == 403
    assert res_admin_eval.json()["code"] == "PERMISSION_DENIED"

    res_admin_hist = client_admin.get("/api/v1/asistencia-tratamiento/historial?id_paciente=10")
    assert res_admin_hist.status_code == 403
    assert res_admin_hist.json()["code"] == "PERMISSION_DENIED"

    res_admin_det = client_admin.get("/api/v1/asistencia-tratamiento/evaluaciones/1")
    assert res_admin_det.status_code == 403
    assert res_admin_det.json()["code"] == "PERMISSION_DENIED"

    res_admin_cat = client_admin.get("/api/v1/asistencia-tratamiento/interacciones/catalogo")
    assert res_admin_cat.status_code == 403
    assert res_admin_cat.json()["code"] == "PERMISSION_DENIED"

    # 5. Recepción -> 403 Forbidden
    client_recep = auth_client_for_user(5, setup_cu18_db)
    res_recep_eval = client_recep.post("/api/v1/asistencia-tratamiento/evaluar")
    assert res_recep_eval.status_code == 403
    assert res_recep_eval.json()["code"] == "PERMISSION_DENIED"

    res_recep_hist = client_recep.get("/api/v1/asistencia-tratamiento/historial?id_paciente=10")
    assert res_recep_hist.status_code == 403
    assert res_recep_hist.json()["code"] == "PERMISSION_DENIED"

    res_recep_det = client_recep.get("/api/v1/asistencia-tratamiento/evaluaciones/1")
    assert res_recep_det.status_code == 403
    assert res_recep_det.json()["code"] == "PERMISSION_DENIED"

    # 6. Paciente pidiendo otro id -> 403 Forbidden
    client_paciente_juan = auth_client_for_user(2, setup_cu18_db)  # Juan (id_paciente=10)
    res_ajeno = client_paciente_juan.get("/api/v1/asistencia-tratamiento/historial?id_paciente=11")
    assert res_ajeno.status_code == 403
    assert res_ajeno.json()["code"] == "PERMISSION_DENIED"

    # Paciente consulta su propio historial -> 200 OK
    res_propio = client_paciente_juan.get("/api/v1/asistencia-tratamiento/historial")
    assert res_propio.status_code == 200

    # 7. Detalle de evaluación ajena -> 404 Not Found
    # Primero Juan evalúa y genera una evaluación en la base de datos
    res_eval_juan = client_paciente_juan.post("/api/v1/asistencia-tratamiento/evaluar")
    assert res_eval_juan.status_code == 200
    id_eval_juan = res_eval_juan.json()["id_evaluacion"]

    # Juan consulta su propio detalle -> 200 OK
    res_det_propio = client_paciente_juan.get(f"/api/v1/asistencia-tratamiento/evaluaciones/{id_eval_juan}")
    assert res_det_propio.status_code == 200

    # Carlos (paciente 11, misma clínica) intenta ver el detalle de la evaluación de Juan -> 404 Not Found
    client_paciente_carlos = auth_client_for_user(3, setup_cu18_db)
    res_det_carlos_ajeno = client_paciente_carlos.get(f"/api/v1/asistencia-tratamiento/evaluaciones/{id_eval_juan}")
    assert res_det_carlos_ajeno.status_code == 404
    assert res_det_carlos_ajeno.json()["code"] == "EVALUATION_NOT_FOUND"

    # Médico sin relación (Dr. Fernando) intenta ver el detalle de la evaluación de Juan -> 404 Not Found
    client_med_sin_pac = auth_client_for_user(8, setup_cu18_db)
    res_det_med_sin_rel = client_med_sin_pac.get(f"/api/v1/asistencia-tratamiento/evaluaciones/{id_eval_juan}")
    assert res_det_med_sin_rel.status_code == 404
    assert res_det_med_sin_rel.json()["code"] == "PATIENT_NOT_FOUND"

    # Médico con relación (Dr. Alberto) consulta el detalle de Juan -> 200 OK
    client_medico = auth_client_for_user(1, setup_cu18_db)
    res_det_med_ok = client_medico.get(f"/api/v1/asistencia-tratamiento/evaluaciones/{id_eval_juan}")
    assert res_det_med_ok.status_code == 200


# ============================================================================
# ESCENARIO 7: Catálogo referencial de interacciones farmacológicas
# ============================================================================
def test_catalogo_interacciones_consulta(setup_cu18_db):
    client = auth_client_for_user(1, setup_cu18_db)

    # Consulta general
    res = client.get("/api/v1/asistencia-tratamiento/interacciones/catalogo")
    assert res.status_code == 200
    data = res.json()
    assert data["total"] >= 3
    assert len(data["items"]) >= 3

    # Filtrar por principio activo
    res_filtro = client.get("/api/v1/asistencia-tratamiento/interacciones/catalogo?principio_activo=ibuprofeno")
    assert res_filtro.status_code == 200
    items = res_filtro.json()["items"]
    assert len(items) == 1
    assert "ibuprofeno" in (items[0]["principio_activo_a"] + items[0]["principio_activo_b"])

    # Filtrar por severidad
    res_sev = client.get("/api/v1/asistencia-tratamiento/interacciones/catalogo?severidad=GRAVE")
    assert res_sev.status_code == 200
    for it in res_sev.json()["items"]:
        assert it["severidad"] == "GRAVE"
