# Tasks: CU06 Buscar Especialistas y Disponibilidad

## 1. Datos y contrato

- [ ] 1.1 Migrar `servicios_medicos` al discriminador `tenant_id UUID`, agregar `modalidad`, índice `(tenant_id, modalidad, costo)` y backfill validado.
- [ ] 1.2 Publicar `openspec/contracts/specialist-search.md` con query, DTOs, errores y ejemplos.

## 2. Backend — FastAPI

- [ ] 2.1 Crear `app/modules/appointments/specialist_search/` con router, schemas, service y dependencias de tenant/RBAC.
- [ ] 2.2 Implementar filtros combinables, paginación estable, perfiles y servicios del tenant.
- [ ] 2.3 Implementar disponibilidad real desde horarios, citas y bloqueos; reutilizar el cálculo en búsqueda y detalle.
- [ ] 2.4 Implementar detalle de disponibilidad y normalizar hora/fecha de la API.
- [ ] 2.5 Añadir pruebas de dos tenants, datos ajenos, filtros combinados, slots ocupados/bloqueados y p95 objetivo.

## 3. Web — Angular

- [ ] 3.1 Crear modelos TypeScript alineados al contrato y servicio HTTP sin `any`.
- [ ] 3.2 Crear página de búsqueda con Reactive Forms, signals, filtros, paginación y navegación al detalle.
- [ ] 3.3 Mostrar foto, nombre, especialidad, matrícula, costo, modalidades y slots; distinguir vacío/error/carga.
- [ ] 3.4 Añadir pruebas de filtros, concurrencia de respuestas y adaptación móvil.

## 4. Mobile — Flutter

- [ ] 4.1 Crear `lib/features/appointments/specialist_search/` en capas data/domain/presentation.
- [ ] 4.2 Implementar datasource, repositorio, provider atómico y serialización alineada al contrato.
- [ ] 4.3 Crear pantalla de filtros, resultados y detalle de disponibilidad, con pull-to-refresh y estados vacío/error/carga.
- [ ] 4.4 Añadir pruebas de modelos, provider y aislamiento de respuesta obsoleta.

## 5. Verificación

- [ ] 5.1 Ejecutar `openspec doctor`, `openspec validate --specs` y validación de cada cambio.
- [ ] 5.2 Ejecutar suites backend, `tsc --noEmit`, tests/build Angular, `flutter analyze` y `flutter test`.
- [ ] 5.3 Medir p95 de búsqueda menor a 2 s con dataset representativo.