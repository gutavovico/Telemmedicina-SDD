# Design: CU30 Gestionar Tenant

## Context

El Super Administrador ya existe como rol global (`roles.id_clinica IS NULL`) y está verificado en `scripts/seed_demo_data.py`. El backend legacy usa `clinicas.id_clinica BIGINT`; la arquitectura objetivo de `project.md` exige `tenant_id UUID`. Los dominios de tenants, suscripciones y solicitudes no deben depender del módulo legacy de clínicas.

## Goals / Non-Goals

**Goals:** ciclo de vida auditable, onboarding pendiente, operación global, continuidad clínica y aislamiento por tenant.

**Non-Goals:** catálogo/edición de planes (CU34), cobro de suscripción (CU31), alta pública (CU32), borrado físico o acceso de tenants a otros tenants.

## Decisions

1. **Dominio backend:** `app/modules/tenants/tenant_management/` y `app/modules/tenants/onboarding/`, cada uno con router, service, schemas y models/dependencies según la estructura por caso de uso.
2. **Entidad canónica:** tabla `tenants` con `id UUID PK`, datos institucionales, `status`, timestamps y `row_version` para control de concurrencia. La migración desde `clinicas` preserva los datos yFKs; `id_clinica` queda como compatibilidad temporal.
3. **Solicitud:** `tenant_requests` con `id UUID`, `request_type='ONBOARDING'`, snapshot institucional/responsable, `requested_plan_id`, `status`, `decision_reason`, actor/decisión/timestamps. `tenant_application_documents` guarda metadata, storage key, hash, MIME y estado.
4. **Transición:** `POST /requests/{id}/approve` crea atómicamente tenant, tenant ADMIN, roles/permisos mínimos y suscripción inicial según el plan; no lo hace activo si el acuerdo comercial no es válido. `reject` conserva la solicitud y su motivo.
5. **Estados:** solicitud `PENDING|APPROVED|REJECTED`; tenant `ACTIVE|SUSPENDED|INACTIVE`. `PENDING`/`REJECTED` pertenecen al recurso de solicitud, no a un tenant parcialmente creado.
6. **Suspensión:** `SUSPENDED` bloquea login operativo, nuevas reservas, nuevos usuarios y operaciones mutantes ordinarias, pero permite: (a) terminar una teleconsulta ya iniciada, (b) leer/continuar la consulta y HCE de citas en curso, (c) exportar historias existentes por actor autorizado. No permite agendar nuevas consultas.
7. **Continuidad:** la autorización se decide por recurso y estado de cita/teleconsulta, no sólo por estado del tenant. `INACTIVE` sí bloquea el acceso normal y se reserva para baja definitiva; la baja no borra HCE.
8. **Acuerdo comercial:** el backoffice actualiza la referencia al plan y notas administrativas de la suscripción; la factura y cobro pertenecen a CU31/CU34.
9. **Auditoría:** eventos globales con `tenant_id` nullable y `actor_user_id`; incluyen estado anterior/nuevo, motivo y request id. El log no filtra datos a tenants.
10. **Concurrencia:** la actualización de estado exige `If-Match` o `row_version`; una versión obsoleta devuelve 409.

## Risks / Trade-offs

- La migración `clinicas` a UUID afecta toda la plataforma; este cambio entrega el diseño pero requiere una migración coordinada antes de exposing UUID en clientes.
- “Consulta en curso” requiere una definición durable (`cita` y/o `teleconsulta` con timestamps/estado); no se inferirá sólo por la hora actual.
- Un tenant suspendido con usuarios activos requiere revising sesiones al momento de cada mutación, no sólo al login.