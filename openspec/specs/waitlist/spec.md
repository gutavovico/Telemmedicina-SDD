# Waitlist

## Purpose

Especificación Formal: CU07 Inscribirse y Reasignar Turnos en Lista de Espera

## Requirements
### Requirement: El sistema SHALL gestionar la lista de espera y reasignar turnos liberados

El sistema SHALL cumplir las reglas numeradas a continuación (en RFC 2119, **DEBE** equivale a SHALL y **NO DEBEN** a SHALL NOT).

1. El sistema **DEBE** permitir a un paciente autenticado inscribirse en `lista_espera` indicando al menos un médico (`id_medico`) o una especialidad (`id_especialidad`), con `fecha_deseada` opcional, `motivo` opcional y prioridad `0`.
2. Recepción y administración **DEBEN** poder inscribir a un paciente de su clínica indicando `id_paciente` y una `prioridad` entre `0` y `5`.
3. El sistema **NO DEBE** permitir dos inscripciones activas (`EN_ESPERA` u `OFRECIDO`) del mismo paciente para el mismo médico y especialidad; debe responder `409 Conflict`.
4. El paciente **DEBE** poder consultar únicamente sus propias inscripciones y su posición. La posición **DEBE** calcularse dentro del grupo (médico/especialidad) ordenando por `prioridad DESC` y `fecha_creacion ASC`; las inscripciones que no estén `EN_ESPERA` **DEBEN** devolver `posicion = 0`.
5. El paciente **DEBE** poder salir de su inscripción (`DELETE /api/v1/lista-espera/{id}`); el staff **DEBE** poder cancelar inscripciones de su clínica. Si la inscripción estaba `OFRECIDO`, el sistema **DEBE** cancelar la cita ofrecida y ofrecer el cupo al siguiente candidato.
6. Cuando una cita pasa a `CANCELADA` (CU25) o se libera un bloqueo de agenda (CU05), el sistema **DEBE** intentar reasignar el cupo al primer candidato elegible: inscripción `EN_ESPERA` del mismo tenant, con `fecha_deseada` nula o menor/igual a la fecha del cupo, ordenada por prioridad y antigüedad.
7. La reasignación **DEBE** crear una cita `PENDIENTE` para el paciente, marcar la inscripción como `OFRECIDO`, registrar `id_cita_ofrecida` y `fecha_ofrecimiento`, y crear una `Notificacion` (`tipo = TURNO_REASIGNADO`, `estado = PENDIENTE`). El push FCM **DEBE** intentarse sin bloquear ni revertir la operación.
8. Si el cupo ya está ocupado por una cita no cancelada o no existe candidato, el sistema **DEBE** continuar sin error. Toda falla en la reasignación o en el push **NO DEBE** revertir la cancelación ni la liberación original.
9. El paciente **DEBE** poder confirmar un turno `OFRECIDO` (`POST /api/v1/lista-espera/{id}/confirmar`), lo que cambia la cita a `CONFIRMADA` y la inscripción a `CONFIRMADO`; o rechazarlo (`POST /api/v1/lista-espera/{id}/rechazar`), lo que cancela la cita, marca la inscripción `RECHAZADO` y ofrece el cupo al siguiente candidato.
10. Recepción y administración **DEBEN** disponer de un panel para filtrar por estado, médico, especialidad y fecha, y para confirmar, rechazar u ofrecer turnos manualmente (`POST /api/v1/lista-espera/{id}/ofrecer`).
11. Toda consulta y mutación **DEBE** filtrar por `id_clinica` del tenant autenticado. Un recurso de otra clínica **DEBE** responder `404 Not Found`; un rol no autorizado, `403 Forbidden`.
12. La funcionalidad **DEBE** estar disponible en web (Angular) y móvil (Flutter), incluyendo la inscripción desde la búsqueda de especialistas (CU06) y la confirmación o rechazo del turno reasignado.

---

#### Scenario: Criterios de aceptación (Gherkin)

```gherkin
Característica: Lista de espera y reasignación de turnos (CU07)

  Antecedentes:
    Dado el paciente "Ana Pérez" en la clínica "Clínica Central"
    Y el médico "Roberto Gómez" de la misma clínica

  Escenario: Inscripción sin cupos
    Cuando Ana envía POST /api/v1/lista-espera con id_medico de Roberto
    Entonces responde 201 Created con estado EN_ESPERA y posicion 1

  Escenario: Inscripción duplicada
    Dada una inscripción activa de Ana para Roberto
    Cuando Ana intenta inscribirse otra vez para el mismo médico
    Entonces responde 409 Conflict

  Escenario: Cancelación libera el cupo
    Dada una cita CONFIRMADA de Roberto el 2026-12-01 a las 09:00
    Y una inscripción EN_ESPERA de Ana para Roberto
    Cuando la cita se actualiza a CANCELADA
    Entonces la inscripción de Ana pasa a OFRECIDO
    Y se crea una cita PENDIENTE para Ana el 2026-12-01 a las 09:00
    Y se crea una Notificacion TURNO_REASIGNADO para Ana

  Escenario: Confirmación del turno
    Dada una inscripción OFRECIDO con cita PENDIENTE
    Cuando Ana envía POST /api/v1/lista-espera/{id}/confirmar
    Entonces la cita pasa a CONFIRMADA y la inscripción a CONFIRMADO

  Escenario: Rechazo y siguiente candidato
    Dadas las inscripciones EN_ESPERA de Ana y luego de Luis para el mismo cupo
    Cuando Ana rechaza el turno ofrecido
    Entonces la inscripción de Ana pasa a RECHAZADO
    Y la de Luis pasa a OFRECIDO

  Escenario: Salida de la lista
    Dada una inscripción EN_ESPERA de Ana
    Cuando Ana envía DELETE /api/v1/lista-espera/{id}
    Entonces la inscripción pasa a CANCELADO

  Escenario: Aislamiento multitenant
    Dada una inscripción de la clínica "Clínica Central"
    Cuando un staff de otra clínica la consulta
    Entonces responde 404 Not Found

  Escenario: Liberación de bloqueo
    Dado un bloqueo APROBADO de Roberto el 2026-12-02 de 10:00 a 10:30
    Y una inscripción EN_ESPERA de Ana con fecha_deseada 2026-12-02
    Cuando el staff libera el bloqueo
    Entonces la inscripción de Ana pasa a OFRECIDO
    Y se crea una cita PENDIENTE a las 10:00
```
