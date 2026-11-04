# Design: CU31 Pagar Suscripción del Tenant

## Context

Stripe está implementado en `app/modules/payments/` para CU19 mediante Checkout, webhook HMAC y comprobantes ReportLab. CU31 es exclusivamente web. El modelo UML de `HU DE PROYECTO.md` propone `planes`, `suscripciones`, `pagos` y `comprobantes`; `project.md` exige `tenant_id UUID`.

## Goals / Non-Goals

**Goals:** cobro seguro e idempotente, estado de suscripción, comprobante PDF, historial y reintento.

**Non-Goals:** editar catálogo de planes (CU34), cambiar/cancelar planes (CU35), excedentes (CU36), pagos de citas (CU19) o cobro móvil.

## Decisions

1. **Dominio:** `app/modules/tenants/subscription_payments/` con router, service, schemas, models y dependencias. Puede reutilizar utilidades Stripe/PDF, pero no el flujo `id_cita` de CU19.
2. **Planes:** `plans` global, versionado e inmutable cuando tiene suscripciones activas; `plan_prices` por `MONTHLY|ANNUAL`, moneda BOB, límites y servicios incluidos. CU34 administrará el catálogo; CU31 sólo consulta versiones activas.
3. **Suscripción:** `subscriptions` con `id UUID`, `tenant_id UUID`, `plan_version_id`, estado, `period_start`, `period_end`, `grace_until` y versión. Estados `TRIALING|ACTIVE|PAST_DUE|EXPIRED|CANCELLED`; la web deriva “Activa”, “Vencida” y “Por vencer”.
4. **Pago:** se extiende `pagos` con `id_suscripcion`, `tipo_pago='SUBSCRIPTION'` y snapshot de plan/precio; la restricción exige exactamente una referencia (`id_cita` o `id_suscripcion`). `stripe_session_id` y referencia son únicas.
5. **Checkout:** `POST /subscriptions/checkout` calcula el precio server-side desde plan/ciclo, persiste `PENDIENTE` y crea una sesión Stripe Checkout. El body nunca contiene tarjeta, monto libre ni tenant id.
6. **Confirmación:** el webhook `checkout.session.completed` se valida con `STRIPE_WEBHOOK_SECRET`, resuelve por sesión y ejecuta una transición idempotente. Reintentos del webhook no duplican pago, extensión ni PDF. La UI puede consultar/sincronizar el estado, nunca marcarlo pagado por Params.
7. **Vigencia:** si la suscripción vigente no ha expirado, la extensión comienza al día siguiente de `period_end`; si está expirada, comienza al confirmarse. El plan nuevo se aplica al periodo contratado.
8. **Factura:** al confirmar, se genera un número único, snapshot y PDF con tenant, plan, ciclo, monto, moneda, fecha y referencia Stripe. La descarga se autoriza contra `tenant_id` de la suscripción.
9. **Reintento:** si falla la creación de checkout o el pago, la suscripción permanece sin cambios y el ADMIN puede reintentar con el mismo plan/ciclo. Una sesión expirada genera otra orden; nunca reutiliza una sesión fallida.
10. **Stripe:** no se almacenan datos de tarjeta. El navegador redirige a Checkout alojado. El secret key y firma del webhook permanecen en backend.

## Risks / Trade-offs

- La moneda `bob` de la configuración actual puede no ser soportada por la cuenta Stripe; se requiere validación de configuración antes de producción.
- Extender vigencia y emitir PDF deben compartir transacción/locking para evitar estados parciales.
- El catálogo de planes depende de CU34, pero este cambio define el contrato mínimo de lectura.