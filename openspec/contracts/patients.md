# Contrato de API REST: Pacientes (CU03 - Gestión de Pacientes)

**Versión del Contrato:** 2.0.0 (SaaS Multitenant)  
**Estándar:** OpenAPI 3.1 / RESTful JSON  
**Ruta Base:** `/api/v1/pacientes`  
**Seguridad Global:** `BearerAuth` (Header `Authorization: Bearer <JWT_ACCESS_TOKEN>`)  
**Encabezado Multitenant:** `X-Tenant-ID: <UUID>` (Alternativo o complementario al claim `tenant_id` del token JWT)  
**Dominio:** `medical_records` / `patients`  

---

## 1. Convenciones Multitenant y Seguridad

1. **Resolución de Inquilino (`Tenant Resolution`):**
   - El backend extrae el `tenant_id` prioritariamente del claim `tenant_id` dentro del token JWT de sesión.
   - En peticiones donde el token no esté emitido o en clientes que operen con contexto explícito, se debe enviar el encabezado HTTP `X-Tenant-ID: <UUID>`.
   - **Prevención de Inyección de Tenant:** El cuerpo de la solicitud (`Request Body`) no debe enviar el `tenant_id`; el backend lo asocia automáticamente desde el contexto autenticado para prevenir vulnerabilidades de suplantación de inquilino (*Tenant Injection*).
2. **Aislamiento Estricto:**
   - Si se solicita un `id_paciente` que pertenece a otro `tenant_id`, el sistema responde `404 Not Found` para no filtrar la existencia del recurso.
   - Las respuestas de error estándar informan códigos específicos de inquilino (`TENANT_NOT_FOUND`, `TENANT_INACTIVE`).

---

## 2. Esquemas de Datos (Data Schemas)

### 2.1 `PacienteCreateRequest` (Payload para registrar paciente en el Tenant)
Utilizado para el alta de nuevos pacientes por personal de Recepción o Administrador de la clínica.

```json
{
  "id_usuario": 12,
  "nombres": "Carlos Alberto",
  "apellidos": "Mamani Terrazas",
  "ci": "7891234",
  "complemento": "LP",
  "fecha_nacimiento": "1990-05-15",
  "genero": "M",
  "telefono": "+591 71234567",
  "correo": "carlos.mamani@email.com",
  "direccion": "Av. Banzer 4to Anillo",
  "ciudad": "Santa Cruz de la Sierra",
  "tipo_sangre": "O+",
  "alergias": "Ninguna conocida",
  "antecedentes_patologicos": "Asma leve en la infancia",
  "contacto_emergencia_nombre": "Maria Terrazas",
  "contacto_emergencia_telefono": "+591 79876543",
  "contacto_emergencia_parentesco": "Madre",
  "seguro_medico": "Seguro Universitario",
  "numero_seguro": "SU-98765"
}
```

* **Campos Requeridos:** `nombres`, `apellidos`, `ci`, `fecha_nacimiento`, `genero`, `telefono`
* **Campos Opcionales:** `id_usuario`, `complemento`, `correo`, `direccion`, `ciudad`, `tipo_sangre`, `alergias`, `antecedentes_patologicos`, `contacto_emergencia_nombre`, `contacto_emergencia_telefono`, `contacto_emergencia_parentesco`, `seguro_medico`, `numero_seguro`
* **Enums y Validaciones:**
  * `genero`: `["M", "F", "OTRO"]`
  * `tipo_sangre`: `["A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-", null]`
  * `fecha_nacimiento`: Formato `YYYY-MM-DD`, no puede ser posterior a la fecha actual.

---

### 2.2 `PacienteUpdateRequest` (Payload para actualización dentro del Tenant)
Utilizado por personal autorizado de la clínica para actualizar datos demográficos y clínicos.

```json
{
  "nombres": "Carlos Alberto",
  "apellidos": "Mamani Terrazas",
  "telefono": "+591 78899000",
  "correo": "carlos.mamani@email.com",
  "direccion": "Av. San Martín Calle 7",
  "ciudad": "Santa Cruz de la Sierra",
  "tipo_sangre": "O+",
  "alergias": "Penicilina, AINEs",
  "antecedentes_patologicos": "Hipertensión arterial controlada",
  "contacto_emergencia_nombre": "Maria Terrazas",
  "contacto_emergencia_telefono": "+591 79876543",
  "contacto_emergencia_parentesco": "Madre",
  "seguro_medico": "Seguro Universitario",
  "numero_seguro": "SU-98765",
  "estado": "ACTIVO"
}
```

---

