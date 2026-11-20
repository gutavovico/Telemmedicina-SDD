# Verificaciones del change `cu11-resultados-laboratorio`

Registro de las verificaciones previas (grupo 0 de `tasks.md`) y de la evidencia de implementación. Las verificaciones previas fueron ejecutadas por el usuario el 2026-11-18; la evidencia de implementación se completa conforme avanzan los grupos.

## Grupo 0 — Verificaciones previas

### 0.1 Q2 — límite de cuerpo de la plataforma (Render)

Comando: `POST` sin token a `https://backend-telemedicina.onrender.com/api/v1/documentos` con cuerpo binario.

| Cuerpo | Resultado | Esperado | Coincide |
|---|---|---|---|
| 11 MB | HTTP 401 | `401` o `422` | Sí |
| 101 MB | HTTP 401 | `401` o `422` | Sí |

Conclusión: la plataforma no corta peticiones de hasta 101 MB antes de que lleguen a la API. El tope de 100 MB por petición se mantiene y ya figura en la fila `LOTE_INVALIDO` del contrato.

### 0.2 Q4 — `pacientes` en la base real (Neon)

| Consulta | Resultado | Esperado | Coincide |
|---|---|---|---|
| Columnas | `ci` varchar NOT NULL; `complemento` varchar nullable; `id_clinica` bigint nullable; `id_usuario` bigint nullable | `id_clinica` bigint nullable | Sí |
| Conteo | `total = 17`, `sin_clinica = 2` | `sin_clinica = 0` | **No (excepción aprobada)** |
| Restricciones | `pacientes_pkey (id_paciente)`; `uq_pacientes_ci_complemento UNIQUE (ci, complemento)`; `pacientes_id_clinica_fkey` → `clinicas`; `pacientes_id_usuario_fkey` → `usuarios` ON DELETE SET NULL; NOT NULL de apellidos, ci, created_at, estado, fecha_nacimiento, genero, id_paciente, nombres, telefono, updated_at | Única sobre `(ci, complemento)` | Sí |
| `alembic_version` | `cu36_billing_overages_024` | `cu36_billing_overages_024` | Sí |

Consecuencias confirmadas:
- La columna `id_clinica` existe, por lo que el filtro de pacientes por clínica es posible.
- Con la restricción única global `(ci, complemento)`, `PACIENTE_AMBIGUO` es prácticamente inalcanzable (se conserva como defensa y se prueba en 6.3 con datos de prueba).
- `complemento` es nullable en la base real: la correspondencia lo normaliza con `COALESCE(complemento, '') = ''` (ver `design.md` D4).
- La base está en la cabeza esperada: la nueva revisión 025 cuelga de `cu36_billing_overages_024`.

## Hallazgos abiertos

### H-1. Dos pacientes sin clínica (calidad de datos; no bloquea el change)

2 de 17 pacientes tienen `id_clinica` NULL: `id_paciente = 1` (Maria Rodriguez, CI 982-11-2) e `id_paciente = 2` (Juan Gómez, CI 451-88-9). Ambos tienen `id_usuario` nulo, por lo que la clínica no puede derivarse de la cuenta.

Efecto sobre CU11: como toda validación de pertenencia es la igualdad `Paciente.id_clinica == id_clinica_sesion` (que en SQL no coincide con `NULL`, ver `design.md` D4), esos pacientes se comportan como inexistentes: 404 en la carga manual y en la resolución de pendientes, y `PACIENTE_NO_ENCONTRADO` (resultado `PENDIENTE_REVISION`) en la sincronización. **No podrán recibir resultados de CU11 hasta que se les asigne una clínica.** Estado: abierto; la regularización de datos la decide y ejecuta el usuario (propuesta en el reporte de la pasada del 2026-11-18, sin ejecutar).

## Grupo 1 y 2 — Evidencia de implementación (pasada del 2026-11-18)

Entorno de las pruebas: variables `DB_HOST=127.0.0.1 DB_PORT=1` para que ninguna prueba pueda abrir una conexión real (las pruebas que arrancan el `lifespan` de la app usan `SessionLocal`). Ninguna operación se ejecutó contra Neon.

**Línea base (antes de los cambios):** `22 failed, 553 passed, 30 skipped, 8 warnings, 19 errors, 65 subtests passed in 99.24s`.
**Final (con las pruebas nuevas de CU11):** `22 failed, 599 passed, 30 skipped, 9 warnings, 19 errors, 65 subtests passed in 95.52s`.
Los 22 `FAILED` y los 19 `ERROR` son los mismos ids que en la línea base (41 de 41, comparación exacta); las 46 pruebas nuevas pasan. Causas preexistentes ajenas a CU11: esquema SQLite de CU10 sin `tenant_subscriptions`, módulos `apscheduler` y `reportlab` no instalados, y `test_integrated_migration_graph_has_one_head` que aún espera la cabeza `cu35_cu18_convergencia_023`.

| Tarea | Evidencia |
|---|---|
| 1.1 | `tests/cu11_support.py` y `tests/test_cu11_support_smoke.py` (SQLite en memoria + override de `get_db`; semilla de dos clínicas, roles, permisos, pacientes —uno sin clínica—, catálogo, orden `FIRMADA` y fuente). 9 pruebas de grupo 1 pasan junto con 1.2 y 1.3. |
| 1.2 | `test_auditoria_misma_transaccion`: `rollback` descarta dato y traza; `commit` los persiste; una auditoría que falla no deja el dato. |
| 1.3 | `tests/test_cu11_conventions.py`: análisis con `ast` de `laboratory_results/` y `laboratory_sync/` (cero `.query(`, `AsyncSession`, `async def`); el escáner detecta los tres casos en archivos temporales e ignora docstrings. |
| 2.1 | `alembic heads` antes de agregar la revisión: cabeza única `cu36_billing_overages_024`; después: `cu11_resultados_laboratorio_025 (head)`, única. |
| 2.2 | `alembic/versions/025_resultados_laboratorio_cu11.py`. `tests/test_cu11_migration.py` (4 pruebas): cabeza única y `down_revision`, upgrade/downgrade/upgrade en SQLite, paridad modelos-migración (equivale a `alembic check` de las 4 tablas, incluidos los nombres de los `CHECK`) y SQL offline de PostgreSQL aditivo. Además, en un PostgreSQL 16 local desechable (contenedor Docker `pgvector/pgvector:pg16`, puerto 55432, ya eliminado): cadena completa `upgrade head` hasta 025, `downgrade -1` (versión vuelve a `cu36_billing_overages_024`, 0 tablas y 0 permisos de CU11, 6 permisos `documents:*` intactos) y nuevo `upgrade head` (4 tablas, 4 permisos, 10 asignaciones). |
| 2.3 | `tests/test_cu11_permissions.py`: matriz exacta por rol (ADMIN 4, MEDICO 3, RECEPCION 2, PACIENTE 1), sin rol `LABORATORIO`, sembrado idempotente y downgrade que solo retira `lab_results:*`. En el PostgreSQL desechable la matriz resultante fue idéntica. |
| 2.4 | `alembic/env.py` importa los modelos nuevos; la prueba de paridad modelos-migración pasa. |
| 2.5 | `tests/test_cu11_constraints.py` (28 pruebas) y comprobación equivalente en PostgreSQL real: `ck_resultado_incorporado_completo`, `ck_resultado_pendiente_sin_expediente`, `ck_resultado_tamano`, `ck_resultado_content_type`, `ck_resultado_responsable`, `uq_resultado_lab_fuente_externo`, `uq_resultado_lab_manual_hash` (parcial) y `uq_fuentes_lab_clinica_codigo` rechazan lo esperado. |
| 2.6 | `test_asignacion_manual_en_rol_nuevo` y `test_la_matriz_de_cu11_es_coherente_con_la_de_cu12`: `lab_results:*` aparece en `list_permissions`; un rol `Administrador` creado como en `auth/clinicas` no los tiene y los recibe con `replace_role_permissions`. Ningún archivo de `app/modules/auth/clinicas/` ni de `app/modules/tenants/` fue modificado. |

Hallazgo de entorno (preexistente, no corregido): `alembic current` falla con `KeyError: 'destination_rev'` por la lógica personalizada de `alembic/env.py`; `alembic upgrade`, `downgrade` y `heads` funcionan.

## Grupo 3 — Evidencia de implementación (backend, bloque A; pasada del 2026-11-18)

