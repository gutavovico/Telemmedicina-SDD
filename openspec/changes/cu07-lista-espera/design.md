# Diseño Técnico: CU07 Lista de Espera

## 1. Modelo de Datos

### 1.1 Tabla `lista_espera`

| Columna | Tipo | Nulo | Descripción |
|---|---|---|---|
| `id_lista_espera` | BIGINT / INTEGER (SQLite) | No | PK autoincremental. |
| `id_clinica` | BIGINT FK `clinicas.id_clinica` | No | Tenant dueño de la inscripción. |
| `id_paciente` | BIGINT FK `pacientes.id_paciente` | No | Paciente en espera. |
| `id_medico` | BIGINT FK `medicos.id_medico` | Sí | Médico preferido; nulo = cualquier médico de la especialidad. |
| `id_especialidad` | BIGINT FK `especialidades.id_especialidad` | Sí | Especialidad preferida. |
| `fecha_deseada` | DATE | Sí | Fecha mínima deseada; nulo = lo antes posible. |
| `estado` | VARCHAR(20) | No | `EN_ESPERA` por defecto. |
| `prioridad` | INTEGER | No | 0 por defecto; mayor = más prioritario. |
| `motivo` | TEXT | Sí | Motivo de la inscripción. |
| `id_cita_ofrecida` | BIGINT FK `citas.id_cita` | Sí | Cita creada al ofrecer el turno. |
| `fecha_ofrecimiento` | TIMESTAMP | Sí | Momento del ofrecimiento. |
| `fecha_respuesta` | TIMESTAMP | Sí | Momento de confirmación/rechazo. |
| `fecha_creacion` | TIMESTAMP | No | Orden de antigüedad. |
| `updated_at` | TIMESTAMP | Sí | Última actualización. |

Índices: `(id_clinica, estado)`, `(id_medico, estado)`, `(id_especialidad, estado)`, `(id_paciente, estado)`.

No se crea una restricción UNIQUE parcial porque SQLite y PostgreSQL difieren; la unicidad de inscripción activa se valida en el servicio dentro de la transacción.

### 1.2 Reutilización

| Tabla | Uso |
|---|---|
| `citas` | Crear la cita `PENDIENTE` ofrecida y actualizarla a `CONFIRMADA`/`CANCELADA`. |
| `notificaciones` | Aviso `TURNO_REASIGNADO` al paciente. |
| `pacientes` / `usuarios` | Resolver paciente y usuario destinatario. |
| `medicos` / `especialidades` | Validar médico y especialidad del tenant. |
| `tratamiento_dispositivos` | Push FCM best-effort (infraestructura CU17/CU19). |

## 2. Módulo Backend

```
app/modules/appointments/lista_espera/
├── __init__.py
├── schemas.py   # Pydantic v2
├── service.py   # Reglas y reasignación
└── router.py    # Endpoints /lista-espera
```

El modelo `ListaEspera` se declara en `app/modules/appointments/models.py` para mantener una sola metadata de SQLAlchemy, siguiendo el patrón de `Cita` y `BloqueoAgenda`.

### 2.1 Algoritmo de reasignación

```
reasignar_turno_liberado(db, *, tenant, medico, especialidad, fecha, hora_inicio, hora_fin, servicio, origen)
  si el cupo ya está ocupado por cita no cancelada -> no hacer nada
  candidato = primera inscripción EN_ESPERA del tenant que cumpla:
      (id_medico = medico) o (id_medico nulo y (id_especialidad nula o = especialidad))
      y (fecha_deseada nula o fecha_deseada <= fecha)
      orden: prioridad DESC, fecha_creacion ASC
  si no hay candidato -> no hacer nada
  crear Cita(PENDIENTE, id_clinica=tenant, id_paciente, id_medico, id_especialidad, fecha, hora)
  inscripcion -> OFRECIDO, id_cita_ofrecida, fecha_ofrecimiento
  crear Notificacion(TURNO_REASIGNADO)
  push best-effort
```

La función es idempotente a nivel de cupo: si ya existe una cita activa en esa fecha/hora/médico, no se ofrece.

### 2.2 Hooks

