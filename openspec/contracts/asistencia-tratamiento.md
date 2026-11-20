# Contrato de API: Asistencia Inteligente de Tratamiento (CU18)

**Versión:** 1.0.0 (SaaS Multitenant)  
**Estándar:** OpenAPI 3.1 / RESTful JSON  
**Ruta Base:** `/api/v1/asistencia-tratamiento`  
**Seguridad Global:** `BearerAuth` (Header `Authorization: Bearer <JWT_ACCESS_TOKEN>`)  
**Módulo:** `ai_assistant` / `treatment_assistance`  
**Casos de Uso / HUs:** CU18, HU1-87..HU1-90, RF-25  

---

## 1. Convenciones Multitenant y Seguridad

1. **Resolución de Inquilino:** Se resuelve exclusivamente a través de `Usuario.id_clinica` (tipo `BIGINT`) del token de autenticación. No se acepta `tenant_id` ni `id_clinica` en los cuerpos de petición (*Prevention of Tenant Injection*).
2. **Control de Acceso (RBAC):**
   - Rol `PACIENTE`: Permiso `assistance:evaluate` para solicitar evaluaciones sobre su propio tratamiento y `assistance:read` para consultar su propio historial de evaluaciones. Intentos de acceder al historial de otro paciente en `/historial` devuelven `403 Forbidden`. En consulta de detalle de evaluación (`/evaluaciones/{id}`), si la evaluación no pertenece a su propio paciente, responde con `404 Not Found` (no revelar existencia).
   - Rol `MEDICO`: Permiso `assistance:read` para consultar en modo de solo lectura las evaluaciones de pacientes de su misma clínica que tengan al menos un tratamiento (tabla de CU17 `tratamientos`, `Tratamiento.id_medico` = perfil del médico autenticado) a su cargo. Paciente inexistente, de otra clínica o sin relación de tratamiento con ese médico responde con `404 Not Found` (no revelar existencia), tanto en el listado (`GET /historial`) como en el detalle (`GET /evaluaciones/{id}`).
   - Otros roles (`ADMIN`, `ADMINISTRADOR`, `SUPERADMIN`, `RECEPCION`, `RECEPCIONISTA`, `FARMACIA` y cualquier otro rol no asistencial): Responden con `403 Forbidden` en todos los endpoints del CU18.
   - El endpoint `POST /evaluar` es exclusivo del paciente (`assistance:evaluate`).
3. **Aislamiento Cruzado entre Clínicas:** Cualquier consulta hacia recursos o pacientes de otra clínica responde con `404 Not Found`.
4. **Principio RF-25:** La API expone sugerencias y alertas informativas y precautorias; bajo ninguna circunstancia modifica estados de prescripción, recetas, dosis ni diagnósticos.

---

## 2. Endpoints

| Método | Ruta | Permiso Requerido | Descripción | Códigos HTTP |
|---|---|---|---|---|
| `POST` | `/api/v1/asistencia-tratamiento/evaluar` | `assistance:evaluate` | Solicita evaluación bajo demanda del tratamiento vigente del paciente | `200`, `401`, `403`, `429` |
| `GET` | `/api/v1/asistencia-tratamiento/historial` | `assistance:read` | Lista el historial paginado de evaluaciones del paciente | `200`, `400`, `401`, `403`, `404` |
| `GET` | `/api/v1/asistencia-tratamiento/evaluaciones/{id}` | `assistance:read` | Obtiene el detalle completo de una evaluación previa | `200`, `401`, `403`, `404` |
| `GET` | `/api/v1/asistencia-tratamiento/interacciones/catalogo` | `assistance:read` | Consulta referencial paginada del catálogo de interacciones | `200`, `401`, `403` |

---

## 3. Esquemas de Petición y Respuesta

### 3.1 `POST /api/v1/asistencia-tratamiento/evaluar`

#### Request Body (Opcional)
```json
{
  "forzar_recalculo": false
}
```