Entorno: `DB_HOST=127.0.0.1 DB_PORT=1` en toda corrida de pytest; storage de pruebas en `tmp_path`; ninguna operación contra Neon.

**Suite completa (misma línea base de la pasada anterior):**
`22 failed, 553 passed, 30 skipped, 8 warnings, 19 errors, 65 subtests passed in 99.24s` → `22 failed, 808 passed, 30 skipped, 9 warnings, 19 errors, 65 subtests passed in 101.29s`.
Los 41 ids que fallan o dan error (22 `FAILED` + 19 `ERROR`) son exactamente los mismos que en la línea base; las 255 pruebas nuevas de CU11 pasan (46 de los grupos 1 y 2 más 209 de este grupo).

| Tarea | Evidencia |
|---|---|
| 3.1 | Paquete `laboratory_results/` con `models`, `schemas`, `service`, `router`, `dependencies` y `files`; `python -c "from app.main import app"` importa; `tests/test_cu11_constraints.py` verde. |
| 3.2 | `tests/test_cu11_files.py`: `.exe`/`.docx`, firma falsa, 10 MB exactos y +1 byte (el corte por tamaño no lee el archivo completo), 0 bytes, nombre con `../`, tipo declarado inconsistente y cada formato válido. |
| 3.3 | `tests/test_cu11_permissions.py`: en los 8 endpoints, 401 sin token, 403 para cuenta sin clínica y 403 sin permiso; la descarga exige ambos permisos; la clínica sale de la sesión (el encabezado `X-Tenant-ID` se ignora); ningún módulo de CU11 importa `get_required_tenant_id` ni `get_current_tenant_id` (análisis con `ast`). |
| 3.4 | `tests/test_cu11_manual_upload.py`: 404 por paciente, examen u orden de otra clínica, inexistente o inactivo; 404 por paciente con `id_clinica` NULL; 409 por orden de otro paciente, no firmada o sin el estudio. |
| 3.5 | Mismo archivo: 201 con resultado `INCORPORADO`, `id_documento`, archivo único en el almacenamiento, documento `RESULTADO_LAB` y auditoría; 422 por campos faltantes, valores inválidos, fecha futura y campos `id_clinica`/`tenant_id`/`estado`/`origen`; 422 con códigos `ARCHIVO_*`; fallo de auditoría, fallo posterior al guardado y fallo del almacenamiento no dejan resultado, documento ni archivo huérfano. |
| 3.6 | `RESULTADO_DUPLICADO` (409) sin segundo archivo; mismo archivo en otro paciente válido; aceptado tras anular; la violación del índice único en la base de datos (carrera simulada) se traduce a 409 y borra el archivo. |
| 3.7 | `tests/test_cu11_consulta.py`: listado por rol, estados que exigen `lab_results:review`, filtros y paginación, `/me`, expediente (pendientes y anulados no aparecen), detalle con redacción por permisos, 404 indistinguible entre clínicas. |
| 3.8 | `tests/test_cu11_descarga.py`: PDF, JPG y PNG con su `Content-Type` real y SHA-256 idéntico, `Content-Disposition` seguro, `X-Content-Type-Options: nosniff`, 403 para RECEPCION, 404 para anulado, pendiente, otro paciente y otra clínica, auditoría de la descarga y sin entrega si la auditoría falla. |
| 3.9 | `tests/test_cu11_revision.py`: asignar (documento creado solo entonces), descartar, validaciones 422, 409 por transición inválida, 403 sin `lab_results:review`, 404 entre clínicas, anular (resultado y documento `ANULADO`, archivo conservado) y ausencia de `DELETE`. |
| 3.10 | `test_openapi_lista_exactamente_las_rutas_del_contrato`: exactamente las 8 operaciones del contrato; el formulario de carga no publica campos de clínica; `main.py` no referencia CU11. |
| 3.11 | `tests/test_cu11_tenant_isolation.py`: matriz paciente, orden, examen y resultado en ambos sentidos, pacientes con `id_clinica` NULL y cuenta de paciente cuyo perfil no tiene clínica; respuestas de error sin datos de la otra clínica. |
| 3.12 | `tests/test_cu11_integration_cu10_cu12.py`: la orden y su documento `ORDEN_LAB` quedan idénticos tras la carga; el documento `RESULTADO_LAB` referencia `id_resultado_laboratorio`; CU12 lo lista y deja de listarlo al anular; un pendiente no aparece en CU12. |
| 3.13 | `tests/test_cu11_audit_cu21.py`: `GET /api/v1/audit-log?tabla_afectada=resultados_laboratorio` devuelve las trazas al administrador de la misma clínica y 404/0 resultados al de otra. |

Comprobación de utilidad de las pruebas (mutaciones temporales, revertidas): al hacer que `id_clinica` NULL "coincida" fallan 5 pruebas; al quitar el filtro de clínica de `obtener_visible` fallan 5 pruebas.

## Grupo 4 — Evidencia de implementación (web, bloque A; pasada del 2026-11-18)

Todo el código web está bajo `frontend_Telemedicina/src/app/features/medical-records/documentos/resultados-laboratorio/` (la carpeta vigente `documentos/`); la carpeta duplicada `documents/` no se tocó. Cambios mínimos fuera de esa carpeta: 4 rutas en `src/app/app.routes.ts`, un enlace de menú por rol y un método en `admin-layout`.

**Pruebas unitarias (`npm run test:vitest`):**
Línea base: `Test Files 51 passed | 1 skipped (52)`, `Tests 425 passed | 5 skipped (430)`, sin fallos.
Final: `Test Files 63 passed | 1 skipped (64)`, `Tests 558 passed | 5 skipped (563)`, sin fallos (+133 pruebas nuevas). `npm run build`: correcto, sin errores ni advertencias.

**Cypress:** `cypress/e2e/cu11-resultados-laboratorio.cy.ts`, 20 pruebas, 20 pasan (`npx cypress run --spec ... --config baseUrl=http://127.0.0.1:4200`). Todas las llamadas al backend se simulan con `cy.intercept` (no hace falta API). En este entorno la variable `ELECTRON_RUN_AS_NODE=1` impide arrancar Cypress; hay que ejecutarlo con `env -u ELECTRON_RUN_AS_NODE`. Los demás specs de `cypress/e2e/` usan un backend real y no se ejecutaron.

| Tarea | Evidencia |
|---|---|
| 4.1 | `models/laboratory-result.models.ts` (interfaces del contrato, sin `any`), `services/laboratory-results.service.ts` y su spec con `HttpTestingController`: URLs y parámetros de los 8 endpoints, `FormData` sin `Content-Type` manual y sin `id_clinica`/`tenant_id`/`estado`/`origen`, descarga como Blob con el `Content-Type` real, y el error de un Blob convertido a JSON. |
| 4.2 | `laboratory-result-form` (formulario reactivo tipado) con `lab-patient-picker` (reutiliza `PatientService.getPatients`) y el catálogo de CU10. Pruebas: validaciones del cliente, éxito, y los códigos `ARCHIVO_*`, `RESULTADO_DUPLICADO`, `PACIENTE_NO_ENCONTRADO`, `EXAMEN_NO_ENCONTRADO`, `ORDEN_*` mostrados junto a su campo. Cypress: carga válida con multipart real, archivo inválido, 422 de archivo y de lista, 409 duplicado. |
| 4.3 | `laboratory-result-list`, `laboratory-result-detail` y `lab-result-file-viewer` (Blob + `URL.createObjectURL`, revocadas al cambiar o destruir). Cypress: listado, vacío, imagen con `blob:`, PDF en marco, descarga y 404 de archivo. |
| 4.4 | `laboratory-result-review`: lista `PENDIENTE_REVISION`, muestra los datos crudos, asigna o descarta. Cypress: asignar, descartar con motivo obligatorio y 404 de paciente de otra clínica. |
| 4.5 | `LaboratoryResultAccessService` sobre el `PermissionsService` existente; rutas con `[staffGuard, permissionsGuard]` (`src/app/app.routes.cu11.spec.ts`); RECEPCION sin archivo, observaciones, hash, filtro de estado ni revisión; PACIENTE no entra al panel. |
| 4.6 | Cypress completo, incluido el flujo carga manual → consulta → anulación. |

### Hallazgo H-2. `lab_orders:read` no está sembrado por ninguna migración del repositorio — RESUELTO (2026-11-19)

