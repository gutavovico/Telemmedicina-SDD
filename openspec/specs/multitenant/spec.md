# Especificación: Aislamiento Multitenant

## Purpose

Esta especificación define los requisitos para implementar el aislamiento multitenant en la plataforma de Telemedicina, garantizando que los datos de cada clínica (tenant) estén completamente aislados y protegidos. Backend real: `id_clinica:BigInteger int`, claim JWT `tenant_id:str|None`, header `X-Tenant-ID:<int>`.

## Verbos RFC 2119

- **SHALL**: Requisito obligatorio
- **SHALL NO**: Prohibición absoluta
- **SHOULD**: Recomendación fuerte
- **MAY**: Opcional

---

## Requisitos Funcionales

### RF-01: Resolución de Tenant

El sistema **SHALL** resolver el tenant actual para cada petición autenticada.

**Criterios de Aceptación:**
- El sistema **SHALL** extraer `tenant_id` (str de `id_clinica`, ver `login/router.py:62`) del claim del token JWT
- El sistema **SHALL** validar que el tenant (`clinicas.id_clinica: BigInteger`) existe en la base de datos
- El sistema **SHALL** validar que el tenant tiene estado `ACTIVO`
- El sistema **SHALL NO** procesar peticiones sin tenant válido (401 si `tenant_id` es `None` y sin `X-Tenant-ID` admin)

**Escenarios:**

```gherkin
Scenario: Tenant válido y activo
  Given un usuario con token JWT válido
  And el claim "tenant_id" es "1" (id_clinica=1)
  And el tenant con id 1 existe y está activo
  When se procesa la petición
  Then el sistema SHALL resolver el tenant correctamente

Scenario: Tenant inactivo
  Given un usuario con token JWT válido
  And el tenant está inactivo
  When se procesa la petición
  Then el sistema SHALL retornar 403 Forbidden
```

### RF-02: Filtro Automático de Consultas

El sistema **SHALL** filtrar automáticamente todas las consultas por el tenant actual.

**Criterios de Aceptación:**
- Toda consulta a tablas transaccionales **SHALL** incluir `WHERE id_clinica = :tenant_id`
- El filtro **SHALL** aplicarse automáticamente sin intervención del desarrollador
- El sistema **SHALL NO** retornar datos de otros tenants

**Escenarios:**

```gherkin
Scenario: Listar usuarios del tenant
  Given un usuario autenticado en el tenant 1
  When solicita GET /api/v1/usuarios
  Then el sistema SHALL retornar solo usuarios con id_clinica = 1

Scenario: Obtener usuario de otro tenant
  Given un usuario autenticado en el tenant 1
  When solicita GET /api/v1/usuarios/5 (pertenece a tenant 2)
  Then el sistema SHALL retornar 404 Not Found
```

### RF-03: Prevención de Tenant Injection

El sistema **SHALL NO** aceptar `id_clinica` desde el cuerpo de la petición del cliente.

**Criterios de Aceptación:**
- El sistema **SHALL** ignorar cualquier campo `id_clinica` en el body
- El sistema **SHALL** usar únicamente el tenant del contexto autenticado
- El sistema **SHALL** retornar 400 si se detecta intento de modificación

**Escenarios:**

```gherkin
Scenario: Intento de inyección en creación
  Given un usuario autenticado en el tenant 1
  When envía POST /api/v1/usuarios con body {"id_clinica": 2}
  Then el sistema SHALL ignorar id_clinica del body
  And SHALL crear el usuario con id_clinica = 1
```

---

## Requisitos No Funcionales

### RNF-01: Rendimiento

- El filtro por tenant **SHALL** agregar menos de 50ms de latencia
- Los índices compuestos **SHALL** optimizar consultas por tenant
- El sistema **SHALL** soportar al menos 100 tenants concurrentes

### RNF-02: Seguridad

- El sistema **SHALL NO** permitir acceso cross-tenant
- El sistema **SHALL** registrar intentos sospechosos en auditoría
- El sistema **SHALL** validar tenant en cada petición

### RNF-03: Escalabilidad

- El modelo **SHALL** soportar crecimiento horizontal
- El sistema **SHALL** permitir agregar nuevos tenants sin downtime
- Las migraciones **SHALL** ser reversibles

---

## Modelo de Datos

### Tablas con Tenant (id_clinica BigInteger FK → clinicas.id_clinica)

| Tabla | Campo Tenant | Nulabilidad real | Nota |
|-------|--------------|------------------|------|
| `usuarios` | `id_clinica` | nullable=True | `NULL` = Super Admin global; `correo` hoy `unique` global → migrar a `UNIQUE(id_clinica, correo)` |
| `roles` | `id_clinica` | nullable=True | `NULL` = rol global (`seed.py:167`); por tenant cuando tiene valor |
| `pacientes` | `id_clinica` | nullable=True | `UniqueConstraint(ci, complemento)` global → migrar a `UNIQUE(id_clinica, ci, complemento)` |
| `medicos` | — (indirecto) | — | Sin FK directa; hereda vía `usuarios.id_clinica` (`tenant_id` property) |
| `citas` | `id_clinica` | según módulo | Filtrado obligatorio por tenant |
| `auditoria` | `id_clinica` | modelo `NOT NULL` vs `seed_clinica.py:16 DROP NOT NULL` | Unificar; vista tenant filtrada + vista global solo Super Admin |

