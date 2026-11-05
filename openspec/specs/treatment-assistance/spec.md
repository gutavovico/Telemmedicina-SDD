# CU18 — Asistencia Inteligente de Tratamiento

## Purpose

Proveer asistencia inteligente y personalizada sobre tratamientos farmacológicos a pacientes mediante la detección determinista de interacciones medicamentosas y la generación contextual de recomendaciones de autocuidado basada en IA con degradación tolerante a fallos, asegurando el aislamiento multitenant estricto y la preservación inmutable del historial clínico.

## Requirements

### Requirement: Evaluación asistida bajo demanda del tratamiento
The system SHALL permitir a un paciente autenticado solicitar bajo demanda la evaluación integral de su tratamiento activo. El sistema SHALL recuperar automáticamente los medicamentos vigentes de sus recetas emitidas (CU16/CU17), diagnósticos activos (CIE-10) y antecedentes registrados en su historia clínica para la clínica actual (`id_clinica`). The system SHALL rechazar cualquier modificación automática sobre dosis, recetas o diagnósticos en cumplimiento del RF-25.

#### Scenario: Paciente solicita evaluación de su tratamiento activo con éxito
- **GIVEN** un paciente autenticado en su clínica con recetas vigentes que contienen principios activos prescritos
- **WHEN** solicita la evaluación asistida de tratamiento enviando una petición `POST /api/v1/asistencia-tratamiento/evaluar`
- **THEN** el sistema analiza los principios activos de su tratamiento vigente, genera el reporte de interacciones y sugerencias contextuales
- **AND** persiste el resultado inmutable en la bitácora clínica y responde con código HTTP 200 OK

#### Scenario: Paciente sin tratamiento ni recetas vigentes
- **GIVEN** un paciente autenticado que no posee recetas activas ni medicamentos vigentes registrados en la clínica
- **WHEN** solicita la evaluación asistida de tratamiento
- **THEN** el sistema responde con código HTTP 200 OK indicando el estado `SIN_TRATAMIENTO_VIGENTE`
- **AND** retorna un mensaje clínico claro informando que no existen fármacos activos que evaluar en el expediente actual

### Requirement: Detección determinista de interacciones farmacológicas y alertas visuales
The system SHALL contrastar por pares cada principio activo presente en el tratamiento vigente del paciente contra el catálogo de interacciones (`interacciones_catalogo`). Ante cualquier coincidencia, el sistema SHALL generar una alerta estructurada especificando los fármacos involucrados, el nivel de severidad (`LEVE`, `MODERADA`, `GRAVE`), la descripción clínica del riesgo y las pautas precautorias inmediatas.

#### Scenario: Detección de interacción crítica en paciente hipertenso (Escenario Principal 3C HU-87)
- **GIVEN** un paciente con diagnóstico de hipertensión arterial y recetas vigentes que contienen "Ibuprofeno" y "Aspirina"
- **WHEN** el paciente solicita la evaluación asistida de tratamiento
- **THEN** el sistema detecta la interacción farmacológica entre ambos principios activos con severidad `GRAVE`
- **AND** genera una alerta visible destacada con el mensaje "Riesgo de interacción: aumento de riesgo de sangrado"
- **AND** acompaña sugerencias precautorias específicas para su condición de hipertensión
- **AND** persiste la alerta en el historial del paciente con severidad crítica

#### Scenario: Tratamiento con medicamentos sin interacciones conocidas (Criterio 5)
- **GIVEN** un paciente con recetas vigentes cuyos principios activos no presentan contraindicaciones ni interacciones registradas en el catálogo
- **WHEN** se ejecuta la evaluación asistida de tratamiento
- **THEN** el sistema retorna una lista vacía de alertas con indicador de riesgo `SIN_RIESGO_DETECTADO`
- **AND** presenta un mensaje explícito y comprensible indicando que no se detectaron interacciones adversas entre sus medicamentos actuales

### Requirement: Generación de recomendaciones contextuales personalizadas
The system SHALL sintetizar sugerencias de autocuidado, estilo de vida y recomendaciones de administración basadas en el perfil patológico, alergias y medicamentos del paciente. The system SHALL emplear un proveedor de IA generativa configurado con prompts sanitizados que excluyan datos de identificación personal (PII: nombres, CI, teléfonos). El texto del usuario o del paciente SHALL ser tratado exclusivamente como dato y nunca como instrucción ejecutable.

