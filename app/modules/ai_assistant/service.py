"""Servicio de negocio para el Asistente Inteligente de Tratamiento (CU18).

Orquesta la recuperación de tratamientos, motor determinista de reglas,
generación con IA con degradación a reglas base, auditoría y control de caché/rate-limiting.
"""
import hashlib
import json
import logging
from datetime import date, datetime, timedelta, timezone
from typing import Any, Dict, List, Optional, Tuple

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session, joinedload

from app.core.audit import registrar_auditoria
from app.modules.ai_assistant.models import (
    AlertaInteraccion,
    EvaluacionAsistencia,
    InteraccionCatalogo,
    RecomendacionTratamiento,
)
from app.modules.ai_assistant.provider import (
    ProviderInvalid,
    ProviderRateLimited,
    ProviderTimeout,
    ProviderUnavailable,
    get_treatment_provider,
)
from app.modules.ai_assistant.rules_engine import (
    detectar_interacciones,
    normalizar_principio_activo,
    obtener_recomendaciones_base,
)
from app.modules.ai_assistant.schemas import (
    AlertaInteraccionDTO,
    CatalogoInteraccionesResponse,
    EvaluacionResumenDTO,
    EvaluacionTratamientoResponse,
    HistorialEvaluacionResponse,
    InteraccionCatalogoDTO,
    MedicamentoAnalizadoDTO,
    RecomendacionTratamientoDTO,
)
from app.modules.auth.models import Usuario
from app.modules.medical_records.hce.models import Consulta, Diagnostico, HistoriaClinica
from app.modules.medical_records.models import Paciente
from app.modules.medical_records.prescriptions.models import Medicamento, Receta, RecetaDetalle

logger = logging.getLogger(__name__)

# Intentar importar modelos CU17 si existen
try:
    from app.modules.medical_records.tratamientos.models import (
        Tratamiento,
        TratamientoMedicamento,
    )
except ImportError:
    Tratamiento = None
    TratamientoMedicamento = None


class AssistanceError(Exception):
    """Excepción de dominio para errores del asistente de tratamiento."""

    def __init__(self, message: str, code: str, status_code: int = 400):
        self.message = message
        self.code = code
        self.status_code = status_code
        super().__init__(message)


def resolver_paciente_desde_usuario(db: Session, usuario: Usuario) -> Paciente:
    """Obtiene la entidad Paciente asociada a un usuario autenticado."""
    stmt = select(Paciente).where(
        Paciente.id_usuario == usuario.id_usuario,
        Paciente.id_clinica == usuario.id_clinica,
    )
    paciente = db.execute(stmt).scalars().first()
    if not paciente:
        # Búsqueda alternativa si Paciente no tiene id_clinica estricto
        stmt_alt = select(Paciente).where(Paciente.id_usuario == usuario.id_usuario)
        paciente = db.execute(stmt_alt).scalars().first()
    if not paciente:
        raise AssistanceError(
            message="Perfil de paciente no encontrado para este usuario",
            code="PATIENT_NOT_FOUND",
            status_code=status.HTTP_404_NOT_FOUND,
        )
    return paciente


