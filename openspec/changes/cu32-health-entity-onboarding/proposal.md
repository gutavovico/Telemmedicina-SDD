# Proposal: CU32 Solicitar Alta y Baja de Entidad de Salud

## Why

El registro público legacy crea inmediatamente una clínica `ACTIVO` y su administrador, no una solicitud pendiente; no acepta documentos legales, plan de interés ni motivo de baja, y no notifica recepción o decisión. Esto incumple el flujo aprobado por CU30, donde una solicitud debe evaluarse antes de crear y activar un tenant.

## What Changes

- Sustituir el registro público directo por una solicitud de onboarding institucional en estado PENDING.
- Capturar y validar datos institucionales, contacto, responsable legal/administrador y plan de interés mediante un portal público.
- Adjuntar documentos legales con validación de tipo/tamaño, almacenamiento privado, hash y control de acceso.
- Enviar confirmación de recepción y notificar al solicitante el resultado aprobado/rechazado.
- Ofrecer baja definitiva a un tenant activo mediante su ADMIN, con solicitud, confirmación y trazabilidad; no borrar datos clínicos.
- Proporcionar un código de seguimiento seguro para consultar el estado de una solicitud sin exponer información de otros solicitantes.

## Capabilities

### New Capabilities

- `entity-onboarding-backend`: alta pública pendiente, documentos, tracking, correo y baja formal.
- `entity-onboarding-web`: portal público de alta/seguimiento y flujo autenticado de baja.

### Modified Capabilities

Ninguna. `POST /clinicas/registrar` se considera legado y no debe crear tenants activos; el flujo aprobado será el de CU32→CU30.

## Impact

Backend FastAPI en `app/modules/tenants/public_onboarding/` y `deactivation_requests/`; Angular en `features/tenants/public-onboarding/`; contrato `openspec/contracts/entity-onboarding.md`. Requiere almacenamiento privado, outbox de correo, auditoría de seguridad y una migración coordinada con CU30. No hay alcance Flutter.