#### Scenario: Generación exitosa de pautas contextuales de autocuidado
- **GIVEN** un paciente evaluado con tratamiento antihipertensivo y antecedentes patológicos registrados
- **WHEN** el motor de asistencia procesa el contexto clínico anonimizado
- **THEN** el sistema genera recomendaciones estructuradas de horarios de toma, hidratación, monitoreo de presión arterial y precauciones dietéticas
- **AND** incluye en cada recomendación un aviso visible indicando que "Las sugerencias de la IA no sustituyen la valoración ni prescripción médica profesional"

### Requirement: Resiliencia del servicio y degradación elegante ante fallos de IA
The system SHALL garantizar la continuidad operativa de la evaluación en caso de indisponibilidad de red, timeout (superior al umbral configurable) o agotamiento de cuota (`429 Rate Limit`) del proveedor externo de IA. Ante tales eventualidades, the system SHALL degradar elegantemente entregando el resultado completo de las alertas deterministas por reglas junto con recomendaciones base predefinidas por catálogo, registrando la advertencia de degradación sin interrumpir el flujo ni devolver error HTTP 500.

#### Scenario: Indisponibilidad o timeout del proveedor de IA generativa
- **GIVEN** una caída de conectividad o tiempo de espera excedido del proveedor de inteligencia artificial
- **WHEN** el paciente solicita la evaluación de tratamiento
- **THEN** el sistema ejecuta el análisis determinista de interacciones farmacológicas
- **AND** adjunta recomendaciones generales estandarizadas según la patología base
- **AND** retorna la respuesta con estado `DEGRADADO_REGLAS_BASE` y código HTTP 200 OK
- **AND** no interrumpe la entrega de alertas de severidad crítica detectadas por reglas

### Requirement: Disponibilidad y consumo multidispositivo en Web y Móvil
The system SHALL exponer un contrato de API RESTful desacoplado y tipado que permita la renderización completa de alertas y recomendaciones tanto en la interfaz web de escritorio (Angular) como en la aplicación móvil del paciente (Flutter). Ambas plataformas SHALL representar de manera visualmente diferenciada los niveles de severidad (`GRAVE` en rojo/alerta crítica, `MODERADA` en ámbar/advertencia, `LEVE` en azul/informativo) y el aviso de no sustitución médica.

#### Scenario: Visualización responsiva de alertas en canales autorizados
- **GIVEN** una evaluación completada con alertas de severidad `GRAVE` y sugerencias contextuales
- **WHEN** el paciente consulta el resultado desde la web o la app móvil
- **THEN** la interfaz web muestra tarjetas de alerta destacadas con código de color rojo y pautas de acción inmediata
- **AND** la aplicación móvil presenta badges de severidad accesibles, opciones de contacto rápido a urgencias y acceso al historial de evaluaciones

### Requirement: Registro inmutable y auditoría en historial clínico
The system SHALL registrar cada evaluación solicitada, junto con la totalidad de alertas e interacciones identificadas, de forma inmutable en las tablas transaccionales de la base de datos asociadas a `(id_clinica, id_paciente)`. The system SHALL registrar de manera atómica un evento en la tabla `auditoria` utilizando la función `registrar_auditoria` dentro de la misma transacción de persistencia.

#### Scenario: Persistencia y trazabilidad de la evaluación asistida
- **GIVEN** una evaluación procesada con alertas e interacciones para un paciente
- **WHEN** finaliza la computación de resultados
- **THEN** se almacena un registro inmutable en `evaluaciones_asistencia` vinculado a sus detalles de alertas y recomendaciones
- **AND** se inserta una traza en `auditoria` con `tabla_afectada='evaluaciones_asistencia'`, `accion='EVALUAR_TRATAMIENTO'` y contexto del usuario
- **AND** los registros persisten sin permitir eliminación física (`soft-delete` o inmutables)

