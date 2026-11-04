# Spec Delta

## Purpose

Define la experiencia Flutter de CU06 para buscar especialistas y consultar disponibilidad real con el mismo contrato que la web.

## ADDED Requirements

### Requirement: Búsqueda móvil de especialistas
The system SHALL provide a Flutter directory for authenticated patients and reception staff, organized as `data`, `domain` and `presentation` under `lib/features/appointments/specialist_search/`. The system SHALL consume the shared specialist-search API and SHALL support name, specialty, modality, cost range and date range filters.

#### Scenario: Consultar filtros
- **GIVEN** an authenticated mobile session
- **WHEN** the user opens the specialist directory
- **THEN** the application presents specialty, modality, cost and date controls
- **AND** requests results using the same contract as the web application

#### Scenario: Estado vacío
- **WHEN** the API returns no matches
- **THEN** the mobile interface displays “No se encontraron resultados”
- **AND** keeps the current filters available for modification

### Requirement: Resultados y detalle móvil
The system SHALL display professional photo, name, specialty, professional license, cost and modalities, and SHALL allow opening real availability. The system SHALL use atomic states for initial, loading, success and error, and SHALL support pull-to-refresh without losing the current filters.

#### Scenario: Abrir disponibilidad
- **WHEN** the user selects a professional
- **THEN** the detail screen requests availability for the selected dates
- **AND** renders free and occupied slots according to the response

#### Scenario: Sesión o tenant no disponible
- **WHEN** the API responds 401 or 403
- **THEN** the application shows an access error
- **AND** does not retain protected results from a previous tenant

### Requirement: Cliente móvil seguro y consistente
The system SHALL send the bearer token and tenant context through the existing secure API client, SHALL store no token or tenant identifier outside secure storage, and SHALL parse snake_case and camelCase keys defensively for backward compatibility with the contract.

#### Scenario: Cambio de cuenta o tenant
- **WHEN** the session changes
- **THEN** protected specialist data is cleared before the new context is displayed