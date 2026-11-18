"""CU36 usage accounting and Stripe Checkout adapter; isolated from CU19/CU31."""
import json
import logging
import os
import uuid
from datetime import datetime, timedelta, timezone
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path
from urllib.parse import urlencode
from urllib.parse import parse_qsl, urlsplit, urlunsplit

import httpx
from dotenv import dotenv_values
from fastapi import HTTPException
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.audit import registrar_auditoria
from app.core.config import settings
from app.modules.appointments.models import Medico
from app.modules.auth.models import VersionPlan
from app.modules.medical_records.hce.models import Consulta
from app.modules.payments.service import _stripe_request, stripe_habilitado, verificar_firma_stripe
from app.modules.tenants.models import SubscriptionChange, SubscriptionPayment, TenantSubscription
from .models import (
    AvisoConsumo, CicloConsumo, EventoStripeExcedente, FotografiaConsumo,
    LiquidacionExcedente, PagoExcedente, RenglonLiquidacion,
)

logger = logging.getLogger(__name__)
CENT = Decimal("0.01")
ZERO = Decimal("0")
RESOURCE = {
    "MEDICOS": ("Médicos", "MEDICO_CICLO_MENSUAL", "limite_medicos"),
    "SEDES": ("Sedes", "SEDE_CICLO_MENSUAL", "limite_sedes"),
    "CONSULTAS": ("Consultas", "CONSULTA", "limite_consultas"),
}


class BillingError(Exception):
    def __init__(self, status: int, code: str, detail: str):
        self.status, self.code, self.detail = status, code, detail


class BillingHttpException(HTTPException):
    """CU36 domain error serialized as {detail: string, code: BILLING_*}."""
    def __init__(self, status: int, code: str, detail: str):
        self.code = code
        super().__init__(status_code=status, detail=detail)


def utcnow():
    return datetime.now(timezone.utc)


def as_utc(value: datetime) -> datetime:
    return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value.astimezone(timezone.utc)


def dec(value) -> Decimal:
    return Decimal(str(value if value is not None else 0))


def decimal_text(value: Decimal | int | None, places: int | None = None) -> str | None:
    if value is None:
        return None
    amount = dec(value)
    if places is not None:
        amount = amount.quantize(Decimal(1).scaleb(-places), rounding=ROUND_HALF_UP)
        return format(amount, f".{places}f")
    text = format(amount.normalize(), "f")
    return "0" if text in ("-0", "") else text


def money_text(value) -> str:
    return decimal_text(dec(value), 2) or "0.00"


def _cu36_env(name: str, default: str = "") -> str:
    """Read dedicated CU36 configuration without changing the shared Settings model."""
    value = os.environ.get(name)
    if value is None:
        env_path = Path(__file__).resolve().parents[3] / ".env"
        value = dotenv_values(env_path).get(name)
    return str(value or default).strip()


def _gateway_secret() -> str:
    try:
        return settings.STRIPE_SECRET_KEY.get_secret_value().strip()
    except Exception:
        return str(settings.STRIPE_SECRET_KEY or "").strip()


def require_test_gateway():
    secret = _gateway_secret()
    if not stripe_habilitado() or not secret.startswith("sk_test_") or secret.startswith("sk_live_"):
        raise BillingError(503, "BILLING_GATEWAY_UNAVAILABLE", "La pasarela de prueba no está configurada")
    return secret


def _rate(version: VersionPlan, recurso: str) -> Decimal | None:
    tariffs = version.tarifas_excedentes or []
    if isinstance(tariffs, dict):
        tariffs = [dict(recurso=key, **(value or {})) for key, value in tariffs.items()]
    for item in tariffs:
        if isinstance(item, dict) and str(item.get("recurso", "")).upper() == recurso:
            return dec(item.get("precio"))
    return None


def _versiones_ciclo(db: Session, sub: TenantSubscription, start: datetime, end: datetime,
                     base_version_id: int | None = None):
    ids = {int(base_version_id or sub.id_version_plan)}
    changes = db.scalars(select(SubscriptionChange).where(
        SubscriptionChange.id_clinica == sub.id_clinica,
        SubscriptionChange.id_suscripcion == sub.id_suscripcion,
        SubscriptionChange.operation == "IMMEDIATE",
        SubscriptionChange.status == "APPLIED",
    )).all()
    for change in changes:
        effective = as_utc(change.effective_at or change.applied_at)
        if start <= effective < end:
            ids.add(int(change.source_version_id))
            if change.target_version_id is not None:
                ids.add(int(change.target_version_id))
    versions = db.scalars(select(VersionPlan).where(VersionPlan.id.in_(sorted(ids))).order_by(VersionPlan.numero)).all()
    return versions


def _resource_terms(versions, resource):
    limit_field = RESOURCE[resource][2]
    limits = [getattr(version, limit_field) for version in versions]
    # Any unlimited version or a missing tariff means this resource is excluded from V1 charging.
    if any(limit is None for limit in limits):
        return None, None, "ILIMITADO"
    rates = [_rate(version, resource) for version in versions]
    if any(rate is None for rate in rates):
        return max(limits), None, "SIN_TARIFA"
    return max(limits), min(rates), "LISTO"


def _plan_summary(version):
    return {"id_version_plan": int(version.id), "plan_id": int(version.plan_id),
            "numero": int(version.numero), "nombre": version.nombre}


def _load_cycle(db: Session, sub: TenantSubscription, *, create: bool,
                interval_start: datetime | None = None, interval_end: datetime | None = None):
    start, end = as_utc(interval_start or sub.fecha_inicio), as_utc(interval_end or sub.fecha_fin)
    if end <= start:
        raise BillingHttpException(404, "BILLING_SUBSCRIPTION_NOT_FOUND", "No hay ciclo vigente")
    cycle = db.scalar(select(CicloConsumo).where(
        CicloConsumo.id_clinica == sub.id_clinica,
        CicloConsumo.id_suscripcion == sub.id_suscripcion,
        CicloConsumo.inicio == start, CicloConsumo.fin_exclusivo == end,
    ).with_for_update())
    if cycle is None and create:
        cycle = CicloConsumo(id_clinica=sub.id_clinica, id_suscripcion=sub.id_suscripcion,
                             inicio=start, fin_exclusivo=end, estado="ABIERTO")
        db.add(cycle)
        try:
            db.flush()
        except IntegrityError:
            db.rollback()
            cycle = db.scalar(select(CicloConsumo).where(
                CicloConsumo.id_clinica == sub.id_clinica,
                CicloConsumo.id_suscripcion == sub.id_suscripcion,
                CicloConsumo.inicio == start, CicloConsumo.fin_exclusivo == end,
            ).with_for_update())
    return cycle


