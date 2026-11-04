## Why
El superadmin necesita administrar una oferta mensual BOB preservando las condiciones históricas. CU31 está confirmado como no implementado; no forma parte del cambio.

## What Changes
Catálogo global web/API, versiones inmutables, filtros, historial, desactivación idempotente y auditoría global atómica. Compatibilidad CU34 autorizada con Session/BIGINT existentes.

## Capabilities
### New Capabilities
- `subscription-plan-catalog`: catálogo global versionado CU34.

## Impact
SDD, backend auth/planes, frontend features/auth/planes, migración nueva y auditoría global limitada. Sin cambios móviles, cobros, consumo ni suscripciones. No escribir en Neon.
