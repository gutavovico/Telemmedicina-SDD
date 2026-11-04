# Tasks: CU32 Solicitar Alta y Baja de Entidad de Salud

## 1. Datos y contrato

- [ ] 1.1 Completar `tenant_requests`/documents con responsable, plan, tracking token y documentos de baja.
- [ ] 1.2 Crear índices únicos normalizados para NIT y solicitudes duplicadas.
- [ ] 1.3 Publicar `openspec/contracts/entity-onboarding.md`.

## 2. Backend — FastAPI

- [ ] 2.1 Crear `app/modules/tenants/public_onboarding/` con router, service, schemas y models.
- [ ] 2.2 Implementar alta multipart validada, normalización, idempotencia/409 y estado PENDING sin crear tenant.
- [ ] 2.3 Implementar almacenamiento privado de documentos, hash, validación y acceso sólo a Super Admin.
- [ ] 2.4 Implementar tracking público por token hasheado con respuesta mínima.
- [ ] 2.5 Integrar outbox/correo de recepción y de decisión APROBADO/RECHAZADO con reintento.
- [ ] 2.6 Crear `app/modules/tenants/deactivation_requests/` y flujo de baja por ADMIN del tenant.
- [ ] 2.7 Añadir pruebas de validación, upload, duplicados, tracking, correo, aislamiento y baja sin borrado.

## 3. Web — Angular

- [ ] 3.1 Crear feature pública `features/tenants/public-onboarding/` con componentes standalone y formularios reactivos.
- [ ] 3.2 Crear formulario institucional/responsable/plan y carga de documentos con progreso, tamaño/tipo y errores.
- [ ] 3.3 Crear página de resultado y consulta por código de seguimiento.
- [ ] 3.4 Crear flujo autenticado de baja para ADMIN del tenant, con motivo y confirmación.
- [ ] 3.5 Añadir pruebas de validación/presentación y adaptación móvil sin permitir el alta en la app Flutter.

## 4. Verificación

- [ ] 4.1 Ejecutar `openspec doctor`, `openspec validate --specs` y validar los cambios.
- [ ] 4.2 Ejecutar pruebas backend, `tsc --noEmit`, tests/build Angular.
- [ ] 4.3 Verificar flujo completo CU32→CU30, correos, adjuntos y baja sin pérdida clínica.