def _usage(db: Session, clinic_id: int, cycle: CicloConsumo, *, final: bool = False):
    doctor_ids = db.scalars(select(Medico.id_medico).where(
        Medico.id_clinica == clinic_id, func.lower(Medico.estado).in_(("activo", "active"))
    ).order_by(Medico.id_medico)).all()
    consultation_ids = db.scalars(select(Consulta.id_consulta).where(
        Consulta.id_clinica == clinic_id,
        Consulta.fecha_consulta >= cycle.inicio.replace(tzinfo=None),
        Consulta.fecha_consulta < cycle.fin_exclusivo.replace(tzinfo=None),
    ).distinct().order_by(Consulta.id_consulta)).all()
    doctors = len(doctor_ids)
    consultations = len(consultation_ids)
    db.add_all([
        FotografiaConsumo(id_ciclo=cycle.id_ciclo, recurso="MEDICOS", cantidad=doctors,
                          ids_observados=doctor_ids if final else None, tipo="CIERRE" if final else "LECTURA"),
        FotografiaConsumo(id_ciclo=cycle.id_ciclo, recurso="CONSULTAS", cantidad=consultations,
                          ids_observados=consultation_ids if final else None, tipo="CIERRE" if final else "LECTURA"),
        FotografiaConsumo(id_ciclo=cycle.id_ciclo, recurso="SEDES", cantidad=None,
                          ids_observados=None, tipo="CIERRE" if final else "LECTURA"),
    ])
    return {"MEDICOS": doctors, "CONSULTAS": consultations, "SEDES": None}, doctor_ids, consultation_ids


def _make_notice(db: Session, cycle: CicloConsumo, resource: str, threshold: Decimal, kind: str,
                 used: Decimal, limit: Decimal):
    existing = db.scalar(select(AvisoConsumo.id_aviso).where(
        AvisoConsumo.id_clinica == cycle.id_clinica, AvisoConsumo.id_ciclo == cycle.id_ciclo,
        AvisoConsumo.recurso == resource, AvisoConsumo.umbral_porcentaje == threshold,
    ))
    if existing:
        return
    label = RESOURCE[resource][0]
    title = "Límite de consumo alcanzado" if kind == "LIMITE" else "Consumo próximo al límite"
    message = (f"{label}: uso {decimal_text(used)} de {decimal_text(limit)} unidades "
               f"({decimal_text(threshold, 0)} % del límite incluido).")
    db.add(AvisoConsumo(id_clinica=cycle.id_clinica, id_ciclo=cycle.id_ciclo, recurso=resource,
                        tipo=kind, umbral_porcentaje=threshold, titulo=title, mensaje=message))


def _threshold_notices(db: Session, cycle: CicloConsumo, usage: dict, versions):
    for resource in ("MEDICOS", "CONSULTAS"):
        limit, _, state = _resource_terms(versions, resource)
        used = usage[resource]
        if used is None or limit is None or state == "ILIMITADO":
            continue
        limit_d, used_d = dec(limit), dec(used)
        if limit_d == ZERO:
            if used_d > ZERO:
                _make_notice(db, cycle, resource, Decimal("100"), "LIMITE", used_d, limit_d)
            continue
        percent = (used_d * Decimal("100") / limit_d)
        if percent >= Decimal("80"):
            _make_notice(db, cycle, resource, Decimal("80"), "UMBRAL", used_d, limit_d)
        if percent >= Decimal("100"):
            _make_notice(db, cycle, resource, Decimal("100"), "LIMITE", used_d, limit_d)


def _service_rows(usage, versions):
    rows, total = [], ZERO
    for resource in ("MEDICOS", "SEDES", "CONSULTAS"):
        name, unit, _ = RESOURCE[resource]
        used = usage.get(resource)
        if resource == "SEDES":
            rows.append({"recurso": resource, "nombre": name, "unidad": unit,
                "limite_incluido": decimal_text(getattr(versions[-1], "limite_sedes")),
                "consumo_validado": None, "saldo_disponible": None, "porcentaje_uso": None,
                "unidades_excedidas": None, "tarifa_excedente": None, "subtotal_estimado": None,
                "estado_medicion": "MEDICION_NO_DISPONIBLE"})
            continue
        limit, rate, state = _resource_terms(versions, resource)
        if state == "ILIMITADO":
            rows.append({"recurso": resource, "nombre": name, "unidad": unit,
                "limite_incluido": None, "consumo_validado": decimal_text(used),
                "saldo_disponible": None, "porcentaje_uso": None, "unidades_excedidas": "0",
                "tarifa_excedente": None, "subtotal_estimado": "0.00", "estado_medicion": state})
            continue
        use_d, limit_d = dec(used), dec(limit)
        excess = max(ZERO, use_d - limit_d)
        percent = None if limit_d == ZERO else use_d * Decimal("100") / limit_d
        subtotal = None if rate is None else (excess * rate).quantize(CENT, rounding=ROUND_HALF_UP)
        if subtotal is not None:
            total += subtotal
        rows.append({"recurso": resource, "nombre": name, "unidad": unit,
            "limite_incluido": decimal_text(limit_d), "consumo_validado": decimal_text(use_d),
            "saldo_disponible": decimal_text(max(ZERO, limit_d - use_d)),
            "porcentaje_uso": decimal_text(percent, 2), "unidades_excedidas": decimal_text(excess),
            "tarifa_excedente": money_text(rate) if rate is not None else None,
            "subtotal_estimado": money_text(subtotal) if subtotal is not None else None,
            "estado_medicion": state})
    return rows, total


