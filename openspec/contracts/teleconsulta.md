# Contrato de API REST: Teleconsulta y Chat de Cita Médica (CU15)

**Versión del Contrato:** 1.0.0 (SaaS Multitenant)  
**Estándar:** OpenAPI 3.1 / RESTful JSON  
**Rutas Base:** `/api/v1/citas`  
**Seguridad Global:** `BearerAuth` (Header `Authorization: Bearer <JWT_ACCESS_TOKEN>`)  
**Encabezado Multitenant:** `X-Tenant-ID: <UUID>`  
**Dominio:** `communications` / `teleconsulta`  

---

## 1. Convenciones Multitenant y Seguridad

- **Aislamiento de Citas y Mensajes:** Todas las consultas y mutaciones de chat se encuentran estrictamente acotadas al inquilino (`id_clinica` / `tenant_id`). Acceso a registros ajenos responde con `404 Not Found` o `403 Forbidden`.
- **Control de Acceso y Participación:** Solo los usuarios debidamente autorizados (el paciente titular de la cita, el médico asignado a la cita o un administrador del tenant) pueden consultar el hilo o enviar mensajes a la cita médica.
- **Formato Semántico de Respuestas:** `200 OK` para consultas, `201 Created` para mensajes enviados, `400 Bad Request` para mensajes inválidos, `403 Forbidden` para accesos no autorizados y `404 Not Found` para citas inexistentes.

---

## 2. Esquemas de Datos (Data Schemas)

### 2.1 `PatientSummaryDTO`
```json
{
  "idPaciente": 10,
  "nombreCompleto": "Carlos Pérez",
  "identificacionId": "12345678X",
  "inicialesAvatar": "CP",
  "seguroProveedor": "Sanitas Plus",
  "seguroPoliza": "Sanitas Plus"
}
```

---

### 2.2 `AppointmentDetailsDTO`
```json
{
  "idCita": 105,
  "nombreMedico": "Dra. Ana López",
  "especialidad": "Medicina General",
  "rangoFechas": "02/09/2024 - 01/02/2024",
  "horaTeleconsulta": "17:00 h",
  "modalidad": "TELEMEDICINA",
  "estado": "CONFIRMADA"
}
```

---

### 2.3 `DoctorProfileSummaryDTO`
```json
{
  "idMedico": 42,
  "nombreCompleto": "Dra. Ana López",
  "cargoEtiqueta": "Su Médico",
  "biografia": "Dra. Ana López es especialista en medicina general, con trayectoria en atención ambulatoria, medicina preventiva y seguimiento clínico personalizado.",
  "fotoUrl": "https://images.unsplash.com/photo-1559839734-2b71ea197ec2?auto=format&fit=crop&q=80&w=400",
  "estadoDisponibilidad": "DISPONIBLE"
}
```

---

### 2.4 `ChatMessageDTO`
```json
{
  "idMensaje": 1,
  "idRemitente": 42,
  "nombreRemitente": "Dra. López",
  "rolRemitente": "MEDICO",
  "contenido": "Hola Carlos, estoy revisando su historial. ¿Tiene alguna pregunta antes de empezar?",
  "horaDisplay": "17:00 h",
  "avatarUrl": "https://images.unsplash.com/photo-1559839734-2b71ea197ec2?auto=format&fit=crop&q=80&w=120",
  "esPropio": false,
  "leido": true
}
```

---

### 2.5 `SendChatMessageCommand`
```json
{
  "idCita": 105,
  "contenido": "¿Tengo que mantener el ayuno antes de la prueba?"
}
```

---

### 2.6 `TeleconsultaViewDTO`
```json
{
  "nombreClinica": "Hospital San Juan de Dios",
  "usuarioActivo": {
    "idUsuario": 24,
    "nombre": "carlos perez",
    "iniciales": "CP"
  },
  "paciente": {
    "idPaciente": 10,
    "nombreCompleto": "Carlos Pérez",
    "identificacionId": "12345678X",
    "inicialesAvatar": "CP",
    "seguroProveedor": "Sanitas Plus",
    "seguroPoliza": "Sanitas Plus"
  },
  "cita": {
    "idCita": 105,
    "nombreMedico": "Dra. Ana López",
    "especialidad": "Medicina General",
    "rangoFechas": "02/09/2024 - 01/02/2024",
    "horaTeleconsulta": "17:00 h",
    "modalidad": "TELEMEDICINA",
    "estado": "CONFIRMADA"
  },
  "medico": {
    "idMedico": 42,
    "nombreCompleto": "Dra. Ana López",
    "cargoEtiqueta": "Su Médico",
    "biografia": "Dra. Ana López es especialista en medicina general, con trayectoria en atención ambulatoria, medicina preventiva y seguimiento clínico personalizado.",
    "fotoUrl": "https://images.unsplash.com/photo-1559839734-2b71ea197ec2?auto=format&fit=crop&q=80&w=400",
    "estadoDisponibilidad": "DISPONIBLE"
  },
  "mensajes": []
}
```

---

## 3. Endpoints de la API REST

### 3.1 Obtener Vista y Estado de Teleconsulta
* **Ruta:** `GET /api/v1/citas/{id_cita}/teleconsulta`
* **Descripción:** Retorna el contexto unificado de la teleconsulta para la cita médica especificada.
* **Seguridad:** `BearerAuth` (JWT) + Inyección de Tenant.
* **Respuestas:**
  * `200 OK`: `TeleconsultaViewDTO`
  * `403 Forbidden`: El usuario no es participante ni administrador.
  * `404 Not Found`: La cita no existe o pertenece a otro inquilino.

### 3.2 Enviar Mensaje al Chat de la Cita
* **Ruta:** `POST /api/v1/citas/{id_cita}/chat/mensajes`
* **Descripción:** Persiste un nuevo mensaje en la cita médica con autoría asociada al usuario autenticado.
* **Payload:** `SendChatMessageCommand`
* **Respuestas:**
  * `201 Created`: `ChatMessageDTO`
  * `400 Bad Request`: Contenido vacío o cita no apta para mensajería.
  * `403 Forbidden`: No autorizado para participar en la cita.
