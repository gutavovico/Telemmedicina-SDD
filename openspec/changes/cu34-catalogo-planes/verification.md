# Verificación CU34 — 2026-11-03

## Reanudación y estructura final

Se recuperaron las ramas, diferencias y archivos nuevos sin descartar cambios. La revisión pendiente de estructura se cerró siguiendo clínicas: Plan/VersionPlan en `auth/models.py`; esquemas, servicio, permisos y router en `auth/planes`; tipos web en `core/models/plan.models.ts`, cliente singleton en `core/services/planes.service.ts` y componentes en `features/auth/planes`. Se retiraron los archivos anteriores del catálogo para evitar copias. No cambiaron tablas, migración ni contrato HTTP.

Tras el ajuste se repitieron con éxito: importación de `app.main` sin iniciar su lifespan, `configure_mappers()` y registro único de las dos entidades; Alembic muestra una sola cabeza; 75 pruebas backend/auditoría con PostgreSQL local; 12 pruebas frontend; build de producción; recorrido completo Edge/API/PostgreSQL con persistencia y móvil. OpenSpec doctor y cambio CU34 pasan. La validación global conserva el fallo preexistente de live-queue indicado abajo. Seguimiento por etapas en `seguimiento.md`.

## Entorno y alcance

Rama `feature/cu34-catalogo-planes` en SDD, backend y frontend. Sin push, merge ni cambios de base. El documento del usuario `SI2-Grupo3.md` conserva SHA256 `8F0E9CF9AFF0B8801179B9317C0A6B64061E4F3AB993D706DEF25BC440D5364E`.

Dependencias backend instaladas desde `requirements.txt` en `.venv-cu34` ignorada. Frontend desde `npm ci`, sin modificar manifiestos/lock. PostgreSQL 17.6 temporal bajo `backend_Telemedicina/tmp/cu34-pg`, escucha exclusivamente en `127.0.0.1:55434`, base `cu34_test_catalog`. Las pruebas PG crean y eliminan sus propios esquemas. Sin acceso a Neon, sin cambiar `.env` y sin scheduler de backups. La aplicación local incluye los routers reales de autenticación, contexto y planes, sin el lifespan de producción.

Al terminar se detuvieron el backend local, Angular y el clúster temporal. Los datos locales y las capturas se conservaron en las rutas ignoradas; no quedan servicios de CU34 ejecutándose.

## Resultados comprobados

Prueba manual reportada por el usuario el 2026-11-04: creó un plan de 200 Bs mensuales con 100 consultas, publicó una versión a 250 Bs y confirmó que el historial conservaba los 200 Bs originales. Después desactivó el plan y verificó su presencia en el filtro Inactivos junto con su historial. Esta validación fue realizada por el usuario, no repetida por el agente.

| Comprobación | Resultado |
|---|---|
| `pytest tests/cu34 tests/test_cu21_auditoria.py -q` con PostgreSQL | 75 passed: 67 CU34 + 8 regresión de auditoría |
| Autorización | Ocho operaciones, anónimo, admin de clínica, rol SUPER de tenant y SUPERVISOR global; sin fallback de privilegio por ID |
| Validaciones | Cadenas monetarias precisas, JSON numérico no finito retorna 422 (no 500), tipos estrictos, servicios, unidades, límites, BOB/MENSUAL y campos extra |
| Transacciones | Fallo de auditoría revierte creación, nueva versión y desactivación |
| Concurrencia PostgreSQL | Dos creaciones mismo código: una gana; dos ediciones misma base: una versión; dos desactivaciones: un evento de cambio |
| Inmutabilidad PostgreSQL | UPDATE/DELETE directo rechazado; precio histórico original conservado; monto máximo exacto |
| Alembic | Cadena completa desde base vacía hasta `cu34_catalogo_016`; downgrade/upgrade vacío; downgrade con historial rechazado |
| Frontend | 12 passed en dos archivos: 11 catálogo + 1 regresión de navegación administrativa |
| Compilación producción | Exit 0; chunk planes lazy 31,29 kB; avisos de presupuesto indicados abajo |
| Edge + Angular + FastAPI + PostgreSQL | Login real, creación, edición, consulta de versión 1 después de versión 2, cancelar y confirmar desactivación, recarga/persistencia y viewport móvil 390 px sin desborde global |
| OpenSpec | `doctor`, especificación `subscription-plan-catalog` y cambio `cu34-catalogo-planes` válidos |

La revisión visual de capturas confirmó tabla/panel en escritorio y disposición vertical con tabla desplazable en móvil. Capturas locales ignoradas por Git: `backend_Telemedicina/tmp/cu34-desktop.png` y `cu34-mobile.png`.

## Límites y verificaciones no verdes

- `openspec validate --specs`: 7 pasan y 1 falla. `live-queue` preexistente no contiene la sección `## Purpose`. No se reescribió esa especificación ajena.
- Pruebas adicionales de clínicas: 6 pasan; `test_registro_publico_crea_clinica_y_admin` falla por autoincremento BIGINT de `clinicas.id_clinica` en SQLite. El catálogo no modifica ese modelo ni implementa el registro de entidades. Se corrigió únicamente la nulabilidad del mapeo Usuario para reflejar la migración 001 y admitir el superadmin real.
- Build: bundle inicial 536,47 kB frente a aviso de 500 kB; tres estilos de laboratorio de 96,17 kB frente a aviso de 50 kB; aviso existente de prerender/outputMode. No se relajaron presupuestos para ocultarlos.
- Pytest emite dos avisos de dependencias: alias CallSpec2 de anyio y uso de httpx por TestClient de Starlette. No son fallos de CU34.
- No se ejecutó la suite completa de todos los módulos ni pruebas sobre una base de producción. No se probó renovación ni preservación de suscripciones reales: CU31 no existe. Se verificó exclusivamente la preservación de las versiones históricas del catálogo.
- No se desplegó. La migración de Neon sigue pendiente de la operación de despliegue autorizada correspondiente.

## Reproducción e integración futura

Consultar `backend_Telemedicina/docs/CU34.md` para comandos de entorno aislado, pruebas, migración futura y archivos afectados. Contrato en `openspec/contracts/planes.md`: consumidores futuros referencian `VersionPlan.id`, no resuelven siempre `Plan.version_actual`. CU34 no agrega modelos de suscripción, pagos, sedes ni mediciones de consumo.