def resumen_actual(db: Session, clinic_id: int):
    sub = db.scalar(select(TenantSubscription).where(
        TenantSubscription.id_clinica == clinic_id,
        TenantSubscription.estado.in_(("ACTIVE", "PAST_DUE", "TRIALING")),
    ))
    now = utcnow()
    if sub is None or not as_utc(sub.fecha_inicio) <= now < as_utc(sub.fecha_fin):
        raise BillingHttpException(404, "BILLING_SUBSCRIPTION_NOT_FOUND", "No hay suscripción o ciclo vigente")
    cycle = _load_cycle(db, sub, create=True)
    version = db.get(VersionPlan, sub.id_version_plan)
    if version is None:
        raise BillingHttpException(409, "BILLING_PLAN_NOT_FOUND", "La versión del plan no está disponible")
    versions = _versiones_ciclo(db, sub, cycle.inicio, cycle.fin_exclusivo)
    if not versions:
        versions = [version]
    frozen = cycle.estado != "ABIERTO" and cycle.consulta_ids is not None
    if frozen:
        usage = {"CONSULTAS": len(cycle.consulta_ids), "MEDICOS": cycle.medicos_activos_cierre, "SEDES": None}
        db.add_all([
            FotografiaConsumo(id_ciclo=cycle.id_ciclo, recurso="MEDICOS", cantidad=usage["MEDICOS"], tipo="LECTURA"),
            FotografiaConsumo(id_ciclo=cycle.id_ciclo, recurso="CONSULTAS", cantidad=usage["CONSULTAS"], tipo="LECTURA"),
        ])
    else:
        usage, _, _ = _usage(db, clinic_id, cycle)
        _threshold_notices(db, cycle, usage, versions)
    rows, total = _service_rows(usage, versions)
    liquidation = db.scalar(select(LiquidacionExcedente.id_liquidacion).where(
        LiquidacionExcedente.id_clinica == clinic_id, LiquidacionExcedente.id_ciclo == cycle.id_ciclo))
    cycle.actualizado_en = utcnow()
    db.commit()
    return {"id_ciclo": cycle.id_ciclo, "id_suscripcion": sub.id_suscripcion,
        "plan": _plan_summary(version), "inicio": cycle.inicio, "fin_exclusivo": cycle.fin_exclusivo,
        "moneda": "BOB", "estado": cycle.estado, "actualizado_en": cycle.actualizado_en,
        "servicios": rows, "total_excedente_estimado": money_text(total), "liquidacion_id": liquidation}


def _line_response(line: RenglonLiquidacion):
    return {"recurso": line.recurso, "unidad": line.unidad,
        "consumo_validado": decimal_text(line.consumo_validado),
        "limite_aplicado": decimal_text(line.limite_aplicado),
        "unidades_excedidas": decimal_text(line.unidades_excedidas),
        "tarifa_aplicada": decimal_text(line.tarifa_aplicada, 2),
        "subtotal": money_text(line.subtotal),
        "versiones_plan_consideradas": list(line.versiones_plan_consideradas or []),
        "regla": line.regla}


def _liquidation_response(db: Session, liquidation: LiquidacionExcedente):
    lines = db.scalars(select(RenglonLiquidacion).where(
        RenglonLiquidacion.id_liquidacion == liquidation.id_liquidacion).order_by(RenglonLiquidacion.recurso)).all()
    return {"id_liquidacion": liquidation.id_liquidacion, "id_ciclo": liquidation.id_ciclo,
        "id_suscripcion": liquidation.id_suscripcion, "version": liquidation.version,
        "renglones": [_line_response(line) for line in lines], "total": money_text(liquidation.total),
        "moneda": "BOB", "estado": liquidation.estado, "emitida_en": liquidation.emitida_en,
        "pagada_en": liquidation.pagada_en, "motivo_revision": liquidation.motivo_revision,
        "comprobante_disponible": liquidation.estado == "PAGADA"}


def _payment_response(payment: PagoExcedente, *, administrative=False):
    result = {"id_pago_excedente": payment.id_pago_excedente, "id_liquidacion": payment.id_liquidacion,
        "estado": payment.estado, "monto": money_text(payment.monto), "moneda": "BOB",
        "checkout_url": payment.checkout_url, "expira_en": payment.expira_en,
        "creado_en": payment.creado_en, "confirmado_en": payment.confirmado_en}
    if administrative:
        result["stripe_session_id"] = payment.stripe_session_id
    return result


def list_notices(db: Session, clinic_id: int, unread: bool | None, skip: int, limit: int):
    query = select(AvisoConsumo).where(AvisoConsumo.id_clinica == clinic_id)
    if unread is True:
        query = query.where(AvisoConsumo.leido_en.is_(None))
    elif unread is False:
        query = query.where(AvisoConsumo.leido_en.is_not(None))
    total = db.scalar(select(func.count()).select_from(query.subquery())) or 0
    rows = db.scalars(query.order_by(AvisoConsumo.creado_en.desc()).offset(skip).limit(limit)).all()
    return {"items": [{"id_aviso": row.id_aviso, "id_ciclo": row.id_ciclo, "recurso": row.recurso,
        "tipo": row.tipo, "umbral_porcentaje": decimal_text(row.umbral_porcentaje), "titulo": row.titulo,
        "mensaje": row.mensaje, "creado_en": row.creado_en, "leido_en": row.leido_en} for row in rows],
        "total": int(total)}


def mark_notice_read(db: Session, clinic_id: int, notice_id: str):
    notice = db.scalar(select(AvisoConsumo).where(
        AvisoConsumo.id_aviso == notice_id, AvisoConsumo.id_clinica == clinic_id).with_for_update())
    if notice is None:
        raise BillingHttpException(404, "BILLING_RESOURCE_NOT_FOUND", "Aviso no encontrado")
    if notice.leido_en is None:
        notice.leido_en = utcnow()
        db.commit()
    return {"id_aviso": notice.id_aviso, "id_ciclo": notice.id_ciclo, "recurso": notice.recurso,
        "tipo": notice.tipo, "umbral_porcentaje": decimal_text(notice.umbral_porcentaje), "titulo": notice.titulo,
        "mensaje": notice.mensaje, "creado_en": notice.creado_en, "leido_en": notice.leido_en}


def list_liquidations(db: Session, clinic_id: int, cycle_id: str | None, skip: int, limit: int):
    query = select(LiquidacionExcedente).where(LiquidacionExcedente.id_clinica == clinic_id)
    if cycle_id:
        query = query.where(LiquidacionExcedente.id_ciclo == cycle_id)
    total = db.scalar(select(func.count()).select_from(query.subquery())) or 0
    rows = db.scalars(query.order_by(LiquidacionExcedente.emitida_en.desc()).offset(skip).limit(limit)).all()
    return {"items": [_liquidation_response(db, row) for row in rows], "total": int(total)}


