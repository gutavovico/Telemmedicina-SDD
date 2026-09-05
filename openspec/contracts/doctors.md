# Contrato de API REST: Gestión de Médicos y Especialidades (CU04)

**Versión del Contrato:** 2.0.0 (SaaS Multitenant)  
**Estándar:** OpenAPI 3.1 / RESTful JSON  
**Rutas Base:** `/api/v1/medicos`, `/api/v1/especialidades`  
**Seguridad Global:** `BearerAuth` (Header `Authorization: Bearer <JWT_ACCESS_TOKEN>`)  
**Encabezado Multitenant:** `X-Tenant-ID: <UUID>`  
**Dominio:** `medicos`  

---

## 1. Convenciones Multitenant

- **Aislamiento de Perfiles Médicos:** Cada perfil médico está vinculado a un usuario del inquilino y scoped a su `tenant_id`. La matrícula profesional es única dentro de cada clínica (`UNIQUE(tenant_id, matricula_profesional)`).
- **Control de Acceso:** La creación y asignación de especialidades a médicos requiere rol `ADMIN` en el tenant. La consulta de `/medicos/me` está disponible para usuarios con rol `MEDICO`.
- **Especialidad Principal:** Un médico puede tener múltiples especialidades asignadas, pero solo una con `es_principal = true`.

---

## 2. Esquemas de Datos (Data Schemas)

### 2.1 `AsignacionEspecialidad`
```json
{
  "id_especialidad": 1,
  "es_principal": true
}
```

---