def recuperar_medicamentos_vigentes(
    db: Session, id_clinica: int, id_paciente: int
) -> List[Dict[str, Any]]:
    """
    Recupera los medicamentos del tratamiento activo del paciente.
    Prioriza tratamientos activos CU17 y recetas vigentes no anuladas CU16.
    """
    medicamentos: Dict[str, Dict[str, Any]] = {}
    hoy = date.today()

    # 1. Recuperar desde Tratamientos CU17 si están disponibles
    if Tratamiento is not None and TratamientoMedicamento is not None:
        stmt_trat = (
            select(TratamientoMedicamento)
            .join(Tratamiento, TratamientoMedicamento.id_tratamiento == Tratamiento.id_tratamiento)
            .where(
                Tratamiento.id_clinica == id_clinica,
                Tratamiento.id_paciente == id_paciente,
                Tratamiento.estado == "ACTIVO",
                TratamientoMedicamento.estado == "ACTIVO",
                TratamientoMedicamento.fecha_fin >= hoy,
            )
        )
        t_meds = db.execute(stmt_trat).scalars().all()
        for tm in t_meds:
            # Obtener principio activo de receta_detalle si es posible
            pa = None
            if tm.id_receta_detalle:
                stmt_rd = select(RecetaDetalle).where(RecetaDetalle.id_receta_detalle == tm.id_receta_detalle)
                rd = db.execute(stmt_rd).scalars().first()
                if rd:
                    pa = rd.principio_activo or rd.medicamento_nombre
            pa_norm = normalizar_principio_activo(pa or tm.medicamento_nombre)
            key = f"{tm.medicamento_nombre}_{pa_norm}"
            if key not in medicamentos:
                medicamentos[key] = {
                    "id_medicamento": None,
                    "nombre": tm.medicamento_nombre,
                    "principio_activo": pa_norm,
                    "dosis": tm.dosis,
                    "frecuencia": tm.frecuencia_texto_receta,
                    "via_administracion": tm.via_administracion,
                }

    # 2. Recuperar desde Recetas CU16 vigentes (estado EMITIDA y no vencidas)
    stmt_rec = (
        select(RecetaDetalle)
        .join(Receta, RecetaDetalle.id_receta == Receta.id_receta)
        .options(joinedload(RecetaDetalle.medicamento))
        .where(
            Receta.id_clinica == id_clinica,
            Receta.id_paciente == id_paciente,
            Receta.estado == "EMITIDA",
            Receta.fecha_vencimiento >= hoy,
        )
    )
    detalles = db.execute(stmt_rec).scalars().all()
    for d in detalles:
        pa = d.principio_activo
        if not pa and d.medicamento:
            pa = d.medicamento.principio_activo
        pa_norm = normalizar_principio_activo(pa or d.medicamento_nombre)
        key = f"{d.medicamento_nombre}_{pa_norm}"
        if key not in medicamentos:
            medicamentos[key] = {
                "id_medicamento": d.id_medicamento,
                "nombre": d.medicamento_nombre,
                "principio_activo": pa_norm,
                "dosis": d.dosis,
                "frecuencia": d.frecuencia,
                "via_administracion": d.via_administracion,
            }

    return list(medicamentos.values())


def recuperar_antecedentes_y_diagnosticos(
    db: Session, id_clinica: int, id_paciente: int
) -> Tuple[List[str], List[str]]:
    """Recupera diagnósticos CIE y antecedentes del paciente en la clínica."""
    diagnosticos_set = set()
    antecedentes_set = set()

    # Paciente
    stmt_p = select(Paciente).where(Paciente.id_paciente == id_paciente)
    paciente = db.execute(stmt_p).scalars().first()
    if paciente:
        if paciente.alergias:
            antecedentes_set.add(f"Alergias: {paciente.alergias}")
        if paciente.antecedentes_patologicos:
            antecedentes_set.add(f"Antecedentes: {paciente.antecedentes_patologicos}")

    # Historia clínica
    stmt_hc = select(HistoriaClinica).where(
        HistoriaClinica.id_clinica == id_clinica,
        HistoriaClinica.id_paciente == id_paciente,
    )
    hc = db.execute(stmt_hc).scalars().first()
    if hc:
        if hc.alergias:
            antecedentes_set.add(f"Alergias HCE: {hc.alergias}")
        if hc.antecedentes_personales:
            antecedentes_set.add(f"Personales: {hc.antecedentes_personales}")
        if hc.antecedentes_familiares:
            antecedentes_set.add(f"Familiares: {hc.antecedentes_familiares}")

    # Diagnósticos recientes de consultas
    stmt_diag = (
        select(Diagnostico)
        .join(Consulta, Diagnostico.id_consulta == Consulta.id_consulta)
        .join(HistoriaClinica, Consulta.id_historia == HistoriaClinica.id_historia)
        .where(
            HistoriaClinica.id_clinica == id_clinica,
            HistoriaClinica.id_paciente == id_paciente,
        )
        .order_by(Diagnostico.fecha_registro.desc())
        .limit(10)
    )
    diag_rows = db.execute(stmt_diag).scalars().all()
    for dg in diag_rows:
        diagnosticos_set.add(f"{dg.codigo_cie} - {dg.descripcion}")

    return list(diagnosticos_set), list(antecedentes_set)


