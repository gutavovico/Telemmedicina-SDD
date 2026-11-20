"""Modelos de fuentes y sincronizaciones de laboratorio (CU11, bloque B).

Todas las tablas llevan ``id_clinica`` (convención del módulo vecino; ``tenant_id``
es solo un alias de lectura). Diseño: ``openspec/changes/cu11-resultados-laboratorio/design.md`` D1.
"""
from sqlalchemy import (
    BigInteger,
    CheckConstraint,
    Column,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
    func,
)

from app.core.database import Base
from app.modules.auth.models import Clinica, Usuario  # noqa: F401  (resuelve las FK en metadata)

_PK = BigInteger().with_variant(Integer, "sqlite")


class FuenteLaboratorio(Base):
    """Fuente de laboratorio configurada por clínica (criterio 4)."""

    __tablename__ = "fuentes_laboratorio"

    id_fuente = Column(_PK, primary_key=True, autoincrement=True)
    id_clinica = Column(BigInteger, ForeignKey("clinicas.id_clinica"), nullable=False)
    codigo = Column(String(50), nullable=False)
    nombre = Column(String(200), nullable=False)
    activa = Column(String(2), nullable=False, default="SI", server_default="SI")
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

    __table_args__ = (
        UniqueConstraint("id_clinica", "codigo", name="uq_fuentes_lab_clinica_codigo"),
        CheckConstraint("activa IN ('SI', 'NO')", name="ck_fuentes_lab_activa"),
        Index("ix_fuentes_lab_id_clinica", "id_clinica"),
    )

    @property
    def tenant_id(self):
        return self.id_clinica

    def __repr__(self) -> str:
        return f"<FuenteLaboratorio(id={self.id_fuente}, codigo='{self.codigo}', activa='{self.activa}')>"


class SincronizacionLaboratorio(Base):
    """Cabecera de un lote de sincronización con contadores y estado (criterios 8 y 9)."""

    __tablename__ = "sincronizaciones_laboratorio"

    id_sincronizacion = Column(_PK, primary_key=True, autoincrement=True)
    id_clinica = Column(BigInteger, ForeignKey("clinicas.id_clinica"), nullable=False)
    id_fuente = Column(BigInteger, ForeignKey("fuentes_laboratorio.id_fuente"), nullable=False)
    tipo = Column(String(10), nullable=False, default="LOTE", server_default="LOTE")
    estado = Column(String(30), nullable=False)
    total_items = Column(Integer, nullable=False, default=0, server_default="0")
    incorporados = Column(Integer, nullable=False, default=0, server_default="0")
    pendientes = Column(Integer, nullable=False, default=0, server_default="0")
    duplicados = Column(Integer, nullable=False, default=0, server_default="0")
    con_error = Column(Integer, nullable=False, default=0, server_default="0")
    reintentos = Column(Integer, nullable=False, default=0, server_default="0")
    id_usuario = Column(BigInteger, ForeignKey("usuarios.id_usuario"), nullable=True)
    proceso = Column(String(50), nullable=True)
    iniciado_en = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    finalizado_en = Column(DateTime(timezone=True), nullable=True)

    __table_args__ = (
        CheckConstraint("tipo IN ('LOTE')", name="ck_sync_lab_tipo"),
        CheckConstraint(
            "estado IN ('EN_PROCESO', 'COMPLETADA', 'COMPLETADA_CON_ERRORES', 'FALLIDA')",
            name="ck_sync_lab_estado",
        ),
        CheckConstraint(
            "total_items >= 0 AND incorporados >= 0 AND pendientes >= 0 "
            "AND duplicados >= 0 AND con_error >= 0 AND reintentos >= 0",
            name="ck_sync_lab_contadores",
        ),
        CheckConstraint("id_usuario IS NOT NULL OR proceso IS NOT NULL", name="ck_sync_lab_responsable"),
        Index("ix_sync_lab_id_clinica", "id_clinica"),
    )

    @property
    def tenant_id(self):
        return self.id_clinica

    def __repr__(self) -> str:
        return f"<SincronizacionLaboratorio(id={self.id_sincronizacion}, estado='{self.estado}')>"


class SincronizacionLaboratorioItem(Base):
    """Resultado de cada ítem de un lote: incorporado, pendiente, duplicado o con error."""

    __tablename__ = "sincronizaciones_laboratorio_items"

    id_item = Column(_PK, primary_key=True, autoincrement=True)
    id_sincronizacion = Column(BigInteger, ForeignKey("sincronizaciones_laboratorio.id_sincronizacion"), nullable=False)
    id_clinica = Column(BigInteger, ForeignKey("clinicas.id_clinica"), nullable=False)
    id_externo = Column(String(100), nullable=False)
    resultado = Column(String(20), nullable=False)
    id_resultado = Column(BigInteger, ForeignKey("resultados_laboratorio.id_resultado"), nullable=True)
    codigo_error = Column(String(50), nullable=True)
    detalle = Column(Text, nullable=True)
    intento = Column(Integer, nullable=False, default=1, server_default="1")
    procesado_en = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    __table_args__ = (
        UniqueConstraint("id_sincronizacion", "id_externo", name="uq_sync_item"),
        CheckConstraint(
            "resultado IN ('INCORPORADO', 'PENDIENTE_REVISION', 'DUPLICADO', 'ERROR')",
            name="ck_sync_item_resultado",
        ),
        Index("ix_sync_items_lab_id_clinica", "id_clinica"),
    )

    @property
    def tenant_id(self):
        return self.id_clinica

    def __repr__(self) -> str:
        return f"<SincronizacionLaboratorioItem(id={self.id_item}, id_externo='{self.id_externo}', resultado='{self.resultado}')>"
