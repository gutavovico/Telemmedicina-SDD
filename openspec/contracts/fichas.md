# Contrato de API REST: Fichas Clínicas (CU09 - Gestionar Fichas Médicas y Expediente Clínico Dinámico)

**Versión del Contrato:** 1.0.0 (SaaS Multitenant)  
**Estándar:** OpenAPI 3.1 / RESTful JSON  
**Ruta Base Canónica:** `/medical-records/fichas` (Alias: `/fichas`)  
**Seguridad Global:** `BearerAuth` (`Authorization: Bearer <JWT_ACCESS_TOKEN>`)  
**Encabezado Multitenant:** `X-Tenant-ID: <UUID|INT>`  
**Dominio:** `medical_records` / `fichas`  

---

## 1. Endpoints

### 1.1 `POST /medical-records/fichas`
Emisión de una nueva ficha clínica con validación atómica de turno y generación de correlativo único.

**Request Body (`FichaCreateRequest`):**
```json
{
  "id_paciente": 2,
  "id_medico": 1,
  "id_servicio": 1,
  "id_especialidad": 1,
  "fecha_atencion": "2026-09-10",
  "hora_inicio": "09:00",
  "hora_fin": "09:30",
  "motivo_consulta": "Consulta periódica de cardiología",
  "signos_vitales": {
    "presion_arterial": "120/80",
    "frecuencia_cardiaca": 75,
    "temperatura": 36.5,
    "peso_kg": 72.0
  },
  "secciones_dinamicas": {}
}
```

**Respuestas:**
- `201 Created`:
  ```json
  {
    "id_ficha": "e1f2a3b4-5678-90ab-cdef-1234567890ab",
    "id_clinica": 1,
    "correlativo": "FICH-20260910-0001",
    "id_paciente": 2,
    "paciente_nombre": "Juan Perez",
    "id_medico": 1,
    "medico_nombre": "Dr. Carlos Ramos",
    "id_servicio": 1,
    "id_especialidad": 1,
    "especialidad_nombre": "Cardiología",
    "fecha_atencion": "2026-09-10",
    "hora_inicio": "09:00",
    "hora_fin": "09:30",
    "motivo_consulta": "Consulta periódica de cardiología",
    "signos_vitales": {
      "presion_arterial": "120/80",
      "frecuencia_cardiaca": 75,
      "temperatura": 36.5,
      "peso_kg": 72.0
    },
    "secciones_dinamicas": {},
    "codigo_cie10": null,
    "diagnostico_descripcion": null,
    "notas_evolucion": null,
    "estado": "EMITIDA",
    "created_at": "2026-09-10T09:00:00Z",
    "updated_at": "2026-09-10T09:00:00Z"
  }
  ```
- `400 Bad Request`: Datos de solicitud inválidos.
- `401 Unauthorized`: Token ausente o inválido.
- `403 Forbidden`: Sin permisos para emitir ficha.
- `409 Conflict`: `{"detail": "El turno seleccionado ya se encuentra ocupado por otra ficha médica o cita clínica"}`.

### 1.2 `GET /medical-records/fichas`
Listado paginado y filtrable de fichas del tenant actual.

**Query Parameters:**
- `id_paciente`: int (opcional)
- `id_medico`: int (opcional)
- `id_especialidad`: int (opcional)
- `fecha`: string `YYYY-MM-DD` (opcional)
- `estado`: string (opcional, ej. `EMITIDA`, `EN_ATENCION`, `FINALIZADA`, `CANCELADA`)
- `skip`: int (default: 0)
- `limit`: int (default: 50)

**Respuestas:**
- `200 OK`:
  ```json
  {
    "total": 1,
    "items": [
      {
        "id_ficha": "e1f2a3b4-5678-90ab-cdef-1234567890ab",
        "id_clinica": 1,
        "correlativo": "FICH-20260910-0001",
        "id_paciente": 2,
        "paciente_nombre": "Juan Perez",
        "id_medico": 1,
        "medico_nombre": "Dr. Carlos Ramos",
        "id_especialidad": 1,
        "especialidad_nombre": "Cardiología",
        "fecha_atencion": "2026-09-10",
        "hora_inicio": "09:00",
        "hora_fin": "09:30",
        "motivo_consulta": "Consulta periódica de cardiología",
        "estado": "EMITIDA",
        "created_at": "2026-09-10T09:00:00Z"
      }
    ]
  }
  ```

### 1.3 `GET /medical-records/fichas/{id}`
Detalle completo de una ficha médica con sus esquemas dinámicos JSONB.

**Respuestas:**
- `200 OK`: Objeto `FichaResponse`.
- `404 Not Found`: Ficha no encontrada en el tenant.

### 1.4 `PATCH /medical-records/fichas/{id}/clinica`
Actualización médica exclusiva de signos vitales, secciones dinámicas JSONB, diagnósticos CIE-10 y notas de evolución.

**Request Body (`FichaClinicaUpdateRequest`):**
```json
{
  "signos_vitales": {
    "presion_arterial": "130/85",
    "frecuencia_cardiaca": 80,
    "temperatura": 36.8,
    "peso_kg": 72.5
  },
  "secciones_dinamicas": {
    "tipo_plantilla": "CARDIOLOGIA",
    "auscultacion": "Ruidos normales sin soplos"
  },
  "codigo_cie10": "I10",
  "diagnostico_descripcion": "Hipertensión esencial",
  "notas_evolucion": "Tratamiento continuado con ajuste de medicación.",
  "estado": "FINALIZADA"
}
```

**Respuestas:**
- `200 OK`: Objeto `FichaResponse` actualizado.
- `400 Bad Request`: Intento de modificar ficha ya finalizada o cancelada.
- `404 Not Found`: Ficha no encontrada.

### 1.5 `POST /medical-records/fichas/{id}/cancelar`
Cancelación de una ficha médica con registro de motivo.

**Request Body:**
```json
{
  "motivo_cancelacion": "Paciente solicita postergación por fuerza mayor"
}
```

**Respuestas:**
- `200 OK`: Objeto `FichaResponse` con `estado: CANCELADA`.
- `400 Bad Request`: No se puede cancelar una ficha `FINALIZADA`.