def calcular_hash_tratamiento(medicamentos: List[Dict[str, Any]], diagnosticos: List[str]) -> str:
    """Calcula un hash SHA-256 canónico del tratamiento para control de caché."""
    med_keys = sorted([f"{m['nombre']}:{m['principio_activo']}" for m in medicamentos])
    diag_keys = sorted(diagnosticos)
    raw = json.dumps({"m": med_keys, "d": diag_keys}, sort_keys=True)
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def evaluar_tratamiento(
    db: Session,
    *,
    id_clinica: int,
    id_paciente: int,
    id_usuario: int,
    forzar_recalculo: bool = False,
    ip_origen: Optional[str] = None,
) -> EvaluacionTratamientoResponse:
    """Ejecuta la evaluación bajo demanda del tratamiento del paciente."""
    # 1. Control de Rate Limiting: Máximo 10 evaluaciones por hora por paciente y clínica
    hace_una_hora = datetime.now(timezone.utc) - timedelta(hours=1)
    stmt_rate = select(func.count(EvaluacionAsistencia.id_evaluacion)).where(
        EvaluacionAsistencia.id_clinica == id_clinica,
        EvaluacionAsistencia.id_paciente == id_paciente,
        EvaluacionAsistencia.fecha_evaluacion >= hace_una_hora,
    )
    eval_count = db.execute(stmt_rate).scalar() or 0
    if eval_count >= 10:
        raise AssistanceError(
            message="Límite de 10 evaluaciones por hora superado",
            code="RATE_LIMIT_EXCEEDED",
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
        )

    # 2. Recuperar medicamentos vigentes
    meds = recuperar_medicamentos_vigentes(db, id_clinica, id_paciente)
    diagnosticos, antecedentes = recuperar_antecedentes_y_diagnosticos(db, id_clinica, id_paciente)

    # Si no hay medicamentos vigentes: responder SIN_TRATAMIENTO_VIGENTE
    if not meds:
        return EvaluacionTratamientoResponse(
            id_evaluacion=None,
            id_paciente=id_paciente,
            fecha_evaluacion=datetime.now(timezone.utc),
            estado_evaluacion="SIN_TRATAMIENTO_VIGENTE",
            nivel_riesgo_global="SIN_RIESGO",
            total_medicamentos_analizados=0,
            total_alertas_detectadas=0,
            resumen_ejecutivo="No cuenta con recetas ni medicamentos vigentes registrados en la clínica en este momento.",
            medicamentos_analizados=[],
            alertas=[],
            recomendaciones=[],
        )

    # 3. Control de Caché de Pre-evaluación (10 minutos)
    hash_prescripciones = calcular_hash_tratamiento(meds, diagnosticos)
    if not forzar_recalculo:
        hace_diez_min = datetime.now(timezone.utc) - timedelta(minutes=10)
        stmt_cache = (
            select(EvaluacionAsistencia)
            .options(
                joinedload(EvaluacionAsistencia.alertas),
                joinedload(EvaluacionAsistencia.recomendaciones),
            )
            .where(
                EvaluacionAsistencia.id_clinica == id_clinica,
                EvaluacionAsistencia.id_paciente == id_paciente,
                EvaluacionAsistencia.hash_prescripciones == hash_prescripciones,
                EvaluacionAsistencia.fecha_evaluacion >= hace_diez_min,
            )
            .order_by(EvaluacionAsistencia.fecha_evaluacion.desc())
        )
        eval_cache = db.execute(stmt_cache).scalars().first()
        if eval_cache:
            return armar_response_desde_modelo(eval_cache)

    # 4. Motor Determinista de Reglas (Detección de Interacciones)
    alertas_detectadas = detectar_interacciones(db, meds)

    # Determinar nivel de riesgo global
    severidades = [a.severidad for a in alertas_detectadas]
    if "GRAVE" in severidades:
        nivel_riesgo_global = "ALTO"
    elif "MODERADA" in severidades:
        nivel_riesgo_global = "MEDIO"
    elif "LEVE" in severidades:
        nivel_riesgo_global = "BAJO"
    else:
        nivel_riesgo_global = "SIN_RIESGO"

    # 5. Generación de Sugerencias Contextuales (IA con degradación tolerante a fallos)
    recomendaciones_data: List[Dict[str, str]] = []
    estado_evaluacion = "COMPLETADA"
    proveedor_utilizado = "groq"

    contexto_ia = {
        "medicamentos": meds,
        "diagnosticos": diagnosticos,
        "antecedentes": antecedentes,
        "alertas_detectadas": [
            {"severidad": a.severidad, "riesgo": a.mensaje_alerta}
            for a in alertas_detectadas
        ],
    }

    provider = get_treatment_provider()
    try:
        recomendaciones_ia = provider.generate_recommendations(contexto_ia)
        for r in recomendaciones_ia:
            recomendaciones_data.append({
                "categoria": r.get("categoria", "PRECAUCION_GENERAL"),
                "titulo": r.get("titulo", "Recomendación de cuidado"),
                "detalle": r.get("detalle", ""),
                "origen": "IA_GENERATIVA",
            })
    except (ProviderUnavailable, ProviderTimeout, ProviderRateLimited, ProviderInvalid) as exc:
        logger.warning("Fallo en proveedor de IA (%s). Degradando a reglas base.", exc)
        estado_evaluacion = "DEGRADADO_REGLAS_BASE"
        proveedor_utilizado = "rules-fallback"
        recomendaciones_data = obtener_recomendaciones_base(meds, diagnosticos, antecedentes)

    # Si la lista de recomendaciones de IA estuviese vacía
    if not recomendaciones_data:
        recomendaciones_data = obtener_recomendaciones_base(meds, diagnosticos, antecedentes)

    # 6. Elaborar resumen ejecutivo
    if alertas_detectadas:
        resumen_ejecutivo = (
            f"Se detectó {len(alertas_detectadas)} interacción(es) farmacológica(s) "
            f"entre los medicamentos analizados. Revise las precauciones indicadas."
        )
    else:
        resumen_ejecutivo = "No se detectaron interacciones adversas entre sus medicamentos vigentes."

    if estado_evaluacion == "DEGRADADO_REGLAS_BASE":
        resumen_ejecutivo += " (Evaluación realizada con reglas clínicas base debido a indisponibilidad temporal del asistente de lenguaje)."

    # 7. Persistir la evaluación de forma inmutable
    evaluacion_row = EvaluacionAsistencia(
        id_clinica=id_clinica,
        id_paciente=id_paciente,
        id_usuario=id_usuario,
        fecha_evaluacion=datetime.now(timezone.utc),
        estado_evaluacion=estado_evaluacion,
        nivel_riesgo_global=nivel_riesgo_global,
        total_medicamentos_analizados=len(meds),
        total_alertas_detectadas=len(alertas_detectadas),
        resumen_ejecutivo=resumen_ejecutivo,
        hash_prescripciones=hash_prescripciones,
        proveedor_ia_utilizado=proveedor_utilizado,
        medicamentos_snapshot=meds,
    )
    db.add(evaluacion_row)
    db.flush()

    # Guardar alertas
    for alt in alertas_detectadas:
        alerta_row = AlertaInteraccion(
            id_evaluacion=evaluacion_row.id_evaluacion,
            id_interaccion=alt.id_interaccion,
            principio_activo_1=alt.principio_activo_1,
            principio_activo_2=alt.principio_activo_2,
            medicamento_1_nombre=alt.medicamento_1_nombre,
            medicamento_2_nombre=alt.medicamento_2_nombre,
            severidad=alt.severidad,
            color_alerta=alt.color_alerta,
            mensaje_alerta=alt.mensaje_alerta,
            pauta_precaucion=alt.pauta_precaucion,
        )
        db.add(alerta_row)

    # Guardar recomendaciones
    for rec in recomendaciones_data:
        rec_row = RecomendacionTratamiento(
            id_evaluacion=evaluacion_row.id_evaluacion,
            categoria=rec["categoria"],
            titulo=rec["titulo"],
            detalle=rec["detalle"],
            origen=rec["origen"],
        )
        db.add(rec_row)

    # 8. Auditoría atómica en la misma transacción
    registrar_auditoria(
        db,
        id_usuario=id_usuario,
        id_clinica=id_clinica,
        tabla_afectada="evaluaciones_asistencia",
        registro_id=evaluacion_row.id_evaluacion,
        accion="EVALUAR_TRATAMIENTO",
        descripcion=f"Evaluación de tratamiento del paciente {id_paciente}: {nivel_riesgo_global} riesgo, {len(alertas_detectadas)} alertas",
        datos_nuevos={
            "estado": estado_evaluacion,
            "riesgo": nivel_riesgo_global,
            "total_alertas": len(alertas_detectadas),
            "total_medicamentos": len(meds),
        },
        direccion_ip=ip_origen,
    )

    db.commit()
    db.refresh(evaluacion_row)

    return armar_response_desde_modelo(evaluacion_row, medicamentos_analizados=meds)


