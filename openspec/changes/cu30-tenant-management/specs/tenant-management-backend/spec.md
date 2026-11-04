# Spec Delta

## Purpose

Define la administración global de tenants de CU30: solicitudes, decisiones, ciclo de vida, acuerdos comerciales, auditoría y continuidad clínica durante suspensión.

## ADDED Requirements

### Requirement: Backoffice global exclusivo del Super Administrador
The system SHALL expose tenant request and tenant lifecycle operations only to an active authenticated user whose global role is `Super Administrador` (`roles.id_clinica IS NULL` and `usuarios.id_clinica IS NULL`). The system SHALL NOT treat a tenant `ADMIN` role as global Super Administrator and SHALL audit every successful or rejected administrative action.

#### Scenario: Administrador de tenant intenta operación global
- **GIVEN** an active ADMIN belonging to a tenant
- **WHEN** the user requests the global tenant list or a lifecycle mutation
- **THEN** the system responds 403
- **AND** no tenant state or request is changed

#### Scenario: Super Administrador global
- **GIVEN** an active user with the seeded global Super Administrador role
- **WHEN** the user opens the backoffice
- **THEN** the API permits global requests without requiring `X-Tenant-ID`

### Requirement: Solicitudes de ingreso revisables
The system SHALL store each onboarding request independently from an active tenant, including institutional snapshot, legal representative, requested plan, documents, contact email, status and decision metadata. The system SHALL allow the Super Administrator to list, filter, inspect documents and approve or reject a request with a mandatory reason for rejection.

#### Scenario: Solicitud pendiente
- **GIVEN** a request with status PENDING and uploaded legal documents
- **WHEN** the Super Administrator opens its detail
- **THEN** the response shows institutional data, representative, plan interest, document metadata and PENDING status
- **AND** does not expose an active tenant or tenant clinical data

#### Scenario: Rechazo
- **WHEN** the Super Administrator rejects a PENDING request with a reason
- **THEN** the response is 200 and the request becomes REJECTED
- **AND** no tenant, ADMIN user or active subscription is created
- **AND** the decision is audited

#### Scenario: Aprobación
- **WHEN** the Super Administrator approves a PENDING request
- **THEN** the system atomically creates one tenant with UUID, one tenant ADMIN and the initial commercial agreement
- **AND** marks the request APPROVED
- **AND** a second approval cannot create another tenant

### Requirement: Ciclo de vida del tenant
The system SHALL support ACTIVE, SUSPENDED and INACTIVE states with reason, actor, timestamps and optimistic version. The system SHALL use soft deactivation and SHALL NOT physically delete clinical data. The system SHALL allow activation, suspension and reactivation only through defined transitions.

#### Scenario: Suspender por mora
- **GIVEN** an ACTIVE tenant
- **WHEN** the Super Administrator suspends it with a reason
- **THEN** the tenant becomes SUSPENDED
- **AND** new reservations and ordinary tenant operations are rejected
- **AND** the event records previous/new state and reason

#### Scenario: Versión obsoleta
- **GIVEN** another administrator already changed the tenant
- **WHEN** a stale update is submitted
- **THEN** the system responds 409
- **AND** does not overwrite the newer state

### Requirement: Continuidad clínica durante suspensión
The system SHALL allow authorized users to finish and access a teleconsulta or consultation already in progress and to access its clinical history, and SHALL allow authorized export of existing histories, even while the tenant is SUSPENDED. The system SHALL continue to reject new appointments, new clinical consultations and other ordinary mutating operations. Suspension SHALL NOT delete or reassign histories, consultations, documents or prescriptions.

#### Scenario: Teleconsulta en curso
- **GIVEN** a SUSPENDED tenant with a teleconsulta already in progress
- **WHEN** its assigned doctor or patient accesses the session and consultation
- **THEN** access is allowed according to the resource's normal role rules
- **AND** the clinical records remain readable and attributable to the original tenant

#### Scenario: Nueva cita durante suspensión
- **WHEN** the same tenant attempts to reserve a new appointment
- **THEN** the system responds 403 with a tenant-suspended reason
- **AND** creates no appointment or notification

### Requirement: Acuerdos comerciales y auditoría
The system SHALL allow the Super Administrator to update the tenant's referenced plan and commercial notes, without collecting payment or modifying plan versions (CU34/CU31). The system SHALL write global audit events containing actor, action, target tenant/request, reason, before/after state and timestamp.

#### Scenario: Actualizar acuerdo
- **WHEN** the Super Administrator selects an active plan and updates commercial notes
- **THEN** the agreement reference is updated and audited
- **AND** no payment, invoice or plan catalogue mutation occurs