def get_liquidation(db: Session, clinic_id: int, liquidation_id: str):
    liquidation = db.scalar(select(LiquidacionExcedente).where(
        LiquidacionExcedente.id_liquidacion == liquidation_id,
        LiquidacionExcedente.id_clinica == clinic_id))
    if liquidation is None:
        raise BillingHttpException(404, "BILLING_RESOURCE_NOT_FOUND", "Liquidación no encontrada")
    return _liquidation_response(db, liquidation)


def list_payments(db: Session, clinic_id: int, liquidation_id: str, skip: int, limit: int):
    owns = db.scalar(select(LiquidacionExcedente.id_liquidacion).where(
        LiquidacionExcedente.id_liquidacion == liquidation_id,
        LiquidacionExcedente.id_clinica == clinic_id))
    if owns is None:
        raise BillingHttpException(404, "BILLING_RESOURCE_NOT_FOUND", "Liquidación no encontrada")
    query = select(PagoExcedente).where(PagoExcedente.id_clinica == clinic_id,
        PagoExcedente.id_liquidacion == liquidation_id)
    total = db.scalar(select(func.count()).select_from(query.subquery())) or 0
    rows = db.scalars(query.order_by(PagoExcedente.creado_en.desc()).offset(skip).limit(limit)).all()
    return {"items": [_payment_response(row) for row in rows], "total": int(total)}


def get_receipt(db: Session, clinic_id: int, liquidation_id: str):
    liquidation = db.scalar(select(LiquidacionExcedente).where(
        LiquidacionExcedente.id_liquidacion == liquidation_id,
        LiquidacionExcedente.id_clinica == clinic_id))
    if liquidation is None:
        raise BillingHttpException(404, "BILLING_RESOURCE_NOT_FOUND", "Liquidación no encontrada")
    if liquidation.estado != "PAGADA":
        raise BillingHttpException(409, "BILLING_PAYMENT_NOT_CONFIRMED", "No existe un pago confirmado")
    payment = db.scalar(select(PagoExcedente).where(
        PagoExcedente.id_liquidacion == liquidation_id, PagoExcedente.id_clinica == clinic_id,
        PagoExcedente.estado == "PAGADO").order_by(PagoExcedente.confirmado_en.desc()))
    if payment is None:
        raise BillingHttpException(409, "BILLING_PAYMENT_NOT_CONFIRMED", "No existe un pago confirmado")
    lines = db.scalars(select(RenglonLiquidacion).where(
        RenglonLiquidacion.id_liquidacion == liquidation_id).order_by(RenglonLiquidacion.recurso)).all()
    return {"id_liquidacion": liquidation_id, "id_pago_excedente": payment.id_pago_excedente,
        "id_ciclo": liquidation.id_ciclo, "fecha_pago": payment.confirmado_en, "moneda": "BOB",
        "renglones": [_line_response(line) for line in lines], "total": money_text(liquidation.total),
        "referencia_stripe": payment.stripe_payment_intent_id or payment.stripe_session_id,
        "documento_url": None}


def close_due_cycles(db: Session, now: datetime | None = None):
    now = as_utc(now or utcnow())
    subscriptions = db.scalars(select(TenantSubscription).order_by(TenantSubscription.id_clinica)).all()
    closed = 0
    for sub in subscriptions:
        intervals = {}
        current_start, current_end = as_utc(sub.fecha_inicio), as_utc(sub.fecha_fin)
        if current_end <= now:
            intervals[(current_start, current_end)] = int(sub.id_version_plan)
        # CU31 updates TenantSubscription in place at renewal. Recover prior cycle boundaries
        # from its immutable payment ledger so a delayed CU36 worker still closes each interval.
        renewals = db.scalars(select(SubscriptionPayment).where(
            SubscriptionPayment.id_clinica == sub.id_clinica,
            SubscriptionPayment.id_suscripcion == sub.id_suscripcion,
            SubscriptionPayment.purpose == "RENEWAL",
            SubscriptionPayment.estado == "PAGADO",
            SubscriptionPayment.period_start.is_not(None),
            SubscriptionPayment.period_end <= now,
        )).all()
        for payment in renewals:
            start, end = as_utc(payment.period_start), as_utc(payment.period_end)
            intervals.setdefault((start, end), int(payment.id_version_plan))
        for (start, end), base_version_id in sorted(intervals.items(), key=lambda entry: entry[0][1]):
            cycle = _load_cycle(db, sub, create=True, interval_start=start, interval_end=end)
            if cycle is None:
                continue
            if cycle.estado != "ABIERTO":
                _review_late_usage(db, sub, cycle)
                continue
            versions = _versiones_ciclo(db, sub, cycle.inicio, cycle.fin_exclusivo, base_version_id)
            if not versions:
                version = db.get(VersionPlan, base_version_id)
                if version is None:
                    cycle.estado = "REVISION_REQUERIDA"
                    db.commit()
                    continue
                versions = [version]
            usage, doctor_ids, consultation_ids = _usage(db, sub.id_clinica, cycle, final=True)
            cycle.medicos_activos_cierre = len(doctor_ids)
            cycle.consulta_ids = list(consultation_ids)
            cycle.plan_versiones = [int(version.id) for version in versions]
            cycle.estado = "CERRADO"
            cycle.cerrado_en = now
            cycle.actualizado_en = now
            rows = []
            total = ZERO
            for resource in ("MEDICOS", "CONSULTAS"):
                limit, rate, state = _resource_terms(versions, resource)
                used = usage.get(resource)
                if used is None or limit is None or rate is None or state != "LISTO":
                    continue
                excess = max(ZERO, dec(used) - dec(limit))
                subtotal = (excess * rate).quantize(CENT, rounding=ROUND_HALF_UP)
                if excess <= ZERO or subtotal <= ZERO:
                    continue
                rows.append({"recurso": resource, "unidad": RESOURCE[resource][1], "consumo_validado": dec(used),
                    "limite_aplicado": dec(limit), "unidades_excedidas": excess,
                    "tarifa_aplicada": rate, "subtotal": subtotal,
                    "versiones_plan_consideradas": [int(version.id) for version in versions],
                    "regla": "MAYOR_LIMITE_MENOR_TARIFA"})
                total += subtotal
            existing = db.scalar(select(LiquidacionExcedente.id_liquidacion).where(
                LiquidacionExcedente.id_clinica == sub.id_clinica, LiquidacionExcedente.id_ciclo == cycle.id_ciclo))
            if rows and total > ZERO and existing is None:
                liquidation = LiquidacionExcedente(id_clinica=sub.id_clinica, id_ciclo=cycle.id_ciclo,
                    id_suscripcion=sub.id_suscripcion, total=total, moneda="BOB", estado="PENDIENTE_PAGO")
                db.add(liquidation)
                db.flush()
                db.add_all([RenglonLiquidacion(id_liquidacion=liquidation.id_liquidacion, **row) for row in rows])
                _audit(db, sub.id_clinica, None, liquidation.id_liquidacion,
                       "LIQUIDACION_EXCEDENTES_EMITIDA", {"total": money_text(total), "id_ciclo": cycle.id_ciclo})
            else:
                _audit(db, sub.id_clinica, None, None, "CICLO_CONSUMO_CERRADO",
                       {"id_ciclo": cycle.id_ciclo, "total_liquidado": money_text(total)})
            db.commit()
            closed += 1
    return closed