def armar_response_desde_modelo(
    eval_model: EvaluacionAsistencia,
    medicamentos_analizados: Optional[List[Dict[str, Any]]] = None,
) -> EvaluacionTratamientoResponse:
    """Convierte el modelo ORM en el DTO de respuesta Pydantic."""
    meds_dto: List[MedicamentoAnalizadoDTO] = []
    meds_source = medicamentos_analizados or eval_model.medicamentos_snapshot or []
    for m in meds_source:
        meds_dto.append(
            MedicamentoAnalizadoDTO(
                id_medicamento=m.get("id_medicamento"),
                nombre=m.get("nombre", ""),
                principio_activo=m.get("principio_activo", ""),
                dosis=m.get("dosis", ""),
                frecuencia=m.get("frecuencia", ""),
                via_administracion=m.get("via_administracion"),
            )
        )

    alertas_dto = [
        AlertaInteraccionDTO(
            id_alerta=a.id_alerta,
            principio_activo_1=a.principio_activo_1,
            principio_activo_2=a.principio_activo_2,
            medicamento_1_nombre=a.medicamento_1_nombre,
            medicamento_2_nombre=a.medicamento_2_nombre,
            severidad=a.severidad,
            color_alerta=a.color_alerta,
            mensaje_alerta=a.mensaje_alerta,
            pauta_precaucion=a.pauta_precaucion,
        )
        for a in eval_model.alertas
    ]

    recs_dto = [
        RecomendacionTratamientoDTO(
            id_recomendacion=r.id_recomendacion,
            categoria=r.categoria,
            titulo=r.titulo,
            detalle=r.detalle,
            origen=r.origen,
        )
        for r in eval_model.recomendaciones
    ]

    return EvaluacionTratamientoResponse(
        id_evaluacion=eval_model.id_evaluacion,
        id_paciente=eval_model.id_paciente,
        fecha_evaluacion=eval_model.fecha_evaluacion,
        estado_evaluacion=eval_model.estado_evaluacion,
        nivel_riesgo_global=eval_model.nivel_riesgo_global,
        total_medicamentos_analizados=eval_model.total_medicamentos_analizados,
        total_alertas_detectadas=eval_model.total_alertas_detectadas,
        resumen_ejecutivo=eval_model.resumen_ejecutivo,
        aviso_legal=eval_model.aviso_legal,
        medicamentos_analizados=meds_dto,
        alertas=alertas_dto,
        recomendaciones=recs_dto,
    )