### 2.3 `PacienteProfilePatchRequest` (Payload para actualización desde App Móvil / Perfil propio)
Permite al paciente autenticado actualizar sus datos de contacto y emergencia en el tenant.

```json
{
  "telefono": "+591 70011223",
  "correo": "carlos.nuevo@email.com",
  "direccion": "Barrio Equipetrol Norte",
  "ciudad": "Santa Cruz de la Sierra",
  "contacto_emergencia_nombre": "Roberto Mamani",
  "contacto_emergencia_telefono": "+591 76655443",
  "contacto_emergencia_parentesco": "Hermano"
}
```

---

### 2.4 `PacienteResponse` (Respuesta de un paciente individual con Tenant Context)
Entidad completa devuelta en operaciones de detalle, creación o actualización.

```json
{
  "id_paciente": 10,
  "tenant_id": "11111111-1111-1111-1111-111111111111",
  "id_usuario": 12,
  "nombres": "Carlos Alberto",
  "apellidos": "Mamani Terrazas",
  "ci": "7891234",
  "complemento": "LP",
  "fecha_nacimiento": "1990-05-15",
  "genero": "M",
  "telefono": "+591 71234567",
  "correo": "carlos.mamani@email.com",
  "direccion": "Av. Banzer 4to Anillo",
  "ciudad": "Santa Cruz de la Sierra",
  "tipo_sangre": "O+",
  "alergias": "Penicilina",
  "antecedentes_patologicos": "Hipertensión arterial",
  "contacto_emergencia_nombre": "Maria Terrazas",
  "contacto_emergencia_telefono": "+591 79876543",
  "contacto_emergencia_parentesco": "Madre",
  "seguro_medico": "Seguro Universitario",
  "numero_seguro": "SU-98765",
  "estado": "ACTIVO",
  "created_at": "2026-08-24T10:30:00Z",
  "updated_at": "2026-08-24T10:30:00Z"
}
```

---

### 2.5 `PacientePaginationResponse` (Listado paginado por Tenant)

```json
{
  "items": [
    {
      "id_paciente": 10,
      "tenant_id": "11111111-1111-1111-1111-111111111111",
      "id_usuario": 12,
      "nombres": "Carlos Alberto",
      "apellidos": "Mamani Terrazas",
      "ci": "7891234",
      "complemento": "LP",
      "fecha_nacimiento": "1990-05-15",
      "genero": "M",
      "telefono": "+591 71234567",
      "correo": "carlos.mamani@email.com",
      "estado": "ACTIVO",
      "created_at": "2026-08-24T10:30:00Z"
    }
  ],
  "total": 1,
  "page": 1,
  "page_size": 10,
  "total_pages": 1
}
```

---

### 2.6 `ErrorResponse` (Estructura estándar de errores)

```json
{
  "detail": "Descripción legible del error",
  "code": "PATIENT_ALREADY_EXISTS_IN_TENANT",
  "timestamp": "2026-08-24T14:00:00Z"
}
```

---

## 3. Endpoints

### 3.1 `POST /api/v1/pacientes`
* **Descripción:** Registra un nuevo paciente y su expediente base dentro del inquilino resuelto.
* **Roles Permitidos:** `ADMIN`, `RECEPCION`
* **Headers:**
  * `Authorization: Bearer <token>` (Requerido)
  * `X-Tenant-ID: <UUID>` (Opcional si viene en claim JWT)
* **Request Body:** `PacienteCreateRequest`
* **Respuestas:**
  * `201 Created` → `PacienteResponse` (Incluye `tenant_id` asignado automáticamente).
  * `400 Bad Request` → Formato de UUID o datos inconsistentes.
  * `401 Unauthorized` → Token ausente, inválido o tenant suspendido.
  * `403 Forbidden` → Rol no autorizado.
  * `409 Conflict` → Documento de identidad (C.I. + complemento) o correo ya registrado **dentro de este mismo tenant**.
  * `422 Unprocessable Entity` → Validación de schema fallida.

---

### 3.2 `GET /api/v1/pacientes`
* **Descripción:** Lista los pacientes del tenant con paginación, ordenamiento y filtros de búsqueda.
* **Roles Permitidos:** `ADMIN`, `RECEPCION`, `MEDICO`
* **Headers:**
  * `Authorization: Bearer <token>` (Requerido)
  * `X-Tenant-ID: <UUID>` (Opcional si viene en claim JWT)