#### Response Body (`200 OK` - Escenario 3C: Interacción Grave Detectada)
```json
{
  "id_evaluacion": 105,
  "id_paciente": 32,
  "fecha_evaluacion": "2026-11-04T08:30:00Z",
  "estado_evaluacion": "COMPLETADA",
  "nivel_riesgo_global": "ALTO",
  "total_medicamentos_analizados": 2,
  "total_alertas_detectadas": 1,
  "resumen_ejecutivo": "Se detectó 1 interacción farmacológica relevante entre los medicamentos prescritos.",
  "medicamentos_analizados": [
    {
      "id_medicamento": 5,
      "nombre": "Ibuprofeno 400 mg",
      "principio_activo": "ibuprofeno",
      "dosis": "400 mg",
      "frecuencia": "Cada 8 horas",
      "via_administracion": "ORAL"
    },
    {
      "id_medicamento": 8,
      "nombre": "Aspirina 100 mg",
      "principio_activo": "acido acetilsalicilico",
      "dosis": "100 mg",
      "frecuencia": "Cada 24 horas",
      "via_administracion": "ORAL"
    }
  ],
  "alertas": [
    {
      "id_alerta": 201,
      "principio_activo_1": "acido acetilsalicilico",
      "principio_activo_2": "ibuprofeno",
      "medicamento_1_nombre": "Aspirina 100 mg",
      "medicamento_2_nombre": "Ibuprofeno 400 mg",
      "severidad": "GRAVE",
      "color_alerta": "ROJO",
      "mensaje_alerta": "Riesgo de interacción: aumento de riesgo de sangrado",
      "pauta_precaucion": "El uso simultáneo incrementa significativamente el riesgo de hemorragia gastrointestinal y disminuye el efecto cardioprotector del ácido acetilsalicílico. Consulte a su médico antes de continuar la toma combinada."
    }
  ],
  "recomendaciones": [
    {
      "id_recomendacion": 301,
      "categoria": "ESTILO_VIDA",
      "titulo": "Monitoreo tensional y pauta por hipertensión",
      "detalle": "Dado su diagnóstico de hipertensión arterial, evite el uso continuo de AINEs sin control estricto de su presión arterial.",
      "origen": "IA_GENERATIVA"
    },
    {
      "id_recomendacion": 302,
      "categoria": "SIGNOS_ALARMA",
      "titulo": "Signos de alarma gastrointestinal",
      "detalle": "Ante la presencia de heces oscuras, dolor urente en el estómago o mareos repentinos, acuda de inmediato al servicio de urgencias.",
      "origen": "IA_GENERATIVA"
    },
    {
      "id_recomendacion": 303,
      "categoria": "HORARIO_ADMINISTRACION",
      "titulo": "Pauta de administración con alimentos",
      "detalle": "Ingiera sus fármacos acompañados de alimentos o un protector gástrico si su médico lo ha indicado previamente.",
      "origen": "IA_GENERATIVA"
    }
  ],
  "aviso_legal": "Esta evaluación constituye una orientación informativa y de apoyo al paciente. Bajo ninguna circunstancia sustituye el criterio médico profesional ni autoriza la suspensión, aumento o modificación de las dosis prescritas por su médico tratante (RF-25)."
}
```

#### Response Body (`200 OK` - Escenario Criterio 5: Sin Interacciones Detectadas)
```json
{
  "id_evaluacion": 106,
  "id_paciente": 33,
  "fecha_evaluacion": "2026-11-04T08:35:00Z",
  "estado_evaluacion": "COMPLETADA",
  "nivel_riesgo_global": "SIN_RIESGO",
  "total_medicamentos_analizados": 1,
  "total_alertas_detectadas": 0,
  "resumen_ejecutivo": "No se detectaron interacciones adversas entre sus medicamentos vigentes.",
  "medicamentos_analizados": [
    {
      "id_medicamento": 12,
      "nombre": "Paracetamol 500 mg",
      "principio_activo": "paracetamol",
      "dosis": "500 mg",
      "frecuencia": "Cada 8 horas",
      "via_administracion": "ORAL"
    }
  ],
  "alertas": [],
  "recomendaciones": [
    {
      "id_recomendacion": 304,
      "categoria": "PRECAUCION_GENERAL",
      "titulo": "Pauta general de adherencia terapéutica",
      "detalle": "Mantenga los horarios indicados en su receta y recuerde hidratarse adecuadamente.",
      "origen": "IA_GENERATIVA"
    }
  ],
  "aviso_legal": "Esta evaluación constituye una orientación informativa y de apoyo al paciente. Bajo ninguna circunstancia sustituye el criterio médico profesional ni autoriza la suspensión, aumento o modificación de las dosis prescritas por su médico tratante (RF-25)."
}
```

#### Response Body (`200 OK` - Escenario Paciente sin Tratamiento Activo)
```json
{
  "id_evaluacion": null,
  "id_paciente": 34,
  "fecha_evaluacion": "2026-11-04T08:40:00Z",
  "estado_evaluacion": "SIN_TRATAMIENTO_VIGENTE",
  "nivel_riesgo_global": "SIN_RIESGO",
  "total_medicamentos_analizados": 0,
  "total_alertas_detectadas": 0,
  "resumen_ejecutivo": "No se encontraron recetas ni medicamentos activos vigentes registrados en la clínica.",
  "medicamentos_analizados": [],
  "alertas": [],
  "recomendaciones": [],
  "aviso_legal": "Esta evaluación constituye una orientación informativa y de apoyo al paciente. Bajo ninguna circunstancia sustituye el criterio médico profesional ni autoriza la suspensión, aumento o modificación de las dosis prescritas por su médico tratante (RF-25)."
}
```