def listar_historial(
    db: Session,
    *,
    id_clinica: int,
    id_paciente: int,
    page: int = 1,
    limit: int = 10,
) -> HistorialEvaluacionResponse:
    """Retorna el historial paginado de evaluaciones de un paciente en su clínica."""
    offset = (page - 1) * limit
    stmt_count = select(func.count(EvaluacionAsistencia.id_evaluacion)).where(
        EvaluacionAsistencia.id_clinica == id_clinica,
        EvaluacionAsistencia.id_paciente == id_paciente,
    )
    total = db.execute(stmt_count).scalar() or 0

    stmt_items = (
        select(EvaluacionAsistencia)
        .where(
            EvaluacionAsistencia.id_clinica == id_clinica,
            EvaluacionAsistencia.id_paciente == id_paciente,
        )
        .order_by(EvaluacionAsistencia.fecha_evaluacion.desc())
        .offset(offset)
        .limit(limit)
    )
    items_rows = db.execute(stmt_items).scalars().all()

    items_dto = [
        EvaluacionResumenDTO(
            id_evaluacion=e.id_evaluacion,
            id_paciente=e.id_paciente,
            fecha_evaluacion=e.fecha_evaluacion,
            estado_evaluacion=e.estado_evaluacion,
            nivel_riesgo_global=e.nivel_riesgo_global,
            total_medicamentos_analizados=e.total_medicamentos_analizados,
            total_alertas_detectadas=e.total_alertas_detectadas,
            resumen_ejecutivo=e.resumen_ejecutivo,
        )
        for e in items_rows
    ]

    total_paginas = (total + limit - 1) // limit if limit > 0 else 1

    return HistorialEvaluacionResponse(
        items=items_dto,
        total=total,
        page=page,
        limit=limit,
        total_paginas=total_paginas,
    )


