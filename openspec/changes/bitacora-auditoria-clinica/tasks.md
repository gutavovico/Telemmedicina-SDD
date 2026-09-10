# Tasks: Implementación de Bitácora de Auditoría Clínica (CU21)

## 1. Database & Migrations (PostgreSQL Neon)

- [x] 1.1 Crear migración Alembic para la tabla `bitacora_auditoria` con columnas: `id_auditoria` (BIGINT PK), `tenant_id` (UUID FK NOT NULL), `id_usuario` (BIGINT FK NOT NULL), `tabla_afectada` (VARCHAR(100)), `registro_id` (BIGINT), `accion` (VARCHAR(50)), `descripcion` (TEXT), `datos_anteriores` (JSONB), `datos_nuevos` (JSONB), `direccion_ip` (VARCHAR(45)), `fecha_hora` (TIMESTAMP DEFAULT CURRENT_TIMESTAMP).
- [x] 1.2 Crear índices sobre `(tenant_id, fecha_hora)`, `(tenant_id, id_usuario)`, `(tenant_id, accion)`, `(tenant_id, tabla_afectada)`.
- [x] 1.3 Verificar integridad referencial con tablas `clinicas` y `usuarios`.

## 2. Backend Implementation (FastAPI)

- [x] 2.1 Crear modelo SQLAlchemy `BitacoraAuditoria` en `app/modules/auditoria/models.py` con relaciones a `Usuario` y tenant.
- [x] 2.2 Crear esquemas Pydantic v2 en `app/modules/auditoria/schemas.py`: `AuditLogEntry`, `AuditLogListResponse`, `AuditLogFilters`.
- [x] 2.3 Implementar `AuditService` en `app/modules/auditoria/service.py` con función `registrar_evento(tenant_id, id_usuario, tabla_afectada, registro_id, accion, descripcion, datos_anteriores, datos_nuevos, direccion_ip)`.
- [x] 2.4 Implementar router `GET /api/v1/audit-log` en `app/modules/auditoria/router.py` con filtros (fecha_inicio, fecha_fin, id_usuario, accion, tabla_afectada, registro_id), paginación (page, page_size) y ordenamiento descendente por `fecha_hora`. Restringir a roles `Administrador` / `Auditor`.
- [x] 2.5 Implementar endpoint `GET /api/v1/audit-log/export/pdf` que genere archivo PDF con los registros filtrados.
- [x] 2.6 Implementar endpoint `GET /api/v1/audit-log/export/excel` que genere archivo Excel con los registros filtrados.
- [x] 2.7 Integrar llamadas a `registrar_evento()` en los servicios existentes de módulos clínicos y administrativos relevantes (pacientes, usuarios, roles, médicos).

## 3. Frontend Web (Angular)

- [x] 3.1 Crear interfaz TypeScript `AuditLogEntry` y `AuditLogFilters` derivados del contrato `openspec/contracts/audit-log.md`.
- [x] 3.2 Crear servicio `AuditService` en Angular que consuma los endpoints `GET /api/v1/audit-log`, `GET /api/v1/audit-log/export/pdf` y `GET /api/v1/audit-log/export/excel`.
- [x] 3.3 Crear componente `bitacora-page` con tabla paginada, filtros reactivos (fecha rango, usuario, acción, tabla, registro_id) y botones de exportación PDF/Excel.
- [x] 3.4 Agregar ruta `/admin/bitacora` protegida por `adminGuard` y agregar entrada "Bitácora" en el sidebar del panel de administración.

## 4. Frontend Mobile (Flutter)

- *(Sin tareas para este caso de uso — CU21 no aplica a la interfaz móvil en Sprint 1.)*

## 5. Automated Tests & Verification

- [x] 5.1 Ejecutar pruebas de inserción en `bitacora_auditoria` y verificar que UPDATE y DELETE son rechazados.
- [x] 5.2 Ejecutar pruebas de aislamiento multitenant para el endpoint `GET /api/v1/audit-log` validando que un tenant no puede ver registros de otro (404/403).
- [x] 5.3 Verificar filtros, paginación y exportación (PDF/Excel) del endpoint.
- [x] 5.4 Validar coherencia formal de OpenSpec ejecutando `openspec doctor` y `openspec validate --specs`.
