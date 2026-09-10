# Proposal: Implementación de Bitácora de Auditoría Clínica (CU21)

## Why
La plataforma SaaS Multitenant de Telemedicina requiere un módulo de auditoría clínica que garantice la trazabilidad completa, inmutabilidad y cumplimiento normativo de todas las operaciones realizadas sobre historias clínicas e información administrativa sensible. Los requisitos funcionales RF-22 y RF-23 y los no funcionales RNF-03, RNF-06 y RNF-07 exigen que toda operación quede registrada de forma inalterable, identificando usuario, acción, fecha, hora, IP y datos afectados, con protección contra modificaciones no autorizadas.

Actualmente no existe un mecanismo formal de auditoría en la plataforma. Este cambio introduce el caso de uso CU21 (Historias de Usuario HU1-38 a HU1-42) como módulo completo con backend, frontend web y contrato de API formalizado bajo SDD.

## What Changes
- **Nueva tabla de auditoría (`bitacora_auditoria`):**
  - Tabla INSERT-ONLY (inmutable) en PostgreSQL con aislamiento por `tenant_id`.
  - Campos: `id_auditoria`, `tenant_id`, `id_usuario`, `tabla_afectada`, `registro_id`, `accion`, `descripcion`, `datos_anteriores` (JSONB), `datos_nuevos` (JSONB), `direccion_ip`, `fecha_hora`.
  - Índices sobre `tenant_id`, `fecha_hora`, `id_usuario`, `accion`, `tabla_afectada`.
  - Restricciones: no permite UPDATE ni DELETE a nivel de aplicación y base de datos.

- **Servicio de auditoría en Backend (FastAPI):**
  - Función `registrar_evento()` invocable desde servicios y/o middleware para insertar registros automáticamente en operaciones sobre tablas clínicas y administrativas.
  - Router `GET /api/v1/audit-log` con filtros (fecha, usuario, acción, tabla, registro_id), paginación y ordenamiento descendente por fecha.
  - Endpoints de exportación: `GET /api/v1/audit-log/export/pdf` y `GET /api/v1/audit-log/export/excel`.
  - Seguridad: requiere rol `Administrador` o `Auditor` (vía dependencia RBAC).

- **Módulo de frontend web (Angular):**
  - Componente `bitacora-page` con tabla paginada, filtros reactivos y botones de exportación PDF/Excel.
  - Integración en el panel de administrador bajo la ruta `/admin/bitacora`.
  - Guard de acceso restringido a roles autorizados.

- **Contrato de API REST:**
  - Nuevo contrato `openspec/contracts/audit-log.md` con esquemas de datos, endpoints y códigos de respuesta HTTP.

## Capabilities

### New Capabilities
- `audit-log`: Registro inmutable y consulta de bitácora de auditoría clínica con filtros, paginación y exportación (PDF/Excel), aislado por `tenant_id` y restringido a roles `Administrador` y `Auditor` (CU21, RF-22, RF-23, RNF-07).

### Modified Capabilities
*(Ninguna capability existente es modificada directamente; los módulos existentes invocarán al servicio de auditoría de forma aditiva.)*

## Impact
- **Backend (FastAPI):**
  - Nuevo módulo: `app/modules/auditoria/` con `router.py`, `service.py`, `schemas.py`, `models.py`.
  - Dependencia compartida: `app/core/dependencies.py` (reutiliza `get_current_tenant` y `get_current_user`).
  - Middleware o decorador de auditoría para interceptar operaciones en módulos clínicos existentes.
- **Base de Datos (PostgreSQL Neon):**
  - Nueva tabla `bitacora_auditoria` con migración Alembic.
  - Claves foráneas a `clinicas` (`tenant_id`) y `usuarios` (`id_usuario`).
  - Política INSERT-ONLY a nivel de permisos de BD.
- **Frontend Web (Angular):**
  - Nuevo componente en `features/admin/bitacora/`.
  - Nuevo servicio `AuditService` consumiendo los endpoints del contrato.
  - Nueva ruta `/admin/bitacora` en el sidebar del panel de administración.
- **Frontend Móvil (Flutter):**
  - Sin impacto. El caso de uso CU21 no aplica para la interfaz móvil según alcance del Sprint 1.
