# Spec Delta

## Purpose

Define el contrato backend de CU06 para buscar especialistas por perfil, especialidad, modalidad, costo y fecha dentro del tenant actual, incluyendo disponibilidad real y aislamiento estricto.

## ADDED Requirements

### Requirement: Búsqueda filtrada y aislada de especialistas
The system SHALL exponer `GET /api/v1/especialistas/buscar` para usuarios autenticados del tenant y SHALL aplicar simultáneamente nombre, especialidad, modalidad, costo mínimo/máximo, rango de fechas y paginación. The system SHALL resolver el tenant desde el claim JWT o `X-Tenant-ID` conforme a `project.md`; SHALL NOT aceptar `tenant_id` en query o body; and SHALL return only professionals, services, prices and availability belonging to the current tenant.

#### Scenario: Filtros combinados
- **GIVEN** el tenant actual tiene un cardiólogo con servicio PRESENCIAL de 150 BOB y una cardióloga con servicio TELECONSULTA de 250 BOB
- **WHEN** se busca especialidad Cardiología, modalidad TELECONSULTA, costo máximo 300 y fecha 2026-04-10
- **THEN** responde 200 con la cardióloga y su servicio
- **AND** no incluye al cardiólogo ni profesionales de otro tenant

#### Scenario: Rango inválido
- **GIVEN** costo mínimo mayor que costo máximo o fecha final anterior a fecha inicial
- **WHEN** se ejecuta la búsqueda
- **THEN** responde 422 con detalle de validación
- **AND** no ejecuta consultas contra la base de datos

#### Scenario: Sin coincidencias
- **WHEN** ningún profesional activo cumple todos los filtros
- **THEN** responde 200 con `total = 0` e `items = []`

### Requirement: Disponibilidad real y calendario
The system SHALL calculate availability from active `horarios_medicos`, service duration, occupied `citas` and approved `bloqueos_agenda`, within the current tenant. The system SHALL expose `GET /api/v1/especialistas/{id_medico}/disponibilidad` for a date range of at most 31 days. A slot SHALL be available only when its complete interval fits the schedule and does not intersect an occupied or blocked interval.

#### Scenario: Slot ocupado o bloqueado
- **GIVEN** un horario 08:00–12:00 con citas y bloqueos que cubren 09:00–10:00
- **WHEN** se consulta disponibilidad
- **THEN** los slots que intersectan ese intervalo figuran como no disponibles
- **AND** los slots libres circundantes figuran como disponibles

#### Scenario: Profesional de otro tenant
- **GIVEN** un `id_medico` existente pero perteneciente a otro tenant
- **WHEN** se solicita su disponibilidad
- **THEN** responde 404 sin revelar nombre, especialidad, horario ni servicios

#### Scenario: Privacidad del resultado
- **WHEN** se devuelve un resultado de búsqueda
- **THEN** la respuesta no contiene identificador ni datos de pacientes, motivo de consulta, diagnóstico ni información clínica

### Requirement: Contrato estable para web y móvil
The system SHALL return `total`, `page`, `per_page` and `items`; each item SHALL contain professional identity, specialties, services, cost, modalities and available slots. The system SHALL normalize dates as `YYYY-MM-DD`, times as `HH:MM:SS`, money as decimal with currency BOB, and SHALL expose only `200`, `401`, `403`, `404` and `422` for these operations.

#### Scenario: Autorización
- **GIVEN** una sesión sin tenant válido
- **WHEN** se consulta el directorio
- **THEN** responde 401 o 403 según exista o no un tenant resoluble

### Requirement: Rendimiento de búsqueda
The system SHALL use indexed and paginated queries and SHALL meet a p95 response time below 2 seconds for the agreed representative dataset.

#### Scenario: Catálogo representativo
- **GIVEN** 100 profesionales y un rango de 31 días en el tenant de prueba
- **WHEN** se ejecuta la búsqueda con filtros
- **THEN** el tiempo p95 medido en el backend es menor a 2 segundos