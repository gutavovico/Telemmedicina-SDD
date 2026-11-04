# Design: CU32 Solicitar Alta y Baja de Entidad de Salud

## Context

CU32 es web público y se integra con CU30. La tabla `tenant_requests` y `tenant_application_documents` propuesta por CU30 es el destino de alta. La baja requiere un recurso y estado distintos porque parte de un tenant existente.

## Goals / Non-Goals

**Goals:** captura institucional completa, adjuntos seguros, estado pendiente, notificaciones y baja formal trazable.

**Non-Goals:** aprobar/rechazar (CU30), cobrar plan (CU31), crear módulos de plan, modificar HCE o borrar datos.

## Decisions

1. **Dominio backend:** `app/modules/tenants/public_onboarding/` para alta y `app/modules/tenants/deactivation_requests/` para baja; cada uno con router, service, schemas y models/dependencies.
2. **Solicitud de alta:** `tenant_requests` con `request_type='ONBOARDING'`, snapshot institucional, `responsible_name`, `responsible_email`, requested plan, `status=PENDING` y token de seguimiento hasheado. El NIT se normaliza y valida como único global de solicitudes/tenants.
3. **Documentos:** carga multipart; PDF/JPG/PNG, máximo configurable por tipo y total; se guarda fuera del directorio público con key aleatoria, MIME verificado, hash SHA-256 y estado `UPLOADED|VALIDATED|REJECTED`. El Super Admin descarga mediante endpoint autorizado.
4. **Idempotencia y duplicados:** la combinación NIT normalizado + tipo de solicitud detecta una solicitud pendiente/activa y devuelve 409 con referencia de seguimiento, sin crear otro tenant o carga duplicada.
5. **Plan de interés:** referencia a una versión de plan pública activa; no implica suscripción ni cobro.
6. **Correo:** se envía confirmación de recepción al responsable y, tras decisión CU30, correo APROBADO/RECHAZADO con motivo cuando corresponda. El envío se registra; un fallo de SMTP no revierte una solicitud ya persistida y puede reintentarse.
7. **Seguimiento:** token opaco de alta aleatoriedad suficiente; el backend almacena sólo hash. Devuelve estado y motivo de rechazo controlado, nunca documentos ni datos del tenant.
8. **Baja:** `tenant_deactivation_requests` con `tenant_id`, motivo, estado `PENDING|APPROVED|REJECTED|CANCELLED`, actor y datos del responsable. La presenta el ADMIN autenticado del tenant; la aprobación corresponde al Super Admin en CU30. No elimina HCE, citas ni documentos.
9. **Prevención de abuso:** rate limiting por IP/correo, captcha opcional/configurable y registro de IP/user-agent en auditoría de seguridad; no se implementa autenticación para el alta pública.
10. **Interoperabilidad:** al aprobar CU30, la misma solicitud/tenant UUID se utiliza; el alta no crea dos recursos ni dos tenants.

## Risks / Trade-offs

- El correo no garantiza entrega; se conserva outbox/auditoría y reintento seguro.
- La unicidad global del NIT reduce duplicados pero requiere una política de normalización documentada.
- La baja definitiva y la suspensión tienen efectos distintos: la baja se solicita formalmente; la suspensión es una acción inmediata del Super Admin.