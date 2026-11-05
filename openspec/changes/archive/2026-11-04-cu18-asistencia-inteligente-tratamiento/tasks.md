# Tasks — CU18: Recibir Asistencia Inteligente de Tratamiento

## 1. Base de Datos y Migraciones

- [x] 1.1 Crear modelos SQLAlchemy 2.0 (`InteraccionCatalogo`, `EvaluacionAsistencia`, `AlertaInteraccion`, `RecomendacionTratamiento`) en `app/modules/ai_assistant/models.py` y verificar congruencia con el diccionario de datos.
- [x] 1.2 Generar migración Alembic encadenada a la revisión head (`cu34_catalogo_016`), creando las 4 tablas con índices, constraints de orden canónico y claves foráneas, y verificar con `alembic check` o upgrade local SQLite/PostgreSQL.
- [x] 1.3 Incorporar en la migración la siembra de datos semilla para interacciones farmacológicas frecuentes (incluyendo el par Ibuprofeno + Aspirina para el Escenario 3C) y la creación de permisos `assistance:evaluate` y `assistance:read` asignados a los roles `PACIENTE` y `MEDICO`.

## 2. Backend (FastAPI) — 18.1 Motor de Sugerencias Contextuales (I-087)

- [x] 2.1 Definir esquemas Pydantic v2 en `app/modules/ai_assistant/schemas.py` (`EvaluacionTratamientoResponse`, `AlertaInteraccionDTO`, `RecomendacionTratamientoDTO`, `HistorialEvaluacionResponse`) y verificar serialización estricta sin campos adicionales.
- [x] 2.2 Implementar adaptador del proveedor de IA en `app/modules/ai_assistant/provider.py` siguiendo el protocolo `TreatmentAssistanceProvider` con cliente Groq, manejo de timeouts (4.0s) y exclusión de datos PII (sanitización de prompts).
- [x] 2.3 Implementar servicio de generación de recomendaciones contextuales y mecanismo de degradación elegante (`DEGRADADO_REGLAS_BASE`) ante fallo, timeout o rate-limit del proveedor en `app/modules/ai_assistant/service.py`, verificable contra el escenario Gherkin de indisponibilidad de IA.
- [x] 2.4 Incorporar lógica de caché de pre-evaluación (hash SHA-256 de 10 minutos) y rate limiting (10 req/hora por paciente) para mitigar costos y latencia.

## 3. Backend (FastAPI) — 18.2 Motor de Detección de Interacciones y Alertas (I-088)

- [x] 3.1 Implementar el motor determinista de reglas en `app/modules/ai_assistant/rules_engine.py` para normalizar principios activos y contrastar por pares contra `interacciones_catalogo`, clasificando severidades (`LEVE`, `MODERADA`, `GRAVE`), verificable contra el Escenario 3C (Ibuprofeno + Aspirina).
- [x] 3.2 Desarrollar el servicio principal de evaluación en `app/modules/ai_assistant/service.py` que recupera el tratamiento vigente de CU16/CU17, orquesta reglas e IA, persiste inmutablemente los resultados y registra la traza en `auditoria` mediante `registrar_auditoria` en la misma transacción.
- [x] 3.3 Implementar dependencias de autorización RBAC y aislamiento en `app/modules/ai_assistant/dependencies.py` validando que `PACIENTE` solo acceda a su propio historial y `MEDICO` a sus pacientes, respondiendo 403 ante roles no autorizados y 404 ante clínicas ajenas.
- [x] 3.4 Implementar router REST en `app/modules/ai_assistant/router.py` con los endpoints `/evaluar`, `/historial`, `/evaluaciones/{id}` y `/interacciones/catalogo`, registrarlo en `app/main.py` y verificar contratos OpenAPI generados.

## 4. Frontend Web (Angular) — 18.3 Interfaz Web del Asistente (I-089)

- [x] 4.1 Crear modelos TypeScript en `src/app/core/models/asistencia-tratamiento.models.ts` alineados con el contrato formal en `openspec/contracts/asistencia-tratamiento.md`.
- [x] 4.2 Crear servicio HTTP tipado `src/app/core/services/asistencia-tratamiento.service.ts` con manejo de signals y métodos para evaluar, listar historial y obtener detalle.
- [x] 4.3 Reemplazar el placeholder de `src/app/features/ai-assistant/` por un componente standalone interactivo con botón de evaluación bajo demanda, spinner de carga, tarjetas de alertas con semáforo de colores (Rojo/Ámbar/Azul), lista de recomendaciones y banner permanente de aviso médico (RF-25).
- [x] 4.4 Integrar panel de historial de evaluaciones y visualización para el médico asignado, verificando compilación con `ng build` o verificación estática.

## 5. Frontend Móvil (Flutter) — 18.4 Interfaz Móvil del Asistente (I-090)

- [x] 5.1 Implementar modelos de datos y serialización JSON (`fromJson` / `toJson`) en `lib/features/ai_assistant/data/models/` derivados del contrato formal.
- [x] 5.2 Implementar repositorio y fuente de datos remota en `lib/features/ai_assistant/data/datasources/` y `lib/features/ai_assistant/domain/repositories/` con inyección segura de Bearer token y cabeceras de tenant.
- [x] 5.3 Implementar gestor de estado (Provider / ChangeNotifier) en `lib/features/ai_assistant/presentation/providers/` con estados atómicos (`Initial`, `Loading`, `Success`, `Error`, `Degraded`).
- [x] 5.4 Reemplazar la pantalla placeholder en `lib/features/ai_assistant/presentation/screens/ai_assistant_screen.dart` con UI responsiva Material 3, mostrando tarjetas destacadas para alertas críticas (rojo/alerta), sugerencias contextuales, aviso legal y botón de llamada a urgencias.

## 6. Pruebas y Verificación Integral

- [x] 6.1 Pruebas unitarias del motor de reglas (`rules_engine.py`): verificar detección del par Ibuprofeno + Aspirina con severidad `GRAVE` (Escenario Principal 3C).
- [x] 6.2 Pruebas de integración del endpoint `POST /evaluar`: validar escenario exitoso, paciente sin tratamiento vigente (`SIN_TRATAMIENTO_VIGENTE`) y paciente sin interacciones (`SIN_RIESGO_DETECTADO`).
- [x] 6.3 Pruebas de resiliencia y degradación: simular timeout del proveedor LLM y verificar que el sistema responda HTTP 200 con estado `DEGRADADO_REGLAS_BASE` y alertas intactas.
- [x] 6.4 Pruebas de aislamiento multitenant y RBAC: verificar rechazo de acceso cruzado con HTTP 404 y rechazo de roles no autorizados con HTTP 403.
- [x] 6.5 Validación de especificaciones con `openspec validate --specs` y documentación del estado final de planificación.
