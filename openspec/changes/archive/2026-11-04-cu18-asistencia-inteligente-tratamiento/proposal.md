# Proposal — CU18: Recibir Asistencia Inteligente de Tratamiento

## Why

Los pacientes bajo tratamiento farmacológico activo enfrentan riesgos de complicaciones por interacciones medicamentosas no advertidas y falta de orientación contextual sobre pautas de autocuidado diario. En el marco del Sprint 3 (HU1-87 a HU1-90, RF-25, prioridad Alta, 28 h, responsable Sandoval Sanchez Gustavo Antonio), se requiere dotar al paciente de una evaluación asistida bajo demanda que analice su tratamiento vigente, detecte interacciones farmacológicas mediante un motor determinista de reglas clínicas y ofrezca sugerencias personalizadas mediante IA generativa, manteniendo siempre la seguridad del paciente sin modificar prescripciones ni diagnósticos.

## What Changes

- **Evaluación Asistida Bajo Demanda:** Endpoint para que el paciente solicite la evaluación de su tratamiento vigente, disparando el cruce de fármacos y la generación de sugerencias.
- **Motor Híbrido de Reglas e Inteligencia Artificial:**
  - *Reglas Deterministas (Detección de Interacciones):* Catálogo global de interacciones farmacológicas con niveles de severidad (`LEVE`, `MODERADA`, `GRAVE`) y alertas estructuradas inmediatas.
  - *IA Generativa Aislada (Sugerencias Contextuales):* Síntesis de pautas de cuidado y estilo de vida basada en antecedentes clínicos y diagnóstico, ejecutada con prompts sanitizados sin PII (sin nombre, CI ni datos identificables).
- **Resiliencia y Degradación Elegante:** En caso de indisponibilidad, timeout o rate-limit del proveedor de IA (Groq u homólogo), el sistema degrada a reglas base de autocuidado sin bloquear la respuesta de interacciones ni arrojar error 500.
- **Aislamiento Multitenant y Persistencia Inmutable:** Las evaluaciones, alertas y recomendaciones emitidas quedan registradas de forma inmutable asociadas a `(id_clinica, id_paciente)` e integradas a la bitácora de auditoría transaccional (`app.core.audit.registrar_auditoria`).
- **Canales Web y Móvil:**
  - Web (Angular): Reemplazo del placeholder de Sprint 4 en `src/app/features/ai-assistant/` con panel de visualización de alertas críticas y sugerencias contextuales con banner de advertencia clínica.
  - Móvil (Flutter): Reemplazo del placeholder en `lib/features/ai_assistant/` estructurado en capas `Data`, `Domain` y `Presentation` con interfaz accesible para pacientes y vista de solo lectura para médicos asignados.
- **Control de Acceso Basado en Roles (RBAC):** Nuevos permisos `assistance:evaluate`, `assistance:read` asignados a `PACIENTE` (gestión y consulta propia) y `MEDICO` (lectura de pacientes con tratamiento a su cargo). Otros roles reciben `403 Forbidden`.

## Capabilities

### New Capabilities
- `treatment-assistance`: Motor híbrido de evaluación farmacológica y recomendaciones contextuales para el paciente, gestión de alertas de interacción, degradación ante fallos del modelo de lenguaje, registro inmutable en historial clínico y presentación multidispositivo (web/móvil).

### Modified Capabilities
<!-- Ninguna capacidad previa modifica sus requisitos formales. -->

## Impact

- **Límites de Dominio y Backend:**
  - Módulo nuevo en `backend_Telemedicina/app/modules/ai_assistant/` conteniendo `router.py`, `service.py`, `schemas.py`, `models.py`, `dependencies.py` y `rules_engine.py`.
  - Integración de cliente LLM seguro reutilizando el patrón de protocolo y manejo de excepciones de `app/modules/analytics/reportes/groq_client.py`.
  - Persistencia con SQLAlchemy 2.0 síncrono (`Session`, `get_db`) y clave compuesta de tenant con `id_clinica: BIGINT` alineada a la convención real del repositorio.
  - Nueva migración Alembic encadenada a la cabeza actual para crear las tablas `interacciones_catalogo`, `evaluaciones_asistencia`, `alertas_interaccion`, `recomendaciones_tratamiento` y sembrar permisos `assistance:*`.
