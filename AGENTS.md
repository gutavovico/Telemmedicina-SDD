# Global Agent Guidelines - Plataforma SaaS Multitenant de Telemedicina

Este archivo define las directrices y estándares técnicos obligatorios para cualquier Agente de Inteligencia Artificial (Antigravity, Gemini, Claude, Cursor, Codex) o desarrollador que opere en este repositorio.

---

## 1. Contexto y Arquitectura del Proyecto

- **Tipo de Plataforma:** Cloud SaaS Multitenant (Software as a Service Multinquilino).
- **Modelo de Inquilinos (Tenants):** Clínicas, consultorios médicos privados y redes de salud operan como Tenants aislados sobre una infraestructura compartida.
- **Estrategia de Datos:** **Pool con Discriminador a nivel de Base de Datos (Shared Database, Shared Schema)** en PostgreSQL (Neon Serverless).
- **Clave de Tenant:** Toda tabla transaccional o clínica incorpora `tenant_id: UUID (NOT NULL, FK a tenants.id)`.
- **Resolución de Inquilino:**
  - Header HTTP `X-Tenant-ID: <UUID>` o claim `tenant_id` en el token JWT.
  - Dependencia FastAPI `get_current_tenant` inyectada en todos los routers.
- **Aislamiento Estricto:** Prohibido el acceso cruzado entre tenants. Acceso a registros ajenos debe responder con `404 Not Found` (o `403 Forbidden`). Unicidad compuesta: `UNIQUE(tenant_id, ci)` y `UNIQUE(tenant_id, correo)`.

---

## 2. Regla de Oro: Spec-Driven Development (SDD)

> [!CAUTION]
> **PROHIBIDO CODIFICAR CÓDIGO DE PRODUCCIÓN SIN CONTRASTAR PRIMERO CONTRA LAS ESPECIFICACIONES (`openspec/specs/`) Y CONTRATOS (`openspec/contracts/`).**
> Ningún endpoint, columna de base de datos, esquema de datos o campo de interfaz puede ser inventado. OpenSpec es la única fuente de verdad.

Todo cambio o nuevo requerimiento sigue el flujo:
1. Propuesta de cambio formal: `openspec new change <nombre-en-kebab-case>`.
2. Especificación formal con verbos RFC 2119 (`The system SHALL ...`) y criterios de aceptación en Gherkin.
3. Actualización de contratos de API en `openspec/contracts/`.
4. Implementación guiada por la especificación.
5. Verificación con `openspec validate --specs` y pruebas automatizadas.

---

## 3. Skills y Estándares Técnicos

Los estándares detallados se encuentran disponibles en las skills de `.agents/skills/` y `.gemini/skills/`:

### 3.1 Backend: FastAPI + SQLAlchemy 2.0 + Alembic + Pydantic v2
- **Estructura Modular por Casos de Uso:** `backend_Telemedicina/app/modules/<dominio>/<caso_de_uso>/` (`router.py`, `service.py`, `schemas.py`, `models.py`, `dependencies.py`).
- **SQLAlchemy 2.0 Asíncrono:** Usar exclusivamente sintaxis `select(...)`, `execute()`, `scalars()` con `AsyncSession`. Prohibido `session.query()`.
- **Filtro de Tenant Obligatorio:** Toda consulta y mutación DEBE incluir `Model.tenant_id == current_tenant.id`.
- **Prevención de Tenant Injection:** Nunca aceptar `tenant_id` en el body de la petición del cliente; se inyecta desde el contexto autenticado del backend.
- **Códigos HTTP Semánticos:** `200 OK`, `201 Created`, `400 Bad Request`, `401 Unauthorized`, `403 Forbidden`, `404 Not Found`, `409 Conflict`, `422 Unprocessable Entity`.
- Ver skill completa: [.agents/skills/fastapi-backend-standards/SKILL.md](file:///c:/Users/tonys/OneDrive/Documentos/contenido/SI2/Proyecto_Telemedicina/.agents/skills/fastapi-backend-standards/SKILL.md).

### 3.2 Frontend Web: Angular Moderno (TypeScript) + Tailwind CSS
- **Standalone Components:** `standalone: true` en todos los componentes. Sin `NgModule`.
- **Reactividad con Signals:** Uso de `signal()`, `computed()` y `effect()` para el estado de la UI.
- **Formularios Reactivos:** Formularios fuertemente tipados con validaciones idénticas a los contratos.
- **Consumo Tipado:** Interfaces TypeScript derivadas directamente de `openspec/contracts/*.md`. Prohibido el tipo `any`.
- **Interceptores Multitenant:** Inyección automática de `Authorization: Bearer <token>` y `X-Tenant-ID: <UUID>`.
- Ver skill completa: [.agents/skills/angular-frontend-standards/SKILL.md](file:///c:/Users/tonys/OneDrive/Documentos/contenido/SI2/Proyecto_Telemedicina/.agents/skills/angular-frontend-standards/SKILL.md).

### 3.3 Frontend Móvil: Flutter (Dart) + Clean Architecture
- **Arquitectura Limpia en Tres Capas:** `Data`, `Domain` y `Presentation` en cada feature dentro de `lib/features/<dominio>/`.
- **Gestión de Estado:** `Provider` / `ChangeNotifier` o `BLoC` con estados atómicos (`Initial`, `Loading`, `Success`, `Error`).
- **Modelos Serializables:** Métodos `fromJson` y `toJson` alineados a los esquemas de Pydantic v2 en `openspec/contracts/`.
- **Seguridad:** Almacenamiento seguro de tokens y `tenant_id` en `FlutterSecureStorage`.
- Ver skill completa: [.agents/skills/flutter-mobile-standards/SKILL.md](file:///c:/Users/tonys/OneDrive/Documentos/contenido/SI2/Proyecto_Telemedicina/.agents/skills/flutter-mobile-standards/SKILL.md).

---

## 4. Verificación Obligatoria
Antes de dar por concluida cualquier interacción que modifique especificaciones o contratos, ejecutar:
```bash
openspec doctor
openspec validate --specs
```
Ambos comandos deben reportar éxito sin errores ni advertencias.
