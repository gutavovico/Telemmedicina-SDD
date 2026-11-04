# Tasks: CU30 Gestionar Tenant

## 1. Datos y migración

- [ ] 1.1 Crear migración `tenants` UUID, `tenant_requests`, documentos y auditoría global; migrar `clinicas` sin pérdida.
- [ ] 1.2 Migrar citas, teleconsultas, HCE y usuarios para referenciar el tenant UUID y añadir índices por tenant/estado.
- [ ] 1.3 Definir versionado de fila y restricciones/estados de solicitud y tenant.

## 2. Backend — FastAPI

- [ ] 2.1 Crear `app/modules/tenants/tenant_management/` y `onboarding/` con router, service, schemas y dependencias.
- [ ] 2.2 Implementar listados/filtros globales de solicitudes y tenants con paginación, sólo Super Admin.
- [ ] 2.3 Implementar detalle documental, aprobación/rechazo transaccional y creación atómica de tenant/ADMIN.
- [ ] 2.4 Implementar activación, suspensión, reactivación e inactivación con motivo, versión y auditoría.
- [ ] 2.5 Implementar política de continuidad para teleconsultas/consultas en curso e HCE.
- [ ] 2.6 Implementar actualización del acuerdo de pago sin cobrar ni modificar el catálogo de planes.
- [ ] 2.7 Añadir pruebas de RBAC, transiciones, concurrencia, auditoría y continuidad clínica.

## 3. Web — Angular

- [ ] 3.1 Crear feature `features/tenants/tenant-management/` con modelos/servicios tipados.
- [ ] 3.2 Crear guard exclusivo de Super Admin verificado contra `/auth/me`.
- [ ] 3.3 Crear lista de solicitudes, detalle con documentos, aprobar/rechazar con motivo y confirmación.
- [ ] 3.4 Crear gestión de tenants con activar/suspender/reactivar y actualización de acuerdo comercial.
- [ ] 3.5 Mostrar auditoría y errores 401/403/404/409; adaptar a pantalla pequeña.

## 4. Verificación

- [ ] 4.1 Ejecutar `openspec doctor`, `openspec validate --specs` y validar los cambios.
- [ ] 4.2 Ejecutar pruebas backend, `tsc --noEmit`, tests/build Angular y revisión de aislamiento.
- [ ] 4.3 Verificar que suspender conserva HCE/teleconsulta en curso pero impide nuevas reservas.