**Resolución (comprobada por el usuario en Neon):** los permisos `lab_orders:create`, `lab_orders:read` y `lab_orders:download` existen en los **roles globales** (`id_clinica` nulo) y están asignados así: ADMIN y MEDICO con los tres, RECEPCION con `read` y `download`, PACIENTE solo con `download` (coincide con la matriz de `tests/test_cu10_laboratory_orders.py`). Por tanto el selector de estudios de la web (`GET /api/v1/ordenes-laboratorio/examenes`, que exige `lab_orders:read`) funciona para ADMIN, MEDICO y RECEPCION; el aviso y el campo de texto libre del formulario quedan solo como degradación para una clínica cuyo rol no tenga el permiso. Lo que sigue es el análisis original, conservado como registro:

El selector de estudio usa `GET /api/v1/ordenes-laboratorio/examenes` (CU10), que exige `lab_orders:read`.
- Búsqueda en `alembic/versions`, `scripts`, `insert_roles.py`, `insert_data.py`, `deploy` y `docs`: **ninguna migración ni semilla crea ni asigna `lab_orders:create|read|download`** (las migraciones 004 y 006 solo siembran `documents:*`, entre ellos `documents:read:lab_orders`, que es otro permiso).
- La única definición de la matriz está en `tests/test_cu10_laboratory_orders.py`: ADMIN y MEDICO con `create/read/download`, RECEPCION con `read/download`, PACIENTE con `download`.
- Por tanto no se puede afirmar desde el código que ADMIN, MEDICO y RECEPCION tengan `lab_orders:read` en Neon (README_Miguel.md dice que CU10 se verificó en Neon, lo que sugiere una carga manual fuera del repositorio).
- Comprobación de solo lectura para el usuario (en el editor SQL de Neon):
  ```sql
  SELECT r.id_clinica, r.nombre AS rol, p.nombre AS permiso
  FROM rol_permisos rp
  JOIN roles r ON r.id_rol = rp.id_rol
  JOIN permisos p ON p.id_permiso = rp.id_permiso
  WHERE p.nombre IN ('lab_orders:read', 'lab_orders:create', 'lab_orders:download')
  ORDER BY r.id_clinica, r.nombre, p.nombre;
  ```
- Comportamiento de la web si falta el permiso: el formulario y la revisión muestran el aviso «No tiene permiso para consultar el catálogo de estudios (lab_orders:read)…» y ofrecen escribir el código del estudio; el servidor lo valida contra el catálogo de la clínica (`EXAMEN_NO_ENCONTRADO` si no existe). No se inventó ningún endpoint.
- Opciones si falta (decisión del usuario, fuera de este change): sembrar `lab_orders:read` para ADMIN, MEDICO y RECEPCION (backend); o pedir un catálogo bajo `lab_results:*` (backend, requeriría actualizar contrato); o mantener el campo de texto.

## Grupo 5 — Evidencia de implementación (móvil, bloque A, solo lectura; pasada del 2026-11-18)

Alcance: `mobile_telemedicina/lib/features/medical_records/` (tres capas), solo `GET /api/v1/resultados-laboratorio/me` y `GET .../{id}/archivo`. No se tocaron backend, web, contrato ni specs. `main.dart` no se modificó: la pantalla de CU11 crea su propio provider.

**Línea base (antes de cambiar):** `flutter analyze --no-pub`: 12 issues (3 errores en `test/asistencia_datasource_test.dart` por `FakeApiClient` desactualizado + 9 infos previos). `flutter test --no-pub`: `+379 -2: Some tests failed.` (no cargan `test/asistencia_datasource_test.dart` y `test/analytics_reports_test.dart`).

**Final:** `flutter analyze --no-pub`: `12 issues found.`, lista idéntica a la línea base (ningún aviso nuevo en archivos tocados). `flutter test --no-pub`: `+443 -2: Some tests failed.`, los mismos dos archivos fallidos; +64 pruebas nuevas, todas en verde. `flutter test test/clinical_document_unit_test.dart`: `+29: All tests passed!` sin modificarlo.

| Tarea | Evidencia |
|---|---|
| 5.1 | `LaboratoryResult`/`LaboratoryResultPage` (dominio), `LaboratoryResultModel`/`LaboratoryResultPageModel` con `fromJson`/`toJson` con todos los campos del contrato y tolerancia a `observaciones`/`hash_archivo` ausentes u ocultos, `LaboratoryResultService`, `LaboratoryResultRepository` + impl, `GetMyLabResultsUseCase`, `DownloadLabResultUseCase`. `test/cu11_laboratory_results_data_test.dart` (30): parseo completo/mínimo/campos ocultos/round-trip, repositorio con éxito, filtros, URL sin `tenant_id`/`id_clinica`, y que el cliente nunca invoca POST/PATCH/DELETE. |
| 5.2 | `LaboratoryResultsProvider` (initial/loading/success/error, paginación, descarte de respuestas obsoletas), `LabResultsListScreen` (loading, vacío, error con Reintentar, pull-to-refresh, carga de más páginas), `LabResultStatusBadge` (icono + texto). `test/cu11_laboratory_results_presentation_test.dart`. |
| 5.3 | `LabResultViewerScreen` + `LabResultFileController`: descarga con Bearer como bytes, archivo temporal (`path_provider`), PDF con `SfPdfViewer.file` (memoria si no hay disco), JPG/PNG con `Image.file`/`Image.memory`; el tipo se detecta por los primeros bytes (el cliente HTTP no devuelve cabeceras) con `content_type` del listado como respaldo; el temporal se borra al salir y una descarga que termina tras salir no deja archivos. Pruebas de controlador y de visor (PDF con visor inyectado, PNG real, loading, error, reintento, borrado). |
| 5.4 | `LabResultErrorMapper` acepta las tres formas de `detail` (objeto `{codigo, mensaje}`, lista de validación, texto) y traduce 401, 403 (incluida la descarga sin `documents:read:lab_results`), 404 (inexistente/otra clínica; `/me` sin perfil de paciente), red, timeout y archivo vacío. Token y `X-Tenant-ID` siguen en `FlutterSecureStorage` vía `ApiClient` (sin cambios). Pruebas del mapper y del repositorio. |
| 5.5 | Cambio mínimo en `documents_list_screen.dart` (+13 / -3 líneas): el chip `RESULTADO_LAB` abre `LabResultsListScreen` sin cambiar el filtro de CU12. `test/cu11_documents_list_chip_test.dart` (2): el chip navega y no consulta CU12 con `RESULTADO_LAB`; los otros chips siguen filtrando. |

**Limitaciones y desviaciones (informadas, sin corregir):**
- `ApiClient` (compartido) conserva el cuerpo del error (`details`) solo en 400, 422 y estados sin tratamiento específico; en 401/403/404 solo conserva el texto, y el `detail` en forma de objeto con `codigo` llega como «Error del servidor (Código N)». El mapper cae entonces al estado HTTP y a la operación (listado/archivo). Recomendación (fuera de este alcance): conservar `details` en todos los estados.
- La tarea 5.3 menciona `SfPdfViewer.memory`/`Image.memory`; se usa el archivo temporal (exigido en el alcance de esta pasada) y la memoria solo como respaldo.
- 5.5 se cumple con el chip (la tarea dice «chip o un elemento»); un elemento de tipo `RESULTADO_LAB` en el listado «Todos» sigue abriendo el visor de CU12, porque cambiar la tarjeta excede el cambio mínimo pedido.
- Sin prueba de integración ni ejecución contra un backend real en esta pasada (ver guía manual en el reporte).

## Grupo 6 — Evidencia de implementación (backend, bloque B: fuentes y sincronización; pasada del 2026-11-19)

Alcance: `backend_Telemedicina/app/modules/medical_records/laboratory_sync/` (`dependencies.py`, `schemas.py`, `service.py`, `router.py`; `models.py` ya existía del grupo 2), `app/core/body_limit.py` (nuevo, ver «Decisiones») y dos `include_router` en `app/modules/medical_records/router.py`. No se tocó `app/main.py`, ni CU10, ni CU12, ni `auth/`, ni `laboratory_results/`; no hay migraciones nuevas (la 025 del grupo 2 ya creó las cuatro tablas). Sesión síncrona con `select()/execute()/scalars()`, sin `.query(`, sin `AsyncSession`, sin `async def` en `laboratory_results/` ni `laboratory_sync/` (`tests/test_cu11_conventions.py` sigue verde).

