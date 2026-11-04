# Spec Delta

## Purpose

Define el contrato backend de CU32 para registrar solicitudes públicas de alta con documentos, notificar su estado y solicitar la baja formal de tenants activos.

## ADDED Requirements

### Requirement: Formulario público de solicitud de alta
The system SHALL expose an unauthenticated public endpoint to submit a health-entity onboarding request containing institutional name, legal name, normalized NIT, contact email and phone, address, responsible person's name/email/phone and requested plan. The system SHALL validate required fields, formats and allowed file types, SHALL create the request in PENDING status, and SHALL NOT create or activate a tenant or user account.

#### Scenario: Alta pendiente válida
- **GIVEN** complete institutional and responsible data plus required legal documents
- **WHEN** the representative submits the form
- **THEN** the system responds 202 with a request id and tracking code
- **AND** stores a PENDING request
- **AND** creates no active tenant

#### Scenario: Datos inválidos
- **WHEN** NIT, email, required document or responsible data is invalid
- **THEN** the system responds 422 with field-level errors
- **AND** stores no partial request

#### Scenario: NIT duplicado
- **GIVEN** a PENDING request or active tenant already has the same normalized NIT
- **WHEN** a new request is submitted
- **THEN** the system responds 409 with a safe duplicate notice
- **AND** creates no second tenant or request

### Requirement: Documentos legales privados
The system SHALL accept legal documents as multipart files with allowlisted MIME/extensions, size limits, random storage keys and SHA-256 hashes. The system SHALL store documents outside the public root and SHALL expose them only to the authorized Super Administrator or the owning request according to policy. The system SHALL reject path traversal, executable content and mismatched file signatures.

#### Scenario: Documento válido
- **WHEN** a PDF below the size limit is uploaded with a valid signature
- **THEN** the system records private storage key, MIME and SHA-256 hash
- **AND** does not return a publicly guessable URL

#### Scenario: Archivo no permitido
- **WHEN** an executable or oversized file is uploaded
- **THEN** the system responds 422 or 413
- **AND** stores no document metadata or file

### Requirement: Confirmación y seguimiento de solicitud
The system SHALL send an email confirming receipt to the responsible email and SHALL store delivery attempts. The system SHALL provide a public tracking endpoint requiring the opaque tracking code, SHALL return only request status and a decision reason when applicable, and SHALL NOT reveal documents, internal notes or tenant clinical data.

#### Scenario: Consulta con código correcto
- **WHEN** the representative supplies the tracking code
- **THEN** the response shows PENDING and the institution display name
- **AND** returns no private document or internal metadata

#### Scenario: Código incorrecto
- **WHEN** an invalid or expired tracking code is supplied
- **THEN** the system responds 404 without disclosing whether a request exists

#### Scenario: Notificación de decisión
- **WHEN** CU30 approves or rejects the request
- **THEN** the system queues/sends an email to the responsible address with the outcome and rejection reason when present
- **AND** records the delivery attempt

### Requirement: Solicitud de baja de tenant activo
The system SHALL allow only an authenticated ADMIN of an ACTIVE tenant to submit a deactivation request with a mandatory reason. The system SHALL create a PENDING deactivation request, SHALL NOT delete tenant, users, appointments, consultations, histories, documents or prescriptions, and SHALL make the request visible to the Super Administrator for decision.

#### Scenario: Baja solicitada
- **WHEN** the tenant ADMIN submits a reason
- **THEN** the system responds 202 with a deactivation request id
- **AND** the tenant remains present with its clinical data

#### Scenario: ADMIN de otro tenant
- **GIVEN** an ADMIN belonging to a different tenant
- **WHEN** the user submits a deactivation request using another tenant id
- **THEN** the system responds 404 or 403
- **AND** creates no request

#### Scenario: Tenant no activo
- **WHEN** an INACTIVE or SUSPENDED tenant attempts to request permanent deactivation
- **THEN** the system responds 409 and directs the user to the appropriate support/operational process
- **AND** creates no duplicate request

### Requirement: Seguridad del portal público
The system SHALL apply rate limiting and audit security-relevant submissions by request correlation, IP and user-agent without exposing them in public responses. The system SHALL NOT treat the public request as authentication of the future tenant administrator.

#### Scenario: Exceso de solicitudes
- **GIVEN** the same IP or contact email exceeds the configured request threshold
- **WHEN** another onboarding request is submitted
- **THEN** the system responds 429 with a retry indication
- **AND** does not persist a partial request or upload

#### Scenario: Auditoría no expuesta
- **WHEN** the representative tracks a valid request
- **THEN** the public response contains only the minimal status information
- **AND** does not expose IP address, user-agent, internal notes or document metadata