def _review_late_usage(db: Session, sub: TenantSubscription, cycle: CicloConsumo):
    if cycle.consulta_ids is None:
        return
    current_ids = db.scalars(select(Consulta.id_consulta).where(
        Consulta.id_clinica == cycle.id_clinica,
        Consulta.fecha_consulta >= cycle.inicio.replace(tzinfo=None),
        Consulta.fecha_consulta < cycle.fin_exclusivo.replace(tzinfo=None),
    ).distinct().order_by(Consulta.id_consulta)).all()
    doctor_ids = db.scalars(select(Medico.id_medico).where(
        Medico.id_clinica == cycle.id_clinica, func.lower(Medico.estado).in_(("activo", "active"))
    ).order_by(Medico.id_medico)).all()
    frozen, current = set(cycle.consulta_ids), set(current_ids)
    doctors_changed = len(doctor_ids) != cycle.medicos_activos_cierre
    if frozen == current and not doctors_changed:
        return
    latest_consult_review = db.scalar(select(FotografiaConsumo).where(
        FotografiaConsumo.id_ciclo == cycle.id_ciclo, FotografiaConsumo.recurso == "CONSULTAS",
        FotografiaConsumo.tipo == "REVISION").order_by(FotografiaConsumo.id_fotografia.desc()).limit(1))
    latest_doctor_review = db.scalar(select(FotografiaConsumo).where(
        FotografiaConsumo.id_ciclo == cycle.id_ciclo, FotografiaConsumo.recurso == "MEDICOS",
        FotografiaConsumo.tipo == "REVISION").order_by(FotografiaConsumo.id_fotografia.desc()).limit(1))
    if latest_consult_review and latest_doctor_review:
        last_consults = latest_consult_review.ids_observados or {}
        last_doctors = latest_doctor_review.ids_observados or []
        if (set(last_consults.get("ids", [])) == current
                and set(last_doctors) == set(doctor_ids)):
            return
    elif latest_consult_review:
        last_consults = latest_consult_review.ids_observados or {}
        if set(last_consults.get("ids", [])) == current and not doctors_changed:
            return
    elif latest_doctor_review and frozen == current:
        if set(latest_doctor_review.ids_observados or []) == set(doctor_ids):
            return
    cycle.estado = "REVISION_REQUERIDA"
    cycle.actualizado_en = utcnow()
    differences = {"consultas_agregadas": sorted(current - frozen), "consultas_retiradas": sorted(frozen - current),
                   "medicos_activos_al_cierre": cycle.medicos_activos_cierre,
                   "medicos_activos_actuales": len(doctor_ids)}
    db.add(FotografiaConsumo(id_ciclo=cycle.id_ciclo, recurso="CONSULTAS", cantidad=len(current_ids),
                             ids_observados={"ids": current_ids, **differences}, tipo="REVISION"))
    db.add(FotografiaConsumo(id_ciclo=cycle.id_ciclo, recurso="MEDICOS", cantidad=len(doctor_ids),
                             ids_observados=doctor_ids, tipo="REVISION"))
    liquidation = db.scalar(select(LiquidacionExcedente).where(
        LiquidacionExcedente.id_ciclo == cycle.id_ciclo,
        LiquidacionExcedente.id_clinica == cycle.id_clinica).with_for_update())
    if liquidation and liquidation.estado == "PENDIENTE_PAGO":
        liquidation.estado = "REVISION_REQUERIDA"
        liquidation.motivo_revision = "Se detectaron consultas tardías o correcciones posteriores al cierre"
    _audit(db, cycle.id_clinica, None, None, "USO_TARDIO_REQUIERE_REVISION",
           {"id_ciclo": cycle.id_ciclo, **differences})
    db.commit()


def evaluate_open_cycles(db: Session, now: datetime | None = None):
    now = as_utc(now or utcnow())
    subscriptions = db.scalars(select(TenantSubscription).where(
        TenantSubscription.estado.in_(("ACTIVE", "PAST_DUE")),
        TenantSubscription.fecha_inicio <= now, TenantSubscription.fecha_fin > now,
    )).all()
    count = 0
    for sub in subscriptions:
        cycle = _load_cycle(db, sub, create=True)
        versions = _versiones_ciclo(db, sub, cycle.inicio, cycle.fin_exclusivo)
        usage, _, _ = _usage(db, sub.id_clinica, cycle)
        _threshold_notices(db, cycle, usage, versions)
        cycle.actualizado_en = now
        db.commit()
        count += 1
    return count


def _audit(db: Session, clinic_id: int, user_id: int | None, record_id: str | None, action: str, details: dict):
    if user_id is None:
        from app.modules.auth.models import Usuario
        user_id = db.scalar(select(Usuario.id_usuario).where(Usuario.id_clinica == clinic_id)
                            .order_by(Usuario.id_usuario).limit(1))
    if user_id is None:
        logger.warning("CU36 no pudo auditar evento sin usuario local de clínica %s", clinic_id)
        return
    registrar_auditoria(db, id_usuario=user_id, id_clinica=clinic_id,
        tabla_afectada="billing_overages", registro_id=None, accion=action,
        descripcion="CU36: consumo y excedentes", datos_nuevos={"registro": record_id, **details})


