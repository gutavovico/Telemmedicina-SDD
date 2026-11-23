"""Regresión: los diagnósticos de teleconsulta deben ser legibles por el HCE (CU28).

La finalización de teleconsulta guardaba Diagnostico.tipo = "PRINCIPAL"/"SECUNDARIO", valores fuera de
TipoDiagnosticoEnum; GET /api/v1/hce/pacientes/{id} fallaba con 500 al serializar la respuesta.
"""
import unittest
from datetime import date
from types import SimpleNamespace
from unittest import mock

from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from sqlalchemy.orm import joinedload, sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base, get_db
from app.main import app
from app.modules.appointments.models import Cita, Medico
from app.modules.auth.dependencies import get_current_user, get_required_tenant_id
from app.modules.auth.models import Clinica, Rol, Usuario
from app.modules.communications import service as comm_service
from app.modules.communications.schemas import (
    DetalleRecetaTeleconsultaItem,
    DiagnosticoTeleconsultaItem,
    EmitirRecetaTeleconsultaCommand,
)
from app.modules.medical_records.hce.models import Diagnostico
from app.modules.medical_records.hce.schemas import TipoDiagnosticoEnum
from app.modules.medical_records.models import Paciente
from app.modules.medical_records.prescriptions import service as rx_service


class TeleconsultaDiagnosticosHceTestCase(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.engine = create_engine(
            "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool
        )
        cls.SessionLocal = sessionmaker(
            bind=cls.engine, autocommit=False, autoflush=False, expire_on_commit=False
        )
        Base.metadata.create_all(cls.engine)

        def override_get_db():
            db = cls.SessionLocal()
            try:
                yield db
            finally:
                db.close()

        app.dependency_overrides[get_db] = override_get_db
        cls.client = TestClient(app)

    @classmethod
    def tearDownClass(cls):
        app.dependency_overrides.clear()
        cls.engine.dispose()

    def setUp(self):
        db = self.SessionLocal()
        try:
            db.add(Clinica(id_clinica=1, nombre="Hospital San Juan de Dios", correo="c@x.org", estado="ACTIVO"))
            db.add_all([Rol(id_rol=2, nombre="MEDICO", estado="ACTIVO"), Rol(id_rol=4, nombre="PACIENTE", estado="ACTIVO")])
            db.flush()
            self.user_medico = Usuario(
                id_usuario=2, id_clinica=1, id_rol=2, nombres="Ana", apellidos="López",
                correo="ana@x.org", password_hash="secret", estado="activo",
            )
            user_paciente = Usuario(
                id_usuario=3, id_clinica=1, id_rol=4, nombres="Carlos", apellidos="Pérez",
                correo="carlos@x.org", password_hash="secret", estado="activo",
            )
            db.add_all([self.user_medico, user_paciente])
            db.flush()
            db.add(Paciente(
                id_paciente=10, id_usuario=3, id_clinica=1, nombres="Carlos", apellidos="Pérez",
                ci="12345678", fecha_nacimiento=date(1985, 3, 20), genero="M",
                telefono="+59171234567", estado="ACTIVO",
            ))
            db.add(Medico(
                id_medico=42, id_clinica=1, id_usuario=2, matricula_profesional="MED-1",
                descripcion_profesional="General", experiencia="10 años", estado="activo",
            ))
            db.flush()
            db.add(Cita(
                id_cita=105, id_clinica=1, id_paciente=10, id_medico=42, fecha_cita=date(2024, 9, 2),
                hora_inicio="17:00", hora_fin="17:30", modalidad="TELEMEDICINA", estado="CONFIRMADA",
            ))
            db.commit()
            # Usuario con su rol ya cargado: fuera de sesión no puede resolver `rol_rel` de forma perezosa.
            self.user_medico = db.execute(
                select(Usuario).options(joinedload(Usuario.rol_rel)).where(Usuario.id_usuario == 2)
            ).scalars().one()
        finally:
            db.close()
        app.dependency_overrides[get_current_user] = lambda: self.user_medico
        app.dependency_overrides[get_required_tenant_id] = lambda: 1

    def tearDown(self):
        app.dependency_overrides.pop(get_current_user, None)
        app.dependency_overrides.pop(get_required_tenant_id, None)
        Base.metadata.drop_all(self.engine)
        Base.metadata.create_all(self.engine)

    def test_diagnosticos_de_teleconsulta_usan_tipos_validos_y_el_hce_responde_200(self):
        command = EmitirRecetaTeleconsultaCommand(
            id_paciente=10,
            motivo_consulta="Control por teleconsulta",
            diagnosticos=[
                DiagnosticoTeleconsultaItem(codigo="I10", descripcion="Hipertensión", principal=True),
                DiagnosticoTeleconsultaItem(codigo="R51", descripcion="Cefalea", principal=False),
            ],
            detalles=[
                DetalleRecetaTeleconsultaItem(
                    nombre_medicamento_manual="Paracetamol", dosis="500 mg", frecuencia="Cada 8 horas", duracion="3 días"
                )
            ],
        )
        db = self.SessionLocal()
        try:
            with mock.patch.object(rx_service, "emitir_receta", return_value=(SimpleNamespace(), None)), \
                 mock.patch.object(rx_service, "receta_to_response", return_value={"ok": True}):
                comm_service.emitir_receta_teleconsulta(
                    db, id_cita=105, command=command, current_user=self.user_medico, tenant_id=1,
                    client_ip="127.0.0.1",
                )
            tipos = {d.codigo_cie: d.tipo for d in db.execute(select(Diagnostico)).scalars().all()}
        finally:
            db.close()

        validos = {t.value for t in TipoDiagnosticoEnum}
        self.assertEqual(set(tipos), {"I10", "R51"})
        self.assertTrue(set(tipos.values()) <= validos, tipos)
        self.assertEqual(tipos["I10"], "DEFINITIVO")
        self.assertEqual(tipos["R51"], "PRESUNTIVO")

        respuesta = self.client.get("/api/v1/hce/pacientes/10", headers={"X-Tenant-ID": "1"})
        self.assertEqual(respuesta.status_code, 200, respuesta.text)
        diagnosticos = [d for c in respuesta.json()["consultas"] for d in c["diagnosticos"]]
        self.assertEqual({d["codigo_cie"] for d in diagnosticos}, {"I10", "R51"})


if __name__ == "__main__":
    unittest.main()