**Línea base (antes de cambiar):** `python -m pytest tests -q` con `DB_HOST=127.0.0.1 DB_PORT=1`: `22 failed, 808 passed, 30 skipped, 9 warnings, 19 errors, 65 subtests passed in 102.11s`.

**Final:** `22 failed, 1013 passed, 36 skipped, 9 warnings, 19 errors, 65 subtests passed in 117.87s`. Los 41 ids que fallan o dan error (22 + 19) son idénticos a los de la línea base (comparación por `diff` de las listas ordenadas); +205 pruebas nuevas en verde; +6 omitidas (PostgreSQL, ver abajo). `tests/test_cu11_*.py`: `460 passed, 6 skipped`.

| Tarea | Evidencia |
|---|---|
| 6.1 | `tests/test_cu11_fuentes.py` (36): crea con código normalizado a mayúsculas y activa `SI`, código repetido en la clínica 409 `FUENTE_DUPLICADA` (también `lab-central`), mismo código en otra clínica válido, validaciones 422 (código corto/largo/con espacio, `id_clinica`/`tenant_id`, `activa`), listado paginado con filtro `activa`, PATCH de nombre y `activa` con auditoría, el código no se modifica (422), fuente ajena o inexistente 404 sin filtrar datos, 403 (MEDICO, RECEPCION, PACIENTE, sin permisos), 401, cuenta sin clínica 403, `X-Tenant-ID` ignorado, sin `DELETE`/`PUT`. |
| 6.2 | `tests/test_cu11_sync_manifest.py` (62): manifiesto no JSON, vacío, sin `items`, con 51 ítems, `id_externo` repetido, campos obligatorios y límites de cada campo, fecha futura, `id_clinica`/`tenant_id` en la raíz, en un ítem (cualquier valor) y como parte del formulario, fuente inexistente / de otra clínica 404, inactiva 409, todos con «no se crea nada» (sincronización, ítems, resultados, documentos y archivos en cero). 50 ítems con observaciones de 2000 caracteres (≈110 KB) se aceptan. Rechazo previo por `Content-Length` > 100 MB (`LOTE_INVALIDO`, también en reintentos; 100 MB exactos se aceptan). |
| 6.3 | `tests/test_cu11_sync_matching.py` (30): correspondencia válida (documento `RESULTADO_LAB` indexado, trazabilidad completa); paciente inexistente, CI solo en otra clínica y paciente con `id_clinica` NULL quedan `PENDIENTE_REVISION` con `PACIENTE_NO_ENCONTRADO`, sin paciente, sin documento y con los datos crudos; `complemento` NULL real en la base (no `''`) coincide con `''` y con `null` recibidos; `PACIENTE_AMBIGUO` con dos filas de CI repetida y `complemento` NULL; estudio inexistente / inactivo / de otra clínica `EXAMEN_NO_VALIDO`; orden de otro paciente `ORDEN_PACIENTE_NO_COINCIDE`; orden inexistente, de otra clínica, no firmada, anulada o sin el estudio `ORDEN_NO_VALIDA`; el pendiente no aparece en el expediente ni en el listado por defecto y es visible solo con `lab_results:review`; archivos inválidos (`.exe`, firma falsa, vacío, > 10 MB, tipo declarado) aislados del resto del lote. |
| 6.4 | `tests/test_cu11_sync_idempotency.py` (14): reenvío del mismo lote (todo `DUPLICADO`, sin filas ni archivos nuevos, sin nuevas trazas de creación), duplicado de pendiente y de anulado (no se reactiva), `CONTENIDO_DISTINTO` (el original no cambia), otra fuente y otra clínica con el mismo `id_externo` son independientes, caída a mitad del lote (proceso muerto simulado con una `BaseException`) y reenvío completo. Carrera simulada insertando la fila entre la verificación y el INSERT: un solo resultado, ítem `DUPLICADO` (o `CONTENIDO_DISTINTO` si el hash difiere), archivo del perdedor borrado, sin documento ni auditoría del perdedor, y los ítems vecinos del lote se conservan. |
| 6.5 | `tests/test_cu11_sync_registry.py` (15): `COMPLETADA`, `COMPLETADA_CON_ERRORES`, `FALLIDA` y la regla de cierre; informe 1/1/1/1 idéntico en la respuesta y en el detalle; fallo de almacenamiento simulado (`ALMACENAMIENTO_FALLIDO`, sin resultado ni archivo, el lote sigue); fallo de la auditoría de un ítem (`ERROR_INTERNO`, el SAVEPOINT deshace resultado y documento y se borra el archivo); el ítem fallido se reintenta con éxito; la auditoría de cierre va en la misma transacción que los contadores; trazas `CREAR_RESULTADO_LABORATORIO`, `REGISTRAR_RESULTADO_PENDIENTE` y `EJECUTAR_SINCRONIZACION_LABORATORIO` con usuario y clínica, visibles en la bitácora CU21 de su clínica y no en la de otra. |
| 6.6 | `tests/test_cu11_sync_endpoints.py` (21): 201 con el esquema exacto del contrato (cabecera e ítems), listado paginado sin `items` y con filtros `id_fuente`, `estado`, `fecha_desde`, `fecha_hasta`, parámetros inválidos 422, detalle con ítems en orden, 404, 401/403 en cada uno de los cuatro endpoints, cuenta sin clínica, `X-Tenant-ID` ignorado, sin `DELETE`/`PUT`/`PATCH`, y OpenAPI sin `id_clinica`/`tenant_id`. |
| 6.7 | `tests/test_cu11_sync_retry.py` (21): reintento exitoso tras corregir el archivo (`intento` 2, contador de errores baja, estado recalculado, `reintentos` 1), puede terminar `PENDIENTE_REVISION`, sigue fallando sin crear nada, varios reintentos acumulan, `ITEM_NO_REINTENTABLE` (ítem integrado, inexistente, ya reintentado, o petición mezclada: se rechaza completa sin procesar nada), `CONTENIDO_DISTINTO` reintentado con el archivo original queda `DUPLICADO`, sincronización ajena o inexistente 404 sin filtrar datos, fuente distinta `LOTE_INVALIDO`, fuente inactiva 409, 401/403. |
| 6.8 | `laboratory_sync/router.py` registrado desde `medical_records/router.py`; `python -c "from app.main import app"` sin error; `tests/test_cu11_tenant_isolation.py` ampliado (+6, 22 en total): fuentes, sincronizaciones, ítems y resultados sincronizados de una clínica no son visibles, modificables ni reintentables desde la otra, y las respuestas 404 no contienen datos de la otra clínica. |

**Aislamiento por ítem con SAVEPOINT (verificado en SQLite y en PostgreSQL).** Cada ítem se escribe dentro de `begin_nested()` y se confirma al terminar. Hallazgo de entorno: con el driver `pysqlite` sin configuración, un `SAVEPOINT` emitido después de un `SELECT` queda como transacción más externa y su `RELEASE` confirma de inmediato (comprobado con un script de sondeo: el `rollback` externo no lo deshacía). `tests/cu11_support.py` ahora aplica la receta de SQLAlchemy (`isolation_level = None` + `BEGIN` explícito) al motor de pruebas, de modo que el SQLite de pruebas anida los SAVEPOINT como PostgreSQL; las 255 pruebas previas de CU11 siguen en verde con ese cambio.

**Validación en PostgreSQL 16 desechable** (contenedor local `pgvector/pgvector:pg16`, puerto 55433, base `cu11b`, `alembic upgrade head` hasta `cu11_resultados_laboratorio_025`, contenedor eliminado al terminar; ninguna conexión a Neon): `tests/test_cu11_sync_postgres.py` con `CU11_TEST_PG_URL=postgresql+psycopg2://...`, `6 passed` (se omite si la variable no está definida): SAVEPOINT que deshace solo el ítem fallido y rollback externo que deshace lo liberado, SAVEPOINT posterior a un `SELECT`, lote mixto con reenvío idempotente, carrera simulada, **carrera real con dos hilos y dos conexiones** (ambos verifican, ambos insertan: exactamente un `INCORPORADO` y un `DUPLICADO`, un archivo, un documento) y fallo posterior a la escritura que no deja filas, documentos ni archivos. La primera ejecución de la carrera real falló por un defecto de la propia prueba (la barrera también bloqueaba la relectura posterior al `IntegrityError`), no del servicio: el log mostraba el `UniqueViolation` de `uq_resultado_lab_fuente_externo` y la relectura; se corrigió la prueba.

