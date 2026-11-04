# Tasks: CU31 Pagar Suscripción del Tenant

## 1. Datos y contrato

- [ ] 1.1 Crear planes/versionado de precios, suscripciones y extend `pagos` para discriminating `SUBSCRIPTION`.
- [ ] 1.2 Definir restricciones de una referencia (`id_cita` o `id_suscripcion`), unicidad Stripe y estados.
- [ ] 1.3 Publicar `openspec/contracts/subscription-payments.md`.

## 2. Backend — FastAPI

- [ ] 2.1 Crear `app/modules/tenants/subscription_payments/` con router, service, schemas, models y RBAC ADMIN.
- [ ] 2.2 Implementar consulta de suscripción, planes/precios activos y cálculo server-side del monto.
- [ ] 2.3 Crear orden PENDIENTE y sesión Stripe Checkout sin aceptar tarjeta, monto ni tenant en body.
- [ ] 2.4 Implementar webhook firmado idempotente y sincronización que renueva vigencia una sola vez.
- [ ] 2.5 Generar comprobante/factura PDF y descarga autorizada por tenant.
- [ ] 2.6 Implementar historial paginado y reintento tras fallo/expiración.
- [ ] 2.7 Añadir pruebas de RBAC, aislamiento, monto, webhook duplicado/fallido, vigencia y PDF.

## 3. Web — Angular

- [ ] 3.1 Crear feature `features/tenants/subscription-payment/` con modelos/servicios tipados.
- [ ] 3.2 Crear guard/visibilidad exclusiva del ADMIN del tenant con perfil verificado.
- [ ] 3.3 Crear pantalla de estado/plan/ciclo, resumen de monto y redirección a Stripe.
- [ ] 3.4 Crear página de retorno/resultado que consulte estado sin declararlo pagado por URL.
- [ ] 3.5 Crear historial con estado y descarga de comprobante PDF; conservar selección tras fallo.
- [ ] 3.6 Añadir pruebas de componentes/guards y adaptación a pantalla pequeña.

## 4. Verificación

- [ ] 4.1 Ejecutar `openspec doctor`, `openspec validate --specs` y validar los cambios.
- [ ] 4.2 Ejecutar pruebas backend, `tsc --noEmit`, tests/build Angular.
- [ ] 4.3 Verificar en sandbox Stripe pago, reenvío de webhook, descarga y aislamiento entre tenants.