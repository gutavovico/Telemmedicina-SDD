# Tareas: Implementar Aislamiento Multitenant

## Fase 1: Infraestructura Base

### Backend

- [ ] **T1.1**: Reutilizar `id_clinica` existente (NO crear `TenantMixin`)
  - Verificado: `Usuario`, `Rol`, `Paciente`, `Auditoria` ya tienen `id_clinica FK -> clinicas.id_clinica`
  - `Medico` hereda tenant vía `Usuario` (sin FK directa) — decidir si se mantiene indirecto
  - Solo agregar índices faltantes si `alembic` los pide

- [ ] **T1.2**: Crear `TenantAwareService` en `app/core/services/base_service.py`
  - Método `filter_by_tenant(query)`
  - Método `validate_ownership(obj)`
  - Constructor acepta `(db, tenant)`

- [ ] **T1.3**: Crear dependencia `get_current_tenant()` en `app/core/dependencies/tenant.py`
  - Extraer `tenant_id` (str de `id_clinica`) del JWT — ver `login/router.py:62,140`
  - Reutilizar/extender `get_current_tenant_id()` existente en `auth/dependencies.py:73-85`
  - Soporte para header `X-Tenant-ID: <int>` (Super Admin / Administrador global)
  - Validar tenant `ACTIVO`, 403 si inactivo, 404 si cross-tenant
  - Backend síncrono (`Session`, no `AsyncSession`) — respetar `core/database.py`

- [ ] **T1.4**: Documentar estado real de nulabilidad (NO forzar `NOT NULL` aún)
  - `Usuario.id_clinica nullable=True` (permite admin global / seed sin clínica)
  - `Rol.id_clinica nullable=True` (roles globales con `None` en `seed.py:167`)
  - `Paciente.id_clinica nullable=True`
  - `Auditoria.id_clinica nullable=False` en modelo, pero `seed_clinica.py:16` hace `DROP NOT NULL` — unificar criterio

- [ ] **T1.5**: Crear `require_super_admin` (Super Admin SaaS)
  - `id_clinica NULL + rol Administrador (id_rol==1 o nombre ADMIN/ADMINISTRADOR)` — no existe `es_super_admin`
  - 403 si no es Super Admin; se usa en `clinicas`, bitácora global y dashboard general

- [ ] **T1.6**: Crear endpoint `GET /api/v1/tenant/context`
  - Retornar `{clinica_id:int|null, clinica_nombre, estado, rol, permisos[], es_super_admin:bool}`
  - Fuente de `rol/permisos` (JWT no los trae) vía `Usuario.rol + RolPermiso`

## Fase 2: Backend tenant + global (sin middleware nuevo)

### Backend

- [ ] **T2.1**: Extender `auth/dependencies.py` (NO middleware nuevo)
  - `get_current_tenant()` + `require_super_admin()` sobre `get_current_user/get_current_tenant_id`
  - Excluir rutas públicas (`/public/*`, `/docs`, `/health`, `/auth/login|register|refresh`)

- [ ] **T2.2**: Actualizar routers existentes para usar `get_current_tenant`
  - `auth/users_management/router.py`
  - `auth/roles_permissions/router.py`
  - `appointments/router.py`
  - `medical_records/router.py`
  - `communications/router.py`
  - `auditoria/router.py` (vista tenant filtrada)

- [ ] **T2.3**: Actualizar servicios para usar `TenantAwareService`
  - Crear instancias con filtro automático
  - Verificar ownership en obtención por ID (404 cross-tenant, no 403)

- [ ] **T2.4**: Endpoints Super Admin `clinicas`
  - `GET /api/v1/clinicas?estado=&page=&per_page=` (lista + `usuarios_activos`)
  - `PATCH /api/v1/clinicas/{id}/estado`
  - `POST /api/v1/public/clinicas/registrar` (onboarding público: clínica + admin inicial)

- [ ] **T2.5**: Bitácora y dashboard global (solo Super Admin, sin filtro tenant)
  - `GET /auditoria?clinica_id=&...` global vs tenant
  - `GET /analytics/resumen-global` vs `resumen-tenant`

## Fase 3: Frontend

### Angular

- [ ] **T3.1**: `TenantService` Signals + persistencia (`src/app/core/services/tenant.service.ts`)
  - `signal<TenantContext|null>`, `computed clinicaId/nombre/isSuperAdmin`
  - `loadTenantContext()` → `GET /tenant/context` + fallback `AuthService.currentUser().id_clinica`
  - `persist localStorage current_clinica` + `isPlatformBrowser()` SSR-safe + `clearTenant()`

