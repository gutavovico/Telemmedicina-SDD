# Propuesta: Implementar Aislamiento Multitenant

## Resumen

Implementa el modelo multitenant **Pool con Discriminador** (Shared Database, Shared Schema) para aislamiento estricto de datos entre clínicas.

## Problema Actual

1. **Filtro manual**: Cada consulta debe incluir manualmente `WHERE id_clinica = X`
2. **Sin prevención de inyección**: Posible acceso a datos de otra clínica
3. **Sin contexto centralizado**: No hay mecanismo para resolver el tenant actual

## Solución

Implementar capa de abstracción multitenant que:
1. Resuelva automáticamente el tenant desde JWT (`tenant_id: str|None`, espejo de `id_clinica`) o header HTTP `X-Tenant-ID: <int>`
2. Filtre automáticamente todas las consultas por `id_clinica: BigInteger FK -> clinicas.id_clinica`
3. Prevenga la inyección de tenant desde el cliente
4. Retorne 404 para accesos cross-tenant

> **Nota backend real (2026-09-07):** los modelos `Usuario`, `Rol`, `Paciente`, `Auditoria` YA traen
> `id_clinica` directo (no se crea `TenantMixin`). El login YA emite `tenant_id` en
> `app/modules/auth/login/router.py:62,140`. Existe `get_current_tenant_id()` en
> `app/modules/auth/dependencies.py:73-85` (retorna `Optional[int]`), pero NO existe aún
> `get_current_tenant()` ni `TenantAwareService`. Tipos: `int`, no `UUID`.

## Criterios de Aceptación

### CA-01: Resolución de Tenant desde JWT
```gherkin
Given un usuario autenticado con token JWT válido
When se realiza cualquier petición a la API
Then el sistema SHALL extraer el tenant_id (str de id_clinica) del token
And SHALL inyectar el tenant actual en el contexto
And SHALL retornar 403 si el tenant está inactivo
```

### CA-02: Filtro Automático de Tenant
```gherkin
Given un tenant activo en el contexto
When se ejecuta cualquier consulta a la BD
Then el sistema SHALL agregar "WHERE id_clinica = :tenant_id"
And SHALL retornar solo los datos del tenant actual
And NO SHALL retornar datos de otros tenants
```

### CA-03: Prevención de Tenant Injection
```gherkin
Given una petición de creación/actualización de recursos
When el body contiene el campo "id_clinica"
Then el sistema SHALL ignorar el valor del cliente
And SHALL usar el tenant_id del contexto autenticado
And SHALL retornar 400 si se intenta modificar el tenant
```

### CA-04: Acceso Cross-Tenant Retorna 404
```gherkin
Given un recurso que pertenece a otro tenant
When el usuario actual intenta acceder al recurso
Then el sistema SHALL retornar 404 Not Found
And NO SHALL retornar 403 Forbidden (para no revelar existencia)
```

### CA-05: Header X-Tenant-ID para Super Admin
```gherkin
Given un usuario con rol Super Admin (Administrador global, id_clinica NULL o rol Administrador)
When envía el header "X-Tenant-ID" con un entero válido (id_clinica)
Then el sistema SHALL usar ese tenant para la petición
And SHALL validar que el usuario tiene rol Super Admin
```

## Roles: Super Admin SaaS vs Admin de Clínica

- **Admin de clínica (`id_clinica=N`):** opera SOLO dentro de su tenant (usuarios, pacientes, citas, bitácora y dashboard de su clínica). Cross-tenant → `404`.
- **Super Admin SaaS (`id_clinica NULL` + rol `Administrador` global, `id_rol==1`):** opera SOBRE los tenants. `Usuario` no tiene columna `es_super_admin`; se resuelve por rol (ver `auth/dependencies.py:88-97`). Puede usar `X-Tenant-ID:<int>`, gestionar clínicas, ver bitácora general y dashboard general sin filtro tenant.

## Impacto en Módulos

| Módulo | Impacto | Descripción |
|--------|---------|-------------|
| `auth/users_management` | Modificar | Filtro por tenant + `/me` como fuente de permisos (JWT no trae `rol/permisos`) |
| `auth/roles_permissions` | Modificar | Roles por tenant (globales con `id_clinica NULL` se mantienen) |
| `appointments` | Modificar | Citas filtradas por tenant |
| `medical_records` | Modificar | Historias/pacientes filtrados por tenant |
| `communications` | Modificar | Notificaciones por tenant |
| `auditoria` | Modificar | Vista tenant (filtrada) + vista global (solo Super Admin, sin filtro) |
| `analytics` | Modificar | Dashboard tenant + dashboard general (solo Super Admin) |
| `clinicas` | Nuevo | `GET /clinicas`, `PATCH /clinicas/{id}/estado`, `POST /public/clinicas/registrar` (onboarding, solo Super Admin salvo registro público) |
| `tenant/context` | Nuevo | `GET /tenant/context` para frontend (rol, permisos, clínica, `es_super_admin` derivado) |
| Frontend `core` | Nuevo/Modificar | `TenantService` Signals + persistencia, `TokenService`, `PermissionsService`, `authInterceptor` (refresh/401) + `tenantInterceptor`, `tenantGuard` + `ClinicaGuard` + `PermissionsGuard` + `SuperAdminGuard`, `TenantSelector`, Navbar, redirección por rol, `PublicService` + `/registro-clinica` |

## Plan de Implementación

1. **Fase 1**: Infraestructura Base (reutilizar `id_clinica` existente, crear TenantAwareService sync, crear `get_current_tenant` + `require_super_admin` sobre `get_current_tenant_id` existente)
2. **Fase 2**: Backend tenant + global (endpoints `tenant/context`, `clinicas`, onboarding público, bitácora/dashboard global solo Super Admin)
3. **Fase 3**: Frontend completo (Tenant/Token/Permissions services, ambos interceptores, 4 guards, persistencia localStorage SSR-safe, Navbar, dashboard por permiso, redirección por rol, registro-clínica)
4. **Fase 4**: Migración de datos (unicidades compuestas `(id_clinica, correo)` / `(id_clinica, ci, complemento)`, índices, backfill `seed.py`+`seed_clinica.py`) + Pruebas y Validación (`validate`, `doctor`)

## Métricas de Éxito

- 100% de consultas filtran por tenant
- 0 incidentes de filtración cross-tenant
- Tiempo de respuesta < 50ms adicionales