### 2.2 `MedicoCreate`
```json
{
  "id_usuario": 15,
  "matricula_profesional": "BOL-1234",
  "descripcion_profesional": "Especialista en Nutrición Clínica",
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

---

### 2.3 `MedicoUpdate`
```json
{
  "matricula_profesional": "BOL-1234",
  "descripcion_profesional": "Nutrición Clínica y Enfermedades Metabólicas",
  "anios_experiencia": 9,
  "foto_profesional": "https://storage.telemedicina.com/medicos/linguini_v2.jpg"
}
```

---

### 2.4 `EstadoUpdate`
```json
{
  "nuevo_estado": "inactivo"
}
```

---

### 2.5 `EspecialidadResponse`
```json
{
  "id_especialidad": 1,
  "nombre": "Nutrición",
  "descripcion": "Especialidad en nutrición clínica y dietética",
  "estado": "activo"
}
```

---

### 2.6 `EspecialidadMedicoResponse`
```json
{
  "id_especialidad": 1,
  "nombre": "Nutrición",
  "es_principal": true
}
```

---

### 2.7 `MedicoResponse`
```json
{
  "id_medico": 3,
  "tenant_id": "11111111-1111-1111-1111-111111111111",
  "id_usuario": 15,
  "matricula_profesional": "BOL-1234",
  "descripcion_profesional": "Especialista en Nutrición Clínica",
  "anios_experiencia": 8,
  "foto_profesional": "https://storage.telemedicina.com/medicos/linguini.jpg",
  "estado": "activo",
  "nombres": "Alfredo",
  "apellidos": "Linguini",
  "correo": "linguini@telemedicina.com",
  "telefono": "+591 76543210",
  "especialidades": [
    {
      "id_especialidad": 1,
      "nombre": "Nutrición",
      "es_principal": true
    }
  ],
  "created_at": "2026-08-24T10:00:00Z",
  "updated_at": "2026-08-24T10:00:00Z"
}
```

---

### 2.8 `MedicoListResponse`
```json
{
  "total": 1,
  "items": [
    {
      "id_medico": 3,
      "tenant_id": "11111111-1111-1111-1111-111111111111",
      "id_usuario": 15,
      "matricula_profesional": "BOL-1234",
      "estado": "activo",
      "nombres": "Alfredo",
      "apellidos": "Linguini",
      "correo": "linguini@telemedicina.com",
      "telefono": "+591 76543210",
      "especialidades": [
        {
          "id_especialidad": 1,
          "nombre": "Nutrición",
          "es_principal": true
        }
      ]
    }
  ]
}
```

---

## 3. Endpoints de Médicos

### 3.1 `POST /api/v1/medicos`
* **Descripción:** Crea el perfil profesional de médico para un usuario ya registrado en el tenant (relación 1:1).
* **Roles:** `ADMIN`
* **Headers:** `Authorization: Bearer <token>`, `X-Tenant-ID: <UUID>`
* **Request Body:** `MedicoCreate`
* **Respuestas:**
  * `201 Created` → `MedicoResponse`
  * `400 Bad Request` → Matrícula duplicada en el tenant o usuario ya tiene perfil médico
  * `401 Unauthorized`
  * `403 Forbidden`
  * `422 Unprocessable Entity`

---

### 3.2 `GET /api/v1/medicos/me`
* **Descripción:** Devuelve el perfil profesional del médico autenticado según su token JWT.
* **Roles:** `MEDICO`
* **Headers:** `Authorization: Bearer <token>`, `X-Tenant-ID: <UUID>`
* **Respuestas:**
  * `200 OK` → `MedicoResponse`
  * `401 Unauthorized`
  * `404 Not Found` → `{"detail": "Perfil médico no encontrado para este usuario"}`

---

### 3.3 `GET /api/v1/medicos`
* **Descripción:** Lista médicos con filtros opcionales (nombre, id_especialidad, estado) acotados al tenant.
* **Query Parameters:**
  * `nombre` (string, opcional): Búsqueda por nombres, apellidos o correo
  * `id_especialidad` (int, opcional): Filtra por especialidad
  * `estado` (string, opcional, default: "activo"): activo o inactivo
  * `skip` (int, default: 0)
  * `limit` (int, default: 20, max: 100)
* **Respuestas:**
  * `200 OK` → `MedicoListResponse`
  * `401 Unauthorized`

---

### 3.4 `GET /api/v1/medicos/{id_medico}`
* **Descripción:** Obtiene el perfil completo del médico verificando pertenencia al tenant.
* **Respuestas:** `200 OK` → `MedicoResponse`, `404 Not Found`

---

### 3.5 `PUT /api/v1/medicos/{id_medico}`
* **Descripción:** Actualiza los datos profesionales del médico en el tenant.
* **Roles:** `ADMIN`
* **Request Body:** `MedicoUpdate`
* **Respuestas:** `200 OK` → `MedicoResponse`, `404 Not Found`

---

### 3.6 `PATCH /api/v1/medicos/{id_medico}/estado`
* **Descripción:** Activa o desactiva lógicamente el médico (`activo`/`inactivo`).
* **Roles:** `ADMIN`
* **Request Body:** `EstadoUpdate`
* **Respuestas:** `200 OK` → `MedicoResponse`, `404 Not Found`

---

### 3.7 `POST /api/v1/medicos/{id_medico}/especialidades`
* **Descripción:** Asigna una especialidad al médico. Si `es_principal: true`, desmarca la principal previa.
* **Roles:** `ADMIN`
* **Request Body:** `AsignacionEspecialidad`
* **Respuestas:** `200 OK` → `MedicoResponse`, `404 Not Found`

---

### 3.8 `DELETE /api/v1/medicos/{id_medico}/especialidades/{id_especialidad}`
* **Descripción:** Remueve una especialidad asignada al médico.
* **Roles:** `ADMIN`
* **Respuestas:** `200 OK` → `MedicoResponse`, `404 Not Found`

---

## 4. Endpoints de Especialidades

### 4.1 `GET /api/v1/especialidades`
* **Descripción:** Lista el catálogo de especialidades médicas.
* **Query Parameters:** `todos` (bool, default: false)
* **Respuestas:** `200 OK` → `list[EspecialidadResponse]`

### 4.2 `POST /api/v1/especialidades`
* **Descripción:** Agrega una especialidad al catálogo.
* **Roles:** `ADMIN`
* **Respuestas:** `201 Created` → `EspecialidadResponse`, `400 Bad Request` (nombre duplicado)

### 4.3 `PUT /api/v1/especialidades/{id_especialidad}`
* **Descripción:** Modifica una especialidad.
* **Roles:** `ADMIN`
* **Respuestas:** `200 OK` → `EspecialidadResponse`, `404 Not Found`

### 4.4 `DELETE /api/v1/especialidades/{id_especialidad}`
* **Descripción:** Elimina una especialidad. Falla si tiene médicos vinculados.
* **Roles:** `ADMIN`
* **Respuestas:** `204 No Content`, `404 Not Found`, `409 Conflict` (médicos asignados)
