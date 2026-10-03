# Technical Design: CU15 Teleconsulta y Chat de Cita Médica

## Context
Ver motivación y requerimientos en `proposal.md` y `specs/cu15-teleconsulta.spec.md`.
La plataforma opera como SaaS Multitenant en PostgreSQL (Neon Serverless) con aislamiento lógico mediante `id_clinica` (`tenant_id`). La interfaz requiere una experiencia de teleconsulta consistente entre el Portal Web (Angular con Signals) y la Aplicación Móvil (Flutter con Clean Architecture + Provider), conectada a los servicios FastAPI existentes.

## Goals / Non-Goals

**Goals:**
- Proporcionar la vista unificada de teleconsulta (datos del paciente, resumen de cita, ficha del especialista y chat en vivo).
- Implementar mensajería bidireccional reactiva con actualización optimista (Optimistic UI) y reconciliación atómica contra la base de datos PostgreSQL.
- Mantener sincronización continua entre clientes (Web y Móvil) mediante sondeo silencioso en segundo plano cada 3.5 segundos.
- Soporte para metadatos de archivos adjuntos (documentos clínicos, imágenes y estudios de laboratorio).
- Garantizar aislamiento multitenant estricto (`404 Not Found` en accesos cruzados de clínica o usuarios no pertenecientes a la cita).

**Non-Goals:**
- Transmisión WebRTC directa punto a punto dentro del hilo de chat (la videollamada se maneja en capa complementaria).
- Modificación de esquemas de facturación o módulos no pertenecientes a CU15.

## Decisions

### 1. Modelo de Datos y Persistencia
- **Decisión:** Tabla `mensajes_chat_cita` con discriminador multitenant `id_clinica` y clave foránea `id_cita`.
- **Alternativas consideradas:**
  - *Tabla genérica de mensajes globales:* Descartada para evitar consultas lentas y mezcla de contextos; asociar directamente a `id_cita` asegura aislamiento inmediato y cascada natural.
- **Campos de Adjuntos:** `adjunto_nombre`, `adjunto_tamano`, `adjunto_url` embebidos directamente en la tabla de mensajes.

### 2. Sincronización en Tiempo Real
- **Decisión:** Polling silencioso periódico (3.5 segundos) combinado con Optimistic UI local.
- **Razón:** Compatibilidad absoluta con infraestructuras serverless (Neon + Render/Containers) sin incurrir en desconexiones de WebSockets o saturación de sockets en planes gratuitos.
- **Reconciliación:** Identificadores temporales locales (negativos) reemplazados al recibir la respuesta `201 Created` del servidor.

### 3. Experiencia de Usuario Diferenciada por Rol
- **Médico (Web):** Widget flotante anclado (`ChatFloatingWidgetComponent`) en esquina inferior derecha (`z-50`), preservando navegación principal y tablas de consulta.
- **Paciente (Web & Móvil):**
  - Web: Vista `/citas/:id/teleconsulta` con dos columnas.
  - Móvil: Pantalla "Mis citas" con segmented control dinámico y modal inferior interactivo (`ChatTeleconsultaScreen.showAsModal`) para respuesta inmediata.

## Risks / Trade-offs

- **[Riesgo: Sobrecarga por Sondeo]** → Mitigación: Intervalo acotado a 3.5 segundos activo únicamente mientras la pantalla o modal de chat esté montado en pantalla; desuscripción y cancelación de `Timer` inmediata en `ngOnDestroy` / `dispose()`.
- **[Riesgo: Intento de Tenant Injection]** → Mitigación: El backend inyecta `current_user` y valida la pertenencia de la cita antes de cualquier lectura o inserción de mensaje.
