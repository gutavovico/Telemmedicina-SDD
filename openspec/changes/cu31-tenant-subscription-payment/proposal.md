# Proposal: CU31 Pagar Suscripción del Tenant

## Why

El backend ya dispone de una integración Stripe Checkout para pagos de citas (CU19), comprobantes PDF y webhook firmado, pero no posee planes, suscripciones ni pagos de plataforma. El registro legacy `/clinicas/registrar` crea tenants activos sin acuerdo comercial. Este CU necesita separar el cobro SaaS del pago de servicios médicos y mantener la vigencia del tenant correctamente tras la confirmación del proveedor.

## What Changes

- Modelar planes versionados, suscripciones del tenant y pagos de suscripción, reutilizando `Pago`/`Comprobante` de forma discriminada sin confundirlos con pagos de citas.
- Permitir al ADMIN del tenant consultar su suscripción, elegir plan/ciclo y crear una sesión Stripe Checkout alojada.
- Confirmar el pago exclusivamente mediante webhook Stripe firmado (o sincronización explícita), de forma idempotente, y extender la vigencia sólo una vez.
- Emitir y descargar comprobante/factura PDF desde el historial de pagos del tenant.
- Conservar la selección ante fallos y ofrecer reintento seguro, sin cobrar dos veces la misma operación.

## Capabilities

### New Capabilities

- `subscription-payment-backend`: estado de suscripción, checkout Stripe, confirmación idempotente, comprobantes e historial.
- `subscription-payment-web`: panel administrativo de pago y descarga.

### Modified Capabilities

Ninguna. CU19 conserva su flujo de pago de citas; CU31 reutiliza únicamente infraestructura técnica compartida de Stripe/PDF.

## Impact

Backend FastAPI en `app/modules/tenants/subscription_payments/`; modelo de planes/suscripciones y extensión discriminada de pagos; contrato `openspec/contracts/subscription-payments.md`. Angular consume el contrato desde `features/tenants/subscription-payment/`. No hay alcance Flutter porque el CU es exclusivamente web. El tenant se deriva del JWT/header, nunca del body.