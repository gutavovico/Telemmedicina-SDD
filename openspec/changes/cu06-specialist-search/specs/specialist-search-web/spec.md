# Spec Delta

## Purpose

Define la experiencia web de CU06 para buscar especialistas, revisar perfiles y consultar disponibilidad real mediante el contrato compartido.

## ADDED Requirements

### Requirement: Directorio de especialistas en la web
The system SHALL provide a web directory for authenticated patients and reception staff, using standalone Angular components, Signals, strongly typed Reactive Forms and the specialist-search API. The system SHALL allow free-text name search and filters for specialty, modality, minimum/maximum cost and date range. The system SHALL show photo, name, specialty, professional license, cost and available modalities.

#### Scenario: Búsqueda desde la interfaz
- **GIVEN** un paciente autenticado
- **WHEN** enters a name, specialty, modality, cost range and dates and submits
- **THEN** the interface sends one request with the normalized filters
- **AND** shows only matching professionals

#### Scenario: Sin resultados
- **WHEN** the API returns `total = 0`
- **THEN** the interface displays “No se encontraron resultados”
- **AND** preserves the entered filters for adjustment

#### Scenario: Error de servicio
- **WHEN** the API returns 401, 403 or 5xx
- **THEN** the interface shows a recoverable error
- **AND** does not present stale or partial results as current

### Requirement: Perfil y calendario de disponibilidad
The system SHALL allow the user to select a professional and view the profile and real availability returned by the API. The system SHALL distinguish available and unavailable slots and SHALL provide a route to the existing appointment workflow without reserving directly from this case.

#### Scenario: Seleccionar profesional
- **WHEN** the user selects a result card
- **THEN** the detail page shows professional and service information
- **AND** requests availability for the selected date range

#### Scenario: Cambiar filtro con respuesta atrasada
- **GIVEN** an older search request remains in flight
- **WHEN** a newer request completes first
- **THEN** the older response cannot replace the newer results

### Requirement: Presentación adaptable y accesible
The system SHALL preserve the established visual system, keyboard navigation, labels, visible focus and readable error/empty states. The system SHALL adapt filters and cards to narrow viewports without horizontal page overflow.

#### Scenario: Pantalla pequeña
- **GIVEN** a viewport of 360 CSS pixels
- **WHEN** the user opens filters and results
- **THEN** controls remain usable, text is legible and the page does not overflow horizontally