def obtener_evaluacion_por_id(
    db: Session,
    *,
    id_evaluacion: int,
    id_clinica: int,
) -> EvaluacionTratamientoResponse:
    """Recupera el detalle completo de una evaluación con aislamiento por clínica."""
    stmt = (
        select(EvaluacionAsistencia)
        .options(
            joinedload(EvaluacionAsistencia.alertas),
            joinedload(EvaluacionAsistencia.recomendaciones),
        )
        .where(
            EvaluacionAsistencia.id_evaluacion == id_evaluacion,
            EvaluacionAsistencia.id_clinica == id_clinica,
        )
    )
    eval_model = db.execute(stmt).scalars().first()
    if not eval_model:
        raise AssistanceError(
            message="Evaluación no encontrada",
            code="EVALUATION_NOT_FOUND",
            status_code=status.HTTP_404_NOT_FOUND,
        )

    return armar_response_desde_modelo(eval_model)


def listar_catalogo_interacciones(
    db: Session,
    *,
    principio_activo: Optional[str] = None,
    severidad: Optional[str] = None,
    page: int = 1,
    limit: int = 20,
) -> CatalogoInteraccionesResponse:
    """Lista las interacciones farmacológicas registradas en el catálogo global."""
    offset = (page - 1) * limit
    stmt = select(InteraccionCatalogo).where(InteraccionCatalogo.estado == "ACTIVO")

    if principio_activo:
        pa_norm = normalizar_principio_activo(principio_activo)
        stmt = stmt.where(
            (InteraccionCatalogo.principio_activo_a.ilike(f"%{pa_norm}%"))
            | (InteraccionCatalogo.principio_activo_b.ilike(f"%{pa_norm}%"))
        )

    if severidad:
        stmt = stmt.where(InteraccionCatalogo.severidad == severidad.upper())

    stmt_count = select(func.count()).select_from(stmt.subquery())
    total = db.execute(stmt_count).scalar() or 0

    stmt_items = stmt.order_by(InteraccionCatalogo.id_interaccion.asc()).offset(offset).limit(limit)
    rows = db.execute(stmt_items).scalars().all()

    items_dto = [
        InteraccionCatalogoDTO(
            id_interaccion=r.id_interaccion,
            principio_activo_a=r.principio_activo_a,
            principio_activo_b=r.principio_activo_b,
            severidad=r.severidad,
            mecanismo=r.mecanismo,
            descripcion_riesgo=r.descripcion_riesgo,
            recomendacion_clinica=r.recomendacion_clinica,
            estado=r.estado,
        )
        for r in rows
    ]

    total_paginas = (total + limit - 1) // limit if limit > 0 else 1

    return CatalogoInteraccionesResponse(
        items=items_dto,
        total=total,
        page=page,
        limit=limit,
        total_paginas=total_paginas,
    )
