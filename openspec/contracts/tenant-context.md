# Contrato: Contexto de Tenant

## Descripción

Este contrato define los endpoints para resolver y obtener información del tenant (clínica) actual en la plataforma de Telemedicina.

---

## Headers Estándar

Todas las peticiones autenticadas **SHALL** incluir:

| Header | Valor | Descripción |
|--------|-------|-------------|
| `Authorization` | `Bearer <token>` | Token JWT de acceso |
| `X-Tenant-ID` | `<integer>` | ID del tenant (opcional, solo Super Admin) |

---

## JWT Payload (Access Token)

El token JWT **SHALL** incluir los siguientes claims:

```json
{
  "sub": "1",
  "tenant_id": "1",
  "token_version": 0,
  "email": "admin@telemedicina.com",
  "type": "access",
  "exp": 1699999999
}
```

> Backend real (`login/router.py:56-63`): `tenant_id: str(id_clinica)|None`, `sub: str(id_usuario)`.
> No se emite `clinica_id:int` ni `rol/permisos` en el JWT.

### Claims Requeridos

| Claim | Tipo | Descripción |
|-------|------|-------------|
| `sub` | string | ID del usuario |
| `tenant_id` | string\|null | Espejo de `id_clinica: BigInteger` (`"1"` o `null` para admin global) |
| `token_version` | integer | Versión de sesión (revocación) |
| `type` | string | Tipo de token (access/refresh) |
| `exp` | integer | Fecha de expiración (Unix timestamp) |

---

## Endpoints

### GET /api/v1/tenant/context

Retorna el tenant actual del usuario autenticado.

#### Request

```
GET /api/v1/tenant/context HTTP/1.1
Host: api.telemedicina.com
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...
```

#### Response 200 (Success)

```json
{
  "clinica_id": 1,
  "clinica_nombre": "Hospital San Juan de Dios",
  "clinica_estado": "ACTIVO",
  "usuario_id": 1,
  "usuario_nombres": "Admin",
  "usuario_apellidos": "Sistema",
  "usuario_correo": "admin@telemedicina.com",
  "rol": "Administrador",
  "permisos": ["users.read", "users.write", "roles.read", "roles.write"],
  "es_super_admin": false
}
```

> `es_super_admin:true` solo si `id_clinica IS NULL + rol Administrador global`. Es derivado (no columna). Para Super Admin, `clinica_id` es `null` hasta que use `X-Tenant-ID`.

#### Response 403 (Forbidden - Tenant Inactivo)

```json
{
  "detail": "Clínica inactiva. Contacte al administrador."
}
```

#### Response 401 (Unauthorized - Token Inválido)

```json
{
  "detail": "Token inválido o expirado"
}
```

---

### GET /api/v1/clinicas

Lista todos los tenants de la plataforma (solo Super Admin).

#### Request

```
GET /api/v1/clinicas?estado=ACTIVO&page=1&per_page=20 HTTP/1.1
Host: api.telemedicina.com
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...
X-Tenant-ID: 1
```

#### Query Parameters

| Parámetro | Tipo | Requerido | Descripción |
|-----------|------|-----------|-------------|
| `estado` | string | No | Filtrar por estado (ACTIVO/INACTIVO) |
| `page` | integer | No | Número de página (default: 1) |
| `per_page` | integer | No | Items por página (default: 20) |

#### Response 200 (Success)

```json
{
  "total": 5,
  "page": 1,
  "per_page": 20,
  "items": [
    {
      "clinica_id": 1,
      "nombre": "Hospital San Juan de Dios",
      "razon_social": "San Juan S.A.",
      "nit": "123456789",
      "estado": "ACTIVO",
      "usuarios_activos": 15,
      "fecha_creacion": "2024-01-15T10:30:00Z"
    }
  ]
}
```

#### Response 403 (Forbidden - Sin Permiso)

```json
{
  "detail": "No tiene permisos para listar clínicas"
}
```

---

### PATCH /api/v1/clinicas/{clinica_id}/estado

Actualiza el estado de un tenant (solo Super Admin).

#### Request

```
PATCH /api/v1/clinicas/1/estado HTTP/1.1
Host: api.telemedicina.com
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...
Content-Type: application/json

{
  "estado": "INACTIVO"
}
```

#### Response 200 (Success)

```json
{
  "clinica_id": 1,
  "nombre": "Hospital San Juan de Dios",
  "estado": "INACTIVO",
  "mensaje": "Estado actualizado correctamente"
}
```

---

### POST /api/v1/public/clinicas/registrar (Onboarding público, sin auth)

```json
{
  "nombre": "Clínica Nueva",
  "nit": "123456",
  "admin_nombres": "Admin",
  "admin_apellidos": "Clínica",
  "admin_email": "admin@nueva.com",
  "admin_password": "Segura123"
}
```
→ `201 {clinica:{id_clinica, nombre, estado}, administrador:{id_usuario, correo}}`. Frontend: `/registro-clinica` → `/login?email=`.

## Códigos de Error

| Código | Descripción | Causa |
|--------|-------------|-------|
| 200 | OK | Petición exitosa |
| 400 | Bad Request | Datos inválidos / inyección `id_clinica` en body |
| 401 | Unauthorized | Token inválido o expirado, o sin `tenant_id` ni `X-Tenant-ID` admin |
| 403 | Forbidden | Sin permisos o tenant inactivo |
| 404 | Not Found | Recurso no encontrado o cross-tenant (no revela existencia) |
| 422 | Validation Error | Error de validación de datos |
