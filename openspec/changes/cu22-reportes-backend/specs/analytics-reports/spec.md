# Spec Delta

## Purpose

Permite que ADMIN consulte indicadores de citas y encuentros clínicos registrados de su clínica con definiciones, filtros y resultados verificables.

## ADDED Requirements

### Requirement: Acceso administrativo y ámbito clínico
The system SHALL permitir catálogo, opciones y consultas CU22 solo a un usuario activo con rol administrativo activo y clínica activa; SHALL derivar la clínica de la cuenta autenticada y SHALL impedir que headers, IDs o filtros amplíen ese ámbito.

#### Scenario: Clínica ajena y rol denegado
- **GIVEN** dos clínicas con citas y un ADMIN activo de la primera
- **WHEN** el ADMIN consulta con `X-Tenant-ID` de la segunda o filtra por un médico ajeno
- **THEN** no obtiene filas, opciones ni agregados de la segunda; el médico ajeno responde 404
- **AND** Médico, Recepción, Paciente y un ADMIN de rol inactivo reciben 403 en cada ruta CU22

### Requirement: Catálogo cerrado y validación
The system SHALL publicar reportes, métricas, dimensiones, columnas, filtros, operadores, orden, formatos y límites permitidos; SHALL rechazar campos desconocidos, duplicados, valores incompatibles, fechas invertidas y parámetros fuera de límite.

#### Scenario: Definición inválida
- **GIVEN** una sesión ADMIN válida
- **WHEN** solicita ordenar por un campo no catalogado o repite un filtro
- **THEN** recibe 422 y no se ejecuta una consulta arbitraria

### Requirement: Encuentros clínicos registrados
The system SHALL contar por `COUNT(DISTINCT id_cita)` las citas con al menos una consulta registrada en el período de `fecha_consulta`, con `Consulta.id_clinica`, historia, cita y médico coherentes con la clínica autenticada, sin exigir `Paciente.id_clinica` ni un estado de cita de cierre.

#### Scenario: Dos evoluciones de una cita y paciente compartido
- **GIVEN** una cita con dos consultas válidas y un paciente con otra atención en una clínica distinta
- **WHEN** ADMIN consulta encuentros de la primera clínica
- **THEN** esa cita cuenta una vez y solo se incluyen las consultas de la primera clínica
- **AND** el paciente cuenta una vez entre los pacientes únicos de ese ámbito

### Requirement: Actividad, cancelaciones y modalidad registrada
The system SHALL contar citas distintas por `fecha_cita`, contar cancelaciones únicamente donde el estado es `CANCELADA`, y clasificar modalidad desde `tipo_consulta` y `modalidad`: coincidencia o valor único reconocido, `CONFLICTO` cuando difieren, `DESCONOCIDA` cuando faltan y `OTRA` cuando el valor no pertenece al catálogo. SHALL usar la especialidad de la cita, con categoría nula explícita.

#### Scenario: Modalidad contradictoria y especialidad ausente
- **GIVEN** una cita con `tipo_consulta=TELEMEDICINA`, `modalidad=PRESENCIAL` y sin especialidad
- **WHEN** ADMIN agrupa citas por modalidad y especialidad
- **THEN** aparece en `CONFLICTO` y sin especialidad, una sola vez
- **AND** el resultado no afirma que hubo videollamada

### Requirement: Agrupación, totales y paginación coherentes
The system SHALL aplicar el mismo período, filtros y ámbito a métricas globales y filas agrupadas; SHALL ordenar de forma estable, paginar grupos y exponer su total. SHALL advertir que pacientes únicos globales no se obtienen sumando grupos.

#### Scenario: Páginas estables y total distinto de suma
- **GIVEN** el mismo paciente atendido por dos médicos en el período
- **WHEN** ADMIN agrupa pacientes únicos por médico y recorre dos páginas
- **THEN** las páginas no repiten grupos y el total global de pacientes únicos es uno

### Requirement: Ausentismo no disponible
The system SHALL publicar ausentismo con `disponible=false`, valor nulo y causa estable `SIN_ESTADO_AUSENCIA`; SHALL rechazar su consulta o exportación como reporte calculable hasta existir una transición explícita.

#### Scenario: Cita pasada sin consulta
- **GIVEN** una cita vencida sin consulta
- **WHEN** ADMIN consulta el catálogo o resultados
- **THEN** no se presenta esa cita como ausencia ni una tasa de ausentismo cero
