from decimal import Decimal
from datetime import datetime, timedelta, timezone
from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path
from types import SimpleNamespace
from urllib.parse import parse_qs, urlsplit
import json
import uuid

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from pydantic import SecretStr
from sqlalchemy import Column, MetaData, Table, create_engine, inspect, select
from sqlalchemy.orm import Session
from alembic.migration import MigrationContext
from alembic.operations import Operations

from app.core.config import settings
from app.modules.tenants.usage_billing import service
from app.core.database import Base
from app.modules.auth.models import VersionPlan
from app.modules.appointments.models import Medico
from app.modules.medical_records.hce.models import Consulta
from app.modules.tenants.models import TenantSubscription
from app.modules.tenants.usage_billing.models import (
    AvisoConsumo, CicloConsumo, EventoStripeExcedente, FotografiaConsumo,
    LiquidacionExcedente, PagoExcedente, RenglonLiquidacion,
)
from app.modules.tenants.usage_billing.router import billing_http_exception_handler
from app.modules.tenants.usage_billing.schemas import AvisoConsumo as AvisoResponse


def sqlite_session():
    """Use real mapped columns but omit unrelated FKs to keep CU36 workflow fixtures isolated."""
    names = ["clinicas", "usuarios", "planes", "versiones_plan", "tenant_subscriptions",
        "subscription_changes", "subscription_payments", "medicos", "consultas", "ciclos_consumo",
        "fotografias_consumo", "avisos_consumo", "liquidaciones_excedentes", "renglones_liquidacion",
        "pagos_excedentes", "eventos_stripe_excedentes"]
    metadata = MetaData()
    for name in names:
        source = Base.metadata.tables[name]
        columns = [Column(column.name, column.type, primary_key=column.primary_key,
            nullable=column.nullable, autoincrement=column.autoincrement,
            server_default=column.server_default) for column in source.columns]
        Table(name, metadata, *columns)
    engine = create_engine("sqlite://")
    metadata.create_all(engine)
    return Session(engine), engine


def add_plan_and_subscription(db, *, start, end, doctor_limit=1, consultation_limit=2,
                              doctor_rate="1.50", consultation_rate="2.00"):
    plan = VersionPlan(id=1, plan_id=1, numero=1, nombre="Base", precio_mensual=Decimal("50.00"),
        moneda="BOB", ciclo="MENSUAL", servicios_incluidos=[], limite_medicos=doctor_limit,
        limite_sedes=3, limite_consultas=consultation_limit,
        tarifas_excedentes=[{"recurso": "MEDICOS", "unidad": "MEDICO_CICLO_MENSUAL", "precio": doctor_rate},
                            {"recurso": "CONSULTAS", "unidad": "CONSULTA", "precio": consultation_rate}],
        demora_pago_dias=0, creado_por=1, creado_en=start)
    sub = TenantSubscription(id_suscripcion="sub-cu36", id_clinica=1, id_version_plan=1,
        ciclo="MONTHLY", fecha_inicio=start, fecha_fin=end, estado="ACTIVE", row_version=1,
        dias_gracia=0, fecha_actualizacion=start)
    db.add_all([plan, sub])
    db.flush()
    return plan, sub


def add_paid_checkout_fixture(db, *, clinic_id=1, amount=Decimal("9.00"), payment_id="pay-cu36-1",
                              liquidation_id="liq-cu36-1", session_id="cs_test_cu36_1"):
    cycle = CicloConsumo(id_ciclo="cycle-cu36-1", id_clinica=clinic_id, id_suscripcion="sub-cu36",
        inicio=datetime(2026, 10, 1, tzinfo=timezone.utc), fin_exclusivo=datetime(2026, 11, 1, tzinfo=timezone.utc),
        estado="CERRADO", consulta_ids=[], medicos_activos_cierre=0, sedes_estado="MEDICION_NO_DISPONIBLE")
    liquidation = LiquidacionExcedente(id_liquidacion=liquidation_id, id_clinica=clinic_id,
        id_ciclo=cycle.id_ciclo, id_suscripcion="sub-cu36", total=amount, moneda="BOB", estado="PENDIENTE_PAGO")
    payment = PagoExcedente(id_pago_excedente=payment_id, id_liquidacion=liquidation_id,
        id_clinica=clinic_id, id_usuario=77, monto=amount, moneda="BOB", estado="PENDIENTE",
        client_idempotency_key=str(uuid.uuid4()), stripe_idempotency_key="cu36-stable-key-" + payment_id,
        stripe_session_id=session_id, checkout_url="https://checkout.stripe.test/session",
        expira_en=datetime(2026, 11, 1, tzinfo=timezone.utc))
    db.add_all([cycle, liquidation, payment])
    db.flush()
    return cycle, liquidation, payment


