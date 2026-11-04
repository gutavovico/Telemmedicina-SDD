# Spec Delta

## Purpose

Define el contrato backend de CU31 para consultar la suscripción, crear checkouts Stripe seguros, confirmar pagos idempotentemente y emitir comprobantes del tenant.

## ADDED Requirements

### Requirement: Consulta de suscripción del tenant
The system SHALL allow only an active ADMIN of the current tenant to read its subscription status, current plan version, limits, included services, billing cycle, period start/end, grace period and payment history. The system SHALL derive the display status ACTIVE, EXPIRED or DUE_SOON from dates and SHALL resolve the tenant from the authenticated context, never from a request body.

#### Scenario: Tenant sin suscripción
- **GIVEN** an authenticated tenant ADMIN without a subscription
- **WHEN** the user requests subscription details
- **THEN** the system responds 200 with no active subscription and a clear `has_subscription = false`

#### Scenario: ADMIN de otro tenant
- **GIVEN** a subscription belonging to another tenant
- **WHEN** the user tries to reference it directly
- **THEN** the system responds 404 without revealing plan, price or payment data

### Requirement: Selección de plan, ciclo y precio autoritativo
The system SHALL expose active plan versions and their MONTHLY or ANNUAL prices, SHALL allow the ADMIN to select a plan version and cycle, and SHALL calculate the amount and currency on the server from stored price data. The system SHALL reject negative/unknown prices, inactive plan versions and unsupported cycles.

#### Scenario: Cálculo anual
- **GIVEN** an active plan with a stored annual price of 2400 BOB
- **WHEN** the ADMIN selects the ANNUAL cycle
- **THEN** the backend returns 2400 BOB and the currency BOB
- **AND** ignores any client-supplied amount

### Requirement: Checkout Stripe seguro e idempotente
The system SHALL create a local PENDING payment and a hosted Stripe Checkout session from the authoritative amount and plan snapshot. The system SHALL NOT accept or store card details and SHALL bind the session to the current tenant, subscription and ADMIN. Repeated requests for the same active checkout SHALL return the existing session rather than create duplicate charges.

#### Scenario: Crear checkout
- **WHEN** an ADMIN selects plan version and cycle
- **THEN** the system responds 201 with a payment id, amount, currency, expiry and Stripe checkout URL
- **AND** creates no subscription extension yet

#### Scenario: Intento de sobrescribir el monto
- **GIVEN** the body contains an extra `amount` or `tenant_id`
- **WHEN** checkout is requested
- **THEN** the system responds 422
- **AND** creates no payment or Stripe session

### Requirement: Confirmación y vigencia idempotentes
The system SHALL accept subscription payment confirmation only from a Stripe webhook with a valid signature or an explicit server-side synchronization with Stripe. The system SHALL update payment, subscription period and plan reference atomically and SHALL make repeated webhook delivery idempotent.

#### Scenario: Webhook duplicado
- **GIVEN** `checkout.session.completed` was processed successfully
- **WHEN** the same event is delivered again
- **THEN** the system returns an accepted acknowledgement
- **AND** does not duplicate payment, period extension or invoice

#### Scenario: Firma inválida
- **WHEN** the webhook signature is missing or invalid
- **THEN** the system responds 400
- **AND** does not change payment or subscription

#### Scenario: Renovación vigente
- **GIVEN** an ACTIVE subscription ending 2026-04-30
- **WHEN** an annual payment is confirmed on 2026-04-10
- **THEN** the new period starts 2026-05-01 and ends 2027-04-30
- **AND** the previous paid period is not lost

### Requirement: Comprobante PDF e historial
The system SHALL generate exactly one comprobante/factura PDF for a confirmed subscription payment, including tenant identity, plan, cycle, amount, currency, date and Stripe reference. The system SHALL allow the tenant ADMIN to list and download only its own payment history and SHALL return 404 for cross-tenant payment ids.

#### Scenario: Descargar comprobante
- **WHEN** the ADMIN downloads a confirmed payment receipt
- **THEN** the response is `application/pdf` with a unique invoice number
- **AND** the PDF contains the tenant and payment reference

#### Scenario: Pago pendiente
- **WHEN** the ADMIN requests a receipt for a PENDING or FAILED payment
- **THEN** no issued invoice is presented as final
- **AND** the response explains that payment is not confirmed

### Requirement: Fallo y reintento sin pérdida
The system SHALL preserve the current subscription when checkout creation or payment fails, SHALL report the failure reason, and SHALL allow the ADMIN to retry with the selected plan/cycle. The system SHALL NOT extend validity for a failed payment.

#### Scenario: Tarjeta rechazada
- **GIVEN** Stripe reports the checkout as failed
- **WHEN** the ADMIN returns or synchronizes
- **THEN** the payment is FAILED and the current subscription is unchanged
- **AND** the interface can retry without selecting the plan again