## Purpose
Gestionar la emisión, reserva, control de turnos y registro clínico evolutivo de fichas médicas ambulatorias con esquemas dinámicos JSONB por especialidad, correlativo único por clínica y catálogo CIE-10 (CU09).

## ADDED Requirements

### Requirement: Emisión Atómica de Fichas Médicas con Correlativo Único (CU09)
The system SHALL permitir la emisión y reserva de fichas médicas para pacientes dentro del ámbito del inquilino autenticado (`tenant_id`), asignando automáticamente un correlativo único alfanumérico secuencial con formato `FICH-YYYYMMDD-XXXX` y vinculando el slot de atención del médico.

#### Scenario: Emisión atómica de ficha con correlativo único
- **GIVEN** que el paciente con ID 2 y el médico con ID 1 pertenecen a la clínica activa con `tenant_id` "1"
- **AND** el médico cuenta con un horario de atención disponible para el día "2026-09-10" en el turno "09:00" - "09:30"
- **WHEN** se envía una solicitud `POST /medical-records/fichas` con:
  ```json
  {
    "id_paciente": 2,
    "id_medico": 1,
    "id_especialidad": 1,
    "fecha_atencion": "2026-09-10",
    "hora_inicio": "09:00",
    "hora_fin": "09:30",
    "motivo_consulta": "Control periódico de presión arterial"
  }
  ```
- **THEN** el sistema responde con código HTTP `201 Created`
- **AND** el registro contiene un campo `correlativo` con formato `FICH-20260910-XXXX`
- **AND** el estado inicial de la ficha queda establecido como `EMITIDA`
- **AND** la ficha queda irrevocablemente asociada al `id_clinica` del inquilino autenticado

### Requirement: Control de Concurrencia y Rechazo de Colisiones de Turnos (CU09)
The system SHALL validar en tiempo real la disponibilidad del slot médico y fecha solicitados, rechazando de forma atómica cualquier intento de sobreposición o doble reserva con código de error HTTP `409 Conflict`.

#### Scenario: Rechazo de colisión de turno con 409 Conflict
- **GIVEN** que ya existe una ficha activa emitida para el médico con ID 1 en fecha "2026-09-10" a las "09:00"
- **WHEN** otro paciente o la recepción intenta emitir una nueva ficha para el mismo médico, misma fecha y mismo horario "09:00"
- **THEN** el sistema bloquea la operación y responde con código HTTP `409 Conflict`
- **AND** el mensaje de error indica detalladamente: "El turno seleccionado ya se encuentra ocupado por otra ficha médica o cita clínica"
- **AND** no se altera ni duplica ningún registro en la base de datos

### Requirement: Flexibilidad de Expediente Clínico con Secciones Dinámicas JSONB (CU09)
The system SHALL soportar la captura y persistencia de esquemas dinámicos JSONB (`signos_vitales` y `secciones_dinamicas`) adaptados a la especialidad del médico tratante sin alterar la estructura tabular relacional.

#### Scenario: Renderizado y persistencia de secciones dinámicas JSONB
- **GIVEN** una ficha médica existente con estado `EMITIDA` o `EN_ATENCION` asociada a la especialidad de Cardiología
- **WHEN** el profesional médico actualiza la ficha mediante `PATCH /medical-records/fichas/{id}/clinica` enviando:
  ```json
  {
    "signos_vitales": {
      "presion_arterial": "130/85",
      "frecuencia_cardiaca": 78,
      "temperatura": 36.7,
      "peso_kg": 82.0
    },
    "secciones_dinamicas": {
      "tipo_plantilla": "CARDIOLOGIA",
      "auscultacion_cardiaca": "Ruidos cardiacos rítmicos sin soplos",
      "electrocardiograma": "Trazado normal sin elevación del segmento ST"
    }
  }
  ```
- **THEN** el sistema responde con código HTTP `200 OK`
- **AND** los objetos JSONB quedan almacenados íntegramente en la base de datos
- **AND** la consulta subsiguiente de la ficha retorna las secciones dinámicas intactas

### Requirement: Registro de Diagnóstico CIE-10 y Notas de Evolución Médica (CU09)
The system SHALL permitir al médico tratante consignar diagnósticos clínicos codificados bajo la clasificación internacional CIE-10, notas de evolución y finalizar la ficha clínica.

#### Scenario: Registro médico de notas CIE-10
- **GIVEN** que el médico tratante se encuentra atendiendo la ficha con ID "f1a2b3c4-d5e6-7f8a-9b0c-1d2e3f4a5b6c"
- **WHEN** envía una solicitud `PATCH /medical-records/fichas/{id}/clinica` con:
  ```json
  {
    "codigo_cie10": "I10",
    "diagnostico_descripcion": "Hipertensión esencial (primaria)",
    "notas_evolucion": "Paciente evoluciona favorablemente. Se ajusta dosis de Enalapril a 10mg cada 12h.",
    "estado": "FINALIZADA"
  }
  ```
- **THEN** el sistema valida que el usuario tiene rol médico y actualiza el estado a `FINALIZADA`
- **AND** el diagnóstico CIE-10 y las notas quedan vinculados al expediente
- **AND** la ficha no puede ser cancelada posteriormente

### Requirement: Consulta y Reserva de Ficha desde la Aplicación Móvil (CU09)
The system SHALL permitir a los pacientes consultar su historial de fichas activas e históricas y emitir nuevas fichas de atención desde la aplicación móvil Flutter.

#### Scenario: Consulta y reserva de ficha desde la aplicación móvil
- **GIVEN** que un paciente autenticado en la app móvil con token JWT válido y `X-Tenant-ID`
- **WHEN** la aplicación envía una solicitud `GET /medical-records/fichas?id_paciente=2`
- **THEN** el sistema responde con código HTTP `200 OK`
- **AND** retorna la lista de fichas del paciente conteniendo `correlativo`, `medico_nombre`, `especialidad_nombre`, `fecha_atencion`, `hora_inicio` y `estado`
- **AND** no se incluye ninguna ficha perteneciente a otro paciente ni a otro inquilino