- [ ] **T3.2**: `TokenService` + `PermissionsService`
  - `TokenService`: storage tokens, `decodeToken():{sub,tenant_id}|null` con `parseInt(tenant_id)`, `isExpired/isAboutToExpire`, `getRefreshToken`
  - `PermissionsService`: `hasPermission/hasAny/hasAll` desde `/me`+`/tenant/context` (JWT no trae permisos), `isSuperAdmin/isAdminClinica`

- [ ] **T3.3**: Interceptores `authInterceptor` + `tenantInterceptor` (Fn)
  - `authInterceptor`: `Bearer`, refresh anticipado, `catchError 401 → logout + /login`
  - `tenantInterceptor`: `X-Tenant-ID:<int>`, excluir `/public/, /auth/login, /auth/register, /register, /login, /recuperar`
  - Orden: `[authInterceptor, tenantInterceptor]`

- [ ] **T3.4**: Guards (Fn, `inject()`)
  - `tenantGuard`: hay tenant → true sino `/login`
  - `ClinicaGuard`: `estado==ACTIVO` sino `/clinica-inactiva`
  - `PermissionsGuard`: `route.data['permissions']` sino `/sin-permisos`
  - `SuperAdminGuard`: `es_super_admin` sino `/dashboard` (para `/admin/clinicas`)
  - Respetar `authGuard/adminGuard` existentes

- [ ] **T3.5**: `app.config.ts` + `AuthService`
  - `withInterceptors([authInterceptor, tenantInterceptor])`
  - `login→saveTokens+fetchProfile+loadTenantContext+redirigirSegunRol`, `logout→clear+ /login`, `refreshToken()`

- [ ] **T3.6**: UI tenant + onboarding público
  - `TenantSelectorComponent` (Super Admin cambia `X-Tenant-ID` + reload)
  - `Navbar` con `clinica.nombre`, `Dashboard` filtra por permiso, `redirigirSegunRol {Administrador:/dashboard, Médico:/mis-citas, Recepción:/citas, Paciente:/mi-historial}`
  - `PublicService.registrarClinica()` + `/registro-clinica` (form clínica+admin, `POST /public/clinicas/registrar` → `/login?email=`)

## Fase 4: Migración de Datos

- [ ] **T4.1**: Crear migración Alembic para asignar tenant por defecto
  - Script `assign_default_tenant.py`
  - Asignar `id_clinica = 1` a registros sin tenant

- [ ] **T4.2**: Definir unicidades compuestas por tenant (rompen compatibilidad si se aplican directo)
  - Actual: `Usuario.correo unique=True` global y `Paciente UniqueConstraint(ci, complemento)` global
  - Objetivo: `UNIQUE(id_clinica, correo)` y `UNIQUE(id_clinica, ci, complemento)`
  - Requiere migración Alembic + limpieza de duplicados; NO solo `NOT NULL`

- [ ] **T4.3**: Crear índices compuestos por tenant
  - `(id_clinica, correo)` en usuarios
  - `(id_clinica, ci)` en pacientes
  - `(id_clinica, fecha_hora)` en auditoría
  - Backfill: `seed.py` no asigna `id_clinica`; `seed_clinica.py` asigna `id_clinica=1 WHERE NULL` — unificar en un solo flujo

## Fase 5: Pruebas y Validación

- [ ] **T5.1**: Pruebas unitarias de `get_current_tenant`
  - Token válido con tenant activo
  - Token con tenant inactivo (debe retornar 403)
  - Super Admin con header `X-Tenant-ID`

- [ ] **T5.2**: Pruebas unitarias de `TenantAwareService`
  - Verificar filtro automático por tenant
  - Verificar validación de ownership

- [ ] **T5.3**: Pruebas de integración cross-tenant
  - Usuario A no puede ver datos de Usuario B
  - Acceso a recurso de otro tenant retorna 404
  - Inyección de `id_clinica` en body retorna 400

- [ ] **T5.4**: Pruebas de rendimiento
  - Consultas con filtro de tenant < 50ms overhead
  - Índices compuestos funcionando correctamente

- [ ] **T5.5**: Verificación OpenSpec
  - Ejecutar `openspec validate --specs`
  - Ejecutar `openspec doctor`

## Definición de Terminado

- [ ] Código implementado y revisado
- [ ] Pruebas pasando (unitarias + integración)
- [ ] Migraciones ejecutadas en staging
- [ ] Documentación actualizada
- [ ] `openspec validate --specs` sin errores
- [ ] `openspec doctor` sin advertencias
