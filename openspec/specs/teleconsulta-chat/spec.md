# Teleconsulta and Medical Chat Specification (CU15)

**Capability ID:** `teleconsulta-chat`  
**Caso de Uso Asociado:** CU15 - Teleconsulta y Chat de Cita Médica (HU1-25, HU1-26)  
**Requisito Funcional:** RF-15  
**Modelo de Servicio:** SaaS Multitenant (Shared Database, Shared Schema)  
**Estado:** Especificación Formal Consolidada (OpenSpec / SDD)  

---

## Purpose
The system SHALL proveer la plataforma interactiva de atención médica remota y comunicación síncrona/asíncrona entre el médico especialista y el paciente en el contexto de una cita médica programada, garantizando el aislamiento lógico multitenant (`tenant_id: UUID` / `id_clinica`), la sincronización en tiempo real mediante actualización optimista (Optimistic UI) con sondeo silencioso, y la interoperabilidad estricta entre el Portal Web (Angular), la Aplicación Móvil (Flutter) y el Backend API RESTful (FastAPI + PostgreSQL Neon).

---

## Requirements

### Requirement: Visualización y Contexto Asistencial de Teleconsulta
The system SHALL presentar una interfaz unificada de teleconsulta a usuarios autorizados que consolide los datos de filiación del paciente, los detalles técnicos de la cita médica, la ficha profesional del especialista tratante y el historial de mensajería asociado a la cita.

#### Scenario: Visualización exitosa y contextual de la sesión de teleconsulta
- **GIVEN** que el paciente con identificación oficial y cita médica activa con ID 105 se encuentra autenticado en su clínica correspondiente
- **WHEN** el usuario accede a la sesión de teleconsulta (`/citas/105/teleconsulta` o modal móvil)
- **THEN** el sistema responde con código HTTP `200 OK`
- **AND** la interfaz exhibe el identificador de clínica ("Hospital San Juan de Dios"), los datos del paciente (nombre completo, documento ID y seguro médico), los detalles de la cita (especialidad y horario) y la ficha del especialista con su disponibilidad

#### Scenario: Acceso contextual desde el perfil del médico tratante
- **GIVEN** que el médico especialista asignado a la cita inicia sesión en el portal
- **WHEN** consulta la atención médica de su paciente
- **THEN** el sistema carga el contexto clínico del paciente y habilita el submódulo de mensajería sin redirigir de ruta ni romper la barra de navegación activa

---

### Requirement: Mensajería Bidireccional en Tiempo Real con Optimistic UI
The system SHALL permitir el intercambio continuo de mensajes de texto y referencias a archivos adjuntos entre el paciente y el médico especialista dentro de la cita médica, incorporando cada mensaje inmediatamente al hilo visual (Optimistic UI) y persistiendo el registro de manera atómica en la base de datos con reconciliación de IDs.

#### Scenario: Envío de mensaje desde el cliente con persistencia inmediata
- **GIVEN** que el usuario escribe un mensaje en la caja de texto del chat
- **WHEN** presiona el botón de envío o la tecla Enter
- **THEN** la burbuja de conversación aparece de forma instantánea en la interfaz con marca de tiempo actual y alineación correspondiente a la autoría
- **AND** el sistema despacha una solicitud `POST /api/v1/citas/{id_cita}/chat/mensajes`
- **AND** al recibir la confirmación del servidor con código `201 Created`, el identificador temporal optimista se reconcilia con el ID definitivo de base de datos

#### Scenario: Sincronización continua de nuevos mensajes mediante sondeo silencioso
- **GIVEN** que el médico envía una respuesta desde su terminal
- **WHEN** se ejecuta el intervalo de sondeo en segundo plano del cliente
- **THEN** el nuevo mensaje se incorpora al historial sin refrescar la pantalla ni descartar mensajes optimistas locales en tránsito

---

### Requirement: Control de Acceso y Aislamiento Multitenant en Teleconsulta
The system SHALL restringir el acceso a los datos de la teleconsulta y al hilo de chat exclusivamente a los usuarios autenticados que pertenezcan a la misma clínica (`tenant_id` / `id_clinica`) y que mantengan la condición de paciente titular, médico tratante o administrador autorizado de dicho centro de salud.

#### Scenario: Intento de acceso cruzado entre clínicas (Cross-tenant)
- **GIVEN** que un usuario autenticado pertenece al inquilino A
- **WHEN** intenta acceder al recurso de teleconsulta o mensajes de una cita médica perteneciente al inquilino B
- **THEN** el backend responde con código HTTP `404 Not Found` (o `403 Forbidden`)
- **AND** ningún dato del paciente, especialista ni mensaje es divulgado

#### Scenario: Intento de participación por un usuario no vinculado a la cita
- **GIVEN** que un usuario pertenece a la misma clínica pero no es el paciente titular, el médico asignado ni administrador
- **WHEN** intenta enviar un mensaje al chat de la cita médica
- **THEN** el sistema rechaza la solicitud con código HTTP `403 Forbidden`

---

### Requirement: Adaptación y Consumo Móvil (Flutter)
The system SHALL proporcionar en la aplicación móvil Flutter una vista adaptada ("Mis citas") y una interfaz modal/flotante de chat ("ChatTeleconsultaScreen") consumiendo directamente los endpoints reales del backend sin datos simulados ni dependencias estáticas.

#### Scenario: Consulta de citas del paciente en cliente móvil
- **GIVEN** que el paciente inicia sesión en la aplicación móvil Flutter
- **WHEN** accede a la sección "Mis citas"
- **THEN** el sistema consulta `GET /citas` con el token JWT del paciente
- **AND** distribuye dinámicamente las citas en las pestañas "Próximas", "Lista de espera", "Pasadas" y "Canceladas" reflejando únicamente los registros reales de PostgreSQL

#### Scenario: Apertura de chat interactivo móvil desde la tarjeta de cita
- **GIVEN** que el paciente visualiza una cita confirmada en su lista móvil
- **WHEN** presiona el botón "Chatear"
- **THEN** se despliega el modal interactivo de teleconsulta con avatar del médico tratante, chip de fecha y hora, hilo de mensajes bidireccional y campo inferior de redacción con envío reactivo
