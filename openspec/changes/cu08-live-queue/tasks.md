# Tasks: CU08 Live Queue

## [Fase 0: SDD]
- [x] T0.1: `proposal.md` (DTOs, endpoints, reutilización de tablas, §CU07).
- [x] T0.2: `specs/cu08-live-queue.spec.md` (RFC 2119 + Gherkin, incl. cross-tenant y CU07).
- [x] T0.3: `design.md` (decisiones, riesgos).
- [x] T0.4: `contracts/live-queue.md` + `specs/live-queue/spec.md` consolidado.

## [Fase 1: Backend — FastAPI]
- [x] T1.1: `app/modules/appointments/live_queue/` (`__init__`, `schemas.py`, `service.py`, `router.py`).
- [x] T1.2: `computar_cola` (universo, orden, ETA, pausas, estados de cola) + `mi_turno` (paciente atado a su registro).
- [x] T1.3: Acciones staff (`avanzar`, `perdida`, `pausas` con `BloqueoAgenda APROBADO`) + `Notificacion TURNO_PROXIMO` (pos. 1–2, con usuario vinculado).
- [x] T1.4: Montaje en `appointments/router.py` (plano + `/api/v1`) con `require_roles` y `get_required_tenant_id`.
- [x] T1.5: Tests `tests/test_cu08_live_queue.py` (sqlite + overrides: mi-turno, recálculo, pausa, perdida, cross-tenant 404, admin 403, interplay CU07).

## [Fase 2: Frontend Web — Angular 21 + Signals]
- [x] T2.1: `core/models/live-queue.models.ts` (DTOs del contrato, sin `any`).
- [x] T2.2: `LiveQueueService` (signals + polling silencioso 5 s + `detenerPolling`, precedente teleconsulta).
- [x] T2.3: Ruta `/mi-cola` (paciente, `authGuard`) + tarjeta "Mi turno de hoy" + acceso desde hub Mi salud.
- [x] T2.4: Ruta `/admin/cola` (`staffGuard`) con cola operativa (selector médico, avanzar/perdida/pausa, banner PAUSADA/DEMORADA) + entrada en sidebar + rutas en `app.routes.server.ts`.
- [x] T2.5: Specs vitest del servicio (cálculo de presentación, guards por rol).

## [Fase 3: Móvil — Flutter Clean Architecture]
- [x] T3.1: `ApiConfig.liveQueue*` + `cola_remote_datasource.dart` (`ApiClient` con JWT + `X-Tenant-ID`).
- [x] T3.2: `cola_models.dart` (`fromJson`/`toJson` tolerantes camelCase/snake_case) + `domain/repositories/cola_repository.dart` + impl.
- [x] T3.3: `ColaProvider` (`ChangeNotifier`, `Timer.periodic` 5 s, carga silenciosa, dispose).
- [x] T3.4: `MiTurnoScreen` (paciente, pull-to-refresh) + `ColaOperativaScreen` (médico, acciones) + registro en `main.dart` + tarjeta en home.

## [Fase 4: Verificación]
- [x] T4.1: Suite backend completa en verde (venv del proyecto).
- [x] T4.2: `tsc --noEmit` + specs web en verde + `npm run build` OK.
- [x] T4.3: `flutter analyze` del feature + `flutter test` del modelo en verde.
- [ ] T4.4: `openspec validate --specs` (sin CLI disponible en este entorno).
