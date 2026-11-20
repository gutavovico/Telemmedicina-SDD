# Tareas: CU07 Lista de Espera

## 1. OpenSpec

- [x] Propuesta `proposal.md`.
- [x] Diseño `design.md`.
- [x] Especificación `specs/cu07-lista-espera.spec.md` (RFC 2119 + Gherkin).
- [x] Contrato `openspec/contracts/waitlist.md`.
- [x] Spec canónica `openspec/specs/waitlist/spec.md`.
- [x] Detalle de CU07 en `openspec/specs/system-design/spec.md`.

## 2. Backend

- [x] Modelo `ListaEspera` en `app/modules/appointments/models.py`.
- [x] Migración `alembic/versions/026_lista_espera_cu07.py`.
- [x] Permisos `waitlist:read` y `waitlist:write` sembrados por rol.
- [x] Schemas Pydantic v2 en `appointments/lista_espera/schemas.py`.
- [x] Servicio con inscripción, salida, posición, confirmación, rechazo y reasignación.
- [x] Router montado en `/lista-espera` y `/api/v1/lista-espera`.
- [x] Hook en cancelación de cita (CU25).
- [x] Hook en liberación de bloqueo de agenda (CU05).
- [x] Notificación `TURNO_REASIGNADO` + push best-effort.
- [x] Pruebas `tests/test_cu07_lista_espera.py`.

## 3. Frontend Web

- [x] Modelos `core/models/waitlist.models.ts`.
- [x] Servicio `features/appointments/waitlist/waitlist.service.ts`.
- [x] Vista paciente `mi-lista-espera`.
- [x] Panel staff `gestion-lista-espera`.
- [x] Rutas `/mi-lista-espera` y `/admin/lista-espera`.
- [x] Enlace en el menú de administración.
- [x] Botón "Unirme a lista de espera" en búsqueda de especialistas.
- [x] Spec del servicio.

## 4. Frontend Móvil

- [x] Feature `lib/features/waitlist/` (data, domain, presentation).
- [x] `WaitlistProvider` con estados y acciones.
- [x] Pantalla `/lista-espera` con posición, confirmar, rechazar y salir.
- [x] Acceso desde búsqueda de especialistas (CU06).
- [x] Acceso desde el menú de inicio.
- [x] Prueba del provider.

## 5. Verificación

- [x] `openspec validate --specs`.
- [x] `pytest tests/test_cu07_lista_espera.py` y regresión de citas/agenda.
- [x] `flutter analyze` y `flutter test`.
- [x] Build/typecheck web.
- [x] Ajuste de `test_cu35_subscriptions` al nuevo head de Alembic (`cu07_lista_espera_026`).
- [x] Corrección del gate de suscripciones CU35 para tolerar esquemas heredados/ligeros sin `tenant_subscriptions`, que rompían las fixtures de CU10.
  - Nota: tras instalar `apscheduler` (ya declarado en `requirements.txt`), la suite completa queda en verde: 1077 passed, 35 skipped, 65 subtests passed.
- [ ] Prueba E2E manual en APK (pendiente de entorno).