**Mutaciones temporales** (se aplicó el cambio, se corrió el subconjunto de pruebas, se restauró el servicio desde una copia y se verificó con `md5sum`): (1) quitar el filtro `id_clinica` de `_sincronizacion_o_404` → 3 fallos (reintento y detalle ajenos, aislamiento); (2) `_buscar_existente` siempre `None` (sin comprobación de duplicado) → 12 fallos; (3) quitar `Paciente.id_clinica ==` de la correspondencia → 3 fallos; (4) reemplazar `begin_nested()` por un contexto nulo (sin SAVEPOINT) → 3 fallos; (5) desactivar el tope de 100 MB → 2 fallos.

**Decisiones y desvíos (informados; ningún artefacto del change fue modificado):**
- **SAVEPOINT frente a `design.md` D3.** D3 dice «no se usan SAVEPOINT» (por pysqlite). Se siguió la instrucción de la pasada: SAVEPOINT por ítem **más** `commit` por ítem (así lo ya integrado sobrevive a una caída a mitad del lote, como pide el escenario de reintento tras caída). D3 debería actualizarse al aprobar.
- **`app/core/body_limit.py` (archivo nuevo, no es `main.py`).** FastAPI lee y decodifica el multipart antes de resolver las dependencias, por lo que un `Depends` no puede rechazar por `Content-Length`; hace falta envolver el manejador de la ruta con un envoltorio `async`. Como los módulos de CU11 no pueden declarar `async def`, la clase base genérica `ContentLengthLimitedRoute` vive en `app/core/` y `laboratory_sync/router.py` la subclasifica (`RutaDeLote`, tope 100 MB). Consecuencia: la petición enorme se rechaza antes de autenticar (422 en lugar de 401).
- **Código de error no catalogado: `SINCRONIZACION_NO_ENCONTRADA`** (404 de la sincronización inexistente o ajena); el contrato dice «404» sin código. **`ERROR_INTERNO`** (ítem): fallo inesperado aislado en un ítem (detalle genérico, causa en el log); el contrato no lo cataloga. Ambos conviene agregarlos al contrato.
- **Manifiesto de más de 1 MB:** Starlette responde `400` con `{"detail": "Part exceeded maximum size of 1024KB."}` (texto plano, no `LOTE_INVALIDO`); con 50 ítems el manifiesto real pesa ≈110 KB en el peor caso, así que solo ocurre con manifiestos fabricados.
- **Dos partes `archivos` con el mismo nombre** son ambiguas: se rechaza el lote (`LOTE_INVALIDO`). Varios ítems pueden referenciar la misma parte. Las partes no referenciadas por el manifiesto se ignoran.
- **`reintentos` de la sincronización** sube en 1 por petición de reintento (no por ítem); el contador por ítem es `intento`.
- **Un ítem `ITEM_NO_REINTENTABLE` rechaza la petición completa** (422) antes de procesar nada; el contrato admite también «422 / ítem».
- **Pendientes:** se guardan con `id_paciente`, `id_documento` y `id_orden` nulos aunque el paciente se haya identificado; `id_examen` se conserva si el estudio es válido; los datos crudos (`ci`, `complemento`, `codigo_examen`, `id_orden`) van solo en el pendiente y la auditoría no copia la CI.
- **Auditoría de cierre** (`EJECUTAR_`/`REINTENTAR_SINCRONIZACION_LABORATORIO`) se escribe al final, en la misma transacción que contadores y estado; si el proceso muere antes, la sincronización queda `EN_PROCESO` con sus ítems ya confirmados y sus trazas de ítem, pero sin la traza de cierre (se cubre con una prueba).

## Grupo 7 — Evidencia de implementación (web, bloque B: fuentes, importación, informe y reintento; pasada del 2026-11-19)

Alcance: `frontend_Telemedicina/src/app/features/medical-records/documentos/resultados-laboratorio/` (carpeta vigente; `documents/` no se tocó). No se modificó el backend, el móvil, el contrato ni el grupo 8. Parte A de esta pasada: contrato, spec `laboratory-sync`, `design.md` D3 y H-2 alineados con el grupo 6 (ver resumen en el reporte de la pasada).

**Línea base (antes de cambiar):** `npm run test:vitest`: `Test Files 63 passed | 1 skipped (64)`, `Tests 558 passed | 5 skipped (563)` (igual que al cierre del grupo 4).
**Final:** `Test Files 75 passed | 1 skipped (76)`, `Tests 716 passed | 5 skipped (721)` (+12 archivos, +158 pruebas, sin fallos). `npm run build`: correcto, sin errores ni advertencias. Cypress `cypress/e2e/cu11-sincronizacion-laboratorio.cy.ts`: **21 pruebas, 21 pasan** (`env -u ELECTRON_RUN_AS_NODE npx cypress run --spec ... --config baseUrl=http://127.0.0.1:4200,video=false,retries=0`, con `ng serve` local; todo el backend simulado con `cy.intercept`); `cypress/e2e/cu11-resultados-laboratorio.cy.ts` (grupo 4) sigue con 20/20.

| Tarea | Evidencia |
|---|---|
| 7.1 | `models/laboratory-sync.models.ts` (interfaces del contrato 2.6 a 2.8, sin `any`; límites 50 ítems, 10 MB, 100 MB, 1 MB) y `services/laboratory-sync.service.ts`: `listarFuentes`, `crearFuente`, `actualizarFuente` (PATCH), `importar`, `reintentar` (multipart con `manifiesto` como texto y una parte `archivos` por archivo, sin fijar `Content-Type`, con `reportProgress` mapeado a `EventoSubida`), `listarSincronizaciones`, `obtenerSincronizacion`. `laboratory-sync.service.spec.ts` (`HttpTestingController`): URLs, parámetros, `FormData`, ausencia de `id_clinica`/`tenant_id`, progreso de subida (con y sin total) y propagación del error. |
| 7.2 | `components/laboratory-sources` (ruta `/admin/resultados-laboratorio/fuentes`, `lab_results:sync`): listado paginado con filtro activa/inactiva, alta con validación de cliente y `FUENTE_DUPLICADA` (409) junto al campo código, activar/desactivar con PATCH, estados de carga/vacío/error. Spec Vitest y Cypress (3 pruebas). |
| 7.3 | `components/laboratory-sync-import` (`.../sincronizaciones/importar`): selector de fuentes activas, manifiesto por archivo `.json` o pegado, varios archivos, validación previa (`utils/laboratory-sync-manifest.ts`: JSON válido, `id_externo` único, correspondencia manifiesto-archivos en ambos sentidos, nombres repetidos, máximo 50 ítems, PDF/JPG/PNG, 10 MB por archivo, 100 MB en total, aviso sobre 50 MB, rechazo de `id_clinica`/`tenant_id`), barra de progreso (`role="progressbar"`), botón deshabilitado durante el envío, errores del servidor en español (`interpretarErrorSincronizacion`: objeto, lista y texto plano, y el `400` de Starlette por un manifiesto de más de 1 MB). `components/laboratory-sync-list` (historial paginado con filtros) y `components/laboratory-sync-detail` (informe: estado del lote incluido `EN_PROCESO`, totales y tabla por ítem con estado, código, mensaje e `intento`). Specs Vitest y Cypress: lote mixto con INCORPORADO, PENDIENTE_REVISION, DUPLICADO y ERROR, reenvío del mismo lote, validaciones de cliente, progreso. |
| 7.4 | Panel de reintento en el detalle: solo los ítems en `ERROR`; el usuario adjunta el archivo corregido de cada uno; la web arma un manifiesto con solo esos ítems (tomados del manifiesto original, con `nombre_archivo` igual al archivo corregido) y llama a `POST .../{id}/reintentos`; actualiza contadores, estado e `intento` con la respuesta; maneja `ITEM_NO_REINTENTABLE` (vuelve a leer el informe) y `SINCRONIZACION_NO_ENCONTRADA`. Specs Vitest y Cypress (reintento de un ítem; solo viaja ese ítem; manifiesto faltante). |
| 7.5 | El informe enlaza la cola de revisión (`laboratory-result-review`, tarea 4.4) cuando hay ítems `PENDIENTE_REVISION` y el usuario tiene `lab_results:review`: `/admin/resultados-laboratorio/revision?id_fuente=<fuente>`. Cambio mínimo en la revisión: lee `?id_fuente=` y lo pasa al listado (sin el parámetro la llamada es idéntica a la del grupo 4; sus pruebas no cambiaron). Cypress: del informe a la cola, con `id_fuente=2` en la petición. **Limitación:** el filtro es por fuente, no por sincronización (el listado del contrato no tiene `id_sincronizacion`). |

