# Tasks: Formalización de Línea Base del Sprint 0 (SaaS Multitenant Baseline)

## 1. Database & Migrations (PostgreSQL Neon)

- [ ] 1.1 Validar que las tablas `usuarios`, `roles`, `permisos`, `medicos`, `especialidades` y `medico_especialidad` contengan la columna `tenant_id: UUID` y verificar las migraciones en Alembic.
- [ ] 1.2 Verificar las restricciones compuestas `UNIQUE(tenant_id, correo)` y `UNIQUE(tenant_id, matricula)` y los índices asociados a `tenant_id`.

## 2. Backend Implementation (FastAPI)

- [ ] 2.1 Formalizar e inyectar el claim `tenant_id` en `create_access_token` y `create_refresh_token` en `app/core/security.py`.
- [ ] 2.2 Actualizar endpoints de `/auth/login`, `/auth/logout`, `/auth/refresh` y verificar el versionado de tokens (`token_version`).
- [ ] 2.3 Verificar endpoints de `/auth/forgot-password` y `/auth/reset-password` confirmando el uso de HMAC-SHA256 y bloqueo tras 5 intentos (HTTP 429).
- [ ] 2.4 Actualizar el router de `/users` para filtrar consultas y mutaciones con `tenant_id == current_tenant.id` y códigos semánticos.
- [ ] 2.5 Actualizar el router de `/roles` y permisos asegurando aislamiento por tenant y permisos RBAC.
- [ ] 2.6 Actualizar el router de `/medicos` y `/especialidades` vinculando la matrícula y asignación de especialidades por tenant.

## 3. Frontend Web (Angular)

- [ ] 3.1 Integrar `tenant.interceptor.ts` y `auth.interceptor.ts` en las llamadas HTTP a `/auth`, `/users` y `/medicos`.
- [ ] 3.2 Tipar los servicios `AuthService`, `UserService`, `RoleService` y `DoctorService` según los contratos OpenAPI en `openspec/contracts/`.

## 4. Frontend Mobile (Flutter)

- [ ] 4.1 Configurar el almacenamiento seguro del token JWT y el `tenant_id` en `FlutterSecureStorage`.
- [ ] 4.2 Alinear los modelos `UsuarioModel`, `MedicoModel` y llamadas REST en la capa de datos con los esquemas Pydantic v2.

## 5. Automated Tests & Verification

- [ ] 5.1 Ejecutar pruebas unitarias e integración para el flujo de autenticación (CU01), cierre de sesión (CU24) y recuperación de contraseña (CU23).
- [ ] 5.2 Ejecutar pruebas de aislamiento multitenant para usuarios (CU02), roles (CU26) y médicos (CU04) validando rechazo cross-tenant (404/403).
- [ ] 5.3 Validar coherencia formal de OpenSpec ejecutando `openspec doctor` y `openspec validate`.
