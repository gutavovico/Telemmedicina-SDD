# Technical Design: Bitácora de Auditoría Clínica (CU21)

## Context
La plataforma SaaS Multitenant de Telemedicina requiere un módulo de auditoría clínica inmutable para cumplir con los requisitos RF-22, RF-23, RNF-03, RNF-06 y RNF-07. Este diseño describe la arquitectura de la tabla de auditoría, el servicio de registro automático, los endpoints de consulta/exportación y la integración con el panel de administración Angular.

Ver motivación y alcance en `proposal.md`.

## Goals / Non-Goals

**Goals:**
- Implementar una tabla `bitacora_auditoria` INSERT-ONLY con aislamiento estricto por `tenant_id`.
- Proveer un servicio de auditoría reutilizable (`AuditService`) que registre automáticamente operaciones CRUD sobre tablas clínicas y administrativas.
- Exponer endpoints REST paginados y con filtros para consulta de la bitácora, restringidos a roles `Administrador` / `Auditor`.
- Implementar exportación de registros filtrados en formato PDF y Excel.
- Integrar el módulo en el panel de administración Angular con tabla reactiva, filtros y paginación.

**Non-Goals:**
- No se implementa auditoría mediante triggers de base de datos (se opta por el enfoque a nivel de aplicación para capturar IP y usuario de sesión).
- No se incluye interfaz móvil (Flutter) para este caso de uso en el Sprint 1.
- No se implementa cifrado en reposo de campos JSONB en esta iteración (se evaluará en sprints posteriores).

## Decisions

### 1. Registro de Auditoría a Nivel de Aplicación (no Triggers)
- **Decisión:** El registro de eventos se realiza mediante llamadas explícitas desde los servicios de backend al `AuditService`, o bien mediante un middleware/decorador FastAPI que intercepte las respuestas exitosas de endpoints relevantes.
- **Justificación:** Los triggers de PostgreSQL no tienen acceso nativo al `id_usuario` de la sesión HTTP ni a la dirección IP del cliente. El enfoque a nivel de aplicación permite capturar estos datos de forma directa desde el contexto de la request.
- **Alternativa Descartada:** Triggers con variables de sesión PostgreSQL (`SET LOCAL app.current_user_id = ...`). Descartado por complejidad adicional con conexiones pooled y async.

### 2. Tabla INSERT-ONLY con Protección a Nivel de Aplicación y BD
- **Decisión:** La tabla `bitacora_auditoria` se protege contra UPDATE y DELETE mediante:
  1. Validación en el servicio de aplicación (no exponer endpoints de mutación).
  2. Revocación de permisos `UPDATE` y `DELETE` para el rol de conexión de la aplicación en PostgreSQL (recomendado en producción).
- **Justificación:** Garantiza la inmutabilidad requerida por RNF-07 y las políticas de cumplimiento normativo.

### 3. Paginación Cursor-Based vs Offset-Based
- **Decisión:** Se utiliza paginación offset-based (`page` + `page_size`) para la primera versión, consistente con los endpoints existentes del proyecto (`/users`, `/pacientes`).
- **Alternativa Futura:** Si el volumen de registros supera los millones, se migrará a cursor-based pagination con `id_auditoria` como cursor.

### 4. Exportación PDF/Excel Server-Side
- **Decisión:** Los archivos PDF y Excel se generan en el backend usando `reportlab` (PDF) y `openpyxl` (Excel), aplicando los mismos filtros que la consulta GET y retornando un stream binario (`application/pdf` o `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`).
- **Justificación:** Garantiza que la exportación respete el aislamiento por tenant y los filtros de seguridad.

## Risks / Trade-offs

- **[Riesgo] Crecimiento acelerado de la tabla de auditoría:**
  - *Mitigación:* Índices parciales sobre `tenant_id` + `fecha_hora` y particionamiento por rango de fechas en iteraciones futuras. Archivado de registros antiguos (> 2 años) a almacenamiento frío.
- **[Riesgo] Impacto en rendimiento al registrar auditoría en cada operación:**
  - *Mitigación:* Inserción asíncrona en background tasks (Celery/BackgroundTasks de FastAPI) para operaciones de lectura (SELECT). Inserción síncrona solo para escrituras (INSERT/UPDATE/DELETE) donde la trazabilidad es crítica.
- **[Riesgo] Datos sensibles en campos JSONB (`datos_anteriores`, `datos_nuevos`):**
  - *Mitigación:* Sanitización de campos sensibles (contraseñas, tokens) antes de la inserción en la bitácora. Se excluyen explícitamente campos como `password`, `token_version`, `refresh_token`.