* **Query Parameters:**
  * `page` (integer, default: `1`): Número de página.
  * `page_size` (integer, default: `10`, max: `100`): Elementos por página.
  * `q` (string, opcional): Búsqueda por coincidencia en nombres o apellidos en el tenant.
  * `ci` (string, opcional): Búsqueda por número de C.I. en el tenant.
  * `estado` (string, opcional, default: `"ACTIVO"`): Filtro por estado (`ACTIVO`, `INACTIVO`, `TODOS`).
* **Respuestas:**
  * `200 OK` → `PacientePaginationResponse` (Aislado al `tenant_id`).
  * `401 Unauthorized` → Token ausente o inválido.
  * `403 Forbidden` → Rol no autorizado (ej. Paciente intentando listar todos).

---

### 3.3 `GET /api/v1/pacientes/{id_paciente}`
* **Descripción:** Obtiene los datos detallados del expediente del paciente por su ID, validando pertenencia al tenant.
* **Roles Permitidos:** `ADMIN`, `RECEPCION`, `MEDICO`
* **Headers:**
  * `Authorization: Bearer <token>` (Requerido)
  * `X-Tenant-ID: <UUID>` (Opcional si viene en claim JWT)
* **Path Parameters:**
  * `id_paciente` (integer, requerido): Identificador único del paciente.
* **Respuestas:**
  * `200 OK` → `PacienteResponse`
  * `401 Unauthorized`
  * `403 Forbidden`
  * `404 Not Found` → `{"detail": "Paciente no encontrado"}` (Retornado tanto si no existe como si pertenece a otro tenant).

---

### 3.4 `GET /api/v1/pacientes/me`
* **Descripción:** Obtiene los datos del perfil del paciente actualmente autenticado en su tenant.
* **Roles Permitidos:** `PACIENTE`
* **Headers:**
  * `Authorization: Bearer <token>` (Requerido)
  * `X-Tenant-ID: <UUID>` (Opcional si viene en claim JWT)
* **Respuestas:**
  * `200 OK` → `PacienteResponse`
  * `401 Unauthorized`
  * `404 Not Found` → `{"detail": "Perfil de paciente no configurado para este usuario en el inquilino actual"}`

---

### 3.5 `PUT /api/v1/pacientes/{id_paciente}`
* **Descripción:** Actualiza los datos del expediente del paciente verificando pertenencia al tenant.
* **Roles Permitidos:** `ADMIN`, `RECEPCION`, `MEDICO`
* **Headers:**
  * `Authorization: Bearer <token>` (Requerido)
  * `X-Tenant-ID: <UUID>` (Opcional si viene en claim JWT)
* **Path Parameters:**
  * `id_paciente` (integer, requerido): Identificador único del paciente.
* **Request Body:** `PacienteUpdateRequest`
* **Respuestas:**
  * `200 OK` → `PacienteResponse`
  * `401 Unauthorized`
  * `403 Forbidden`
  * `404 Not Found` → `{"detail": "Paciente no encontrado"}` (No existe o pertenece a otro tenant).
  * `422 Unprocessable Entity` → Validación de schema fallida.

---

### 3.6 `PATCH /api/v1/pacientes/me`
* **Descripción:** Permite al paciente autenticado actualizar sus datos de contacto y emergencia dentro de su tenant.
* **Roles Permitidos:** `PACIENTE`
* **Headers:**
  * `Authorization: Bearer <token>` (Requerido)
  * `X-Tenant-ID: <UUID>` (Opcional si viene en claim JWT)
* **Request Body:** `PacienteProfilePatchRequest`
* **Respuestas:**
  * `200 OK` → `PacienteResponse`
  * `401 Unauthorized`
  * `404 Not Found` → `{"detail": "Perfil de paciente no encontrado"}`
  * `422 Unprocessable Entity` → Formatos de contacto inválidos.

---

### 3.7 `DELETE /api/v1/pacientes/{id_paciente}`
* **Descripción:** Realiza la desactivación lógica (baja lógica / soft delete) del paciente en el tenant (`estado = 'INACTIVO'`).
* **Roles Permitidos:** `ADMIN`
* **Headers:**
  * `Authorization: Bearer <token>` (Requerido)
  * `X-Tenant-ID: <UUID>` (Opcional si viene en claim JWT)
* **Path Parameters:**
  * `id_paciente` (integer, requerido): Identificador del paciente.
* **Respuestas:**
  * `200 OK` → `{"detail": "Paciente desactivado correctamente", "id_paciente": 10, "tenant_id": "11111111-1111-1111-1111-111111111111", "estado": "INACTIVO"}`
  * `401 Unauthorized`
  * `403 Forbidden`
  * `404 Not Found` → `{"detail": "Paciente no encontrado"}` (No existe o pertenece a otro tenant).