- **Frontend Web (Angular):**
  - Componente standalone en `src/app/features/ai-assistant/` consumiendo el nuevo servicio tipado `src/app/core/services/asistencia-tratamiento.service.ts` e interfaces en `src/app/core/models/asistencia-tratamiento.models.ts`.
- **Frontend Móvil (Flutter):**
  - Feature en `mobile_telemedicina/lib/features/ai_assistant/` organizada en `data/`, `domain/` y `presentation/` utilizando `Provider` / `ChangeNotifier` para estados atómicos (`Initial`, `Loading`, `Success`, `Error`).
- **Contratos:**
  - Creación del contrato formal en `openspec/contracts/asistencia-tratamiento.md`.
- **Aislamiento y Auditoría:**
  - Resolución de clínica mediante `Usuario.id_clinica` autenticado; intentos de acceso entre clínicas responden `404 Not Found`. Auditoría registrada en la misma transacción de persistencia.

## Mapeo CU18 → HU / RF / Criterios de Aceptación

| Código | Descripción en Documento Fuente | Mapeo en CU18 |
|---|---|---|
| **HU1-87** | Motor de recomendaciones contextuales y sugerencias | Tarea 18.1: Endpoint y lógica de sugerencias personalizadas con IA y fallback |
| **HU1-88** | Detección de interacciones y alertas | Tarea 18.2: Motor determinista de reglas de interacciones con severidad y alertas |
| **HU1-89** | Interfaz Web del Asistente Inteligente | Tarea 18.3: Pantalla web en Angular con tarjetas de severidad y descarga/lectura |
| **HU1-90** | Interfaz Móvil del Asistente Inteligente | Tarea 18.4: Pantalla móvil en Flutter con alertas visuales destacadas y badges |
| **RF-25** | Soporte de IA sin mutación automática | La IA apoya con alertas y sugerencias SIN modificar prescripciones ni dosis |
| **Criterio 1** | Recomendaciones según tratamiento e historial | Contexto extraído de recetas vigentes (CU16/CU17), diagnósticos CIE y antecedentes |
| **Criterio 2** | Detección de interacciones y alerta visible | Cruce por pares de principios activos contra `interacciones_catalogo` |
| **Criterio 3** | Sugerencias personalizadas basadas en perfil | Recomendaciones de estilo de vida, hidratación y precauciones según patología base |
| **Criterio 4** | Disponibilidad en Web y Móvil | Implementación simétrica en Angular y Flutter con diseño responsivo |
| **Criterio 5** | Mensaje claro ante ausencia de alertas/riesgos | Estado explícito `SIN_RIESGO_DETECTADO` con mensaje positivo de tranquilidad |
| **Criterio 6** | Registro en historial del paciente | Guardado inmutable en `evaluaciones_asistencia` y traza en `auditoria` |
| **Escenario 3C**| Paciente hipertenso con Ibuprofeno + Aspirina | Alerta ROJA visible "Riesgo de interacción: aumento de riesgo de sangrado" + sugerencias de hipertensión + registro en historial |

## Supuestos y Fuera de Alcance

1. **Fuera de alcance — Entrada manual de fármacos:** Aunque la tarjeta 3C menciona ingreso manual de medicamentos, la especificación formal del CU18 y su diagrama de estados establecen que la evaluación extrae los medicamentos vigentes del tratamiento clínico activo del paciente (CU16/CU17). No se habilita ingreso manual ad-hoc en esta fase para evitar inconsistencias con el expediente médico.
2. **Fuera de alcance — Triaje pre-consulta (`triage`):** No se modifica `app/modules/medical_records/triage/` ni sus vistas correspondientes; dicho módulo corresponde al triaje de síntomas previo a la cita médica y es independiente de la asistencia de tratamiento.
3. **Privacidad de Datos (PII):** Al interactuar con el proveedor de IA generativa, el backend nunca envía nombres, apellidos, números de identificación (CI), teléfonos ni identificadores directos. Solo se envían listas de principios activos, códigos/descripciones diagnósticas y antecedentes anonimizados.
4. **No Automatización Médica:** La IA y el motor de reglas no tienen capacidad de cancelar recetas, modificar dosis ni suspender tratamientos; toda acción terapéutica requiere intervención del médico tratante.