def _return_url(base: str, params: dict[str, str]):
    parts = urlsplit(base)
    query = dict(parse_qsl(parts.query, keep_blank_values=True))
    query.update(params)
    return urlunsplit((parts.scheme, parts.netloc, parts.path, urlencode(query), parts.fragment))


def _stripe_post_idempotent(data: dict, idempotency_key: str):
    secret = require_test_gateway()
    headers = {"Authorization": f"Bearer {secret}", "Content-Type": "application/x-www-form-urlencoded",
               "Idempotency-Key": idempotency_key}
    try:
        with httpx.Client(timeout=settings.STRIPE_TIMEOUT_SECONDS) as client:
            response = client.post(f"{settings.STRIPE_API_BASE_URL.rstrip('/')}/v1/checkout/sessions",
                                   headers=headers, data={key: str(value) for key, value in data.items()})
    except httpx.HTTPError as exc:
        raise BillingError(502, "BILLING_GATEWAY_UNCERTAIN", "No fue posible confirmar la respuesta de Stripe") from exc
    try:
        body = response.json()
    except Exception:
        body = {}
    if response.status_code >= 400:
        logger.error("CU36 Stripe Checkout rechazado (HTTP %s)", response.status_code)
        code = "BILLING_GATEWAY_UNCERTAIN" if response.status_code >= 500 else "BILLING_GATEWAY_ERROR"
        raise BillingError(502, code, "Stripe no pudo confirmar la creación de Checkout")
    if not body.get("id") or not body.get("url") or not body.get("expires_at"):
        raise BillingError(502, "BILLING_GATEWAY_UNCERTAIN", "Stripe devolvió una sesión incompleta")
    return body


def _stripe_checkout_data(payment: PagoExcedente, liquidation: LiquidacionExcedente):
    success_base = _cu36_env("BILLING_CU36_SUCCESS_URL", "http://localhost:4200/admin/consumo")
    cancel_base = _cu36_env("BILLING_CU36_CANCEL_URL", "http://localhost:4200/admin/consumo")
    params = {"id_liquidacion": liquidation.id_liquidacion,
              "id_pago_excedente": payment.id_pago_excedente}
    success = _return_url(success_base, {**params, "checkout": "success",
                                          "session_id": "{CHECKOUT_SESSION_ID}"})
    cancel = _return_url(cancel_base, {**params, "checkout": "cancelled"})
    amount = int((dec(liquidation.total) * 100).quantize(Decimal("1"), rounding=ROUND_HALF_UP))
    expires = int((utcnow() + timedelta(hours=2)).timestamp())
    return {
        "mode": "payment", "client_reference_id": payment.id_pago_excedente,
        "success_url": success, "cancel_url": cancel, "expires_at": expires,
        "line_items[0][quantity]": 1,
        "line_items[0][price_data][currency]": "bob",
        "line_items[0][price_data][unit_amount]": amount,
        "line_items[0][price_data][product_data][name]": "Excedentes del plan mensual",
        "metadata[tipo]": "excedente",
        "metadata[id_liquidacion]": liquidation.id_liquidacion,
        "metadata[id_pago_excedente]": payment.id_pago_excedente,
        "metadata[id_clinica]": payment.id_clinica,
    }


def _attach_session(db: Session, payment: PagoExcedente):
    liquidation = db.scalar(select(LiquidacionExcedente).where(
        LiquidacionExcedente.id_liquidacion == payment.id_liquidacion,
        LiquidacionExcedente.id_clinica == payment.id_clinica))
    if liquidation is None:
        raise BillingError(404, "BILLING_RESOURCE_NOT_FOUND", "Liquidación no encontrada")
    if payment.stripe_session_id and payment.checkout_url:
        return
    session = _stripe_post_idempotent(_stripe_checkout_data(payment, liquidation), payment.stripe_idempotency_key)
    payment.stripe_session_id = session["id"]
    payment.checkout_url = session["url"]
    payment.expira_en = datetime.fromtimestamp(int(session["expires_at"]), timezone.utc)
    db.commit()


def create_checkout(db: Session, clinic_id: int, user_id: int, liquidation_id: str, client_key: str):
    require_test_gateway()
    liquidation = db.scalar(select(LiquidacionExcedente).where(
        LiquidacionExcedente.id_liquidacion == liquidation_id,
        LiquidacionExcedente.id_clinica == clinic_id).with_for_update())
    if liquidation is None:
        raise BillingHttpException(404, "BILLING_RESOURCE_NOT_FOUND", "Liquidación no encontrada")
    if liquidation.estado != "PENDIENTE_PAGO":
        raise BillingHttpException(409, "BILLING_LIQUIDATION_NOT_PAYABLE", "La liquidación no admite checkout")
    now = utcnow()
    attempts = db.scalars(select(PagoExcedente).where(
        PagoExcedente.id_liquidacion == liquidation_id,
        PagoExcedente.id_clinica == clinic_id).order_by(PagoExcedente.creado_en.desc()).with_for_update()).all()
    for attempt in attempts:
        if attempt.estado == "PENDIENTE" and attempt.expira_en and as_utc(attempt.expira_en) <= now:
            attempt.estado = "EXPIRADO"
    prior_key = db.scalar(select(PagoExcedente).where(
        PagoExcedente.id_clinica == clinic_id,
        PagoExcedente.client_idempotency_key == client_key).with_for_update())
    if prior_key is not None:
        if prior_key.id_liquidacion != liquidation_id or prior_key.estado != "PENDIENTE":
            raise BillingHttpException(409, "BILLING_IDEMPOTENCY_KEY_USED", "La clave ya corresponde a un intento anterior")
        if prior_key.expira_en and as_utc(prior_key.expira_en) <= now:
            prior_key.estado = "EXPIRADO"
            db.commit()
            raise BillingHttpException(409, "BILLING_IDEMPOTENCY_KEY_USED", "El intento asociado a la clave expiró; use otra clave")
        active, created = prior_key, False
    else:
        active = next((attempt for attempt in attempts if attempt.estado == "PENDIENTE"), None)
        created = False
    if active is None:
        active = PagoExcedente(id_liquidacion=liquidation_id, id_clinica=clinic_id, id_usuario=user_id,
            monto=liquidation.total, moneda="BOB", estado="PENDIENTE", client_idempotency_key=client_key,
            stripe_idempotency_key=f"cu36-{uuid.uuid4()}")
        db.add(active)
        db.flush()
        _audit(db, clinic_id, user_id, liquidation_id, "CHECKOUT_EXCEDENTES_INICIADO",
               {"id_pago_excedente": active.id_pago_excedente, "monto": money_text(active.monto)})
        db.commit()
        db.refresh(active)
        created = True
    # Keep repeated requests bound to one active attempt, independent of a new client key.
    if not created and active.stripe_session_id and active.checkout_url:
        return {"checkout": {"id_pago_excedente": active.id_pago_excedente,
            "id_liquidacion": active.id_liquidacion, "monto": money_text(active.monto), "moneda": "BOB",
            "checkout_url": active.checkout_url, "expira_en": active.expira_en, "estado": "PENDIENTE"},
            "created": False}
    try:
        _attach_session(db, active)
    except BillingError as exc:
        if exc.code != "BILLING_GATEWAY_UNCERTAIN":
            active.estado = "FALLIDO"
            _audit(db, clinic_id, user_id, liquidation_id, "CHECKOUT_EXCEDENTES_FALLIDO",
                   {"id_pago_excedente": active.id_pago_excedente, "code": exc.code})
            db.commit()
        raise
    db.refresh(active)
    return {"checkout": {"id_pago_excedente": active.id_pago_excedente,
        "id_liquidacion": active.id_liquidacion, "monto": money_text(active.monto), "moneda": "BOB",
        "checkout_url": active.checkout_url, "expira_en": active.expira_en, "estado": "PENDIENTE"},
        "created": created}