**Permisos:** las cuatro pantallas exigen `[staffGuard, permissionsGuard]` con `lab_results:sync` (`app.routes.cu11-sync.spec.ts`: rutas, orden de las estáticas frente a `resultados-laboratorio/:id`, y guards por rol: solo ADMIN entra; MEDICO y RECEPCION son redirigidos a `/sin-permisos`; un PACIENTE no entra). `LaboratoryResultAccessService.puedeSincronizar()` (spec por rol) gobierna los controles: el listado de resultados ofrece el enlace «Sincronizaciones» solo con `lab_results:sync`, y el informe ofrece reintento solo con ese permiso. Cypress: MEDICO redirigido en las cuatro rutas y sin enlace; ADMIN con enlace.

**Cambios mínimos a archivos del grupo 4** (sus pruebas siguen verdes sin modificarlas): `models/laboratory-result.models.ts` (`PERMISOS_RESULTADOS.sync` y los códigos del bloque B), `services/laboratory-result-access.service.ts` (`puedeSincronizar`), `utils/laboratory-result-errors.ts` (mensajes en español de los códigos del bloque B, nombres de campo y `mensajeDeCodigo` exportado), `testing/lab-result.testing.ts` (`sincronizar` en `accesoFalso`), `components/laboratory-result-list/laboratory-result-list.html` (enlace a sincronizaciones), `components/laboratory-result-review/laboratory-result-review.ts` (`id_fuente`) y `app.routes.ts` (cuatro rutas antes de `resultados-laboratorio/:id`).

**Hallazgos de la pasada:**
- El informe `GET /{id}` no incluye los datos de cada ítem (CI, estudio, fecha…), solo `id_externo`, resultado, error e `intento`; por eso el reintento necesita el manifiesto original. La web lo conserva en `sessionStorage` al importar (solo en esa pestaña) y, si no está, pide cargarlo de nuevo.
- Un formulario con `(ngSubmit)` sin `FormsModule`/`ReactiveFormsModule` no intercepta el envío y recarga la página: lo detectó Cypress, no las pruebas unitarias que llamaban al método directamente. Se usa `(submit)` con `preventDefault` y hay una prueba que dispara el evento `submit` real.
- Entorno (causa no determinada): después de ejecutar `npm run build`, `ng serve` y Cypress, `npm run test:vitest` falló varias veces con «Vitest failed to find the runner» en TODOS los archivos (también en los antiguos y en un spec trivial), sin relación con el código: una copia idéntica del árbol fuera de OneDrive pasaba, al mover `dist/` aparte volvía a pasar y, más tarde, la suite volvió a pasar en sitio tras borrar los artefactos (`dist/`, `.angular/`, `cypress/videos`, `cypress/downloads`) y la copia. Las cifras finales son de la suite completa, sin artefactos, ejecutada en sitio (`75 passed | 1 skipped`, `716 passed | 5 skipped`) y repetida en la copia con el mismo resultado. Si reaparece, borrar `dist/`, `.angular/` y los artefactos de Cypress y reintentar.

## Cierre — verificación integral del grupo 8 (pasada del 2026-11-19)

Alcance: solo verificación. No se ejecutó `/opsx:sync` ni `/opsx:archive`. Único cambio de código de producción: un defecto de CU11 encontrado por la revisión de seguridad (logs), corregido de forma mínima y con prueba (ver «Defecto corregido»).

### Suites completas (8.1 a 8.3)

| Repo | Línea base / referencia | Resultado final |
|---|---|---|
| backend (`DB_HOST=127.0.0.1 DB_PORT=1`, `python -m pytest tests -q`) | `22 failed, 808 passed, 30 skipped, 9 warnings, 19 errors` (antes de CU11 grupo 6); referencia previa al cierre `22 failed, 1013 passed, 36 skipped, 19 errors` | Corrida 1 (antes del arreglo de logs): `22 failed, 1013 passed, 36 skipped, 9 warnings, 19 errors, 65 subtests passed in 239.68s`, los mismos 41 ids. Corrida determinista final (con `STRIPE_SECRET_KEY` vacía, Stripe simulado, sin red): `22 failed, 1018 passed, 36 skipped, 9 warnings, 19 errors, 65 subtests passed in 108.62s`: los mismos 41 ids y nada más (+5 pruebas nuevas de `tests/test_cu11_logs.py`). |
| frontend `npm run test:vitest` | `Test Files 63 passed \| 1 skipped (64)`, `Tests 558 passed \| 5 skipped (563)` | `Test Files 75 passed \| 1 skipped (76)`, `Tests 716 passed \| 5 skipped (721)` |
| frontend `npm run build` | — | exit 0, `Application bundle generation complete`, sin errores ni advertencias |
| Cypress (solo los dos specs de CU11, con `env -u ELECTRON_RUN_AS_NODE`, `ng serve` local, `cy.intercept`) | — | `cu11-resultados-laboratorio.cy.ts`: 20 passing. `cu11-sincronizacion-laboratorio.cy.ts`: 21 passing con la máquina libre. Una corrida concurrente con el pytest completo dio 8 fallos, todos `Timed out after waiting 60000ms for your remote page to load` (carga de la máquina, no del código); repetida en solitario pasó 21/21. |
| mobile `flutter analyze --no-pub` | `12 issues found.` | `12 issues found.`, lista idéntica a la línea base (3 errores en `test/asistencia_datasource_test.dart` y 9 infos previos) |
| mobile `flutter test --no-pub` | `+379 -2` | `+443 -2: Some tests failed.`: los mismos dos archivos preexistentes (`test/asistencia_datasource_test.dart` y `test/analytics_reports_test.dart`); +64 pruebas nuevas de CU11 |

Los demás specs de Cypress (`cu10`, `cu12`, `cu17`, `cu23`) requieren un backend real y NO se ejecutaron; por eso `npm run test:e2e` completo (parte de 8.2) no se da por verificado.

**Fallos intermitentes ajenos a CU11 (red):** `tests/test_cu31_subscription_payments.py` hace una llamada real a Stripe en `POST /api/v1/subscriptions/checkout` cuando hay una clave configurada en el entorno; si la red a `api.stripe.com` es lenta o no responde, el endpoint devuelve `502` y fallan, según la corrida, hasta 3 de sus pruebas (`test_webhook_raiz_despacha_suscripcion_por_metadatos`, `test_webhook_sin_firma_valida_rechaza_y_no_confirma`, `test_confirmacion_idempotente_y_extension_de_vigencia`). Cada una pasa en solitario y todas pasan con Stripe simulado. Con la clave vacía (modo simulado previsto en `app/core/config.py`) la suite es determinista. Sugerencia: fijar `STRIPE_SECRET_KEY` vacía en las corridas de verificación.

### Trazabilidad de criterios (8.4)

Notación: backend `tests/<archivo>::<prueba>`; web `<spec>`; Cypress `cu11-resultados-laboratorio.cy.ts` (A) y `cu11-sincronizacion-laboratorio.cy.ts` (B); móvil `test/<archivo>`. El móvil es de solo lectura (I-116) y solo cubre C7.

