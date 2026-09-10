# Design Document: CU09 – Gestionar Fichas Médicas y Expediente Clínico Dinámico

## 1. Modelo de Datos Relacional y Multitenant

### Tabla: `fichas_clinicas`
Almacena el registro principal de fichas médicas emitidas, su correlativo auditable, la referencia al paciente, médico, especialidad y turno, así como los bloques JSONB dinámicos y la resolución clínica (CIE-10).

```sql
CREATE TABLE fichas_clinicas (
    id_ficha VARCHAR(36) PRIMARY KEY, -- UUID v4
    id_clinica BIGINT NOT NULL REFERENCES clinicas(id_clinica) ON DELETE RESTRICT,
    correlativo VARCHAR(50) NOT NULL, -- Ej: FICH-20260910-0001
    id_paciente BIGINT NOT NULL REFERENCES pacientes(id_paciente) ON DELETE RESTRICT,
    id_medico BIGINT NOT NULL REFERENCES medicos(id_medico) ON DELETE RESTRICT,
    id_servicio BIGINT NULL REFERENCES servicios_medicos(id_servicio) ON DELETE SET NULL,
    id_especialidad BIGINT NULL REFERENCES especialidades(id_especialidad) ON DELETE SET NULL,
    id_cita BIGINT NULL REFERENCES citas(id_cita) ON DELETE SET NULL,
    
    fecha_emision TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    fecha_atencion DATE NOT NULL,
    hora_inicio VARCHAR(10) NOT NULL, -- HH:MM
    hora_fin VARCHAR(10) NOT NULL,    -- HH:MM
    
    motivo_consulta TEXT NOT NULL,
    signos_vitales JSONB DEFAULT '{}'::jsonb,
    secciones_dinamicas JSONB DEFAULT '{}'::jsonb,
    
    codigo_cie10 VARCHAR(30) NULL,
    diagnostico_descripcion TEXT NULL,
    id_diagnostico BIGINT NULL REFERENCES diagnosticos(id_diagnostico) ON DELETE SET NULL,
    notas_evolucion TEXT NULL,
    
    estado VARCHAR(30) DEFAULT 'EMITIDA' NOT NULL, -- EMITIDA, EN_ATENCION, FINALIZADA, CANCELADA
    motivo_cancelacion TEXT NULL,
    
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    
    CONSTRAINT uq_fichas_clinica_correlativo UNIQUE (id_clinica, correlativo),
    CONSTRAINT uq_fichas_medico_slot UNIQUE (id_clinica, id_medico, fecha_atencion, hora_inicio)
);

CREATE INDEX idx_fichas_clinica_paciente ON fichas_clinicas(id_clinica, id_paciente);
CREATE INDEX idx_fichas_clinica_medico ON fichas_clinicas(id_clinica, id_medico, fecha_atencion);
CREATE INDEX idx_fichas_clinica_estado ON fichas_clinicas(id_clinica, estado);
```

### Estructura de Secciones Dinámicas JSONB por Especialidad

#### 1. Signos Vitales (`signos_vitales`)
```json
{
  "presion_arterial": "120/80",
  "frecuencia_cardiaca": 75,
  "frecuencia_respiratoria": 18,
  "temperatura": 36.6,
  "saturacion_oxigeno": 98,
  "peso_kg": 70.5,
  "talla_cm": 172.0,
  "imc": 23.8
}
```

#### 2. Secciones Dinámicas (`secciones_dinamicas`)
- **Medicina General / Familiar:**
  ```json
  {
    "tipo_plantilla": "MEDICINA_GENERAL",
    "anamnesis": "Paciente refiere cuadro de 3 días de evolución caracterizado por cefalea holocraneana y odinofagia leve.",
    "examen_fisico": "Orofaringe congestiva sin exudados pultáceos. Murmullo vesicular conservado bilateralmente.",
    "habitos": "Tabaquismo ocasional. Niega consumo de alcohol."
  }
  ```
- **Pediatría:**
  ```json
  {
    "tipo_plantilla": "PEDIATRIA",
    "edad_meses": 24,
    "percentil_peso": "P50",
    "percentil_talla": "P60",
    "desarrollo_psicomotriz": "Camina sin apoyo, pronuncia palabras sueltas.",
    "vacunas_al_dia": true
  }
  ```
- **Cardiología:**
  ```json
  {
    "tipo_plantilla": "CARDIOLOGIA",
    "antecedentes_coronarios": "Hipertensión arterial diagnosticada hace 5 años, tratada con Losartán 50mg.",
    "auscultacion_cardiaca": "R1 y R2 normofonéticos, sin soplos audibles.",
    "electrocardiograma_previo": "Ritmo sinusal regular, FC 72 lpm, sin signos de isquemia aguda."
  }
  ```

---

## 2. Contratos API REST (Endpoints y Códigos HTTP)