#### Response Body (`200 OK` - Escenario Degradación Elegante por Fallo de IA)
```json
{
  "id_evaluacion": 107,
  "id_paciente": 32,
  "fecha_evaluacion": "2026-11-04T08:45:00Z",
  "estado_evaluacion": "DEGRADADO_REGLAS_BASE",
  "nivel_riesgo_global": "ALTO",
  "total_medicamentos_analizados": 2,
  "total_alertas_detectadas": 1,
  "resumen_ejecutivo": "Se detectó 1 interacción farmacológica relevante entre los medicamentos prescritos.",
  "medicamentos_analizados": [
    {
      "id_medicamento": 5,
      "nombre": "Ibuprofeno 400 mg",
      "principio_activo": "ibuprofeno",
      "dosis": "400 mg",
      "frecuencia": "Cada 8 horas",
      "via_administracion": "ORAL"
    },
    {
      "id_medicamento": 8,
      "nombre": "Aspirina 100 mg",
      "principio_activo": "acido acetilsalicilico",
      "dosis": "100 mg",
      "frecuencia": "Cada 24 horas",
      "via_administracion": "ORAL"
    }
  ],
  "alertas": [
    {
      "id_alerta": 202,
      "principio_activo_1": "acido acetilsalicilico",
      "principio_activo_2": "ibuprofeno",
      "medicamento_1_nombre": "Aspirina 100 mg",
      "medicamento_2_nombre": "Ibuprofeno 400 mg",
      "severidad": "GRAVE",
      "color_alerta": "ROJO",
      "mensaje_alerta": "Riesgo de interacción: aumento de riesgo de sangrado",
      "pauta_precaucion": "El uso simultáneo incrementa significativamente el riesgo de hemorragia gastrointestinal y disminuye el efecto cardioprotector del ácido acetilsalicílico. Consulte a su médico antes de continuar la toma combinada."
    }
  ],
  "recomendaciones": [
    {
      "id_recomendacion": 305,
      "categoria": "PRECAUCION_GENERAL",
      "titulo": "Pauta de seguridad clínica base",
      "detalle": "Siga rigurosamente las dosis y horarios prescritos por su médico. Ante cualquier malestar inusual o síntoma adverso, suspenda la automedicación y acuda a consulta.",
      "origen": "REGLA_PREDEFINIDA"
    }
  ],
  "aviso_legal": "Esta evaluación constituye una orientación informativa y de apoyo al paciente. Bajo ninguna circunstancia sustituye el criterio médico profesional ni autoriza la suspensión, aumento o modificación de las dosis prescritas por su médico tratante (RF-25)."
}
```

---

### 3.2 `GET /api/v1/asistencia-tratamiento/historial`

#### Parámetros Query
- `page`: int >= 1 (default 1)
- `limit`: int 1..50 (default 10)
- `id_paciente`: int opcional (requerido para rol `MEDICO`, ignorado para `PACIENTE`)

#### Response Body (`200 OK`)
```json
{
  "items": [
    {
      "id_evaluacion": 105,
      "id_paciente": 32,
      "fecha_evaluacion": "2026-11-04T08:30:00Z",
      "estado_evaluacion": "COMPLETADA",
      "nivel_riesgo_global": "ALTO",
      "total_medicamentos_analizados": 2,
      "total_alertas_detectadas": 1,
      "resumen_ejecutivo": "Se detectó 1 interacción farmacológica relevante."
    }
  ],
  "total": 1,
  "page": 1,
  "limit": 10,
  "total_paginas": 1
}
```

---

### 3.3 `GET /api/v1/asistencia-tratamiento/evaluaciones/{id}`

- Devuelve el esquema completo idéntico al response de `POST /evaluar`.
- Si `id` no pertenece al paciente, a un paciente con tratamiento a cargo del médico autenticado o a la clínica activa, devuelve `404 Not Found` (no revelar existencia).

---

### 3.4 `GET /api/v1/asistencia-tratamiento/interacciones/catalogo`

#### Parámetros Query
- `principio_activo`: string opcional
- `severidad`: string opcional (`LEVE`, `MODERADA`, `GRAVE`)
- `page`: int >= 1 (default 1)
- `limit`: int 1..100 (default 20)

---

## 4. Códigos de Error Semánticos

| Código HTTP | Error Code | Descripción |
|---|---|---|
| `400 Bad Request` | `PATIENT_ID_REQUIRED` | El médico no proporcionó el parámetro obligatorio id_paciente |
| `401 Unauthorized` | `AUTHENTICATION_REQUIRED` | Token JWT ausente, inválido o expirado |
| `403 Forbidden` | `PERMISSION_DENIED` | Usuario carece de permisos `assistance:*`, paciente intenta acceder al expediente de otro paciente, o rol administrativo/no asistencial intenta acceder al servicio |
| `404 Not Found` | `EVALUATION_NOT_FOUND` | La evaluación solicitada no existe o no pertenece al paciente/médico autorizado |
| `404 Not Found` | `PATIENT_NOT_FOUND` | El paciente no existe, pertenece a otra clínica o no tiene un tratamiento a cargo del médico autenticado |
| `429 Too Many Requests`| `RATE_LIMIT_EXCEEDED` | Límite de 10 evaluaciones por hora excedido para el paciente. Incluye cabecera HTTP `Retry-After` con los segundos de espera recomendados (ej. `3600`). |
| `422 Unprocessable` | `VALIDATION_ERROR` | Error en validación de parámetros de entrada |