### Tablas sin Tenant (Globales)

| Tabla | Razón |
|-------|-------|
| `clinicas` | Catálogo de tenants |
| `permisos` | Catálogo global de permisos |
| `especialidades` | Catálogo global de especialidades |
| `token_blacklist` | Tokens revocados (global) |

---

## Contratos de API

### GET /api/v1/tenant/context

Retorna el tenant actual del usuario autenticado.

**Request:**
```
GET /api/v1/tenant/context
Authorization: Bearer <token>
```

**Response 200:**
```json
{
  "clinica_id": 1,
  "clinica_nombre": "Hospital San Juan de Dios",
  "rol": "Administrador",
  "estado": "ACTIVO"
}
```

### GET /api/v1/clinicas

Lista todos los tenants (solo Super Admin).

**Request:**
```
GET /api/v1/clinicas
Authorization: Bearer <token>
X-Tenant-ID: 1
```

**Response 200:**
```json
{
  "total": 5,
  "items": [
    {
      "clinica_id": 1,
      "nombre": "Hospital San Juan de Dios",
      "estado": "ACTIVO",
      "usuarios_activos": 15,
      "fecha_creacion": "2024-01-15T10:30:00Z"
    }
  ]
}
```

---

## Trazabilidad

| Requisito | Criterio de Aceptación | Estado |
|-----------|------------------------|--------|
| RF-01 | CA-01, CA-02, CA-03 | Pendiente |
| RF-02 | CA-04, CA-05 | Pendiente |
| RF-03 | CA-06, CA-07 | Pendiente |
| RF-04 | CA-08 | Pendiente |
| RF-05 | CA-09, CA-10 | Pendiente |

### RF-04: Acceso Cross-Tenant

El sistema **SHALL** retornar 404 cuando se intenta acceder a un recurso de otro tenant.

**Criterios de Aceptación:**
- El sistema **SHALL** retornar 404 (no 403) para recursos de otros tenants
- El sistema **SHALL NO** revelar la existencia del recurso
- El sistema **SHALL** registrar el intento en auditoría

### RF-05: Soporte Super Admin SaaS (distinto de Admin de clínica)

El sistema **SHALL** distinguir `Super Admin SaaS (id_clinica NULL + rol Administrador global)` de `Admin tenant (id_clinica=N)` y permitir al primero operar sin filtro tenant.

**Criterios de Aceptación:**
- El header `X-Tenant-ID: <int>` **SHALL** ser opcional y solo efectivo para Super Admin (`id_rol==1` o `Rol.nombre` en `ADMIN/ADMINISTRADOR`; no existe `es_super_admin`)
- Admin tenant que envíe `X-Tenant-ID` ajeno **SHALL** ser ignorado (usa su `id_clinica`) o recibir `404`
- Super Admin **SHALL** poder: `GET /clinicas`, `PATCH /clinicas/{id}/estado`, bitácora global (`GET /auditoria` sin filtro) y dashboard global (`GET /analytics/resumen-global`); Admin tenant solo vistas filtradas
- Onboarding público `POST /public/clinicas/registrar` **SHALL** crear clínica + admin inicial sin auth

### RF-06: Frontend multitenant (teoría Frontend_Multitenant_SaaS.md, solo conceptos)

El frontend **SHALL** implementar: `TenantService` Signals + `localStorage` SSR-safe, `TokenService` (decode `tenant_id:str→int`, expiración), `PermissionsService` (desde `/me`+`/tenant/context`, el JWT no trae permisos), `authInterceptor` (Bearer+refresh+401) antes que `tenantInterceptor` (`X-Tenant-ID`), guards `tenantGuard` + `ClinicaGuard(estado)` + `PermissionsGuard(data.permissions)` + `SuperAdminGuard`, `TenantSelector`, Navbar con clínica, dashboard por permiso, `redirigirSegunRol` y ruta pública `/registro-clinica`.

---

## Requirements

### Requirement: Tenant resolution from JWT claim
The system SHALL resolve the current tenant from the JWT `tenant_id` claim (string mirror of `id_clinica`) and reject requests without a valid active tenant.

#### Scenario: Valid active tenant resolves
- **WHEN** a request arrives with a valid JWT whose `tenant_id` is "1" and tenant 1 is ACTIVO
- **THEN** the system resolves tenant 1 for the request

#### Scenario: Inactive tenant is forbidden
- **WHEN** a request arrives with a valid JWT whose tenant is INACTIVO
- **THEN** the system returns 403 Forbidden

### Requirement: Strict cross-tenant isolation
The system SHALL filter every transactional query by `id_clinica` and return 404 for resources belonging to another tenant.

#### Scenario: Cross-tenant access returns 404
- **WHEN** a user of tenant 1 requests a user resource that belongs to tenant 2
- **THEN** the system returns 404 Not Found without revealing existence

### Requirement: Super Admin SaaS support
The system SHALL distinguish Super Admin SaaS (`id_clinica NULL` + global `Administrador` role) from tenant Admin and allow header-based tenant switching only for Super Admin.

#### Scenario: Super Admin switches tenant via header
- **WHEN** a Super Admin sends `X-Tenant-ID: 2` with a valid token
- **THEN** the system operates in the context of tenant 2
