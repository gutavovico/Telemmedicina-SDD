## Purpose
Administrar integralmente el ciclo de vida de usuarios internos y el modelo de control de acceso basado en roles (RBAC: Administrador, Médico, Recepción, Paciente) y permisos granulares, garantizando el particionamiento lógico y la unicidad compuesta por inquilino (`tenant_id`) en la plataforma SaaS (CU02, CU26).

## ADDED Requirements

### Requirement: Gestión de Cuentas de Usuario por Inquilino (CU02)
The system SHALL permitir a los administradores autenticados crear, consultar, actualizar y deshabilitar lógicamente cuentas de usuario asociadas al `tenant_id` de su organización.

#### Scenario: Creación exitosa de un usuario administrativo o asistencial
- **GIVEN** que el usuario autenticado tiene el rol "ADMIN" en el tenant "11111111-1111-1111-1111-111111111111"
- **AND** existe un rol "MEDICO" activo en dicho inquilino con ID 2
- **WHEN** envía una solicitud `POST /api/v1/users` con:
  ```json
  {
    "id_rol": 2,
    "nombres": "Jorge Leonel",
    "apellidos": "Rojas Farell",
    "correo": "jorge.rojas@clinica.com",
    "telefono": "+591 76543210",
    "password": "PasswordSeguro123"
  }
  ```
- **THEN** el sistema responde con código HTTP `201 Created`
- **AND** la respuesta incluye `id_usuario`, el `tenant_id` asignado automáticamente y estado "activo"
- **AND** la contraseña se almacena de forma irreversible mediante hash bcrypt

#### Scenario: Intento de registro de usuario con correo duplicado en el mismo tenant
- **GIVEN** que ya existe un usuario con correo "jorge.rojas@clinica.com" en el mismo `tenant_id`
- **WHEN** el administrador intenta registrar otro usuario con el mismo correo
- **THEN** el sistema responde con código HTTP `400 Bad Request` o `409 Conflict`
- **AND** el mensaje indica "Ya existe un usuario registrado con este correo electrónico"

#### Scenario: Registro del mismo correo en dos tenants diferentes
- **GIVEN** que existe un usuario con correo "director@salud.com" en el tenant "11111111-1111-1111-1111-111111111111"
- **WHEN** un administrador del tenant "22222222-2222-2222-2222-222222222222" registra a un usuario con el mismo correo "director@salud.com"
- **THEN** el sistema responde con código HTTP `201 Created`
- **AND** ambas cuentas coexisten de manera aislada gracias a la restricción compuesta `UNIQUE(tenant_id, correo)`

#### Scenario: Desactivación lógica de un usuario (Soft Disable)
- **GIVEN** que existe un usuario activo con ID 5 en el tenant del administrador
- **WHEN** el administrador envía `PATCH /api/v1/users/5/status` con `{ "activo": false }`
- **THEN** el sistema responde con código HTTP `200 OK`
- **AND** el estado del usuario cambia a "inactivo"
- **AND** cualquier intento de inicio de sesión de dicho usuario es rechazado inmediatamente con código HTTP `403 Forbidden`

### Requirement: Administración de Roles y Matriz de Permisos RBAC (CU26)
The system SHALL proveer la gestión dinámica de roles y la asignación de permisos del sistema acotada al inquilino, restringiendo su configuración exclusivamente a administradores autorizados.

#### Scenario: Consulta del catálogo de roles del tenant
- **GIVEN** que el usuario autenticado tiene el rol "ADMIN" en su tenant
- **WHEN** envía una solicitud `GET /api/v1/roles`
- **THEN** el sistema responde con código HTTP `200 OK`
- **AND** devuelve la lista de roles definidos para su organización (ej. Administrador, Médico, Recepción, Paciente)
- **AND** no se exponen roles pertenecientes a otros inquilinos

#### Scenario: Creación de un rol personalizado en la clínica
- **GIVEN** que el administrador necesita un nuevo perfil "ENFERMERIA"
- **WHEN** envía una solicitud `POST /api/v1/roles` con:
  ```json
  {
    "nombre": "Enfermería",
    "descripcion": "Personal de enfermería y triaje médico"
  }
  ```
- **THEN** el sistema responde con código HTTP `201 Created`
- **AND** crea el rol con estado "ACTIVO" vinculado al `tenant_id` del administrador

#### Scenario: Asignación y reemplazo de permisos a un rol
- **GIVEN** que existe un rol con ID 3 y existen los permisos con IDs [10, 11, 12]
- **WHEN** el administrador envía una solicitud `PUT /api/v1/roles/3/permissions` con:
  ```json
  {
    "id_permisos": [10, 11, 12]
  }
  ```
- **THEN** el sistema responde con código HTTP `200 OK`
- **AND** reemplaza atómicamente la lista de permisos asignados a dicho rol

#### Scenario: Usuario sin rol de administrador intenta acceder a la gestión de usuarios o roles
- **GIVEN** que un usuario autenticado posee el rol "MEDICO" o "PACIENTE"
- **WHEN** intenta enviar una solicitud `GET /api/v1/users` o `POST /api/v1/roles`
- **THEN** el sistema deniega el acceso y responde con código HTTP `403 Forbidden`
- **AND** el mensaje indica "Permiso denegado: se requiere rol de administrador"