def version(*, doctor_limit=10, consultation_limit=100, doctor_rate="2.00", consultation_rate="1.25"):
    tariffs = []
    if doctor_rate is not None:
        tariffs.append({"recurso": "MEDICOS", "unidad": "MEDICO_CICLO_MENSUAL", "precio": doctor_rate})
    if consultation_rate is not None:
        tariffs.append({"recurso": "CONSULTAS", "unidad": "CONSULTA", "precio": consultation_rate})
    return SimpleNamespace(id=4, plan_id=2, numero=1, nombre="Base", limite_medicos=doctor_limit,
                           limite_consultas=consultation_limit, limite_sedes=5, tarifas_excedentes=tariffs)


def test_usage_estimates_round_lines_half_up_and_marks_sedes_unmeasured():
    plan = version(doctor_limit=3, consultation_limit=100, doctor_rate="1.00", consultation_rate="2.00")
    rows, total = service._service_rows({"MEDICOS": 4, "CONSULTAS": 105, "SEDES": None}, [plan])

    by_code = {row["recurso"]: row for row in rows}
    assert by_code["MEDICOS"]["subtotal_estimado"] == "1.00"
    assert by_code["CONSULTAS"]["unidades_excedidas"] == "5"
    assert by_code["CONSULTAS"]["subtotal_estimado"] == "10.00"
    assert by_code["SEDES"]["estado_medicion"] == "MEDICION_NO_DISPONIBLE"
    assert by_code["SEDES"]["consumo_validado"] is None
    assert total == Decimal("11.00")


def test_money_string_uses_round_half_up_to_cents():
    assert service.money_text(Decimal("1.005")) == "1.01"


def test_contract_serializes_instants_as_utc_z():
    instant = datetime(2026, 11, 13, 10, 30, tzinfo=timezone.utc)
    aviso = AvisoResponse(id_aviso="a", id_ciclo="c", recurso="CONSULTAS", tipo="LIMITE",
        umbral_porcentaje="100", titulo="límite", mensaje="uso", creado_en=instant, leido_en=None)
    assert aviso.model_dump(mode="json")["creado_en"] == "2026-11-13T10:30:00Z"


def test_resource_terms_uses_largest_limit_and_lowest_rate_across_versions():
    lower = version(doctor_limit=10, doctor_rate="2.00")
    higher = version(doctor_limit=15, doctor_rate="1.75")

    assert service._resource_terms([lower, higher], "MEDICOS") == (15, Decimal("1.75"), "LISTO")


def test_any_unlimited_version_or_missing_rate_excludes_resource():
    limited = version(doctor_limit=10, doctor_rate="2.00")
    unlimited = version(doctor_limit=None, doctor_rate=None)
    no_rate = version(doctor_limit=12, doctor_rate=None)

    assert service._resource_terms([limited, unlimited], "MEDICOS") == (None, None, "ILIMITADO")
    assert service._resource_terms([limited, no_rate], "MEDICOS") == (12, None, "SIN_TARIFA")


def test_zero_limit_has_no_percent_but_counts_all_use_as_excess():
    rows, total = service._service_rows({"MEDICOS": 2, "CONSULTAS": 0, "SEDES": None},
                                        [version(doctor_limit=0)])
    doctors = next(row for row in rows if row["recurso"] == "MEDICOS")
    assert doctors["porcentaje_uso"] is None
    assert doctors["unidades_excedidas"] == "2"
    assert total == Decimal("4.00")


