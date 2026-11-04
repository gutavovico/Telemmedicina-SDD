# Spec Delta

## Purpose

Define el portal web de CU32 para el alta institucional pública, el seguimiento seguro y la solicitud autenticada de baja de una entidad activa.

## ADDED Requirements

### Requirement: Portal público de alta institucional
The system SHALL provide an unauthenticated web form for a health entity to enter institutional data, legal representative and plan interest, and to attach required legal documents. The system SHALL use strongly typed Reactive Forms, show field and file errors, and SHALL NOT imply that the tenant is already active.

#### Scenario: Enviar solicitud
- **WHEN** the representative completes all required fields and attaches valid documents
- **THEN** the interface submits multipart data once
- **AND** displays the tracking code and explains that the request is PENDING review

#### Scenario: Validación local
- **WHEN** a required field or document is invalid
- **THEN** the interface identifies the field/document and prevents submission
- **AND** preserves entered values

#### Scenario: Documento rechazado
- **WHEN** the server rejects an unsupported, oversized or invalid-signature file
- **THEN** the interface reports the specific file problem
- **AND** does not state that the request was received

### Requirement: Seguimiento y notificación
The system SHALL provide a public tracking page where the representative enters the tracking code and sees only status and an appropriate decision message. The system SHALL explain that receipt was emailed and SHALL never display private documents or internal review notes.

#### Scenario: Solicitud pendiente
- **WHEN** a valid code identifies a PENDING request
- **THEN** the page shows pending status and next-step guidance
- **AND** does not expose internal notes

#### Scenario: Solicitud rechazada
- **WHEN** a valid code identifies a REJECTED request
- **THEN** the page shows the rejection and the contact channel for clarification

### Requirement: Baja definitiva desde la web autenticada
The system SHALL provide a deactivation option only to the ADMIN of the current ACTIVE tenant, SHALL require a reason and confirmation, and SHALL explain that clinical records are retained. The system SHALL display the resulting request status and SHALL NOT delete data from the browser flow.

#### Scenario: Confirmar baja
- **WHEN** the ADMIN enters a reason and confirms
- **THEN** the interface submits the request and shows PENDING
- **AND** clearly states that the Super Administrator must evaluate it

#### Scenario: Conflicto
- **WHEN** the backend responds 409 because the tenant is no longer active
- **THEN** the interface displays the current state and offers the appropriate support path

### Requirement: Formulario accesible y adaptable
The system SHALL provide labels, keyboard navigation, visible focus, announced validation and non-color-only status cues. The system SHALL adapt the form and file list to narrow viewports without horizontal page overflow.

#### Scenario: Navegación por teclado
- **WHEN** the representative completes and submits the form using only the keyboard
- **THEN** every field and file control is reachable
- **AND** focus is visible and validation results are announced

#### Scenario: Pantalla estrecha
- **GIVEN** a viewport of 360 CSS pixels
- **WHEN** the form and uploaded file list are displayed
- **THEN** all content remains readable and usable
- **AND** the page does not overflow horizontally