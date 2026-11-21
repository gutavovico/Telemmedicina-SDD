"""Modelos de persistencia para el Asistente Inteligente de Tratamiento (CU18).

Soporta PostgreSQL y SQLite (variantes Integer/JSON para tests).
"""
from sqlalchemy import (
    BigInteger,
    CheckConstraint,
    Column,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    JSON,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import relationship

from app.core.database import Base

ID = BigInteger().with_variant(Integer, "sqlite")
JSON_VALUE = JSONB().with_variant(JSON(), "sqlite")


class InteraccionCatalogo(Base):
    """Catálogo global referencial de interacciones farmacológicas (sin id_clinica)."""

    __tablename__ = "interacciones_catalogo"

    id_interaccion = Column(ID, primary_key=True, autoincrement=True)
    principio_activo_a = Column(String(200), nullable=False)
    principio_activo_b = Column(String(200), nullable=False)
    severidad = Column(String(20), nullable=False)  # LEVE | MODERADA | GRAVE
    mecanismo = Column(Text, nullable=True)
    descripcion_riesgo = Column(Text, nullable=False)
    recomendacion_clinica = Column(Text, nullable=False)
    estado = Column(String(20), nullable=False, default="ACTIVO")  # ACTIVO | INACTIVO
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    __table_args__ = (
        UniqueConstraint("principio_activo_a", "principio_activo_b", name="uq_interacciones_catalogo_par"),
        CheckConstraint("severidad IN ('LEVE', 'MODERADA', 'GRAVE')", name="ck_interacciones_severidad"),
        CheckConstraint("estado IN ('ACTIVO', 'INACTIVO')", name="ck_interacciones_estado"),
        Index("ix_interacciones_activo_a", "principio_activo_a"),
        Index("ix_interacciones_activo_b", "principio_activo_b"),
    )

    def __repr__(self) -> str:
        return f"<InteraccionCatalogo({self.principio_activo_a} + {self.principio_activo_b}: {self.severidad})>"


class EvaluacionAsistencia(Base):
    """Registro inmutable de una sesión de asistencia inteligente para un paciente en una clínica."""

    __tablename__ = "evaluaciones_asistencia"

    id_evaluacion = Column(ID, primary_key=True, autoincrement=True)
    id_clinica = Column(ID, ForeignKey("clinicas.id_clinica"), nullable=False)
    id_paciente = Column(ID, ForeignKey("pacientes.id_paciente"), nullable=False)
    id_usuario = Column(ID, ForeignKey("usuarios.id_usuario"), nullable=False)
    fecha_evaluacion = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    estado_evaluacion = Column(String(30), nullable=False)  # COMPLETADA | DEGRADADO_REGLAS_BASE | SIN_TRATAMIENTO_VIGENTE
    nivel_riesgo_global = Column(String(20), nullable=False)  # SIN_RIESGO | BAJO | MEDIO | ALTO
    total_medicamentos_analizados = Column(Integer, nullable=False, default=0)
    total_alertas_detectadas = Column(Integer, nullable=False, default=0)
    resumen_ejecutivo = Column(Text, nullable=True)
    aviso_legal = Column(
        Text,
        nullable=False,
        default="Esta asistencia inteligente apoya con alertas y sugerencias de autocuidado. No sustituye la valoración médica profesional ni modifica diagnósticos, dosis o prescripciones vigentes.",
    )
    hash_prescripciones = Column(String(64), nullable=True)
    proveedor_ia_utilizado = Column(String(50), nullable=True)
    medicamentos_snapshot = Column(JSON_VALUE, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    alertas = relationship("AlertaInteraccion", back_populates="evaluacion", cascade="all, delete-orphan", order_by="AlertaInteraccion.id_alerta")
    recomendaciones = relationship("RecomendacionTratamiento", back_populates="evaluacion", cascade="all, delete-orphan", order_by="RecomendacionTratamiento.id_recomendacion")

    __table_args__ = (
        Index("ix_evaluaciones_clinica_paciente", "id_clinica", "id_paciente"),
        Index("ix_evaluaciones_clinica_fecha", "id_clinica", "fecha_evaluacion"),
        Index("ix_evaluaciones_cache", "id_clinica", "id_paciente", "hash_prescripciones", "fecha_evaluacion"),
    )

    @property
    def tenant_id(self):
        return str(self.id_clinica) if self.id_clinica is not None else None

    def __repr__(self) -> str:
        return f"<EvaluacionAsistencia(id={self.id_evaluacion}, paciente={self.id_paciente}, estado={self.estado_evaluacion})>"


class AlertaInteraccion(Base):
    """Alerta de interacción farmacológica detectada en una evaluación."""

    __tablename__ = "alertas_interaccion"

    id_alerta = Column(ID, primary_key=True, autoincrement=True)
    id_evaluacion = Column(ID, ForeignKey("evaluaciones_asistencia.id_evaluacion", ondelete="CASCADE"), nullable=False)
    id_interaccion = Column(ID, ForeignKey("interacciones_catalogo.id_interaccion"), nullable=True)
    principio_activo_1 = Column(String(200), nullable=False)
    principio_activo_2 = Column(String(200), nullable=False)
    medicamento_1_nombre = Column(String(200), nullable=False)
    medicamento_2_nombre = Column(String(200), nullable=False)
    severidad = Column(String(20), nullable=False)  # LEVE | MODERADA | GRAVE
    color_alerta = Column(String(20), nullable=False)  # ROJO | AMBAR | AZUL
    mensaje_alerta = Column(Text, nullable=False)
    pauta_precaucion = Column(Text, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    evaluacion = relationship("EvaluacionAsistencia", back_populates="alertas")

    __table_args__ = (
        CheckConstraint("severidad IN ('LEVE', 'MODERADA', 'GRAVE')", name="ck_alertas_severidad"),
        Index("ix_alertas_evaluacion", "id_evaluacion"),
    )

    def __repr__(self) -> str:
        return f"<AlertaInteraccion(id={self.id_alerta}, severidad={self.severidad}, {self.principio_activo_1}+{self.principio_activo_2})>"


class RecomendacionTratamiento(Base):
    """Recomendación contextual o pauta de autocuidado asociada a una evaluación."""

    __tablename__ = "recomendaciones_tratamiento"

    id_recomendacion = Column(ID, primary_key=True, autoincrement=True)
    id_evaluacion = Column(ID, ForeignKey("evaluaciones_asistencia.id_evaluacion", ondelete="CASCADE"), nullable=False)
    categoria = Column(String(50), nullable=False)  # HORARIO_ADMINISTRACION | ESTILO_VIDA | SIGNOS_ALARMA | NUTRICION_HIDRATACION | PRECAUCION_GENERAL
    titulo = Column(String(200), nullable=False)
    detalle = Column(Text, nullable=False)
    origen = Column(String(20), nullable=False)  # IA_GENERATIVA | REGLA_PREDEFINIDA
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    evaluacion = relationship("EvaluacionAsistencia", back_populates="recomendaciones")

    __table_args__ = (
        CheckConstraint("origen IN ('IA_GENERATIVA', 'REGLA_PREDEFINIDA')", name="ck_recomendaciones_origen"),
        Index("ix_recomendaciones_evaluacion", "id_evaluacion"),
    )

    def __repr__(self) -> str:
        return f"<RecomendacionTratamiento(id={self.id_recomendacion}, categoria={self.categoria}, origen={self.origen})>"

