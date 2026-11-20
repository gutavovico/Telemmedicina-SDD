# Especificación: CU07 Inscribirse y Reasignar Turnos en Lista de Espera

## 1. Requisitos Funcionales (RFC 2119)

### 1.1 Inscripción

- **R1.** El sistema SHALL permitir a un paciente autenticado inscribirse en la lista de espera indicando al menos un médico o una especialidad.
- **R2.** El sistema SHALL permitir a recepción y administración inscribir a un paciente de su clínica indicando `id_paciente`.
- **R3.** El sistema SHALL rechazar con `409 Conflict` una segunda inscripción activa (`EN_ESPERA` u `OFRECIDO`) del mismo paciente para el mismo médico y especialidad.
- **R4.** El sistema SHALL asignar prioridad `0` a las inscripciones creadas por un paciente; solo el staff SHALL poder fijar prioridad entre `0` y `5`.
- **R5.** El sistema SHALL registrar `fecha_creacion` para ordenar las inscripciones por antigüedad.

### 1.2 Consulta y posición

- **R6.** El sistema SHALL devolver al paciente únicamente sus propias inscripciones.
- **R7.** El sistema SHALL calcular la posición de una inscripción `EN_ESPERA` dentro de su grupo (médico/especialidad) ordenando por `prioridad DESC` y `fecha_creacion ASC`.
- **R8.** El sistema SHALL devolver `posicion = 0` para inscripciones que no estén `EN_ESPERA`.
- **R9.** El sistema SHALL permitir al staff filtrar por estado, médico, especialidad y fecha deseada dentro de su clínica.

### 1.3 Salida

- **R10.** El sistema SHALL permitir al paciente salir de su inscripción y al staff cancelar inscripciones de su clínica.
- **R11.** Si la inscripción estaba `OFRECIDO`, el sistema SHALL cancelar la cita ofrecida y ofrecer el cupo al siguiente candidato.

### 1.4 Reasignación automática

- **R12.** Cuando una cita pasa a `CANCELADA`, el sistema SHALL intentar reasignar el cupo al primer candidato elegible.
- **R13.** Cuando se libera un bloqueo de agenda (`LIBERADO`), el sistema SHALL intentar reasignar el inicio de la franja liberada.
- **R14.** El sistema SHALL considerar solo inscripciones `EN_ESPERA` de la misma clínica, con `fecha_deseada` nula o menor/igual a la fecha del cupo.
- **R15.** El sistema SHALL preferir al candidato con mayor `prioridad` y, a igual prioridad, al más antiguo.
- **R16.** El sistema SHALL crear una cita `PENDIENTE` para el candidato y marcar la inscripción como `OFRECIDO`.
- **R17.** El sistema SHALL crear una notificación `TURNO_REASIGNADO` dirigida al usuario del paciente y SHALL intentar un push sin bloquear la operación.
- **R18.** Si no existe candidato o el cupo ya está ocupado, el sistema SHALL continuar sin error.
- **R19.** Cualquier fallo en la reasignación SHALL NOT revertir la cancelación de la cita ni la liberación del bloqueo.

### 1.5 Confirmación y rechazo

- **R20.** El paciente SHALL poder confirmar un turno `OFRECIDO`; el sistema SHALL cambiar la cita a `CONFIRMADA` y la inscripción a `CONFIRMADO`.
- **R21.** El paciente SHALL poder rechazar un turno `OFRECIDO`; el sistema SHALL cancelar la cita, marcar la inscripción `RECHAZADO` y ofrecer el cupo al siguiente candidato.
- **R22.** El staff SHALL poder confirmar o rechazar en nombre de un paciente de su clínica.

### 1.6 Seguridad multitenant

- **R23.** Toda consulta y mutación SHALL filtrar por `id_clinica` del tenant autenticado.
- **R24.** Un recurso de otra clínica SHALL responder `404 Not Found`.
- **R25.** Un rol no autorizado SHALL responder `403 Forbidden`.

