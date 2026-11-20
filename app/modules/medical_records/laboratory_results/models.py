"""Modelo de resultados de laboratorio (CU11, bloque A).

Tabla propia enlazada a ``documentos_clinicos`` para el archivo. ``id_clinica`` sigue la
convención del módulo vecino (``tenant_id`` es solo un alias de lectura). Diseño:
``openspec/changes/cu11-resultados-laboratorio/design.md`` D1 y D2.
"""
from sqlalchemy import (
    BigInteger,
    CheckConstraint,
    Column,
    Date,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    JSON,
    String,
    Text,
    UniqueConstraint,
    func,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB

from app.core.database import Base
from app.modules.auth.models import Clinica, Usuario  # noqa: F401  (resuelve las FK en metadata)
from app.modules.medical_records.clinical_documents.models import DocumentoClinico  # noqa: F401
from app.modules.medical_records.laboratory_orders.models import ExamenLaboratorio, OrdenLaboratorio  # noqa: F401
from app.modules.medical_records.laboratory_sync import models as _sync_models  # noqa: F401
from app.modules.medical_records.models import Paciente  # noqa: F401

_PK = BigInteger().with_variant(Integer, "sqlite")

ESTADOS = ("INCORPORADO", "PENDIENTE_REVISION", "ANULADO")
ORIGENES = ("MANUAL", "SINCRONIZADO")
CONTENT_TYPES = ("application/pdf", "image/jpeg", "image/png")
TAMANO_MAXIMO_BYTES = 10 * 1024 * 1024


class ResultadoLaboratorio(Base):
    """Resultado de laboratorio incorporado, pendiente de revisión o anulado."""

    __tablename__ = "resultados_laboratorio"

    id_resultado = Column(_PK, primary_key=True, autoincrement=True)
    id_clinica = Column(BigInteger, ForeignKey("clinicas.id_clinica"), nullable=False)
    # Nulo solo en PENDIENTE_REVISION: un pendiente jamás se asocia a un expediente.
    id_paciente = Column(BigInteger, ForeignKey("pacientes.id_paciente"), nullable=True)
    id_orden = Column(BigInteger, ForeignKey("ordenes_laboratorio.id_orden"), nullable=True)
    id_examen = Column(BigInteger, ForeignKey("examenes_laboratorio.id_examen"), nullable=True)
    codigo_examen = Column(String(50), nullable=False)
    nombre_examen = Column(String(200), nullable=True)
    laboratorio_origen = Column(String(200), nullable=False)
    fecha_realizacion = Column(Date, nullable=False)
    observaciones = Column(Text, nullable=True)
    estado = Column(String(20), nullable=False)
    origen = Column(String(12), nullable=False)
    id_fuente = Column(BigInteger, ForeignKey("fuentes_laboratorio.id_fuente"), nullable=True)
    id_externo = Column(String(100), nullable=True)
    id_sincronizacion = Column(BigInteger, ForeignKey("sincronizaciones_laboratorio.id_sincronizacion"), nullable=True)
    motivo_pendiente = Column(String(40), nullable=True)
    datos_correspondencia = Column(JSONB().with_variant(JSON(), "sqlite"), nullable=True)
    nombre_archivo = Column(String(255), nullable=False)
    archivo_url = Column(String(500), nullable=False)
    hash_archivo = Column(String(64), nullable=False)
    content_type = Column(String(50), nullable=False)
    tamano_bytes = Column(BigInteger, nullable=False)
    id_documento = Column(BigInteger, ForeignKey("documentos_clinicos.id_documento"), nullable=True)
    registrado_por = Column(BigInteger, ForeignKey("usuarios.id_usuario"), nullable=True)
    proceso = Column(String(50), nullable=True)
    registrado_en = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    resuelto_por = Column(BigInteger, ForeignKey("usuarios.id_usuario"), nullable=True)
    resuelto_en = Column(DateTime(timezone=True), nullable=True)
    motivo_resolucion = Column(Text, nullable=True)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

    __table_args__ = (
        # Idempotencia de la sincronización. En PostgreSQL los NULL son distintos, por lo que
        # no afecta a las cargas manuales (id_fuente e id_externo nulos).
        UniqueConstraint("id_clinica", "id_fuente", "id_externo", name="uq_resultado_lab_fuente_externo"),
        CheckConstraint("estado IN ('INCORPORADO', 'PENDIENTE_REVISION', 'ANULADO')", name="ck_resultado_estado"),
        CheckConstraint("origen IN ('MANUAL', 'SINCRONIZADO')", name="ck_resultado_origen"),
        CheckConstraint(
            "content_type IN ('application/pdf', 'image/jpeg', 'image/png')",
            name="ck_resultado_content_type",
        ),
        CheckConstraint("tamano_bytes > 0 AND tamano_bytes <= 10485760", name="ck_resultado_tamano"),
        CheckConstraint(
            "estado <> 'INCORPORADO' OR (id_paciente IS NOT NULL AND id_examen IS NOT NULL)",
            name="ck_resultado_incorporado_completo",
        ),
        CheckConstraint(
            "estado <> 'PENDIENTE_REVISION' OR (id_paciente IS NULL AND id_documento IS NULL)",
            name="ck_resultado_pendiente_sin_expediente",
        ),
        CheckConstraint(
            "(origen = 'SINCRONIZADO' AND id_fuente IS NOT NULL AND id_externo IS NOT NULL) "
            "OR (origen = 'MANUAL' AND id_fuente IS NULL AND id_externo IS NULL)",
            name="ck_resultado_origen_fuente",
        ),
        CheckConstraint("registrado_por IS NOT NULL OR proceso IS NOT NULL", name="ck_resultado_responsable"),
        # Duplicado de carga manual: mismo paciente y mismo SHA-256 mientras siga INCORPORADO.
        Index(
            "uq_resultado_lab_manual_hash",
            "id_clinica",
            "id_paciente",
            "hash_archivo",
            unique=True,
            postgresql_where=text("origen = 'MANUAL' AND estado = 'INCORPORADO'"),
            sqlite_where=text("origen = 'MANUAL' AND estado = 'INCORPORADO'"),
        ),
        Index("ix_resultados_lab_id_clinica", "id_clinica"),
        Index("ix_resultados_lab_clinica_paciente_estado", "id_clinica", "id_paciente", "estado"),
        Index("ix_resultados_lab_clinica_estado_registro", "id_clinica", "estado", "registrado_en"),
        Index("ix_resultados_lab_clinica_fecha", "id_clinica", "fecha_realizacion"),
    )

    @property
    def tenant_id(self):
        return self.id_clinica

    def __repr__(self) -> str:
        return (
            f"<ResultadoLaboratorio(id={self.id_resultado}, estado='{self.estado}', "
            f"origen='{self.origen}', codigo_examen='{self.codigo_examen}')>"
        )