def _flag_payment_review(db: Session, payment: PagoExcedente, reason: str, *, event_id=None):
    liquidation = db.scalar(select(LiquidacionExcedente).where(
        LiquidacionExcedente.id_liquidacion == payment.id_liquidacion,
        LiquidacionExcedente.id_clinica == payment.id_clinica).with_for_update())
    if liquidation and liquidation.estado != "PAGADA":
        liquidation.estado = "REVISION_REQUERIDA"
        liquidation.motivo_revision = reason[:1000]
    if event_id:
        db.merge(EventoStripeExcedente(id_evento=event_id, tipo="checkout.session", resultado="REVISION", detalle=reason[:500]))
    _audit(db, payment.id_clinica, payment.id_usuario, payment.id_liquidacion,
           "PAGO_EXCEDENTES_REQUIERE_REVISION", {"id_pago_excedente": payment.id_pago_excedente, "motivo": reason})
    db.commit()


def _check_stripe_session(payment: PagoExcedente, liquidation: LiquidacionExcedente, session: dict):
    metadata = session.get("metadata") or {}
    amount = int((dec(liquidation.total) * 100).quantize(Decimal("1"), rounding=ROUND_HALF_UP))
    expected = {
        "id": payment.stripe_session_id,
        "client_reference_id": payment.id_pago_excedente,
        "metadata.tipo": "excedente",
        "metadata.id_liquidacion": liquidation.id_liquidacion,
        "metadata.id_pago_excedente": payment.id_pago_excedente,
        "metadata.id_clinica": str(payment.id_clinica),
        "amount_total": amount,
        "currency": "bob",
    }
    actual = {"id": session.get("id"), "client_reference_id": session.get("client_reference_id"),
        "metadata.tipo": metadata.get("tipo"), "metadata.id_liquidacion": metadata.get("id_liquidacion"),
        "metadata.id_pago_excedente": metadata.get("id_pago_excedente"),
        "metadata.id_clinica": str(metadata.get("id_clinica", "")),
        "amount_total": session.get("amount_total"), "currency": str(session.get("currency", "")).lower()}
    return all(actual[key] == value for key, value in expected.items())


def _confirm_paid_session(db: Session, payment: PagoExcedente, session: dict, *, event_id=None):
    liquidation = db.scalar(select(LiquidacionExcedente).where(
        LiquidacionExcedente.id_liquidacion == payment.id_liquidacion,
        LiquidacionExcedente.id_clinica == payment.id_clinica).with_for_update())
    if liquidation is None or not _check_stripe_session(payment, liquidation, session):
        _flag_payment_review(db, payment, "La sesión Stripe no coincide con el intento o el importe congelado", event_id=event_id)
        raise BillingHttpException(422, "BILLING_PAYMENT_MISMATCH", "La sesión de pago requiere revisión")
    if session.get("payment_status") != "paid":
        return payment, False
    if liquidation.estado == "REVISION_REQUERIDA":
        _flag_payment_review(db, payment, liquidation.motivo_revision or "Liquidación bloqueada para revisión", event_id=event_id)
        return payment, False
    if payment.estado == "PAGADO" and liquidation.estado == "PAGADA":
        if event_id:
            db.add(EventoStripeExcedente(id_evento=event_id, tipo="checkout.session.completed", resultado="DUPLICADO"))
            db.commit()
        return payment, True
    if liquidation.estado != "PENDIENTE_PAGO":
        _flag_payment_review(db, payment, "Estado de liquidación incompatible con pago Stripe", event_id=event_id)
        raise BillingHttpException(422, "BILLING_PAYMENT_MISMATCH", "La sesión de pago requiere revisión")
    if dec(payment.monto) != dec(liquidation.total):
        _flag_payment_review(db, payment, "El monto persistido del intento difiere de la liquidación", event_id=event_id)
        raise BillingHttpException(422, "BILLING_PAYMENT_MISMATCH", "La sesión de pago requiere revisión")
    payment.estado = "PAGADO"
    payment.confirmado_en = utcnow()
    pi = session.get("payment_intent")
    payment.stripe_payment_intent_id = pi.get("id") if isinstance(pi, dict) else pi
    liquidation.estado = "PAGADA"
    liquidation.pagada_en = payment.confirmado_en
    liquidation.referencia_stripe = payment.stripe_payment_intent_id or payment.stripe_session_id
    if event_id:
        db.add(EventoStripeExcedente(id_evento=event_id, tipo="checkout.session.completed", resultado="PAGADO"))
    _audit(db, payment.id_clinica, payment.id_usuario, payment.id_liquidacion,
           "PAGO_EXCEDENTES_CONFIRMADO", {"id_pago_excedente": payment.id_pago_excedente,
                                           "referencia": liquidation.referencia_stripe})
    db.commit()
    db.refresh(payment)
    return payment, True


