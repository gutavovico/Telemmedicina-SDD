## Why

El médico necesita ver los resultados de laboratorio del paciente durante la atención, pero hoy no existe ninguna forma de incorporarlos: CU10 emite solicitudes (`ordenes_laboratorio`) y CU12 indexa documentos (`documentos_clinicos`, que ya admite `tipo_documento = 'RESULTADO_LAB'`), pero no hay carga de archivos, ni vínculo con el estudio solicitado, ni sincronización con laboratorios, ni cola de revisión. Sin esto se cumple solo la mitad del ciclo "solicitar → recibir → consultar" (RF-19, RF-20) y no hay garantía de integridad frente a duplicados (RNF-06).

CU11 (prioridad Alta, 20 h) cierra ese ciclo con dos vías de entrada (carga manual y sincronización por lote) y una regla de seguridad clave: un resultado sin correspondencia válida **nunca** se incorpora a un expediente.

## What Changes

**Bloque A — Carga manual y consulta (I-113, parte de I-115, I-116)**
- Nueva tabla `resultados_laboratorio` (por clínica) con estados `INCORPORADO`, `PENDIENTE_REVISION`, `ANULADO` y origen `MANUAL` | `SINCRONIZADO`.
- Carga manual por `multipart/form-data` de PDF, JPG o PNG (máx. 10 MB, validado por firma de archivo además de extensión), con paciente, estudio (código de `examenes_laboratorio`), fecha de realización y laboratorio de origen; vínculo opcional con una orden de CU10.
- Al incorporar, se indexa el archivo en `documentos_clinicos` como `RESULTADO_LAB` y se enlaza con el resultado.
- Consulta en el expediente (listado por paciente, detalle, descarga con `content_type` correcto) con alcance por rol.
- Revisión de pendientes (asignar o descartar) y anulación lógica de resultados incorporados.
- Cuatro permisos nuevos `lab_results:create|read|review|sync` sembrados por migración.
- Web: carga, listado/detalle en el expediente y cola de revisión, sobre `features/medical-records/documentos/` (la carpeta vigente según rutas). Móvil: solo lectura.

**Bloque B — Sincronización (I-114, resto de I-115)**
- Tablas `fuentes_laboratorio` (integración configurada por clínica), `sincronizaciones_laboratorio` y `sincronizaciones_laboratorio_items` (lotes y errores por ítem).
- Endpoint de ingestión por lote, idempotente por `(id_clinica, fuente, id_externo)`; correspondencia automática por paciente, estudio y orden; los que no corresponden quedan `PENDIENTE_REVISION`.
- Reintento de ítems con error sin duplicar lo ya guardado.
- Web: pantalla de estado de sincronizaciones y gestión mínima de fuentes.

**Fuera de alcance (no-objetivos)**
- Webhook HMAC o polling hacia laboratorios externos: queda documentado en `design.md` como extensión futura, sin requisitos.
- Notificaciones al médico o al paciente: las cubre CU20.
- Valores clínicos estructurados (analitos, rangos de referencia, interpretación): el resultado es un archivo más metadatos.
- Corregir la brecha de aislamiento de `create_document` de CU12 (paciente sin filtro por clínica) y el `content_type` fijo en `application/pdf` de CU12: se registran como deuda conocida para un change aparte.
- Documentar CU10 y CU12 completos en OpenSpec: se recomienda un change posterior de contratos; CU11 solo declara sus puntos de integración.
- Rol `LABORATORIO`: no se crea.
- Infraestructura asíncrona compartida (`AsyncSession`): trabajo futuro transversal, sin tareas en este change. La única excepción a `AGENTS.md` es la sesión síncrona acotada de CU11 (sección 5).

Sin cambios incompatibles (**BREAKING**): solo se agregan tablas, permisos y endpoints; no se modifican los contratos ni el comportamiento de CU10 y CU12.

## Capabilities

### New Capabilities
- `laboratory-results`: carga manual, validación de archivos, correspondencia con paciente/estudio/orden, estados, revisión de pendientes, consulta en el expediente, descarga, trazabilidad, permisos y aislamiento por clínica (criterios 1, 2, 3, 5, 7, 9).
- `laboratory-sync`: fuentes de laboratorio por clínica, ingestión por lote idempotente, control de duplicados, registro de sincronizaciones y errores, y reintento sin duplicar (criterios 4, 5, 6, 8, 9).

### Modified Capabilities
<!-- Ninguna. CU10 y CU12 no tienen spec en openspec/specs/ (solo código); CU11 no modifica sus requisitos. -->

## Impact

**Dominio y límites:** módulo `medical_records` (junto a `laboratory_orders` y `clinical_documents`). Nuevos paquetes de caso de uso `app/modules/medical_records/laboratory_results/` y `.../laboratory_sync/`, registrados en `app/modules/medical_records/router.py` (no se toca `app/main.py` salvo que apareciera un worker, que no se prevé).

**Aislamiento por clínica:** todas las tablas nuevas llevan `id_clinica BIGINT NOT NULL` (convención real del módulo; alias `tenant_id` por propiedad). Toda consulta filtra por la clínica del usuario autenticado; nunca se acepta `tenant_id` ni `id_clinica` en el body. Paciente, orden, examen y fuente de otra clínica responden `404`.

**Backend (FastAPI):** migración Alembic nueva (cuelga del head `cu36_billing_overages_024`), modelos, esquemas, servicios, routers, almacenamiento reutilizando `clinical_documents/storage.py`, auditoría, pruebas `tests/test_cu11_*.py`. Usa `Session` síncrona acotada a los módulos de CU11, con la excepción registrada en `AGENTS.md` §5 el 2026-11-18 (el backend no tiene infraestructura asíncrona; ver `design.md` D14). Se mantienen `select()/execute()/scalars()` y la prohibición de `session.query()`.

**Contratos:** nuevo `openspec/contracts/resultados-laboratorio.md`.

**Web (Angular):** carga, detalle y revisión bajo `features/medical-records/documentos/`; pantalla de sincronizaciones; modelos tipados derivados del contrato; sin tocar la carpeta duplicada `documents/`.

**Móvil (Flutter):** consulta de resultados incorporados y visor de archivo (PDF e imágenes) en `lib/features/medical_records/` con provider propio; de `documents_list_screen` solo se reutiliza el punto de entrada (el chip `RESULTADO_LAB` navega a la pantalla de CU11), sin modificar el provider ni el visor de CU12.

**Casos de uso vecinos:** CU09/CU28 (expediente/HCE), CU10 (órdenes y catálogo de exámenes), CU12 (documentos clínicos, permisos `documents:*`), CU21 (bitácora de auditoría), CU27 (exportación, consumirá el tipo `RESULTADO_LAB`).