def test_checkout_request_fixes_bob_and_return_params(monkeypatch):
    monkeypatch.setattr(service, "_cu36_env", lambda name, default="": {
        "BILLING_CU36_SUCCESS_URL": "https://web.test/consumo?tab=usage",
        "BILLING_CU36_CANCEL_URL": "https://web.test/consumo",
    }.get(name, default))
    payment = SimpleNamespace(id_pago_excedente="pay-1", id_liquidacion="liq-1", id_clinica=8)
    liquidation = SimpleNamespace(id_liquidacion="liq-1", total=Decimal("12.34"))

    data = service._stripe_checkout_data(payment, liquidation)
    success = parse_qs(urlsplit(data["success_url"]).query)
    cancel = parse_qs(urlsplit(data["cancel_url"]).query)

    assert data["line_items[0][price_data][currency]"] == "bob"
    assert data["line_items[0][price_data][unit_amount]"] == 1234
    assert success["checkout"] == ["success"]
    assert success["id_pago_excedente"] == ["pay-1"]
    assert success["id_liquidacion"] == ["liq-1"]
    assert success["session_id"] == ["{CHECKOUT_SESSION_ID}"]
    assert cancel["checkout"] == ["cancelled"]


def test_gateway_rejects_live_or_missing_secret(monkeypatch):
    monkeypatch.setattr(service, "stripe_habilitado", lambda: True)
    monkeypatch.setattr(settings, "STRIPE_SECRET_KEY", SecretStr("sk_live_not_a_real_secret"))
    with pytest.raises(service.BillingError) as live:
        service.require_test_gateway()
    assert live.value.status == 503
    assert live.value.code == "BILLING_GATEWAY_UNAVAILABLE"

    monkeypatch.setattr(service, "stripe_habilitado", lambda: False)
    with pytest.raises(service.BillingError):
        service.require_test_gateway()


def test_session_validation_requires_persisted_session_metadata_amount_and_bob():
    payment = SimpleNamespace(stripe_session_id="cs_test_1", id_pago_excedente="pay-1", id_clinica=8)
    liquidation = SimpleNamespace(id_liquidacion="liq-1", total=Decimal("12.34"))
    session = {"id": "cs_test_1", "client_reference_id": "pay-1", "amount_total": 1234,
        "currency": "bob", "metadata": {"tipo": "excedente", "id_liquidacion": "liq-1",
        "id_pago_excedente": "pay-1", "id_clinica": "8"}, "payment_status": "paid"}

    assert service._check_stripe_session(payment, liquidation, session)
    session["amount_total"] = 1
    assert not service._check_stripe_session(payment, liquidation, session)


def test_cu36_migration_creates_its_owned_tables_on_sqlite():
    path = Path(__file__).resolve().parents[1] / "alembic" / "versions" / "024_cu36_billing_overages.py"
    spec = spec_from_file_location("cu36_migration_test", path)
    migration = module_from_spec(spec)
    spec.loader.exec_module(migration)
    engine = create_engine("sqlite://")
    with engine.begin() as connection:
        context = MigrationContext.configure(connection)
        with Operations.context(context):
            migration.upgrade()
        names = set(inspect(connection).get_table_names())
    assert {"ciclos_consumo", "fotografias_consumo", "avisos_consumo", "liquidaciones_excedentes",
            "renglones_liquidacion", "pagos_excedentes", "eventos_stripe_excedentes"} <= names


def test_domain_errors_match_contract_shape():
    app = FastAPI()
    app.add_exception_handler(service.BillingHttpException, billing_http_exception_handler)

    @app.get("/domain-error")
    def domain_error():
        raise service.BillingHttpException(404, "BILLING_RESOURCE_NOT_FOUND", "No encontrado")

    response = TestClient(app).get("/domain-error")
    assert response.status_code == 404
    assert response.json() == {"detail": "No encontrado", "code": "BILLING_RESOURCE_NOT_FOUND"}