| Criterio | Requisitos y escenarios (spec) | Pruebas automáticas | Endpoints del contrato |
|---|---|---|---|
| **C1** Selección de paciente y registro | `laboratory-results`: «Selección de paciente y registro del resultado» (registro exitoso, paciente de otra clínica, cuerpo con identificador de clínica, encabezado de otra clínica, sin permiso de carga) | Backend: `test_cu11_manual_upload::test_carga_exitosa_crea_resultado_documento_archivo_y_auditoria`, `::test_paciente_de_otra_clinica_da_404_sin_efectos`, `::test_paciente_con_id_clinica_null_se_comporta_como_inexistente`, `::test_campos_prohibidos_en_el_cuerpo_dan_422`, `::test_el_encabezado_x_tenant_id_no_cambia_la_clinica`, `::test_sin_permiso_de_carga_da_403`; `test_cu11_tenant_isolation`. Web: `laboratory-result-form.spec` («envía los datos válidos solo con los campos del contrato…»), `lab-patient-picker.spec`; Cypress A «carga un resultado válido enviando multipart sin campos de clínica ni estado» | `POST /resultados-laboratorio` |
| **C2** Carga manual: estudio y orden | «Carga manual con identificación del estudio» y «Vínculo opcional con la orden» (carga completa, estudio inexistente, campo faltante, fecha futura, orden válida / de otra clínica / de otro paciente / no firmada) | Backend: `test_cu11_manual_upload::test_orden_valida_se_vincula`, `::test_ordenes_invalidas`, `::test_examen_inexistente_de_otra_clinica_o_inactivo_da_404`, `::test_campos_obligatorios_faltantes_dan_422`, `::test_fecha_futura_da_422`, `::test_valores_invalidos_dan_422`. Web: `laboratory-result-form.spec` («la fecha de realización no puede ser futura», «la orden debe ser un entero positivo», catálogo de CU10), Cypress A (validaciones y catálogo) | `POST /resultados-laboratorio` |
| **C3** Validación de datos y archivos | `laboratory-results`: «Validación de datos y archivos antes de guardar» (8 escenarios); `laboratory-sync`: «Validación por ítem y errores aislados» | Backend: `test_cu11_files` (todas), `test_cu11_manual_upload::test_archivos_invalidos_dan_422_con_codigo_y_sin_efectos`, `::test_archivo_mayor_a_10_mb_da_422`; `test_cu11_sync_matching::test_un_archivo_exe_no_frena_el_lote`, `::test_cada_archivo_invalido_queda_en_error_sin_persistir_nada_y_sin_afectar_al_resto`, `::test_un_nombre_de_archivo_con_ruta_nunca_forma_parte_de_la_clave_de_almacenamiento`; `test_cu11_sync_manifest::test_archivo_declarado_pero_ausente_no_rechaza_el_lote_solo_ese_item`. Web: `laboratory-result-file.spec`, `laboratory-sync-manifest.spec`, Cypress A/B (archivo no PDF/JPG/PNG) | `POST /resultados-laboratorio`, `POST /sincronizaciones-laboratorio` |
| **C4** Fuentes e ingestión por lote | `laboratory-sync`: «Fuentes de laboratorio configuradas por clínica» (5 escenarios) e «Ingestión por lote desde una fuente activa» (5) | Backend: `test_cu11_fuentes` (todas), `test_cu11_sync_manifest` (`::test_control_positivo_un_lote_valido_se_acepta`, `::test_fuente_inexistente_responde_404_y_no_crea_nada`, `::test_fuente_inactiva_responde_409_y_no_crea_nada`, `::test_id_externo_repetido_en_el_lote_rechaza_todo`, `::test_lote_sin_permiso_de_sincronizacion_responde_403_y_no_crea_nada`). Web: `laboratory-sources.spec`, `laboratory-sync-import.spec`, `laboratory-sync.service.spec`; Cypress B «Fuentes de laboratorio» y «Importación por lote» | `GET/POST /fuentes-laboratorio`, `PATCH /fuentes-laboratorio/{id}`, `POST /sincronizaciones-laboratorio` |
| **C5** Correspondencia, pendientes y revisión | `laboratory-results`: «Estados del resultado…», «Revisión y resolución de pendientes»; `laboratory-sync`: «Correspondencia con paciente, estudio y orden» (5 escenarios) | Backend: `test_cu11_sync_matching` (todas), `test_cu11_revision` (todas), `test_cu11_consulta::test_estados_pendiente_y_anulado_exigen_review`, `::test_revisor_ve_pendiente_con_datos_de_correspondencia_y_otros_no`. Web: `laboratory-result-review.spec`, `laboratory-result-review.fuente.spec`; Cypress A (asignar/descartar) y B (enlace a la cola, 7.5) | `POST /resultados-laboratorio/{id}/resolver`, `GET /resultados-laboratorio?estado=PENDIENTE_REVISION`, `POST /sincronizaciones-laboratorio` |
| **C6** Control de duplicados | `laboratory-sync`: «Control de duplicados por fuente» (6 escenarios, incluida la carrera) | Backend: `test_cu11_sync_idempotency` (todas, incluida la carrera simulada), `test_cu11_constraints::test_idempotencia_clinica_fuente_id_externo`, `::test_un_anulado_sigue_ocupando_su_id_externo`; `test_cu11_sync_postgres` (carrera real en PostgreSQL, se omite sin `CU11_TEST_PG_URL`). Cypress B «reenviar el mismo lote deja los ítems como DUPLICADO» | `POST /sincronizaciones-laboratorio` |
| **C7** Consulta y descarga | `laboratory-results`: «Consulta de resultados en el expediente» (6) y «Descarga del archivo con tipo de contenido correcto» (3) | Backend: `test_cu11_consulta` (todas), `test_cu11_descarga` (todas), `test_cu11_tenant_isolation`. Web: `laboratory-result-list.spec`, `laboratory-result-detail.spec`, `lab-result-file-viewer.spec`; Cypress A. Móvil: `cu11_laboratory_results_data_test.dart` (modelo con y sin campos ocultos, repositorio 401/403/404/red), `cu11_laboratory_results_presentation_test.dart` (lista, visor PDF/imagen, borrado del temporal), `cu11_documents_list_chip_test.dart` | `GET /resultados-laboratorio`, `GET /pacientes/{id}/resultados-laboratorio`, `GET /resultados-laboratorio/me`, `GET /resultados-laboratorio/{id}`, `GET /resultados-laboratorio/{id}/archivo` |
| **C8** Registro de sincronizaciones y reintento | `laboratory-sync`: «Registro de sincronizaciones y errores» (4) y «Reintento sin duplicar» (4) | Backend: `test_cu11_sync_registry` (todas), `test_cu11_sync_retry` (todas), `test_cu11_sync_endpoints` (todas). Web: `laboratory-sync-detail.spec`, `laboratory-sync-list.spec`, `lab-sync-badge.spec`; Cypress B (informe mixto, reintento de un ítem, `ITEM_NO_REINTENTABLE`, `SINCRONIZACION_NO_ENCONTRADA`, historial) | `GET /sincronizaciones-laboratorio`, `GET /sincronizaciones-laboratorio/{id}`, `POST /sincronizaciones-laboratorio/{id}/reintentos` |
| **C9** Trazabilidad, permisos, aislamiento y anulación | `laboratory-results`: «Anulación lógica», «Trazabilidad e integridad», «Permisos y asignación por rol», «Integridad y unicidad», «Forma uniforme de los errores», «Puntos de integración»; `laboratory-sync`: «Trazabilidad y aislamiento de la sincronización» | Backend: `test_cu11_permissions` (matriz, 401/403 en todos los endpoints, `test_openapi_lista_exactamente_las_rutas_del_contrato`), `test_cu11_audit_cu21`, `test_cu11_revision::test_anular_un_incorporado_anula_resultado_y_documento_sin_borrar_el_archivo`, `::test_no_existe_eliminacion_fisica`, `test_cu11_manual_upload::test_falla_de_auditoria_no_deja_resultado_documento_ni_archivo`, `::test_mismo_archivo_para_el_mismo_paciente_da_409_sin_segundo_archivo`, `test_cu11_constraints`, `test_cu11_integration_cu10_cu12`, `test_cu11_tenant_isolation`, `test_cu11_sync_registry::test_trazabilidad_de_un_resultado_sincronizado_y_de_la_sincronizacion`, `test_cu11_conventions`, `test_cu11_logs` (nuevo). Web: `app.routes.cu11.spec`, `app.routes.cu11-sync.spec`, `laboratory-result-access.sync.spec`; Cypress B «Vista sin permiso de sincronización» | Los 15 endpoints (todos exigen su permiso; ningún `DELETE`) |

Todos los criterios (C1 a C9) tienen al menos una prueba automática; ninguno queda sin cubrir.

### Contrato frente a OpenAPI

