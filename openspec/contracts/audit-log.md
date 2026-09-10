# Contrato de API REST: Bitácora de Auditoría Clínica (CU21)

**Versión del Contrato:** 1.0.0 (SaaS Multitenant)  
**Estándar:** OpenAPI 3.1 / RESTful JSON  
**Ruta Base:** `/api/v1/audit-log`  
**Seguridad Global:** `BearerAuth` (Header `Authorization: Bearer <JWT_ACCESS_TOKEN>`)  
**Encabezado Multitenant:** `X-Tenant-ID: <UUID>`  
**Dominio:** `auditoria` / `audit-log`  
**Roles Autorizados:** `Administrador`, `Auditor`  

---

## 1. Convenciones Multitenant y Seguridad

- **Aislamiento por Tenant:** Todos los endpoints filtran registros exclusivamente por el `tenant_id` extraído del token JWT. No se permite acceso cruzado entre inquilinos. Intentos de acceso a registros de otro tenant responden con `404 Not Found`.
- **Control de Acceso RBAC:** Únicamente los usuarios con rol `Administrador` o `Auditor` pueden acceder a los endpoints de auditoría. Usuarios con otros roles reciben `403 Forbidden`.
- **Inmutabilidad:** No se exponen endpoints de creación, actualización ni eliminación de registros de auditoría. Los registros se generan automáticamente por el sistema.

---

## 2. Esquemas de Datos (Data Schemas)

### 2.1 `AuditLogEntry`
```json
{
  "id_auditoria": 1542,
  "tenant_id": "11111111-1111-1111-1111-111111111111",
  "id_usuario": 1,
  "nombre_usuario": "Admin Sistema",
  "tabla_afectada": "pacientes",
  "registro_id": 87,
  "accion": "UPDATE",
  "descripcion": "Actualización de datos personales del paciente",
  "datos_anteriores": {
    "nombres": "Juan Carlos",
    "telefono": "+591 70000001"
  },
  "datos_nuevos": {
    "nombres": "Juan Carlos",
    "telefono": "+591 70000099"
  },
  "direccion_ip": "192.168.1.45",
  "fecha_hora": "2026-09-06T14:30:00Z"
}
```

**Campos:**
| Campo | Tipo | Requerido | Descripción |
|---|---|---|---|
| `id_auditoria` | integer (BIGINT) | Sí | Identificador único del registro de auditoría |
| `tenant_id` | string (UUID) | Sí | Identificador del inquilino |
| `id_usuario` | integer (BIGINT) | Sí | ID del usuario que realizó la operación |
| `nombre_usuario` | string | Sí | Nombre completo del usuario (concatenación de nombres + apellidos) |
| `tabla_afectada` | string | Sí | Nombre de la tabla de BD afectada |
| `registro_id` | integer (BIGINT) | No | ID del registro afectado dentro de la tabla |
| `accion` | string (enum) | Sí | Tipo de operación: `INSERT`, `UPDATE`, `DELETE`, `SELECT`, `LOGIN`, `LOGOUT` |
| `descripcion` | string | No | Descripción textual de la operación |
| `datos_anteriores` | object (JSONB) | No | Estado previo del registro (para UPDATE/DELETE) |
| `datos_nuevos` | object (JSONB) | No | Estado nuevo del registro (para INSERT/UPDATE) |
| `direccion_ip` | string | No | Dirección IP del cliente (IPv4 o IPv6) |
| `fecha_hora` | string (ISO 8601) | Sí | Fecha y hora exacta de la operación |

---

### 2.2 `AuditLogListResponse`
```json
{
  "data": [
    { "...": "AuditLogEntry" }
  ],
  "total": 342,
  "page": 1,
  "page_size": 20,
  "total_pages": 18
}
```

**Campos:**
| Campo | Tipo | Descripción |
|---|---|---|
| `data` | array[AuditLogEntry] | Lista de registros de auditoría |
| `total` | integer | Total de registros que coinciden con los filtros |
| `page` | integer | Página actual |
| `page_size` | integer | Cantidad de registros por página |
| `total_pages` | integer | Total de páginas disponibles |

---

## 3. Parámetros de Filtro (Query Parameters)