- `appointments/consultas/service.py::actualizar_cita`: si el estado pasa a `CANCELADA`, tras `db.commit()` se invoca la reasignación en un `try/except`; un fallo no revierte la cancelación.
- `appointments/consultas/service.py::eliminar_cita`: antes de borrar se captura la información del cupo; tras `db.commit()` se invoca la reasignación best-effort.
- `appointments/agenda/service.py::cambiar_bloqueo`: cuando `accion == "liberar"`, tras `_guardar(db)` se invoca la reasignación para el inicio de la franja liberada, usando `duracion_minutos` del servicio.

### 2.3 Multitenant y roles

- `get_required_tenant_id` en todos los endpoints.
- Paciente: resuelto por `Paciente.id_usuario == current_user.id_usuario`; solo ve y modifica lo propio.
- Staff (`ADMIN`, `MEDICO`, `RECEPCION`): limitado a `ListaEspera.id_clinica == tenant`.
- Cruce de tenant o recurso ajeno → `404`. Rol no autorizado → `403`.

### 2.4 Permisos

Migración `026_lista_espera_cu07`:

| Permiso | Descripción | Roles |
|---|---|---|
| `waitlist:read` | Consultar lista de espera y posición | ADMIN, MEDICO, RECEPCION, PACIENTE |
| `waitlist:write` | Inscribirse, salir, confirmar, rechazar y ofrecer turnos | ADMIN, MEDICO, RECEPCION, PACIENTE |

La autorización efectiva de endpoints se refuerza con `require_roles` y el scope de paciente; los permisos quedan disponibles para el guard de rutas web.

## 3. Contrato REST

Ver `openspec/contracts/waitlist.md`. Resumen:

- `POST /api/v1/lista-espera` (201) — inscribirse.
- `GET /api/v1/lista-espera` — listar (paciente: propias; staff: tenant, con filtros).
- `GET /api/v1/lista-espera/mi-espera` — inscripciones propias con posición.
- `DELETE /api/v1/lista-espera/{id}` — salir.
- `POST /api/v1/lista-espera/{id}/confirmar` — aceptar turno ofrecido.
- `POST /api/v1/lista-espera/{id}/rechazar` — rechazar y ofrecer al siguiente.
- `POST /api/v1/lista-espera/{id}/ofrecer` (staff) — ofrecer manualmente un cupo.

## 4. Frontend Web (Angular)

- `core/models/waitlist.models.ts`: DTOs camelCase derivados del contrato.
- `features/appointments/waitlist/waitlist.service.ts`: cliente HTTP con signals.
- `mi-lista-espera`: vista paciente con posición, estado y acciones confirmar/rechazar/salir.
- `gestion-lista-espera`: panel staff con filtros por estado/médico/especialidad y acciones.
- Rutas `/mi-lista-espera` (authGuard) y `/admin/lista-espera` (staffGuard + `waitlist:read`).
- Botón "Unirme a lista de espera" en el detalle de disponibilidad del especialista (CU06).

## 5. Frontend Móvil (Flutter)

Feature `lib/features/waitlist/` con Clean Architecture:

```
data/       models, datasource, repository impl
domain/     entities, repository
presentation/ providers, screens
```

- `WaitlistProvider` con estados `initial/loading/success/error` y acciones join/leave/confirm/reject.
- Pantalla `/lista-espera`: lista de inscripciones, posición, ofertas con Confirmar/Rechazar y formulario de inscripción.
- Desde la búsqueda de especialistas (CU06) se abre `/lista-espera` con argumentos `{idMedico, idEspecialidad, nombreMedico}`.
- Acceso directo desde el menú de inicio del paciente.

## 6. Pruebas

- Backend: `tests/test_cu07_lista_espera.py` (sqlite + overrides, patrón CU08).
  - Inscripción, duplicado, posición, aislamiento de tenant.
  - Cancelación de cita → ofrecimiento + notificación.
  - Confirmar → cita `CONFIRMADA`.
  - Rechazar → siguiente candidato.
  - Salir → `CANCELADO`.
  - Liberación de bloqueo → ofrecimiento.
- Web: spec del servicio de mapeo snake_case → camelCase.
- Móvil: prueba del provider con repositorio fake.
