# Doctor and Specialties Management Specification

## Purpose
Gestionar los perfiles profesionales de médicos y especialistas, incluyendo matrículas profesionales, credenciales, catálogo de especialidades clínicas y asignación de áreas de atención con aislamiento lógico por inquilino (`tenant_id`) en la plataforma SaaS Multitenant (CU04).

## Requirements

### Requirement: Registro y Mantenimiento del Perfil Profesional Médico (CU04)
The system SHALL permitir asociar un perfil profesional médico a una cuenta de usuario existente en el inquilino, validando la unicidad de la matrícula profesional dentro del tenant y manteniendo la relación 1:1.

#### Scenario: Alta exitosa de un médico con matrícula y datos profesionales
- **GIVEN** que existe una cuenta de usuario activa con ID 15 con rol "MEDICO" en el tenant del administrador
- **WHEN** el administrador envía una solicitud `POST /api/v1/medicos` con:
  ```json
  {
    "id_usuario": 15,
    "matricula_profesional": "BOL-1234",
    "descripcion_profesional": "Especialista en Nutrición Clínica y Dietética",
    "anios_experiencia": 8,
    "foto_profesional": "https://storage.telemedicina.com/medicos/linguini.jpg",
    "especialidades": [
      {
        "id_especialidad": 1,
        "es_principal": true
      }
    ]
  }
  ```
- **THEN** el sistema responde con código HTTP `201 Created`
- **AND** el perfil médico queda creado con estado "activo" y asociado al `tenant_id` de la clínica
- **AND** la especialidad con ID 1 queda marcada como principal

#### Scenario: Intento de registro con matrícula profesional duplicada en el mismo tenant
- **GIVEN** que ya existe un médico registrado con matrícula "BOL-1234" en el mismo tenant
- **WHEN** se intenta dar de alta a otro usuario con la misma matrícula "BOL-1234"
- **THEN** el sistema responde con código HTTP `400 Bad Request` o `409 Conflict`
- **AND** el mensaje indica "Ya existe un médico registrado con esta matrícula profesional"

#### Scenario: Registro de la misma matrícula en tenants diferentes
- **GIVEN** que existe un médico con matrícula "BOL-1234" en el tenant "11111111-1111-1111-1111-111111111111"
- **WHEN** una clínica distinta con tenant "22222222-2222-2222-2222-222222222222" registra a un médico con la misma matrícula "BOL-1234"
- **THEN** el sistema permite la creación y responde con código HTTP `201 Created`
- **AND** ambas clínicas operan sus registros médicos de manera independiente

#### Scenario: Actualización de datos profesionales del médico
- **GIVEN** que existe un médico con ID 3 en el tenant
- **WHEN** se envía una solicitud `PUT /api/v1/medicos/3` con nuevos años de experiencia y descripción
- **THEN** el sistema responde con código HTTP `200 OK`
- **AND** los datos quedan actualizados en la base de datos

### Requirement: Consulta y Búsqueda Filtrada de Médicos
The system SHALL permitir la búsqueda y listado paginado de especialistas médicos dentro del inquilino, aplicando filtros por nombre, especialidad y estado de actividad.

#### Scenario: Listado paginado de médicos con filtro de especialidad
- **GIVEN** que existen 12 médicos registrados en el tenant, 4 de ellos con la especialidad "Nutrición" (ID 1)
- **WHEN** un usuario autenticado envía `GET /api/v1/medicos?id_especialidad=1&skip=0&limit=10`
- **THEN** el sistema responde con código HTTP `200 OK`
- **AND** el campo `total` es 4 y la lista `items` contiene únicamente a los 4 médicos de nutrición pertenecientes al tenant

#### Scenario: Médico autenticado consulta su propio perfil profesional
- **GIVEN** que el usuario autenticado tiene rol "MEDICO" y posee un perfil profesional asociado
- **WHEN** envía una solicitud `GET /api/v1/medicos/me`
- **THEN** el sistema responde con código HTTP `200 OK`
- **AND** devuelve su perfil profesional, incluyendo matrícula, descripción y lista de especialidades asignadas

### Requirement: Gestión del Catálogo de Especialidades y Asignaciones
The system SHALL administrar el catálogo de especialidades médicas y su vinculación con los profesionales, garantizando que cada médico posea a lo sumo una especialidad principal.

#### Scenario: Asignación de nueva especialidad principal
- **GIVEN** que un médico ya tiene una especialidad principal asignada
- **WHEN** el administrador envía `POST /api/v1/medicos/{id_medico}/especialidades` con una nueva especialidad marcada con `"es_principal": true`
- **THEN** el sistema responde con código HTTP `200 OK`
- **AND** desmarca automáticamente la especialidad principal previa
- **AND** establece la nueva especialidad como la única principal del médico

#### Scenario: Intento de eliminación de especialidad asignada a médicos activos
- **GIVEN** que la especialidad con ID 2 tiene médicos asignados en la clínica
- **WHEN** el administrador envía una solicitud `DELETE /api/v1/especialidades/2`
- **THEN** el sistema rechaza la eliminación con código HTTP `409 Conflict`
- **AND** el mensaje indica que no se puede eliminar una especialidad con médicos vinculados
