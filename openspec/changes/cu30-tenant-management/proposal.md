# Proposal: CU30 Gestionar Tenant

## Why

El backoffice actual sólo lista y cambia el estado de `clinicas`; no existe una solicitud de ingreso pendiente, revisión documental, aprobación/rechazo trazable ni gestión de acuerdos comerciales. La suspensión actual usa un booleano de estado global y no distingue operaciones permitidas durante consultas en curso. El CU exige que suspender no bloquee ni pierda consultas ya iniciadas ni historias clínicas.

## What Changes

- Separar solicitudes de tenant de tenants activos mediante un recurso de onboarding con estados y decisión auditada.
- Introducir el ciclo de vida global del tenant: `PENDING`, `ACTIVE`, `SUSPENDED`, `INACTIVE` y `REJECTED`, con baja lógica.
- Incorporar backoffice web exclusivo del Super Administrador global para listar, revisar, aprobar, rechazar, activar, suspender y actualizar acuerdos de pago.
- Definir una política de continuidad: la suspensión bloquea nuevas operaciones, pero conserva acceso acotado a consultas en curso e historia clínica.
- Registrar actor, motivo, estado anterior/nuevo y referencia de la solicitud en auditoría global.

## Capabilities

### New Capabilities

- `tenant-management-backend`: ciclo de vida global, solicitudes, aprobación/rechazo, acuerdos y continuidad clínica.
- `tenant-management-web`: backoffice de gestión de tenants para Super Administrador.

### Modified Capabilities

Ninguna. La gestión legacy de clínicas se conserva como compatibilidad temporal durante la migración UUID, pero no define el contrato objetivo de CU30.

## Impact

Backend FastAPI en `app/modules/tenants/tenant_management/` y `onboarding/`; Angular en `features/tenants/tenant-management/`; contratos `openspec/contracts/tenant-management.md`. La migración `clinicas` → `tenants UUID` es transversal y requiere coordinación con todos los dominios. La regla de continuidad altera las dependencias de autorización de citas, teleconsultas e HCE.