Rutas registradas bajo el prefijo canónico `/medical-records/fichas` (con alias `/fichas`):

### 2.1 `POST /medical-records/fichas` (Emisión de Ficha con Validación Atómica)
- **Roles:** `PACIENTE`, `RECEPCION`, `ADMIN`.
- **Precondición:** El slot (`id_medico`, `fecha_atencion`, `hora_inicio`) debe estar disponible.
- **Códigos de Respuesta:**
  - `201 Created`: Ficha emitida exitosamente con correlativo generado (`FICH-YYYYMMDD-XXXX`).
  - `400 Bad Request`: Parámetros o fecha de slot inválidos.
  - `401 Unauthorized`: Token ausente o expirado.
  - `403 Forbidden`: Paciente intentando emitir ficha para un tercero o tenant suspendido.
  - `404 Not Found`: Médico, paciente o especialidad no encontrados en el tenant.
  - `409 Conflict`: El slot solicitado ya se encuentra ocupado por otra ficha o cita en el tenant.

### 2.2 `GET /medical-records/fichas` (Listado Paginado con Filtros)
- **Roles:** `PACIENTE` (solo sus fichas), `RECEPCION`, `MEDICO` (fichas asignadas), `ADMIN`.
- **Query Params:** `id_paciente`, `id_medico`, `id_especialidad`, `fecha`, `estado`, `page`, `page_size`.
- **Código:** `200 OK`.

### 2.3 `GET /medical-records/fichas/{id}` (Detalle de Ficha y Campos Dinámicos)
- **Roles:** `PACIENTE`, `RECEPCION`, `MEDICO`, `ADMIN`.
- **Código:** `200 OK`, `404 Not Found` (si pertenece a otro tenant o no existe).

### 2.4 `PATCH /medical-records/fichas/{id}/clinica` (Llenado Médico y Diagnóstico)
- **Roles:** `MEDICO`, `ADMIN`.
- **Payload:** `signos_vitales`, `secciones_dinamicas`, `codigo_cie10`, `diagnostico_descripcion`, `notas_evolucion`, `estado` (`EN_ATENCION`, `FINALIZADA`).
- **Código:** `200 OK`, `403 Forbidden` (médico no asignado o rol no clínico), `404 Not Found`.

### 2.5 `POST /medical-records/fichas/{id}/cancelar` (Cancelación de Ficha)
- **Roles:** `PACIENTE`, `RECEPCION`, `ADMIN`.
- **Payload:** `motivo_cancelacion`.
- **Código:** `200 OK`, `400 Bad Request` (si la ficha ya está `FINALIZADA`).

---

## 3. Arquitectura Web Angular (Frontend)

- **Patrón:** Standalone Components + Signals (`signal()`, `computed()`) + Reactive Forms.
- **Ubicación:** `src/app/features/medical-records/fichas/`:
  - `ficha-emision/`: Selector en cascada (Especialidad -> Médico -> Slots interactivos del día) + Formulario de motivo y pre-triaje.
  - `ficha-detalle/`: Renderizador reactivo de formulario dinámico JSONB según plantilla clínica de la especialidad, integración con catálogo CIE-10 (autocompletado reactivo) y notas de evolución.
  - `ficha-list/`: Tabla reactiva con filtrado multifactorial, badges de estado semánticos (`EMITIDA` azul, `EN_ATENCION` amarillo, `FINALIZADA` verde, `CANCELADA` rojo) y acciones por rol.
- **Servicios:** `src/app/core/services/ficha.service.ts` con manejo de estados asíncronos y tipado estricto `FichaModels`.

---

## 4. Arquitectura Móvil Flutter (Clean Architecture)

- **Patrón:** Clean Architecture desacoplada en 3 capas:
  - **Data:**
    - `ficha_model.dart`: Mapeo JSON con soporte nativo de `signos_vitales` y `secciones_dinamicas` como `Map<String, dynamic>`.
    - `ficha_remote_datasource.dart`: Llamadas a `/medical-records/fichas` mediante `ApiClient` con headers `Authorization` y `X-Tenant-ID`.
  - **Domain:**
    - `ficha_entity.dart`: Entidad de negocio pura.
    - `ficha_repository.dart`: Contrato de repositorio.
    - `create_ficha_usecase.dart`, `get_patient_fichas_usecase.dart`, `cancel_ficha_usecase.dart`.
  - **Presentation:**
    - `ficha_provider.dart`: `ChangeNotifier` con estados (`Initial`, `Loading`, `Loaded`, `Error`) y manejo de errores 409 Conflict.
    - `fichas_screen.dart`: Listado de fichas activas e históricas del paciente con pull-to-refresh y tags de estado.
    - `book_ficha_screen.dart`: Flujo guiado de emisión de ficha móvil con confirmación de correlativo.