### Requirement: Aislamiento multitenant y control de acceso basado en roles (RBAC)
The system SHALL validar que únicamente los usuarios con rol `PACIENTE` (para su propio registro) o `MEDICO` (con al menos un tratamiento asignado al paciente en la clínica) puedan consultar o ejecutar evaluaciones. The system SHALL resolver la clínica exclusivamente desde `Usuario.id_clinica` autenticado. Para el rol `PACIENTE`, el sistema SHALL permitir únicamente consultar su propio historial y realizar evaluaciones; si solicita el historial de otro paciente en `/historial`, SHALL responder con código HTTP 403 Forbidden. En detalle de evaluación (`/evaluaciones/{id}`), si la evaluación no pertenece a su propio paciente, SHALL responder con código HTTP 404 Not Found. Para el rol `MEDICO`, el sistema SHALL permitir consultar únicamente evaluaciones de pacientes de su misma clínica que tengan al menos un tratamiento (tabla `tratamientos` de CU17, `Tratamiento.id_medico` = perfil del médico autenticado) a su cargo; ante pacientes inexistentes, de otra clínica o sin relación de tratamiento con ese médico, SHALL responder con código HTTP 404 Not Found tanto en listado como en detalle. Usuarios con roles administrativos o no autorizados (`ADMIN`, `ADMINISTRADOR`, `SUPERADMIN`, `RECEPCION`, `RECEPCIONISTA`, `FARMACIA` y cualquier otro rol) SHALL recibir HTTP 403 Forbidden en todos los endpoints de asistencia. El endpoint `/evaluar` SHALL ser exclusivo de pacientes autenticados con permiso `assistance:evaluate`.

#### Scenario: Paciente accede exclusivamente a su propio historial
- **GIVEN** un paciente autenticado con credenciales válidas
- **WHEN** intenta consultar el historial de evaluaciones de otro paciente dentro de la misma clínica enviando `id_paciente` ajeno
- **THEN** el sistema rechaza la solicitud respondiendo con código HTTP 403 Forbidden

#### Scenario: Médico consulta paciente a su cargo con tratamiento activo
- **GIVEN** un médico autenticado con un paciente que tiene al menos un tratamiento a su cargo en la misma clínica
- **WHEN** consulta el historial o detalle de evaluación de ese paciente
- **THEN** el sistema autoriza la consulta y responde con código HTTP 200 OK

#### Scenario: Médico consulta paciente sin relación de tratamiento o de clínica ajena
- **GIVEN** un médico autenticado en una clínica
- **WHEN** intenta consultar el historial o detalle de un paciente sin tratamiento a su cargo o perteneciente a otra clínica
- **THEN** el sistema no revela la existencia del registro ajeno y responde con código HTTP 404 Not Found

#### Scenario: Rol administrativo o no asistencial intenta acceder al servicio
- **GIVEN** un usuario autenticado con rol `ADMIN`, `SUPERADMIN` o `RECEPCION`
- **WHEN** intenta solicitar una evaluación, listar el historial o consultar detalle
- **THEN** el sistema rechaza el acceso respondiendo con código HTTP 403 Forbidden

---

## Data Dictionary

### 1. Entidad: `interacciones_catalogo` (Catálogo Global de Interacciones Farmacológicas)
- **Propósito:** Catálogo maestro referencial de interacciones por pares de principios activos (sin discriminador `id_clinica`).
- **Campos:**
  - `id_interaccion: BIGINT (PK, autoincremental)`
  - `principio_activo_a: VARCHAR(200) NOT NULL` (en minúsculas normalizadas)
  - `principio_activo_b: VARCHAR(200) NOT NULL` (en minúsculas normalizadas)
  - `severidad: VARCHAR(20) NOT NULL` (`LEVE`, `MODERADA`, `GRAVE`)
  - `mecanismo: TEXT NULL` (descripción del mecanismo farmacodinámico o farmacocinético)
  - `descripcion_riesgo: TEXT NOT NULL` (ej. "Aumento de riesgo de hemorragia gastrointestinal")
  - `recomendacion_clinica: TEXT NOT NULL` (pautas de precaución o monitorización)
  - `estado: VARCHAR(20) NOT NULL DEFAULT 'ACTIVO'` (`ACTIVO`, `INACTIVO`)
  - `created_at: TIMESTAMP WITH TIME ZONE DEFAULT NOW()`
- **Restricciones:**
  - `UNIQUE(principio_activo_a, principio_activo_b)`
  - `CHECK(severidad IN ('LEVE', 'MODERADA', 'GRAVE'))`
  - `CHECK(principio_activo_a < principio_activo_b)` (orden canónico lexicográfico para evitar duplicados simétricos A-B y B-A)

