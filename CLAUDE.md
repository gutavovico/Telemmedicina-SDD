# CLAUDE.md

Guía para Claude Code en este repositorio. Las reglas normativas completas están en [AGENTS.md](AGENTS.md) (obligatorio leerlo); aquí solo se resume el mapa del proyecto y los comandos. Si algo contradice a AGENTS.md, gana AGENTS.md.

## Qué es

Plataforma SaaS multitenant de telemedicina (Shared Database, Shared Schema en PostgreSQL/Neon). Tres clientes sobre una sola API:

| Carpeta | Stack |
|---|---|
| `backend_Telemedicina/` | FastAPI, SQLAlchemy 2.0, Alembic, Pydantic v2 |
| `frontend_Telemedicina/` | Angular 21 standalone + Signals + Tailwind, Cypress |
| `mobile_telemedicina/` | Flutter, Clean Architecture (`lib/features/<dominio>/{data,domain,presentation}`) |
| raíz (`openspec/`, docs) | OpenSpec: specs, contratos, changes |

**Es un monorepo** (`gutavovico/Telemmedicina-SDD`): backend, frontend, móvil y `openspec/` viven en un solo repositorio git. Ya no hay subrepos ni submódulos `specs/`; las specs y contratos se editan solo en `openspec/` de la raíz. Los repos antiguos `gutavovico/backend_Telemedicina`, `frontend_Telemedicina` y `mobile_telemedicina` quedan archivados (solo lectura) y conservan su historial previo a la migración (que también está importado aquí). El CI está en `.github/workflows/` (`backend.yml`, `frontend.yml`, `mobile.yml`), con filtro `paths:` por carpeta.

Rama de trabajo de Gustavo: `Gustavo`; se integra con `main` mediante merge (`Merge branch 'main' into Gustavo`) y PRs de ramas `feature/cuXX-...`. Un mismo PR puede tocar varias carpetas (p. ej. `openspec/` + backend + frontend + móvil) y debe seguir el flujo SDD.

## Regla de oro: SDD

No escribir código de producción sin contrastarlo con `openspec/specs/` y `openspec/contracts/`. No inventar endpoints, columnas ni campos. Flujo para cambios nuevos: `openspec new change <kebab-case>` → spec con RFC 2119 + Gherkin → contrato en `openspec/contracts/` → implementar → verificar. Hay skills/comandos para esto (`/opsx:propose`, `/opsx:apply`, `/opsx:archive`, `/opsx:explore`, `/opsx:update`, `/opsx:sync`).

Al tocar specs o contratos, antes de terminar:
```bash
openspec doctor
openspec validate --specs
```
Ambos deben dar éxito sin errores ni advertencias.

Contratos actuales: auth, users, doctors, patients, fichas, live-queue, teleconsulta, analytics, audit-log, notificaciones, pagos, planes, asistencia-tratamiento, agenda-local-verification. Changes activos en `openspec/changes/` (CU08, CU09, CU15, CU19, CU22, CU34…); los terminados van a `openspec/changes/archive/`.

## Multitenancy (resumen; detalle en AGENTS.md §1)

- Tenant por `X-Tenant-ID` o claim `tenant_id` del JWT, vía `get_current_tenant`.
- Toda consulta/mutación filtra por tenant; nunca aceptar `tenant_id` en el body.
- Acceso cruzado → `404` (o `403`). Unicidad compuesta con tenant (`ci`, `correo`).
- **Excepción acotada CU34** (AGENTS.md §5): Plan/VersionPlan son globales (sin tenant), solo superadmin, BOB con 2 decimales, ciclo MENSUAL, `Session` síncrona. No extender esa excepción a otros módulos.
- **Excepción acotada CU11** (AGENTS.md §5): `Session` síncrona solo en `app/modules/medical_records/laboratory_results/` y `laboratory_sync/` (resultados y sincronización de laboratorio); siguen vigentes `select/execute/scalars`, sin `session.query()` y el filtro por clínica. No se extiende a otros módulos.
- Nota de nomenclatura: el código usa `id_clinica` (tablas `clinicas`, `Usuario.id_clinica`) donde los docs dicen `tenant_id`/`tenants`. Sigue lo que ya hace el módulo que tocas y confirma con el contrato.

## Backend (`backend_Telemedicina/`)

Módulos en `app/modules/<dominio>/<caso_de_uso>/` (`router.py`, `service.py`, `schemas.py`, `models.py`): `auth` (incl. `planes`, roles/permisos, auditoría, usuarios), `tenants` (gestión, onboarding, pagos de suscripción, `usage_billing` CU36), `appointments`, `medical_records` (HCE, recetas, tratamientos), `communications` (teleconsulta/chat), `payments`, `notificaciones`, `analytics`, `ai_assistant`, `backup`, `auditoria`. Routers registrados en `app/main.py` (cuidado: aquí chocan los merges; conserva los imports de ambos lados).

```bash
# desde backend_Telemedicina/ (venv en .venv o venv)
python -m uvicorn app.main:app --reload --port 8000      # docs en /docs
python -m pytest tests -q                                 # tests/test_cuNN_*.py, por caso de uso
python -m pytest tests/test_cu17_tratamientos.py -q       # un solo archivo
alembic upgrade head                                      # migraciones en alembic/versions (última: 024_cu36_billing_overages)
```

- SQLAlchemy: solo `select()/execute()/scalars()`; prohibido `session.query()`.
- Códigos HTTP semánticos (200, 201, 400, 401, 403, 404, 409, 422).
- Errores de dominio se mapean con exception handlers registrados en `main.py` (p. ej. `PlanError`, `PagoError`, `BillingError`).
- Los `README_*.md` del backend contienen guías de prueba y cuentas seed; úsalos en vez de copiar credenciales aquí. `.env` contiene secretos: no leer ni commitear.

## Web (`frontend_Telemedicina/`)

```bash
npm start                 # ng serve (proxy en proxy.conf.json)
npm run build             # producción
npm run test:vitest       # unit tests (ng test --watch=false)
npm run test:e2e          # Cypress headless (cypress/)
```

Estructura: `src/app/{core,shared,features/<dominio>}`. Interfaces TypeScript derivadas de `openspec/contracts/*.md`, sin `any`; interceptor funcional agrega `Authorization` y `X-Tenant-ID`. Rutas de admin bajo `/admin/...` (p. ej. `/admin/planes`).

## Móvil (`mobile_telemedicina/`)

```bash
flutter pub get
flutter run
flutter test              # test/ ; integration_test/ para E2E
flutter analyze
```

Features en `lib/features/` (auth, appointments, cola_virtual, communications, medical_records, payments, teleconsulta, treatments, analytics, ai_assistant, home). Modelos con `fromJson/toJson` alineados al contrato; tokens y `tenant_id` en `FlutterSecureStorage`.

## Sincronizar

Basta un solo `git fetch --all --prune` en la raíz. Antes de mergear confirma que el árbol de trabajo esté limpio. Los comandos de las secciones Backend, Web y Móvil se ejecutan **desde su carpeta** (`cd backend_Telemedicina`, etc.). `SI2-Grupo3.md` (≈20 MB) en la raíz es un documento fuente: no lo abras entero ni lo leas completo.