def test_cycle_close_freezes_usage_and_creates_exactly_one_liquidation(monkeypatch):
    db, engine = sqlite_session()
    monkeypatch.setattr(service, "_audit", lambda *args, **kwargs: None)
    start, end = datetime(2026, 10, 1, tzinfo=timezone.utc), datetime(2026, 11, 1, tzinfo=timezone.utc)
    add_plan_and_subscription(db, start=start, end=end)
    db.add_all([
        Medico(id_medico=1, id_usuario=11, id_clinica=1, matricula_profesional="M1", estado="Activo"),
        Medico(id_medico=2, id_usuario=12, id_clinica=1, matricula_profesional="M2", estado="active"),
    ])
    db.add_all([
        Consulta(id_consulta=n, id_clinica=1, id_historia=1, id_cita=n, id_medico=1,
            motivo_consulta="motivo", sintomas="sintomas", evolucion="evolucion", plan_medico="plan",
            fecha_consulta=datetime(2026, 10, 10 + n, 12)) for n in (1, 2, 3)
    ])
    db.commit()

    now = datetime(2026, 11, 2, tzinfo=timezone.utc)
    assert service.close_due_cycles(db, now) == 1
    assert service.close_due_cycles(db, now) == 0
    cycles = db.scalars(select(CicloConsumo)).all()
    liquidations = db.scalars(select(LiquidacionExcedente)).all()
    lines = db.scalars(select(RenglonLiquidacion).where(
        RenglonLiquidacion.id_liquidacion == liquidations[0].id_liquidacion)).all()

    assert len(cycles) == 1
    assert cycles[0].estado == "CERRADO"
    assert cycles[0].medicos_activos_cierre == 2
    assert cycles[0].consulta_ids == [1, 2, 3]
    assert len(liquidations) == 1
    assert liquidations[0].total == Decimal("3.50")
    assert {line.recurso for line in lines} == {"MEDICOS", "CONSULTAS"}
    assert sorted(line.subtotal for line in lines) == [Decimal("1.50"), Decimal("2.00")]
    db.close()
    engine.dispose()


def test_threshold_notices_are_deduplicated_at_80_and_100_and_zero_limit(monkeypatch):
    db, engine = sqlite_session()
    start, end = datetime(2026, 10, 1, tzinfo=timezone.utc), datetime(2026, 11, 1, tzinfo=timezone.utc)
    cycle = CicloConsumo(id_ciclo="cycle-notices", id_clinica=1, id_suscripcion="sub-cu36",
        inicio=start, fin_exclusivo=end, estado="ABIERTO")
    db.add(cycle)
    db.flush()
    plan = version(doctor_limit=10, consultation_limit=100)
    usage = {"MEDICOS": 8, "CONSULTAS": 100, "SEDES": None}
    service._threshold_notices(db, cycle, usage, [plan])
    service._threshold_notices(db, cycle, usage, [plan])
    db.commit()
    notices = db.scalars(select(AvisoConsumo).where(AvisoConsumo.id_ciclo == cycle.id_ciclo)).all()
    assert len(notices) == 3
    assert {(notice.recurso, notice.umbral_porcentaje) for notice in notices} == {
        ("MEDICOS", Decimal("80.00")), ("CONSULTAS", Decimal("80.00")), ("CONSULTAS", Decimal("100.00"))}

    zero_cycle = CicloConsumo(id_ciclo="cycle-zero", id_clinica=1, id_suscripcion="sub-cu36",
        inicio=start, fin_exclusivo=end, estado="ABIERTO")
    db.add(zero_cycle)
    db.flush()
    zero_plan = version(doctor_limit=0, consultation_limit=100)
    service._threshold_notices(db, zero_cycle, {"MEDICOS": 2, "CONSULTAS": 0, "SEDES": None}, [zero_plan])
    db.commit()
    zero_notice = db.scalar(select(AvisoConsumo).where(AvisoConsumo.id_ciclo == zero_cycle.id_ciclo))
    assert zero_notice.tipo == "LIMITE"
    assert zero_notice.umbral_porcentaje == Decimal("100.00")
    db.close()
    engine.dispose()


