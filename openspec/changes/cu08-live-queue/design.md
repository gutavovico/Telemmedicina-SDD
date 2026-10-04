# Technical Design: CU08 Live Queue

## Context
Ver `proposal.md` y `specs/cu08-live-queue.spec.md`. Backend FastAPI con sesión síncrona (`Session`, precedente agenda/CU05), BD con `id_clinica` como discriminador (desviación documentada del spec `tenant_id UUID`) y `citas.hora` en VARCHAR (`HH:MM[:SS]`). Web Angular 21 con signals; móvil Flutter con `ChangeNotifier`. Sin Firebase/push: solo `http`, `provider`, `flutter_secure_storage`.

## Goals / Non-Goals

**Goals:**
- Fila del día calculada al vuelo desde `citas` (sin tablas ni migraciones nuevas).
- Vista paciente (posición + ETA + estado) en web y móvil.
- Cola operativa staff en web (agenda) y móvil (médico) con avanzar / perdida / pausas.
- Notificación `TURNO_PROXIMO` al quedar en posición 1–2.
- Aislamiento multitenant estricto y privacidad por rol.

**Non-Goals:**
- WebSockets/WebRTC (igual que CU15: planes serverless gratuitos; polling 5 s).
- `lista_espera` / CU07: la cola no la toca (contrato vía `citas`).
- Auditoría dedicada: los cambios quedan trazados en `citas.estado` + `check_in` + `bloqueos_agenda.motivo` + `notificaciones`.
- Reasignación automática de huecos (eso es CU07).

## Decisions

### 1. Sin DDL: estados como valores VARCHAR
`citas.estado` es `String(30)` sin CHECK, por lo que `EN_CURSO`, `ATENDIDA` y `PERDIDA` se usan sin migración. `ATENDIDA` es operativa (salió de la fila); el cierre clínico a `COMPLETADA` sigue siendo CU28. Alternativa descartada: tabla `cola_virtual` propia (duplicaría el estado de `citas` y exigiría sincronización).

### 2. Cálculo de la fila (servicio, una sola función `computar_cola`)
Universo: citas del médico+fecha con estado en (`PENDIENTE`,`CONFIRMADA`,`EN_CURSO`), orden `hora_inicio` normalizada (`_a_hora` tolerante `HH:MM[:SS]`, precedente `agenda/service.py`) e `id_cita`. Pausa vigente: `BloqueoAgenda` con `estado=APROBADO`, misma fecha y `hora_inicio <= ahora < hora_fin`. ETA por entrada = suma de duraciones de los de delante + minutos restantes de pausa vigente; duración = servicio de la cita si existe, si no promedio del médico (`ServicioMedico.duracion_minutos`), si no 20. Umbrales: demora acumulada > 30 → `DEMORADA`; sin pendientes → `SIN_TURNOS`.

### 3. Tiempo real por sondeo
Web: `LiveQueueService` con signals + `setInterval(5000)` y `refrescarSilencioso` (sin spinner), limpieza en `ngOnDestroy` (precedente `teleconsulta.service.ts` / `teleconsulta-page.ts`). Móvil: `ColaProvider` con `Timer.periodic(5 s)` y carga silenciosa con reconciliación (precedente `teleconsulta_provider.dart`). Sin Optimistic UI: el paciente no muta nada y las acciones staff esperan la respuesta del servidor.

### 4. Tenant y roles
`get_required_tenant_id` obligatorio (precedente CU15) + scope `join(Medico).join(Usuario).filter(Usuario.id_clinica == tenant)` con tolerancia a `Cita.id_clinica NULL` (precedente `communications/service.py`). Roles: `require_roles(["MEDICO","MÉDICO","RECEPCION","RECEPCIÓN"])` para operativa (sin ADMIN de clínica, matriz HU → 403; el superadmin global mantiene su bypass de framework); paciente resuelto por `id_usuario` y atado a su `id_paciente`. MEDICO solo su `id_medico` (403 ajeno); RECEPCION exige `id_medico` (422 si falta, precedente agenda).

### 5. UX por plataforma
- Web paciente: tarjeta "Mi turno de hoy" en `/mi-cola` + acceso desde el hub Mi salud; staff: `/admin/cola` (staffGuard) con selector de médico (recepción) y acciones por fila.
- Móvil paciente: `MiTurnoScreen` con pull-to-refresh + polling; médico: `ColaOperativaScreen` con acciones. Sin ruta nueva obligatoria: apertura desde Mis citas y registro en `main.dart`.

## Risks / Trade-offs

- **[Riesgo: sondeo cada 5 s con N clientes]** → Mitigación: queries acotadas a un médico+fecha con índices existentes (`fecha_cita`, `estado`); el intervalo solo corre con la vista montada.
- **[Riesgo: doble cómputo web/móvil]** → Mitigación: el cálculo vive solo en el backend; los clientes renderizan DTOs.
- **[Riesgo: ADMIN ve 403 en /admin/cola]** (staffGuard del frontend lo deja pasar) → Mitigación: el componente muestra el `detail` del backend ("acceso restringido a médico/recepción"); documentado como fiel a la matriz HU.
- **[Riesgo: notificaciones duplicadas]** → Mitigación: se crean solo dentro de `avanzar`/`perdida` (evento discreto), no en cada lectura.
