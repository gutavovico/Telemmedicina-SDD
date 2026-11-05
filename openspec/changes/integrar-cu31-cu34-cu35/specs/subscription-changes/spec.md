## ADDED Requirements

### Requirement: Contracted snapshots
The system SHALL retain the contracted CU34 version and the version charged on each payment.

#### Scenario: Catalog edition
- **WHEN** the superadministrator creates a new version
- **THEN** the subscription and previous payments retain their original version identifiers and conditions

### Requirement: Effective subscription changes
The system SHALL apply an immediate upgrade only after verified payment and SHALL apply scheduled changes or cancellation at their effective date, isolated by entity.

#### Scenario: Duplicate confirmation
- **WHEN** a payment confirmation is delivered twice
- **THEN** only one change is applied and the original cycle end is preserved

#### Scenario: Scheduled action
- **WHEN** a scheduled action is processed before its effective date
- **THEN** the current contract remains unchanged

#### Scenario: Foreign entity
- **WHEN** another entity requests a payment or change belonging to a different subscription
- **THEN** the operation is rejected without revealing or modifying that subscription


### Requirement: Explicit monthly renewal acceptance
The system SHALL show the currently published version of the same plan before checkout and SHALL bind renewal to the accepted version and agreed monthly period. A pending cancellation SHALL block renewal; a pending change SHALL use its stored destination version.

#### Scenario: Version published after acceptance
- **WHEN** a newer version is published after a renewal checkout was accepted
- **THEN** the confirmed payment and next cycle use the accepted snapshot and the paid current cycle remains unchanged until closing

#### Scenario: No accepted or successful renewal
- **WHEN** the administrator does not accept or payment fails
- **THEN** the system does not extend the paid cycle or apply the new version

#### Scenario: Unpaid scheduled destination
- **WHEN** the effective closing arrives without a confirmed destination renewal payment
- **THEN** the request waits for renewal without changing the previous paid dates or substituting the requested snapshot

### Requirement: Effective cancellation access
The system SHALL deny clinical use for the canceled entity from its effective date, including worker delay, while preserving administrator login, subscription state, payment history, receipts and clinical data.

#### Scenario: Another entity remains active
- **WHEN** one entity reaches its cancellation date
- **THEN** only that entity loses clinical access and another active entity retains access

### Requirement: Verified historical migration
The system SHALL preserve applied CU18 and catalog revisions, converge both histories in a new revision and require an explicit verified original billing anchor for each existing subscription, without matching versions by name.

#### Scenario: Original anchor unavailable
- **WHEN** an existing subscription has no operator-verified original anchor mapping
- **THEN** migration fails without altering its version, dates or historical payments

#### Scenario: Populated canonical subscription
- **GIVEN** an explicit original anchor fixture and a subscription and payment referencing a canonical CU34 version
- **WHEN** the CU18 database is upgraded to the converged head
- **THEN** the exact version references, charged amount and agreed cycle dates remain unchanged
