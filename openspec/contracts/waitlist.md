# Contrato de API REST: Lista de Espera (CU07)

**Versión del Contrato:** 1.0.0 (SaaS Multitenant)
**Estándar:** OpenAPI 3.1 / RESTful JSON
**Rutas Base:** `/lista-espera` y `/api/v1/lista-espera` (web y móvil consumen `/api/v1/lista-espera`)
**Seguridad Global:** `BearerAuth` (`Authorization: Bearer <JWT_ACCESS_TOKEN>`)
**Encabezado Multitenant:** `X-Tenant-ID: <id_clinica>`
**Dominio:** `appointments` / `lista_espera`
**Roles:** PACIENTE (solo lo propio), MEDICO, RECEPCION y ADMIN (su clínica).

---

## 1. Convenciones Multitenant y Seguridad

- **Tenant obligatorio:** `get_required_tenant_id`; toda consulta filtra `ListaEspera.id_clinica == tenant`.
- **Aislamiento:** recurso de otra clínica → `404 Not Found`; paciente que intenta operar una inscripción ajena → `404`; rol indebido → `403`.
- **Permisos:** `waitlist:read` (consultas) y `waitlist:write` (inscripción, salida, confirmación, rechazo, ofrecimiento).
- **Códigos:** `200 OK`, `201 Created`, `400` payload inválido, `403` rol indebido, `404` recurso ajeno/inexistente, `409` inscripción duplicada, `422` validación.

---

## 2. Esquemas de Datos

### 2.1 `InscripcionEsperaDTO`

```json
{
  "idListaEspera": 10,
  "idPaciente": 4,
  "pacienteNombre": "Ana Pérez",
  "idMedico": 3,
  "medicoNombre": "Roberto Gómez Flores",
  "idEspecialidad": 2,
  "especialidadNombre": "Cardiología",
  "fechaDeseada": "2026-12-01",
  "estado": "EN_ESPERA",
  "prioridad": 0,
  "posicion": 1,
  "motivo": "Sin cupos en la fecha",
  "idCitaOfrecida": null,
  "fechaCreacion": "2026-11-20T10:15:00"
}
```

### 2.2 `ListaEsperaPageDTO`

```json
{ "total": 1, "page": 1, "pageSize": 50, "items": [ /* InscripcionEsperaDTO */ ] }
```

### 2.3 `InscripcionEsperaCommand`

```json
{
  "id_paciente": 4,
  "id_medico": 3,
  "id_especialidad": 2,
  "fecha_deseada": "2026-12-01",
  "prioridad": 0,
  "motivo": "Sin cupos en la fecha"
}
```

- Paciente: `id_paciente` se ignora y se resuelve de la sesión.
- Staff: `id_paciente` es obligatorio.
- `id_medico` o `id_especialidad`: al menos uno.

### 2.4 `OfrecerTurnoCommand`

```json
{ "fecha": "2026-12-01", "hora_inicio": "09:00", "hora_fin": "09:30" }
```

`hora_fin` es opcional; si falta se calcula con la duración del servicio o 20 minutos.

---

## 3. Endpoints

### 3.1 Inscribirse

* **Ruta:** `POST /api/v1/lista-espera`
* **Roles:** PACIENTE, RECEPCION, ADMIN
* **Payload:** `InscripcionEsperaCommand`
* **Respuestas:** `201 Created` → `InscripcionEsperaDTO` · `400` · `403` · `404` médico/especialidad ajena · `409` inscripción activa duplicada · `422`.

### 3.2 Listar inscripciones

* **Ruta:** `GET /api/v1/lista-espera?estado=&id_medico=&id_especialidad=&fecha_deseada=&page=1&page_size=50`
* **Roles:** PACIENTE (solo propias), MEDICO/RECEPCION/ADMIN (tenant).
* **Respuestas:** `200 OK` → `ListaEsperaPageDTO`.

### 3.3 Mis inscripciones con posición

* **Ruta:** `GET /api/v1/lista-espera/mi-espera`
* **Roles:** PACIENTE
* **Respuestas:** `200 OK` → `InscripcionEsperaDTO[]` (incluye `posicion`).

### 3.4 Salir de la lista

* **Ruta:** `DELETE /api/v1/lista-espera/{id}`
* **Roles:** PACIENTE (propia), MEDICO/RECEPCION/ADMIN (tenant).
* **Efecto:** estado → `CANCELADO`; si estaba `OFRECIDO`, cancela la cita ofrecida y ofrece el cupo al siguiente.
* **Respuestas:** `200 OK` → `InscripcionEsperaDTO` · `404` · `403`.

### 3.5 Confirmar turno ofrecido

* **Ruta:** `POST /api/v1/lista-espera/{id}/confirmar`
* **Roles:** PACIENTE (propia), MEDICO/RECEPCION/ADMIN (tenant).
* **Efecto:** cita ofrecida → `CONFIRMADA`; inscripción → `CONFIRMADO`.
* **Respuestas:** `200 OK` → `InscripcionEsperaDTO` · `404` · `409` si no está `OFRECIDO`.

### 3.6 Rechazar turno ofrecido

* **Ruta:** `POST /api/v1/lista-espera/{id}/rechazar`
* **Roles:** PACIENTE (propia), MEDICO/RECEPCION/ADMIN (tenant).
* **Efecto:** cita ofrecida → `CANCELADA`; inscripción → `RECHAZADO`; el cupo se ofrece al siguiente candidato.
* **Respuestas:** `200 OK` → `InscripcionEsperaDTO` · `404` · `409` si no está `OFRECIDO`.

### 3.7 Ofrecer turno manualmente (staff)

* **Ruta:** `POST /api/v1/lista-espera/{id}/ofrecer`
* **Roles:** MEDICO, RECEPCION, ADMIN
* **Payload:** `OfrecerTurnoCommand`
* **Efecto:** crea una cita `PENDIENTE` para la inscripción y la marca `OFRECIDO`, con notificación.
* **Respuestas:** `200 OK` → `InscripcionEsperaDTO` · `400` franja inválida · `404` · `409` cupo ocupado o inscripción no elegible.

---

## 4. Notificaciones

| Campo | Valor |
|---|---|
| `tipo` | `TURNO_REASIGNADO` |
| `canal` | `PUSH` |
| `titulo` | `Turno disponible` |
| `mensaje` | `Se liberó un turno con {médico} el {fecha} a las {hora}. Confirma o rechaza en tu lista de espera.` |
| `estado` | `PENDIENTE` |

El push FCM es best-effort: si el proveedor no está configurado o falla, la notificación en base de datos y la reasignación se mantienen.
