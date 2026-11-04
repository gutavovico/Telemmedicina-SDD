# Spec Delta

## Purpose

Define el panel web de CU31 para que el ADMIN del tenant revise su suscripción, pague mediante Stripe y descargue comprobantes sin exponer otros tenants.

## ADDED Requirements

### Requirement: Panel de suscripción exclusivo del ADMIN del tenant
The system SHALL expose subscription payment navigation and routes only to an authenticated tenant ADMIN with a fresh verified profile. The system SHALL hide the entry for other roles and SHALL not display another tenant's subscription.

#### Scenario: Rol no autorizado
- **GIVEN** a MEDICO, RECEPCION, PACIENTE or global Super Administrator profile
- **WHEN** the user opens `/admin/suscripcion` directly
- **THEN** the guard prevents access
- **AND** no subscription data is rendered

### Requirement: Selección y redirección a pago
The system SHALL show current subscription status, plan details, limits, cycle, period and DUE_SOON information; SHALL allow selecting an active plan version and MONTHLY/ANNUAL cycle; and SHALL request checkout from the backend. The system SHALL display the server-calculated amount and redirect to the returned hosted Stripe URL.

#### Scenario: Continuar al pago
- **WHEN** the ADMIN selects plan and cycle and confirms
- **THEN** the interface calls the checkout API once
- **AND** redirects to the returned checkout URL
- **AND** does not collect card data in the application

#### Scenario: Fallo de creación
- **WHEN** checkout creation fails
- **THEN** the interface displays a recoverable error
- **AND** preserves the selected plan and cycle for retry

### Requirement: Resultado autoritativo e idempotente
The system SHALL treat the return URL as a trigger to query/synchronize status, not as proof of payment. The system SHALL display success only when the backend reports a confirmed payment and SHALL distinguish pending, failed, cancelled and expired states.

#### Scenario: Regreso antes del webhook
- **WHEN** the return page loads while the backend still reports PENDING
- **THEN** the interface shows that confirmation is pending
- **AND** can refresh without starting a second charge

#### Scenario: Pago confirmado
- **WHEN** the backend reports PAGADO
- **THEN** the interface shows the new validity period and enables receipt download

### Requirement: Historial y comprobante
The system SHALL show paginated subscription payments with date, plan, cycle, amount and status, and SHALL download the PDF receipt only for a confirmed payment. The system SHALL show accessible loading, empty and error states and SHALL adapt to narrow viewports.

#### Scenario: Descarga fallida
- **WHEN** the receipt request fails
- **THEN** the interface informs the user and does not download or open an error JSON as a PDF