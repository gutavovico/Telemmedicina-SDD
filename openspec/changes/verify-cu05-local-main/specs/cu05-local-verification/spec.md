## ADDED Requirements

### Requirement: Ejecución local aislada
The system SHALL usar localhost:8000 en Angular development, conservar Render en production y seleccionar el driver PostgreSQL instalado. CU16 SHALL mantener su validación criptográfica de startup.

#### Scenario: Desarrollo local
- **GIVEN** Angular en localhost:4200 y API local configurada
- **WHEN** se consulta agenda
- **THEN** la petición usa localhost:8000 con CORS autorizado

### Requirement: Recepción autenticada
The system SHALL derivar el rol visual de CU5 del nombre rol devuelto por GET /auth/me, normalizando acentos y mayúsculas, sin depender del catálogo administrativo ni inferir privilegios de IDs.

#### Scenario: Recepción sin permiso de catálogo
- **GIVEN** una sesión con rol Recepción e id_clinica válido
- **WHEN** abre la agenda
- **THEN** muestra el enlace Agenda y carga médicos y servicios sin consultar el catálogo de roles

### Requirement: Horas de citas heredadas
The system SHALL interpretar horas TIME o texto ISO local para verificar solapamientos sin escribir citas. Las citas CANCELADA SHALL quedar fuera del cálculo de ocupación y de los avisos por bloqueo. Datos no interpretables de citas no canceladas SHALL impedir anunciar disponibilidad libre y producir advertencias.

#### Scenario: Cita con horas varchar
- **GIVEN** una cita con horas 10:00 y 10:30 almacenadas como texto
- **WHEN** CU5 calcula disponibilidad
- **THEN** el slot solapado está ocupado sin error de tipos

#### Scenario: Hora inválida
- **GIVEN** una cita con hora no interpretable
- **WHEN** CU5 calcula disponibilidad
- **THEN** citas_verificadas es false y no se anuncian slots libres

#### Scenario: Cita cancelada
- **GIVEN** una cita CANCELADA en la fecha del médico, incluso sin hora_fin
- **WHEN** CU5 calcula disponibilidad o se aprueba un bloqueo superpuesto
- **THEN** esa cita no ocupa slots, no produce aviso de intervalo incompleto y no recibe notificación de reprogramación

#### Scenario: Cita vigente sin hora final
- **GIVEN** una cita no cancelada con hora_fin ausente
- **WHEN** CU5 calcula disponibilidad
- **THEN** citas_verificadas es false, los slots no se anuncian libres y la advertencia identifica la cita y la hora faltante
