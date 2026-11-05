# Contrato de API REST: Fila Virtual y Tiempos de Espera — Live Queue (CU08)

**Versión del Contrato:** 1.0.0 (SaaS Multitenant)
**Estándar:** OpenAPI 3.1 / RESTful JSON
**Rutas Base:** `/cola` y `/api/v1/cola` (web y móvil consumen `/api/v1/cola`)
**Seguridad Global:** `BearerAuth` (Header `Authorization: Bearer <JWT_ACCESS_TOKEN>`)
**Encabezado Multitenant:** `X-Tenant-ID: <id_clinica>`
**Dominio:** `appointments` / `live_queue`
**Roles:** PACIENTE (mi-turno), MEDICO / RECEPCION (operativa y acciones). ADMIN de clínica → `403`.

---

## 1. Convenciones Multitenant y Seguridad

- **Tenant obligatorio:** `get_required_tenant_id` + scope por clínica del médico (`join` a usuarios). `Cita.id_clinica NULL` legado se tolera si el médico es del tenant.
- **Aislamiento:** cita/cola de otra clínica → `404 Not Found`; paciente que pide turno ajeno → `404`; rol indebido → `403`.
- **Privacidad:** `mi-turno` no contiene datos de terceros; la operativa no expone motivo, notas ni datos clínicos.
- **Códigos:** `200 OK` consultas, `201 Created` pausas, `400` payload inválido, `403` rol indebido, `404` recurso ajeno/inexistente, `422` recepcionista sin `id_medico`.

---

## 2. Esquemas de Datos (Data Schemas)

### 2.1 `MiTurnoDTO`
```json
{
  "idCita": 12,
  "hora": "09:20",
  "estado": "PENDIENTE",
  "posicion": 2,
  "etaMinutos": 20,
  "delante": 1,
  "proximo": true,
  "estadoCola": "NORMAL",
  "mensajeCola": null,
  "medicoNombre": "Roberto Gómez Flores",
  "fecha": "2026-10-04"
}
```
Sin cita pendiente hoy: `{ "idCita": 0, "posicion": 0, "etaMinutos": 0, "delante": 0, "proximo": false, "estadoCola": "SIN_TURNOS", "mensajeCola": "No tienes turnos pendientes hoy.", ... }`.

### 2.2 `ColaOperativaDTO`
```json
{
  "idMedico": 3,
  "medicoNombre": "Roberto Gómez Flores",
  "fecha": "2026-10-04",
  "estadoCola": "PAUSADA",
  "mensajeCola": "Atención pausada hasta las 10:15 por Desinfección de consultorio",
  "duracionPromedioMin": 20,
  "totalPendientes": 3,
  "entradas": [
    { "idCita": 11, "hora": "09:00", "estado": "EN_CURSO", "posicion": 1, "etaMinutos": 0, "pacienteNombre": "Ana Pérez", "checkIn": null }
  ]
}
```

### 2.3 `RegistrarPausaCommand`
```json
{ "idMedico": 3, "fecha": "2026-10-04", "horaInicio": "10:00", "horaFin": "10:15", "motivo": "Desinfección de consultorio" }
```

---

## 3. Endpoints de la API REST

### 3.1 Mi turno (paciente)
* **Ruta:** `GET /api/v1/cola/mi-turno`
* **Seguridad:** rol PACIENTE; la cita debe pertenecer a su `id_paciente`.
* **Respuestas:** `200 OK`: `MiTurnoDTO` · `404`: sin cita hoy / cita ajena / clínica ajena.

### 3.2 Cola operativa (staff)
* **Ruta:** `GET /api/v1/cola?fecha=YYYY-MM-DD&id_medico=N`
* **Seguridad:** MEDICO (solo su médico) / RECEPCION (`id_medico` obligatorio).
* **Respuestas:** `200 OK`: `ColaOperativaDTO` · `403`: rol indebido o médico ajeno · `422`: sin `id_medico` (recepción).

### 3.3 Avanzar la fila (staff)
* **Ruta:** `POST /api/v1/cola/{id_cita}/avanzar`
* **Efecto:** cita → `ATENDIDA` (+ `check_in` si faltaba); siguiente pendiente → `EN_CURSO`; crea `Notificacion TURNO_PROXIMO` a pacientes en posición 1–2 con usuario vinculado.
* **Respuestas:** `200 OK`: `ColaOperativaDTO` actualizada · `403`/`404` según §1.

### 3.4 Marcar turno perdido (staff)
* **Ruta:** `POST /api/v1/cola/{id_cita}/perdida`
* **Efecto:** cita → `PERDIDA` y mismo avance/notificación que 3.3.
* **Respuestas:** `200 OK`: `ColaOperativaDTO` · `403`/`404` según §1.

### 3.5 Registrar pausa (staff)
* **Ruta:** `POST /api/v1/cola/pausas`
* **Payload:** `RegistrarPausaCommand`. **Efecto:** `201 Created` con `BloqueoAgenda` (`estado=APROBADO`).
* **Respuestas:** `201 Created` · `400`: franja inválida · `403`/`404` según §1.