Los siguientes parámetros son opcionales y se aplican a los endpoints `GET /api/v1/audit-log` y a los endpoints de exportación:

| Parámetro | Tipo | Descripción | Ejemplo |
|---|---|---|---|
| `page` | integer | Número de página (default: 1) | `page=2` |
| `page_size` | integer | Registros por página (default: 20, max: 100) | `page_size=50` |
| `fecha_inicio` | string (ISO date) | Fecha de inicio del rango (inclusive) | `fecha_inicio=2026-09-01` |
| `fecha_fin` | string (ISO date) | Fecha de fin del rango (inclusive) | `fecha_fin=2026-09-06` |
| `id_usuario` | integer | Filtrar por ID de usuario que realizó la acción | `id_usuario=5` |
| `accion` | string (enum) | Filtrar por tipo de acción: `INSERT`, `UPDATE`, `DELETE`, `SELECT` | `accion=UPDATE` |
| `tabla_afectada` | string | Filtrar por nombre de tabla afectada | `tabla_afectada=pacientes` |
| `registro_id` | integer | Filtrar por ID de registro específico | `registro_id=87` |

---

## 4. Endpoints

### 4.1 `GET /api/v1/audit-log`
* **Descripción:** Lista los registros de auditoría del tenant autenticado con filtros opcionales, paginación y ordenamiento descendente por `fecha_hora`.
* **Roles:** `Administrador`, `Auditor`
* **Headers:**
  * `Authorization: Bearer <token>`
  * `X-Tenant-ID: <UUID>`
* **Query Parameters:** Todos los parámetros de la sección 3 (opcionales).
* **Respuestas:**
  * `200 OK` → `AuditLogListResponse`
  * `401 Unauthorized` → Token inválido o ausente
  * `403 Forbidden` → Usuario sin rol autorizado
  * `422 Unprocessable Entity` → Parámetros de filtro con formato inválido

---

### 4.2 `GET /api/v1/audit-log/{id_auditoria}`
* **Descripción:** Obtiene el detalle completo de un registro de auditoría específico, incluyendo los campos JSONB `datos_anteriores` y `datos_nuevos`.
* **Roles:** `Administrador`, `Auditor`
* **Headers:**
  * `Authorization: Bearer <token>`
  * `X-Tenant-ID: <UUID>`
* **Respuestas:**
  * `200 OK` → `AuditLogEntry`
  * `401 Unauthorized`
  * `403 Forbidden`
  * `404 Not Found` → Registro inexistente o perteneciente a otro tenant

---

### 4.3 `GET /api/v1/audit-log/export/pdf`
* **Descripción:** Genera y descarga un archivo PDF con los registros de auditoría que coincidan con los filtros aplicados. La exportación respeta el aislamiento por tenant.
* **Roles:** `Administrador`, `Auditor`
* **Headers:**
  * `Authorization: Bearer <token>`
  * `X-Tenant-ID: <UUID>`
* **Query Parameters:** `fecha_inicio`, `fecha_fin`, `id_usuario`, `accion`, `tabla_afectada`, `registro_id` (todos opcionales).
* **Respuestas:**
  * `200 OK` → Binary stream con `Content-Type: application/pdf` y `Content-Disposition: attachment; filename="bitacora_auditoria_<fecha>.pdf"`
  * `401 Unauthorized`
  * `403 Forbidden`
  * `422 Unprocessable Entity`

---

### 4.4 `GET /api/v1/audit-log/export/excel`
* **Descripción:** Genera y descarga un archivo Excel (.xlsx) con los registros de auditoría que coincidan con los filtros aplicados. La exportación respeta el aislamiento por tenant.
* **Roles:** `Administrador`, `Auditor`
* **Headers:**
  * `Authorization: Bearer <token>`
  * `X-Tenant-ID: <UUID>`
* **Query Parameters:** `fecha_inicio`, `fecha_fin`, `id_usuario`, `accion`, `tabla_afectada`, `registro_id` (todos opcionales).
* **Respuestas:**
  * `200 OK` → Binary stream con `Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet` y `Content-Disposition: attachment; filename="bitacora_auditoria_<fecha>.xlsx"`
  * `401 Unauthorized`
  * `403 Forbidden`
  * `422 Unprocessable Entity`