def test_checkout_reuses_active_attempt_and_allows_new_key_after_failure(monkeypatch):
    db, engine = sqlite_session()
    monkeypatch.setattr(service, "_audit", lambda *args, **kwargs: None)
    monkeypatch.setattr(service, "stripe_habilitado", lambda: True)
    monkeypatch.setattr(settings, "STRIPE_SECRET_KEY", SecretStr("sk_test_unit_test"))
    _, liquidation, _ = add_paid_checkout_fixture(db)
    calls = []

    def fake_post(data, key):
        calls.append((data, key))
        return {"id": f"cs_test_{len(calls)}", "url": f"https://checkout.test/{len(calls)}",
                "expires_at": int((service.utcnow() + timedelta(hours=2)).timestamp())}

    monkeypatch.setattr(service, "_stripe_post_idempotent", fake_post)
    first_key, retry_key = str(uuid.uuid4()), str(uuid.uuid4())
    first = service.create_checkout(db, 1, 77, liquidation.id_liquidacion, first_key)
    repeated_same_key = service.create_checkout(db, 1, 77, liquidation.id_liquidacion, first_key)
    repeated_other_key = service.create_checkout(db, 1, 77, liquidation.id_liquidacion, retry_key)
    assert first["created"] is True
    assert repeated_same_key["created"] is False
    assert repeated_other_key["created"] is False
    assert first["checkout"]["id_pago_excedente"] == repeated_other_key["checkout"]["id_pago_excedente"]
    assert len(calls) == 1
    assert calls[0][0]["line_items[0][price_data][currency]"] == "bob"

    attempt = db.scalar(select(PagoExcedente).where(PagoExcedente.id_pago_excedente == first["checkout"]["id_pago_excedente"]))
    attempt.estado = "FALLIDO"
    db.commit()
    retried = service.create_checkout(db, 1, 77, liquidation.id_liquidacion, retry_key)
    assert retried["created"] is True
    assert retried["checkout"]["id_pago_excedente"] != attempt.id_pago_excedente
    assert len(db.scalars(select(PagoExcedente)).all()) == 3  # including the fixture's expired historical attempt
    assert len(calls) == 2
    assert calls[0][1] != calls[1][1]
    db.close()
    engine.dispose()


def stripe_paid_session(payment, liquidation, *, amount=None, paid=True):
    return {"id": payment.stripe_session_id, "client_reference_id": payment.id_pago_excedente,
        "payment_status": "paid" if paid else "unpaid", "status": "complete",
        "amount_total": int(liquidation.total * 100) if amount is None else amount, "currency": "bob",
        "payment_intent": "pi_test_cu36", "metadata": {"tipo": "excedente",
        "id_liquidacion": liquidation.id_liquidacion, "id_pago_excedente": payment.id_pago_excedente,
        "id_clinica": str(payment.id_clinica)}}