`app.openapi()` (importando la app con `DB_HOST=127.0.0.1 DB_PORT=1`, sin servidor ni base): 15 operaciones de CU11, las mismas rutas y métodos de las secciones 3 y 4 del contrato, sin `DELETE`; mismos parámetros de consulta; multipart y cuerpos JSON con los mismos campos (3.1: 7 partes, 5 obligatorias; 4.4 y 4.7: `manifiesto` y `archivos`); los esquemas de respuesta coinciden campo por campo con los ejemplos 2.2 (31 campos), 2.6 (6), 2.8 (16 y 6 del ítem); ni `id_clinica` ni `tenant_id` en ninguna entrada; todos los códigos de dominio del catálogo 1.1 existen en el código con el mismo estado HTTP. Diferencias (documentales, sin error de transcripción): (1) OpenAPI declara solo `2xx` y `422` por operación; `401/403/404/409/500` y los cuerpos de error de dominio no están declarados en `responses=` (los verifican las pruebas); (2) `manifiesto` y `archivos` figuran como opcionales en OpenAPI mientras el contrato los pide: el servidor responde `422 LOTE_INVALIDO` si falta el manifiesto y deja el ítem en `ERROR ARCHIVO_AUSENTE` si falta su archivo.

### Revisión de seguridad (solo lectura)

Sin `.query(`, `AsyncSession` ni `async def` en `laboratory_results/` ni `laboratory_sync/`; todo `select()` de datos filtra por `id_clinica` de la sesión (los listados lo hacen en la lista `condiciones`); ningún endpoint lee `tenant_id`/`id_clinica` del cliente (`router.py:56-66` de resultados y `service.CAMPOS_DE_CLINICA`/`router.py:43` de sincronización los rechazan; los cuerpos JSON usan `extra="forbid"`); los 15 endpoints exigen su permiso; los nombres se sanean con `files.sanear_nombre` (`files.py:68`, usado en `files.py:105` desde la carga manual y desde `laboratory_sync/service.py:352`) y la descarga usa `_content_disposition` (`router.py:242`).

Hallazgos:
1. **Corregido (medio):** `logger.exception` en `laboratory_sync/service.py` (procesamiento y almacenamiento de un ítem) y en `laboratory_results/service.py` (almacenamiento y compensación) volcaba el traceback completo; el mensaje de una excepción de SQLAlchemy incluye los parámetros de la sentencia (CI, datos de correspondencia) y el de una falla de almacenamiento puede incluir rutas locales. Ahora solo se registra la clase de la excepción (`descripcion_segura`, `laboratory_results/service.py:41`; usos en `:207`, `:266`, `laboratory_sync/service.py:389` y `:556`). Prueba nueva `tests/test_cu11_logs.py` (5 pruebas; la de procesamiento falla con el código anterior).
2. **Informativo:** `laboratory_results/service.py:205` y `:207` registran la clave de objeto de un archivo huérfano (`documentos/xx/yy/resultado-lab-<clínica>-<uuid>.ext`); no es una ruta del sistema de archivos ni contiene datos clínicos y hace falta para limpiar huérfanos. `laboratory_sync/service.py:556` registra el `id_externo` (identificador de la fuente).
3. **Informativo:** `laboratory_results/dependencies.py:43` y `:58` consultan `rol_permisos`/`roles` sin `id_clinica`: son tablas de roles y permisos del propio usuario autenticado (no datos de pacientes).
4. **Informativo (heredado de FastAPI):** el multipart se lee y se vuelca a disco temporal antes de resolver la autenticación, así que un cliente sin token puede forzar la lectura de hasta 100 MB por petición antes de recibir `401`; con más de 100 MB, `422 LOTE_INVALIDO` antes de autenticar (documentado en el contrato). Mitigación fuera de CU11: límite de cuerpo en el proxy o una ruta que autentique primero.
5. **Ya documentado:** una petición de ingestión de más de 100 MB revela el tope a un cliente anónimo.

### Hallazgos abiertos

- **H-1** Dos pacientes sin clínica en Neon (`id_paciente` 1 y 2; ver H-1 en «Hallazgos abiertos», al inicio de este documento): quedan como inexistentes para CU11 (404/`PACIENTE_NO_ENCONTRADO`); falta el `UPDATE` de regularización, propuesto y no ejecutado.
- **Neon:** la migración 025 no se aplicó (solo se probó en SQLite y en un PostgreSQL 16 desechable); hay que respaldarla y aplicarla antes del despliegue (ver `design.md`, Migration Plan).
- **CU12 con JPG/PNG:** CU12 sirve `application/pdf` fijo (análisis y corrección mínima propuesta en `design.md` D13); mientras no se corrija, abrir los resultados por los endpoints de CU11.
- **7.5:** la cola de revisión se filtra por fuente, no por sincronización (el listado del contrato no tiene `id_sincronizacion`).
- **Reintento web:** el informe no trae los datos de cada ítem, así que la web conserva el manifiesto original en `sessionStorage` (solo esa pestaña) o pide cargarlo de nuevo.
- **Pruebas preexistentes que fallan (41 ids):** CU10 sin `tenant_subscriptions` en SQLite, `apscheduler`/`reportlab` sin instalar y `test_integrated_migration_graph_has_one_head` (espera la cabeza `cu35_cu18_convergencia_023`; con CU11 la cabeza es `cu11_resultados_laboratorio_025`). Móvil: `asistencia_datasource_test.dart` y `analytics_reports_test.dart`, y 12 avisos de `flutter analyze`.
- **Fallos intermitentes de red** de `test_cu31_subscription_payments.py` (ver arriba) y fallo transitorio de vitest («failed to find the runner») tras `npm run build`/`ng serve`/Cypress en esta máquina.
- **`npm run test:e2e` completo** (8.2): ejecutado el 2026-11-20 (ver «Cierre de 8.2 y 8.5»). **`openspec validate --specs`** (8.5): resuelto, 9 de 9 sin errores ni advertencias.
- **Integración con `origin/Gustavo`:** el commit `92a04c9` (`app/main.py`, `appointments/router.py`, `auth/models.py`, `medical_records/router.py`) sigue sin integrar; CU11 solo comparte con él `medical_records/router.py` (conservar los `import` e `include_router` de ambos lados).

## Cierre de 8.2 y 8.5 (2026-11-20)

**8.5 (cerrada).** `openspec doctor` correcto; `openspec validate --specs`: `9 passed, 0 failed` sin errores ni advertencias (solo avisos INFO de longitud); `openspec validate cu11-resultados-laboratorio`: válido. Para lograrlo se corrigió la estructura de `openspec/specs/live-queue/spec.md` (CU08): se añadieron `## Purpose`, `## Requirements`, un `### Requirement` con una frase SHALL y un `#### Scenario`; el texto de las reglas no cambió. Ese archivo va en un commit aparte de CU11.

**8.2 (web).**

| Comando | Resultado |
|---|---|
| `npm run build` | correcto (código 0) |
| `npm run test:vitest` | `74 passed, 1 failed` archivos; `715 passed, 1 failed, 5 skipped` pruebas |
| `npm run test:e2e` (completo, con `ng serve` en 4200) | 6 specs: CU11 resultados 20/20 y CU11 sincronización 21/21 pasan; CU17 9/9 pasa; CU10, CU12 y CU23 fallan |

- **Fallo de vitest:** `treatment-schedule.spec.ts` (CU17), prueba 5 «cambio de fecha mediante datepicker». Fija la fecha `'2026-11-20'`, que coincide con el día de la ejecución; `onFechaChange` ignora una fecha igual a la seleccionada y no recarga. Depende del calendario, no de CU11: la ejecución anterior (716 pasadas) fue otro día.
- **Fallos de Cypress (CU10, CU12, CU23):** `cy.login` (`cypress/support/commands.ts`) inicia sesión con `medico@test.com` contra el backend real (`127.0.0.1:8000`, base Neon) y la sesión no se crea (`expected '/login' to not include '/login'`). Esos specs no simulan el backend y no se tocaron en CU11.
- **Entorno:** en esta máquina `ELECTRON_RUN_AS_NODE=1` impide arrancar Cypress (`cachedDataRejected`); se ejecutó con la variable sin definir.
- **Estado de 8.2 (cerrada):** el criterio se acotó a CU11 por decisión del usuario (2026-11-20). `npm run build` correcto; las pruebas de CU11 (vitest y Cypress `cu11-*`, 41 pruebas) pasan. Los fallos descritos arriba (1 de vitest en CU17 y los specs Cypress CU10, CU12 y CU23) son ajenos a CU11 y quedan registrados como hallazgos.
