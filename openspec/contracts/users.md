# Contrato de API REST: Usuarios, Roles y Permisos (CU02, CU26)

**Versión del Contrato:** 2.0.0 (SaaS Multitenant)  
**Estándar:** OpenAPI 3.1 / RESTful JSON  
**Ruta Base:** `/api/v1`  
**Seguridad Global:** `BearerAuth` (Header `Authorization: Bearer <JWT_ACCESS_TOKEN>`)  
**Encabezado Multitenant:** `X-Tenant-ID: <UUID>`  
**Dominio:** `users` / `roles`  

---

## 1. Convenciones Multitenant y RBAC

- **Control de Acceso:** Todos los endpoints de administración de usuarios y roles exigen rol `ADMIN` dentro del inquilino autenticado.
- **Aislamiento por Tenant:** Las listas de usuarios y roles devuelven únicamente registros que coincidan con el `tenant_id` del token. La consulta o modificación de un ID de otro tenant responde con `404 Not Found`.
- **Unicidad:** La verificación de correos duplicados en `/users` opera exclusivamente dentro del `tenant_id` del llamante (`UNIQUE(tenant_id, correo)`).

---

## 2. Esquemas de Datos (Data Schemas)

### 2.1 `AdminUserCreate`
```json
{
  "id_rol": 2,
  "nombres": "Jorge Leonel",
  "apellidos": "Rojas Farell",
  "correo": "jorge.rojas@clinica.com",
  "telefono": "+591 76543210",
  "password": "PasswordSeguro123",
  "foto_perfil": "https://storage.telemedicina.com/usuarios/avatar.jpg"
}
```

---

### 2.2 `AdminUserUpdate`
```json
{
  "id_rol": 2,
  "nombres": "Jorge Leonel",
  "apellidos": "Rojas Farell",
  "telefono": "+591 76543210",
  "foto_perfil": "https://storage.telemedicina.com/usuarios/avatar.jpg"
}
```

---

### 2.3 `AdminUserStatusUpdate`
```json
{
  "activo": false
}
```

---

### 2.4 `AdminUserResponse`
```json
{
  "id_usuario": 15,
  "tenant_id": "11111111-1111-1111-1111-111111111111",
  "id_rol": 2,
  "rol_nombre": "MEDICO",
  "nombres": "Jorge Leonel",
  "apellidos": "Rojas Farell",
  "correo": "jorge.rojas@clinica.com",
  "telefono": "+591 76543210",
  "estado": "activo",
  "foto_perfil": "https://storage.telemedicina.com/usuarios/avatar.jpg",
  "created_at": "2026-08-24T10:00:00Z"
}
```

---

### 2.5 `RoleCreate` / `RoleUpdate`
```json
{
  "nombre": "Enfermería",
  "descripcion": "Personal de apoyo médico y triaje"
}
```

---

### 2.6 `RoleResponse`
```json
{
  "id_rol": 5,
  "tenant_id": "11111111-1111-1111-1111-111111111111",
  "nombre": "Enfermería",
  "descripcion": "Personal de apoyo médico y triaje",
  "estado": "ACTIVO",
  "created_at": "2026-08-24T10:00:00Z"
}
```

---

### 2.7 `PermissionResponse`
```json
{
  "id_permiso": 10,
  "codigo": "PATIENT_CREATE",
  "nombre": "Crear Pacientes",
  "modulo": "medical_records"
}
```

---

### 2.8 `RolePermissionsUpdate`
```json
{
  "id_permisos": [10, 11, 12]
}
```

---

## 3. Endpoints de Usuarios

### 3.1 `GET /api/v1/users`
* **Descripción:** Lista los usuarios administrables del inquilino actual.
* **Roles:** `ADMIN`
* **Headers:** `Authorization: Bearer <token>`, `X-Tenant-ID: <UUID>`
* **Respuestas:**
  * `200 OK` → `list[AdminUserResponse]`
  * `401 Unauthorized`
  * `403 Forbidden`

---

