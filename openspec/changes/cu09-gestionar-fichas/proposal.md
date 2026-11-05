# Proposal: CU09 – Gestionar Fichas Médicas y Expediente Clínico Dinámico

## 1. Justificación y Propósito
El caso de uso **CU09: Gestionar Fichas Médicas y Expediente Clínico Dinámico** es la piedra angular operativa del Sprint 1 para la gestión ambulatoria y clínica de la plataforma SaaS Multitenant. Permite formalizar el acto de recepción, reserva y emisión de fichas médicas de atención para pacientes, vinculando el turno agendado (o demanda espontánea) con una estructura de expediente clínico evolutivo y dinámico por especialidad médica.

En un entorno SaaS multiclínica, cada inquilino (`tenant_id`) requiere:
1. Control de concurrencia atómica en tiempo real para evitar la emisión duplicada de fichas sobre el mismo slot de agenda médica (respondiendo con `409 Conflict`).
2. Generación automática de correlativos alfanuméricos auditables y únicos por clínica (ej. `FICH-YYYYMMDD-XXXX`).
3. Flexibilidad documental mediante esquemas JSONB tipados para anamnesis, exploración física específica por especialidad (Pediatría, Cardiología, Nutrición, etc.) y constantes vitales.
4. Conexión nativa con el catálogo internacional de diagnósticos CIE-10 y notas de evolución clínica.

---

## 2. Mapeo de Historias de Usuario (HU1-29 a HU1-33)

| Historia de Usuario | Título | Actor Principal | Resumen de Alcance |
| :--- | :--- | :--- | :--- |
| **HU1-29** | Emisión y Reserva de Ficha por Paciente | Paciente | El paciente puede emitir/reservar su propia ficha médica desde el portal web o app móvil seleccionando especialidad, médico y slot disponible. |
| **HU1-30** | Emisión Administrativa en Recepción | Recepcionista / Admin | Emisión de fichas presenciales o virtuales para cualquier paciente registrado en la clínica, validando disponibilidad de turno en tiempo real. |
| **HU1-31** | Consulta y Triaje de Fichas Médicas | Médico / Enfermería | Visualización en tiempo real de las fichas emitidas para el turno del médico, registro preliminar de signos vitales y cambio a estado `EN_ATENCION`. |
| **HU1-32** | Expediente Clínico Dinámico por Especialidad | Médico | Captura de anamnesis estructurada y secciones dinámicas (JSONB) configuradas según la especialidad del médico. |
| **HU1-33** | Registro Diagnóstico CIE-10 y Cierre de Ficha | Médico | Asociación de diagnósticos codificados (CIE-10), notas de evolución y cierre formal de la ficha pasando a estado `FINALIZADA`. |

---

## 3. Impacto Arquitectural en los 6 Paquetes Canónicos

1. **`medical_records` (Paquete Anfitrión):**
   - Incorpora la entidad `FichaClinica` y el subdominio `fichas/` (`router.py`, `service.py`, `schemas.py`, `models.py`).
   - Se conecta bidireccionalmente con `HistoriaClinica` y los catálogos diagnósticos (`diagnosticos_cie10`).
2. **`appointments` (Referencia Externa):**
   - Consume y valida los turnos de `Cita`, disponibilidad de `HorarioMedico` y catálogos de `ServicioMedico` y `Especialidad`.
   - Marca turnos como ocupados o vinculados al generarse una ficha activa.
3. **`auth` (Seguridad y Multitenancy):**
   - Validación estricta de claims `tenant_id` y roles RBAC (`PACIENTE`, `RECEPCION`, `MEDICO`, `ADMIN`).
4. **`analytics` (Preparación Sprint 3):**
   - Estructuración de eventos de telemetría (fichas emitidas, tiempos de espera, diagnósticos frecuentes) indexables para reportería.
5. **`communications` (Preparación Sprint 2):**
   - Generación de notificaciones automáticas y preparación de sala de videoconsulta cuando el tipo de atención sea telemedicina.
6. **`ai_assistant` (Preparación Sprint 4):**
   - La estructura de secciones dinámicas (JSONB) y signos vitales servirá como payload de contexto clínico para el motor de triaje asistido por IA.

---

## 4. Alcance Multiplataforma

- **Backend (FastAPI + SQLAlchemy 2.0 + PostgreSQL):**
  - Módulo `app/modules/medical_records/fichas/` con aislamiento estricto por `tenant_id`.
  - Transacciones con control de concurrencia y validación anti-colisión con respuesta `409 Conflict`.
  - Generador de correlativo secuencial `FICH-YYYYMMDD-XXXX`.
  - Migración Alembic secuencial derivada del head `c3d4e5f6a7b8`.
- **Frontend Web (Angular 19 Standalone):**
  - Módulo en `src/app/features/medical-records/fichas/` con `ficha-emision`, `ficha-detalle` y `ficha-list`.
  - Formularios reactivos dinámicos con Signals y renderizado por especialidad.
  - Consumo tipado mediante `FichaService` y modelos `FichaModels`.
- **Frontend Móvil (Flutter Clean Architecture):**
  - Módulo `lib/features/medical_records/` con separación en 3 capas (`data/`, `domain/`, `presentation/`).
  - Emisión de fichas móviles, selección de turnos, visualización de fichas activas e historial con correlativo único.

---

## 5. Requisitos No Funcionales (NFR) y Estándares RFC 2119

- **RNF-CU09-01 (Tiempo de Respuesta):** Las operaciones de emisión y consulta de fichas DEBEN ejecutarse en un tiempo inferior a 2.0 segundos bajo condiciones normales de red.
- **RNF-CU09-02 (Concurrencia Atómica):** El sistema DEBE garantizar que dos solicitudes concurrentes para el mismo slot médico y fecha resulten en una única emisión exitosa y el rechazo inmediato de la segunda con `409 Conflict`.
- **RNF-CU09-03 (Aislamiento Multitenant):** Ningún usuario de un `tenant_id` PODRÁ consultar o mutar fichas de otro inquilino bajo ninguna circunstancia (respuesta `404 Not Found`).
- **RNF-CU09-04 (Flexibilidad de Esquema):** El backend y los clientes DEBEN admitir campos dinámicos en formato JSONB sin requerir alteraciones al esquema relacional de la base de datos.