### 2. Entidad: `evaluaciones_asistencia` (Evaluación de Asistencia Inteligente)
- **Propósito:** Registro transaccional inmutable de una sesión de asistencia solicitada por el paciente en una clínica.
- **Campos:**
  - `id_evaluacion: BIGINT (PK, autoincremental)`
  - `id_clinica: BIGINT NOT NULL (FK -> clinicas.id_clinica)`
  - `id_paciente: BIGINT NOT NULL (FK -> pacientes.id_paciente)`
  - `id_usuario: BIGINT NOT NULL (FK -> usuarios.id_usuario)` (solicitante)
  - `fecha_evaluacion: TIMESTAMP WITH TIME ZONE DEFAULT NOW()`
  - `estado_evaluacion: VARCHAR(30) NOT NULL` (`COMPLETADA`, `DEGRADADO_REGLAS_BASE`, `SIN_TRATAMIENTO_VIGENTE`)
  - `nivel_riesgo_global: VARCHAR(20) NOT NULL` (`SIN_RIESGO`, `BAJO`, `MEDIO`, `ALTO`)
  - `total_medicamentos_analizados: INTEGER NOT NULL DEFAULT 0`
  - `total_alertas_detectadas: INTEGER NOT NULL DEFAULT 0`
  - `resumen_ejecutivo: TEXT NULL`
  - `proveedor_ia_utilizado: VARCHAR(50) NULL` (ej. 'groq-llama-3', 'rules-fallback')
  - `created_at: TIMESTAMP WITH TIME ZONE DEFAULT NOW()`
- **Restricciones e Índices:**
  - `Index("ix_evaluaciones_clinica_paciente", "id_clinica", "id_paciente")`
  - `Index("ix_evaluaciones_clinica_fecha", "id_clinica", "fecha_evaluacion")`

### 3. Entidad: `alertas_interaccion` (Detalle de Alertas Detectadas)
- **Propósito:** Alertas generadas por el cruce determinista de principios activos en una evaluación específica.
- **Campos:**
  - `id_alerta: BIGINT (PK, autoincremental)`
  - `id_evaluacion: BIGINT NOT NULL (FK -> evaluaciones_asistencia.id_evaluacion ON DELETE CASCADE)`
  - `id_interaccion: BIGINT NULL (FK -> interacciones_catalogo.id_interaccion)`
  - `principio_activo_1: VARCHAR(200) NOT NULL`
  - `principio_activo_2: VARCHAR(200) NOT NULL`
  - `medicamento_1_nombre: VARCHAR(200) NOT NULL`
  - `medicamento_2_nombre: VARCHAR(200) NOT NULL`
  - `severidad: VARCHAR(20) NOT NULL` (`LEVE`, `MODERADA`, `GRAVE`)
  - `mensaje_alerta: TEXT NOT NULL`
  - `pauta_precaucion: TEXT NOT NULL`
  - `created_at: TIMESTAMP WITH TIME ZONE DEFAULT NOW()`
- **Restricciones:**
  - `CHECK(severidad IN ('LEVE', 'MODERADA', 'GRAVE'))`

### 4. Entidad: `recomendaciones_tratamiento` (Sugerencias Contextuales)
- **Propósito:** Recomendaciones contextuales de cuidado generadas por IA o reglas base en una evaluación.
- **Campos:**
  - `id_recomendacion: BIGINT (PK, autoincremental)`
  - `id_evaluacion: BIGINT NOT NULL (FK -> evaluaciones_asistencia.id_evaluacion ON DELETE CASCADE)`
  - `categoria: VARCHAR(50) NOT NULL` (`HORARIO_ADMINISTRACION`, `ESTILO_VIDA`, `SIGNOS_ALARMA`, `NUTRICION_HIDRATACION`, `PRECAUCION_GENERAL`)
  - `titulo: VARCHAR(200) NOT NULL`
  - `detalle: TEXT NOT NULL`
  - `origen: VARCHAR(20) NOT NULL` (`IA_GENERATIVA`, `REGLA_PREDEFINIDA`)
  - `created_at: TIMESTAMP WITH TIME ZONE DEFAULT NOW()`

