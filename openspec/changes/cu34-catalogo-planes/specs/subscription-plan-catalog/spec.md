## ADDED Requirements

### Requirement: Global authorization
The system SHALL restrict every catalog endpoint to an authenticated, active global superadministrator, with no tenant selection or client-supplied tenant. Tenant administrators and clinical staff SHALL receive 403; anonymous callers SHALL receive 401.

#### Scenario: Tenant cannot administer global plans
- **WHEN** an entity administrator calls any catalog endpoint
- **THEN** the response is 403 even if a tenant header or a role name containing SUPER is supplied

### Requirement: Monthly commercial conditions
The system SHALL accept BOB/MENSUAL only, finite nonnegative decimal monetary strings with at most two fractional digits and twelve integer digits, integer limits from 0 to 2147483647 or NULL for unlimited, and nonnegative integer grace days. Zero price means free. Zero limit means no included units. Omitted tariffs mean unconfigured and never authorize overuse.

#### Scenario: Unlimited resource cannot have a tariff
- **WHEN** a tariff targets a resource whose limit is NULL
- **THEN** validation fails with 422

#### Scenario: Monetary input is invalid
- **WHEN** an amount is negative, nonfinite, a JSON float, or has more than two decimal digits
- **THEN** validation fails with 422 without persistence or rounding

### Requirement: Atomic creation and immutable versions
The system SHALL atomically persist Plan, VersionPlan number 1 and a global audit event. Editing SHALL append a version, require version_base, and serialize changes on the plan row. Prior versions SHALL never be updated or deleted by the catalog. Database constraints SHALL prevent repeated version numbers and PostgreSQL SHALL reject UPDATE/DELETE on historical versions.

#### Scenario: Stale edit
- **WHEN** two requests edit the same base version
- **THEN** only one creates the next version and the other receives 409

#### Scenario: Audit persistence fails
- **WHEN** creation or editing fails while recording audit
- **THEN** the whole catalog transaction rolls back

### Requirement: Search and historical consultation
The system SHALL support paginated search by code/current name, state filtering, current detail and paginated immutable version history and detail. The catalog SHALL impose no limit on the number of plans.

#### Scenario: Search matches current name
- **WHEN** a superadmin searches a current plan name and active state
- **THEN** only matching plans are returned with total and stable ID ordering

### Requirement: Deactivation
The system SHALL deactivate after explicit web confirmation, preserve identity and versions, forbid further edits, and expose no delete/reactivation endpoint. Repeated deactivation SHALL return the same state without additional versions or audit events.

#### Scenario: Repeat deactivation
- **WHEN** an already inactive plan is deactivated
- **THEN** it remains inactive and history and audit counts do not change

### Requirement: Connected administrative web
The system SHALL reuse the admin layout, show navigation only for superadmin, use real HTTP, provide a responsive catalog and side editor, explicit unlimited controls, version history, accessible confirmation, loading/empty/error/success states and protection from double submissions. Failed requests SHALL preserve input. Stale edits SHALL offer explicit reload without silently overwriting the form.

#### Scenario: Failed edit preserves input
- **WHEN** saving returns 409 or a network error
- **THEN** the form remains populated and the user can deliberately reload the latest conditions

### Requirement: Future consumers
The system SHALL expose stable plan and version IDs with complete conditions. CU31/CU35/CU36 SHALL reference the contracted version rather than always selecting the latest. CU34 SHALL neither modify subscriptions nor assert real subscription preservation has been tested.

#### Scenario: New version does not rewrite history
- **WHEN** version 2 is published
- **THEN** querying version 1 returns its original conditions
