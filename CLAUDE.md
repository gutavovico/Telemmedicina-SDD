# CLAUDE.md

Guía para Claude Code en este repositorio. Las reglas normativas completas están en [AGENTS.md](AGENTS.md) (obligatorio leerlo); aquí solo se resume el mapa del proyecto y los comandos. Si algo contradice a AGENTS.md, gana AGENTS.md.

## Qué es

Plataforma SaaS multitenant de telemedicina (Shared Database, Shared Schema en PostgreSQL/Neon). Tres clientes sobre una sola API:

| Carpeta | Stack | Repo remoto |
|---|---|---|
| `backend_Telemedicina/` | FastAPI, SQLAlchemy 2.0, Alembic, Pydantic v2 | `gutavovico/backend_Telemedicina` |
| `frontend_Telemedicina/` | Angular 21 standalone + Signals + Tailwind, Cypress | `gutavovico/frontend_Telemedicina` |
| `mobile_telemedicina/` | Flutter, Clean Architecture (`lib/features/<dominio>/{data,domain,presentation}`) | `gutavovico/mobile_telemedicina` |
| raíz (`openspec/`, docs) | OpenSpec: specs, contratos, changes | `gutavovico/Telemmedicina-SDD` |

**Son 4 repos git independientes.** El `.gitignore` de la raíz excluye las tres carpetas de código, así que `git` en la raíz solo ve `openspec/`, docs y archivos de agentes. Cada subrepo trae además un submódulo `specs/` (apunta a Telemmedicina-SDD, queda en HEAD desacoplado; no lo edites ahí, edita `openspec/` en la raíz).

Rama de trabajo de Gustavo: `Gustavo` en cada repo; se integra con `main` mediante merge (`Merge branch 'main' into Gustavo`) y PRs de ramas `feature/cuXX-...`.

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

## Sincronizar repos

Para traer cambios remotos hay que hacerlo **por cada repo** (`git fetch --all --prune` en la raíz y en cada subrepo; los `specs/` de los subrepos fallan al fetch si el gitlink apunta a un commit no publicado: es ruido, no un error real). Antes de mergear confirma que el árbol de trabajo esté limpio. `SI2-Grupo3.md` (≈20 MB) en la raíz es un documento fuente: no lo abras entero ni lo leas completo.