## 2. Criterios de Aceptación (Gherkin)

### 2.1 Inscripción exitosa

```gherkin
Feature: Inscripción en lista de espera
  Como paciente sin cupos disponibles
  Quiero inscribirme en la lista de espera
  Para que el sistema me asigne un turno cuando se libere

  Scenario: Paciente se inscribe para un médico
    Given un paciente autenticado de la clínica "A"
    And un médico activo de la clínica "A"
    When el paciente envía POST /api/v1/lista-espera con id_medico
    Then el sistema responde 201 Created
    And la inscripción queda en estado "EN_ESPERA"
    And la posición del paciente es 1
```

### 2.2 Inscripción duplicada

```gherkin
  Scenario: Paciente intenta inscribirse dos veces
    Given una inscripción activa del paciente para el médico
    When el paciente envía otra inscripción para el mismo médico y especialidad
    Then el sistema responde 409 Conflict
```

### 2.3 Reasignación por cancelación

```gherkin
Feature: Reasignación automática de turnos
  Scenario: Cancelación de cita libera un cupo
    Given una cita confirmada del médico "M" el "2026-12-01" a las "09:00"
    And una inscripción EN_ESPERA del paciente "P" para el médico "M"
    When la cita se actualiza a estado "CANCELADA"
    Then la inscripción de "P" pasa a "OFRECIDO"
    And se crea una cita PENDIENTE para "P" el "2026-12-01" a las "09:00"
    And se crea una notificación "TURNO_REASIGNADO" para "P"
```

### 2.4 Confirmación

```gherkin
  Scenario: Paciente confirma el turno ofrecido
    Given una inscripción en estado "OFRECIDO" con una cita PENDIENTE
    When el paciente envía POST /api/v1/lista-espera/{id}/confirmar
    Then la cita pasa a "CONFIRMADA"
    And la inscripción pasa a "CONFIRMADO"
```

### 2.5 Rechazo con siguiente candidato

```gherkin
  Scenario: Paciente rechaza y se ofrece al siguiente
    Given dos inscripciones EN_ESPERA para el mismo cupo, "P1" más antigua que "P2"
    And "P1" recibió el ofrecimiento
    When "P1" envía POST /api/v1/lista-espera/{id}/rechazar
    Then la inscripción de "P1" pasa a "RECHAZADO"
    And la cita de "P1" se cancela
    And la inscripción de "P2" pasa a "OFRECIDO"
```

### 2.6 Salida

```gherkin
  Scenario: Paciente sale de la lista
    Given una inscripción EN_ESPERA del paciente
    When el paciente envía DELETE /api/v1/lista-espera/{id}
    Then la inscripción pasa a "CANCELADO"
```

### 2.7 Aislamiento multitenant

```gherkin
  Scenario: Staff de otra clínica intenta ver una inscripción
    Given una inscripción de la clínica "A"
    And un usuario staff autenticado de la clínica "B"
    When el staff consulta la inscripción
    Then el sistema responde 404 Not Found
```

### 2.8 Liberación de bloqueo

```gherkin
  Scenario: Liberar un bloqueo ofrece el cupo
    Given un bloqueo APROBADO del médico "M" el "2026-12-02" de "10:00" a "10:30"
    And una inscripción EN_ESPERA para "M" con fecha_deseada "2026-12-02"
    When el staff libera el bloqueo
    Then la inscripción pasa a "OFRECIDO"
    And se crea una cita PENDIENTE a las "10:00"
```

## 3. Reglas de Validación

| Campo | Regla |
|---|---|
| `id_medico` / `id_especialidad` | Al menos uno debe estar presente. |
| `prioridad` | Entero entre 0 y 5. |
| `fecha_deseada` | Formato `YYYY-MM-DD`. |
| `motivo` | Máximo 500 caracteres. |
| `estado` (filtro) | Uno de los estados definidos o vacío. |
