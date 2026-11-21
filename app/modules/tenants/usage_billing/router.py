from typing import Annotated

from fastapi import APIRouter, Depends, Header, HTTPException, Query, Request, Response, status
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.modules.auth.dependencies import require_admin
from app.modules.auth.models import Usuario
from . import service
from .schemas import (
    AvisoConsumo, AvisosPage, CheckoutExcedentes, ComprobanteExcedentes, EstadoPagoExcedentes,
    LiquidacionExcedentes, LiquidacionesPage, PagosPage, ResumenCiclo,
)

router = APIRouter(prefix="/api/v1/facturacion", tags=["CU36 - consumo y excedentes"])


def _local_admin(db: Session = Depends(get_db), user: Usuario = Depends(require_admin)) -> Usuario:
    if user.id_clinica is None:
        raise service.BillingHttpException(403, "BILLING_CLINIC_REQUIRED",
            "La cuenta debe estar asociada a una clínica")
    return user


@router.get("/consumo/actual", response_model=ResumenCiclo)
def get_current_usage(db: Session = Depends(get_db), user: Usuario = Depends(_local_admin)):
    return service.resumen_actual(db, int(user.id_clinica))


@router.get("/avisos", response_model=AvisosPage)
def get_notices(
    no_leidos: bool | None = Query(default=None), skip: int = Query(default=0, ge=0),
    limit: int = Query(default=20, ge=1, le=100), db: Session = Depends(get_db),
    user: Usuario = Depends(_local_admin),
):
    return service.list_notices(db, int(user.id_clinica), no_leidos, skip, limit)


@router.patch("/avisos/{id_aviso}/leer", response_model=AvisoConsumo)
def read_notice(id_aviso: str, db: Session = Depends(get_db), user: Usuario = Depends(_local_admin)):
    return service.mark_notice_read(db, int(user.id_clinica), id_aviso)


@router.get("/liquidaciones", response_model=LiquidacionesPage)
def get_liquidations(
    ciclo_id: str | None = Query(default=None), skip: int = Query(default=0, ge=0),
    limit: int = Query(default=20, ge=1, le=100), db: Session = Depends(get_db),
    user: Usuario = Depends(_local_admin),
):
    return service.list_liquidations(db, int(user.id_clinica), ciclo_id, skip, limit)


@router.get("/liquidaciones/{id_liquidacion}", response_model=LiquidacionExcedentes)
def get_liquidation(id_liquidacion: str, db: Session = Depends(get_db), user: Usuario = Depends(_local_admin)):
    return service.get_liquidation(db, int(user.id_clinica), id_liquidacion)


@router.post("/liquidaciones/{id_liquidacion}/checkout", response_model=CheckoutExcedentes)
def start_checkout(
    id_liquidacion: str,
    idempotency_key: Annotated[str, Header(alias="Idempotency-Key", min_length=16, max_length=64)],
    response: Response, db: Session = Depends(get_db), user: Usuario = Depends(_local_admin),
):
    if not (idempotency_key.isalnum() or all(c.isalnum() or c in "-_." for c in idempotency_key)):
        raise HTTPException(422, detail="Idempotency-Key contiene caracteres no permitidos")
    try:
        result = service.create_checkout(db, int(user.id_clinica), int(user.id_usuario), id_liquidacion, idempotency_key)
    except service.BillingError as exc:
        raise service.BillingHttpException(exc.status, exc.code, exc.detail) from exc
    if not result["created"]:
        response.status_code = status.HTTP_200_OK
    return result["checkout"]


@router.get("/liquidaciones/{id_liquidacion}/pagos", response_model=PagosPage)
def get_payments(
    id_liquidacion: str, skip: int = Query(default=0, ge=0), limit: int = Query(default=20, ge=1, le=100),
    db: Session = Depends(get_db), user: Usuario = Depends(_local_admin),
):
    return service.list_payments(db, int(user.id_clinica), id_liquidacion, skip, limit)


@router.post("/liquidaciones/{id_liquidacion}/pagos/{id_pago_excedente}/sincronizar",
             response_model=EstadoPagoExcedentes)
def synchronize_payment(
    id_liquidacion: str, id_pago_excedente: str, db: Session = Depends(get_db),
    user: Usuario = Depends(_local_admin),
):
    try:
        return service.synchronize_payment(db, int(user.id_clinica), id_liquidacion, id_pago_excedente)
    except service.BillingError as exc:
        raise service.BillingHttpException(exc.status, exc.code, exc.detail) from exc


@router.get("/liquidaciones/{id_liquidacion}/comprobante", response_model=ComprobanteExcedentes)
def get_receipt(id_liquidacion: str, db: Session = Depends(get_db), user: Usuario = Depends(_local_admin)):
    return service.get_receipt(db, int(user.id_clinica), id_liquidacion)


@router.post("/webhook/stripe")
async def stripe_webhook(request: Request, stripe_signature: str = Header(default="", alias="Stripe-Signature"),
                         db: Session = Depends(get_db)):
    payload = await request.body()
    return service.process_webhook(db, payload, stripe_signature)


def billing_error_handler(_request: Request, exc: service.BillingError):
    return JSONResponse(status_code=exc.status, content={"detail": exc.detail, "code": exc.code})


def billing_http_exception_handler(_request: Request, exc: service.BillingHttpException):
    return JSONResponse(status_code=exc.status_code, content={"detail": exc.detail, "code": exc.code})
