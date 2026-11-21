# Propuesta de Cambio: CU07 Inscribirse y Reasignar Turnos en Lista de Espera (`cu07-lista-espera`)

## 1. Contexto y Objetivos

Habilitar la **lista de espera** para pacientes que no encuentran cupos disponibles en la búsqueda de especialistas (CU06). Cuando se libera un turno por cancelación de una cita (CU25) o por liberación de un bloqueo de agenda (CU05), el sistema reasigna automáticamente el primer cupo elegible al paciente con mayor prioridad y antigüedad, crea la cita y le notifica para que confirme o rechace.

**CU07 no es CU08.** CU07 administra la *demanda sin cupo* (`lista_espera`); CU08 administra el *orden de atención de citas ya asignadas* (`citas` del día). El único contrato entre ambos es la tabla `citas`: cuando CU07 confirma un turno reasignado, crea una `cita` normal que CU08 verá automáticamente.

Objetivos:

1. Permitir que un paciente se inscriba en la lista de espera desde la búsqueda de especialistas (web y móvil).
2. Mostrar al paciente su posición y el estado de su inscripción.
3. Reasignar automáticamente el primer cupo elegible al liberarse un turno, con notificación.
4. Permitir confirmar o rechazar un turno reasignado; si se rechaza, ofrecer el cupo al siguiente candidato.
5. Dar a recepción/administración un panel para gestionar inscripciones y reasignaciones.

## 2. Alcance

### Incluido

- Tabla `lista_espera` con aislamiento por clínica (`id_clinica`), paciente, médico/especialidad, fecha deseada, estado y prioridad.
- Migración Alembic aditiva y reversible.
- Permisos `waitlist:read` y `waitlist:write`.
- Endpoints REST multitenant para inscribirse, listar, consultar posición, salir, confirmar, rechazar y ofrecer manualmente.
- Hook de reasignación en la cancelación de citas (CU25) y en la liberación de bloqueos de agenda (CU05).
- Notificación en la tabla `notificaciones` (`tipo = TURNO_REASIGNADO`) y push best-effort reutilizando la infraestructura FCM existente.
- Vistas web (paciente y staff) y pantalla móvil Flutter.

### Fuera de alcance

- Lista de espera por orden de llegada en vivo (eso es CU08).
- Cobros, recordatorios multicanal programados (CU19/CU20).
- Reasignación entre clínicas distintas: siempre dentro del mismo tenant.

## 3. Estados de la Inscripción

| Estado | Significado |
|---|---|
| `EN_ESPERA` | Inscripción activa esperando un cupo. |
| `OFRECIDO` | Se liberó un cupo, se creó una cita `PENDIENTE` y se notificó al paciente. |
| `CONFIRMADO` | El paciente aceptó el turno; la cita pasa a `CONFIRMADA`. |
| `RECHAZADO` | El paciente rechazó el turno; el cupo se ofrece al siguiente candidato. |
| `CANCELADO` | El paciente salió de la lista o la inscripción fue anulada por el staff. |
| `EXPIRADO` | Reservado para vencimiento futuro del ofrecimiento. |

## 4. Reglas de Negocio

1. Un paciente no puede tener dos inscripciones activas (`EN_ESPERA` u `OFRECIDO`) para el mismo médico y especialidad.
2. El paciente solo puede inscribirse, salir y responder por sus propias inscripciones; el staff de la clínica puede gestionar las de su tenant.
3. La prioridad la define el staff (0–5). El paciente siempre entra con prioridad 0. A igual prioridad, gana la inscripción más antigua (`fecha_creacion`).
4. La reasignación automática solo considera inscripciones `EN_ESPERA` del tenant, con `fecha_deseada` nula o menor/igual a la fecha del cupo.
5. Si el cupo ya está ocupado por una cita no cancelada, no se ofrece.
6. Si el paciente rechaza, el cupo se ofrece al siguiente candidato elegible. Si no hay más, la cita ofrecida se cancela.
7. Toda falla en la reasignación o en el push **no revierte** la cancelación ni la liberación del turno original.

## 5. Contratos y Compatibilidad

- Contrato REST: `openspec/contracts/waitlist.md`.
- Rutas: `/lista-espera` y `/api/v1/lista-espera` (web y móvil consumen `/api/v1/lista-espera`).
- No se modifican contratos existentes de CU05, CU06, CU08 ni CU25; solo se añaden hooks internos.