def _state_response(db: Session, payment: PagoExcedente):
    liquidation = db.scalar(select(LiquidacionExcedente).where(
        LiquidacionExcedente.id_liquidacion == payment.id_liquidacion,
        LiquidacionExcedente.id_clinica == payment.id_clinica))
    return {"id_pago_excedente": payment.id_pago_excedente, "id_liquidacion": payment.id_liquidacion,
        "estado_pago": payment.estado, "estado_liquidacion": liquidation.estado if liquidation else "REVISION_REQUERIDA",
        "confirmado_en": payment.confirmado_en, "checkout_url": payment.checkout_url}


def synchronize_payment(db: Session, clinic_id: int, liquidation_id: str, payment_id: str):
    require_test_gateway()
    payment = db.scalar(select(PagoExcedente).where(
        PagoExcedente.id_pago_excedente == payment_id, PagoExcedente.id_liquidacion == liquidation_id,
        PagoExcedente.id_clinica == clinic_id).with_for_update())
    if payment is None:
        raise BillingHttpException(404, "BILLING_RESOURCE_NOT_FOUND", "Intento de pago no encontrado")
    liquidation = db.scalar(select(LiquidacionExcedente).where(
        LiquidacionExcedente.id_liquidacion == liquidation_id, LiquidacionExcedente.id_clinica == clinic_id))
    if liquidation is None:
        raise BillingHttpException(404, "BILLING_RESOURCE_NOT_FOUND", "Liquidación no encontrada")
    if payment.estado == "PAGADO":
        result = _state_response(db, payment)
        _audit(db, clinic_id, payment.id_usuario, payment.id_liquidacion,
               "SINCRONIZAR_PAGO_EXCEDENTES", {"id_pago_excedente": payment.id_pago_excedente,
                                                "estado": payment.estado})
        db.commit()
        return result
    if not payment.stripe_session_id:
        raise BillingHttpException(409, "BILLING_CHECKOUT_NOT_READY", "La sesión Checkout todavía no está disponible")
    try:
        session = _stripe_request("GET", "/v1/checkout/sessions/" + payment.stripe_session_id)
    except Exception as exc:
        logger.error("CU36 no pudo sincronizar sesión Stripe")
        raise BillingHttpException(502, "BILLING_GATEWAY_ERROR", "No se pudo consultar Stripe") from exc
    if not _check_stripe_session(payment, liquidation, session):
        _flag_payment_review(db, payment, "La sesión Stripe no coincide con el intento o el importe congelado")
        raise BillingHttpException(422, "BILLING_PAYMENT_MISMATCH", "La sesión de pago requiere revisión")
    if session.get("status") == "expired" and payment.estado == "PENDIENTE":
        payment.estado = "EXPIRADO"
        db.commit()
    elif session.get("payment_status") == "paid":
        _confirm_paid_session(db, payment, session)
    result = _state_response(db, payment)
    _audit(db, clinic_id, payment.id_usuario, payment.id_liquidacion,
           "SINCRONIZAR_PAGO_EXCEDENTES", {"id_pago_excedente": payment.id_pago_excedente,
                                            "estado": payment.estado})
    db.commit()
    return result


def process_webhook(db: Session, payload: bytes, signature: str):
    secret = _cu36_env("STRIPE_CU36_WEBHOOK_SECRET")
    if not secret:
        raise BillingHttpException(503, "BILLING_GATEWAY_UNAVAILABLE", "El webhook CU36 no está configurado")
    try:
        verificar_firma_stripe(payload, signature, secret)
    except Exception as exc:
        raise BillingHttpException(400, "BILLING_WEBHOOK_SIGNATURE_INVALID", "Firma Stripe inválida") from exc
    try:
        event = json.loads(payload.decode("utf-8"))
        event_id, event_type = str(event["id"]), str(event["type"])
        session = event["data"]["object"]
    except Exception as exc:
        raise BillingHttpException(400, "BILLING_WEBHOOK_INVALID", "Evento Stripe inválido") from exc
    if db.get(EventoStripeExcedente, event_id) is not None:
        return {"received": True, "ignored": True}
    supported = {"checkout.session.completed", "checkout.session.async_payment_succeeded",
                 "checkout.session.expired", "checkout.session.async_payment_failed"}
    if event_type not in supported:
        db.add(EventoStripeExcedente(id_evento=event_id, tipo=event_type, resultado="IGNORADO"))
        db.commit()
        return {"received": True, "ignored": True}
    payment = db.scalar(select(PagoExcedente).where(
        PagoExcedente.stripe_session_id == session.get("id")).with_for_update())
    if payment is None:
        db.add(EventoStripeExcedente(id_evento=event_id, tipo=event_type, resultado="IGNORADO",
                                     detalle="Sesión no registrada en CU36"))
        db.commit()
        return {"received": True, "ignored": True}
    # Another concurrent delivery of the same signed event may have committed while this
    # handler waited for the payment row lock.
    if db.get(EventoStripeExcedente, event_id) is not None:
        return {"received": True, "ignored": True}
    if not _check_stripe_session(payment,
            db.scalar(select(LiquidacionExcedente).where(
                LiquidacionExcedente.id_liquidacion == payment.id_liquidacion,
                LiquidacionExcedente.id_clinica == payment.id_clinica)), session):
        _flag_payment_review(db, payment, "Evento firmado con sesión o monto discordante", event_id=event_id)
        raise BillingHttpException(422, "BILLING_PAYMENT_MISMATCH", "La sesión de pago requiere revisión")
    if event_type in ("checkout.session.completed", "checkout.session.async_payment_succeeded"):
        if session.get("payment_status") == "paid":
            _confirm_paid_session(db, payment, session, event_id=event_id)
        else:
            db.add(EventoStripeExcedente(id_evento=event_id, tipo=event_type, resultado="PENDIENTE"))
            db.commit()
        return {"received": True, "ignored": False}
    if payment.estado == "PENDIENTE":
        payment.estado = "EXPIRADO" if event_type == "checkout.session.expired" else "FALLIDO"
    db.add(EventoStripeExcedente(id_evento=event_id, tipo=event_type, resultado=payment.estado))
    _audit(db, payment.id_clinica, payment.id_usuario, payment.id_liquidacion,
           "PAGO_EXCEDENTES_FINALIZADO_SIN_PAGO", {"id_pago_excedente": payment.id_pago_excedente,
                                                   "estado": payment.estado})
    db.commit()
    return {"received": True, "ignored": False}
