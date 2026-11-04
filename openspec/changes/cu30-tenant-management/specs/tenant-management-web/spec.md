# Spec Delta

## Purpose

Define el backoffice web de CU30 para que el Super Administrador revise solicitudes y gestione el ciclo de vida y acuerdo comercial de tenants.

## ADDED Requirements

### Requirement: Acceso exclusivo al backoffice de tenants
The system SHALL expose tenant management navigation and routes only to a verified global Super Administrator. The system SHALL wait for a fresh `/auth/me` profile, SHALL hide links for tenant ADMIN/other roles, and SHALL prevent direct navigation without granting access to protected data.

#### Scenario: ADMIN de clínica navega directamente
- **GIVEN** a verified tenant ADMIN profile
- **WHEN** the user opens `/admin/tenants` or `/admin/tenant-requests`
- **THEN** the guard redirects away and the tenant request/tenant APIs are not consumed

### Requirement: Revisión y decisión de solicitudes
The system SHALL provide paginated request lists with status filters, a detail view for institutional data, representative, plan interest and legal document metadata, and explicit approve/reject actions. The system SHALL require a rejection reason, show confirmations and preserve the user's input on a recoverable error.

#### Scenario: Rechazar solicitud
- **WHEN** the Super Administrator enters a reason and rejects a PENDING request
- **THEN** the interface confirms the decision, refreshes the list and shows the audited result

#### Scenario: Documento no disponible
- **WHEN** document metadata is missing or its storage object is unavailable
- **THEN** the interface shows a recoverable error
- **AND** does not claim that the document was downloaded or approved

### Requirement: Gestión del estado y acuerdo comercial
The system SHALL allow the Super Administrator to activate, suspend, reactivate and deactivate tenants with mandatory reasons where applicable, and SHALL show status, current plan/commercial agreement, pending subscription state and change history. The system SHALL NOT expose payment collection in this case of use.

#### Scenario: Suspender tenant
- **WHEN** the Super Administrator confirms suspension with a reason
- **THEN** the interface shows the tenant as SUSPENDED and explains that in-progress consultations and histories remain protected

#### Scenario: Conflicto de versión
- **WHEN** the backend responds 409 to a stale state change
- **THEN** the interface reloads the tenant, informs the user that it changed elsewhere and does not retry automatically

### Requirement: Presentación auditable y adaptable
The system SHALL present actor, timestamp, reason and before/after state for lifecycle events, SHALL use accessible labels/dialogs/focus and SHALL remain usable in narrow viewports without horizontal page overflow.

#### Scenario: Auditoría visible
- **WHEN** the Super Administrator opens the change history of a tenant
- **THEN** the interface shows actor, timestamp, reason and previous/new state
- **AND** does not expose the personal data of patients or documents

#### Scenario: Diálogo accesible en pantalla pequeña
- **GIVEN** a narrow viewport
- **WHEN** the user opens a confirmation dialog
- **THEN** focus is trapped within the dialog, controls have labels and the page does not overflow horizontally