def test_signed_webhook_is_idempotent_and_only_paid_status_confirms(monkeypatch):
    db, engine = sqlite_session()
    monkeypatch.setattr(service, "_audit", lambda *args, **kwargs: None)
    monkeypatch.setattr(service, "_cu36_env", lambda name, default="": "whsec_unit_test" if name == "STRIPE_CU36_WEBHOOK_SECRET" else default)
    monkeypatch.setattr(service, "verificar_firma_stripe", lambda payload, signature, secret: None)
    _, liquidation, payment = add_paid_checkout_fixture(db)
    unpaid = stripe_paid_session(payment, liquidation, paid=False)
    event = {"id": "evt_unpaid_cu36", "type": "checkout.session.completed", "data": {"object": unpaid}}
    assert service.process_webhook(db, json.dumps(event).encode(), "t=1,v1=test")["ignored"] is False
    db.refresh(payment)
    db.refresh(liquidation)
    assert payment.estado == "PENDIENTE"
    assert liquidation.estado == "PENDIENTE_PAGO"

    paid = stripe_paid_session(payment, liquidation)
    event = {"id": "evt_paid_cu36", "type": "checkout.session.async_payment_succeeded", "data": {"object": paid}}
    assert service.process_webhook(db, json.dumps(event).encode(), "t=1,v1=test")["ignored"] is False
    assert service.process_webhook(db, json.dumps(event).encode(), "t=1,v1=test")["ignored"] is True
    db.refresh(payment)
    db.refresh(liquidation)
    assert payment.estado == "PAGADO"
    assert liquidation.estado == "PAGADA"
    assert db.scalar(select(EventoStripeExcedente).where(EventoStripeExcedente.id_evento == "evt_paid_cu36")) is not None
    late_failure = {"id": "evt_late_failure_cu36", "type": "checkout.session.async_payment_failed",
                    "data": {"object": paid}}
    service.process_webhook(db, json.dumps(late_failure).encode(), "t=1,v1=test")
    db.refresh(payment)
    db.refresh(liquidation)
    assert payment.estado == "PAGADO"
    assert liquidation.estado == "PAGADA"
    db.close()
    engine.dispose()


def test_mismatched_webhook_amount_requires_review_without_payment(monkeypatch):
    db, engine = sqlite_session()
    monkeypatch.setattr(service, "_audit", lambda *args, **kwargs: None)
    monkeypatch.setattr(service, "_cu36_env", lambda name, default="": "whsec_unit_test" if name == "STRIPE_CU36_WEBHOOK_SECRET" else default)
    monkeypatch.setattr(service, "verificar_firma_stripe", lambda payload, signature, secret: None)
    _, liquidation, payment = add_paid_checkout_fixture(db)
    bad = stripe_paid_session(payment, liquidation, amount=1)
    event = {"id": "evt_bad_amount_cu36", "type": "checkout.session.completed", "data": {"object": bad}}

    with pytest.raises(service.BillingHttpException) as failure:
        service.process_webhook(db, json.dumps(event).encode(), "t=1,v1=test")
    db.refresh(payment)
    db.refresh(liquidation)
    assert failure.value.status_code == 422
    assert failure.value.code == "BILLING_PAYMENT_MISMATCH"
    assert payment.estado == "PENDIENTE"
    assert liquidation.estado == "REVISION_REQUERIDA"
    db.close()
    engine.dispose()


def test_sync_keeps_unpaid_checkout_pending_then_confirms_paid_session(monkeypatch):
    db, engine = sqlite_session()
    monkeypatch.setattr(service, "_audit", lambda *args, **kwargs: None)
    monkeypatch.setattr(service, "stripe_habilitado", lambda: True)
    monkeypatch.setattr(settings, "STRIPE_SECRET_KEY", SecretStr("sk_test_unit_test"))
    _, liquidation, payment = add_paid_checkout_fixture(db)
    session = stripe_paid_session(payment, liquidation, paid=False)
    monkeypatch.setattr(service, "_stripe_request", lambda method, path: session)

    pending = service.synchronize_payment(db, 1, liquidation.id_liquidacion, payment.id_pago_excedente)
    assert pending["estado_pago"] == "PENDIENTE"
    assert pending["estado_liquidacion"] == "PENDIENTE_PAGO"
    session["payment_status"] = "paid"
    confirmed = service.synchronize_payment(db, 1, liquidation.id_liquidacion, payment.id_pago_excedente)
    assert confirmed["estado_pago"] == "PAGADO"
    assert confirmed["estado_liquidacion"] == "PAGADA"
    db.close()
    engine.dispose()


def test_liquidation_lookup_is_scoped_to_authenticated_clinic():
    db, engine = sqlite_session()
    _, liquidation, _ = add_paid_checkout_fixture(db)
    with pytest.raises(service.BillingHttpException) as failure:
        service.get_liquidation(db, 2, liquidation.id_liquidacion)
    assert failure.value.status_code == 404
    db.close()
    engine.dispose()