### 3.2 `POST /api/v1/users`
* **Descripción:** Crea un usuario interno asignándole un rol existente en el tenant.
* **Roles:** `ADMIN`
* **Headers:** `Authorization: Bearer <token>`, `X-Tenant-ID: <UUID>`
* **Request Body:** `AdminUserCreate`
* **Respuestas:**
  * `201 Created` → `AdminUserResponse`
  * `400 Bad Request` → Correo duplicado en el mismo tenant o datos inconsistentes
  * `401 Unauthorized`
  * `403 Forbidden`
  * `422 Unprocessable Entity`

---

### 3.3 `GET /api/v1/users/{id_usuario}`
* **Descripción:** Obtiene el detalle administrativo de un usuario verificando pertenencia al tenant.
* **Roles:** `ADMIN`
* **Headers:** `Authorization: Bearer <token>`, `X-Tenant-ID: <UUID>`
* **Respuestas:**
  * `200 OK` → `AdminUserResponse`
  * `404 Not Found` → Usuario inexistente o de otro tenant

---

### 3.4 `PUT /api/v1/users/{id_usuario}`
* **Descripción:** Actualiza los datos de un usuario del tenant.
* **Roles:** `ADMIN`
* **Headers:** `Authorization: Bearer <token>`, `X-Tenant-ID: <UUID>`
* **Request Body:** `AdminUserUpdate`
* **Respuestas:**
  * `200 OK` → `AdminUserResponse`
  * `404 Not Found`
  * `422 Unprocessable Entity`

---

### 3.5 `PATCH /api/v1/users/{id_usuario}/status`
* **Descripción:** Habilita o deshabilita un usuario sin eliminarlo físicamente.
* **Roles:** `ADMIN`
* **Headers:** `Authorization: Bearer <token>`, `X-Tenant-ID: <UUID>`
* **Request Body:** `AdminUserStatusUpdate`
* **Respuestas:**
  * `200 OK` → `AdminUserResponse`
  * `404 Not Found`

---

## 4. Endpoints de Roles y Permisos

### 4.1 `GET /api/v1/roles`
* **Descripción:** Lista los roles configurados en el tenant.
* **Roles:** `ADMIN`
* **Respuestas:** `200 OK` → `list[RoleResponse]`

### 4.2 `POST /api/v1/roles`
* **Descripción:** Crea un nuevo rol en el tenant.
* **Roles:** `ADMIN`
* **Request Body:** `RoleCreate`
* **Respuestas:** `201 Created` → `RoleResponse`

### 4.3 `GET /api/v1/roles/{id_rol}`
* **Descripción:** Obtiene el detalle de un rol del tenant.
* **Roles:** `ADMIN`
* **Respuestas:** `200 OK` → `RoleResponse`, `404 Not Found`

### 4.4 `PUT /api/v1/roles/{id_rol}`
* **Descripción:** Actualiza un rol existente.
* **Roles:** `ADMIN`
* **Request Body:** `RoleUpdate`
* **Respuestas:** `200 OK` → `RoleResponse`, `404 Not Found`

### 4.5 `PATCH /api/v1/roles/{id_rol}/status`
* **Descripción:** Cambia el estado del rol (`ACTIVO` / `INACTIVO`).
* **Roles:** `ADMIN`
* **Request Body:** `RoleStatusUpdate`
* **Respuestas:** `200 OK` → `RoleResponse`, `404 Not Found`

### 4.6 `GET /api/v1/permissions`
* **Descripción:** Lista el catálogo general de permisos del sistema.
* **Roles:** `ADMIN`
* **Respuestas:** `200 OK` → `list[PermissionResponse]`

### 4.7 `GET /api/v1/roles/{id_rol}/permissions`
* **Descripción:** Obtiene la lista de permisos asignados al rol especificado.
* **Roles:** `ADMIN`
* **Respuestas:** `200 OK` → `list[PermissionResponse]`, `404 Not Found`

### 4.8 `PUT /api/v1/roles/{id_rol}/permissions`
* **Descripción:** Reemplaza atómicamente la lista de permisos de un rol.
* **Roles:** `ADMIN`
* **Request Body:** `RolePermissionsUpdate`
* **Respuestas:** `200 OK` → `list[PermissionResponse]`, `404 Not Found`
