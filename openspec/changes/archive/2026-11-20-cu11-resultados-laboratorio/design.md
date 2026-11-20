## Context

Motivación y alcance: ver `proposal.md`. Requisitos: `specs/laboratory-results/spec.md` y `specs/laboratory-sync/spec.md`. Contrato: `openspec/contracts/resultados-laboratorio.md`.

**Estado verificado en el código (rama `Gustavo`):**

| Elemento | Hecho verificado | Ruta |
|---|---|---|
| Catálogo de estudios | `examenes_laboratorio` (`id_examen`, `id_clinica`, `codigo`, `nombre`, `activo` `'SI'/'NO'`), único por `(id_clinica, codigo)` | `app/modules/medical_records/laboratory_orders/models.py` |
| Órdenes | `ordenes_laboratorio` (`id_orden`, `id_clinica`, `id_paciente`, `examenes` JSONB `[{codigo,nombre,indicaciones}]`, `estado` BORRADOR/FIRMADA/ANULADA) | ídem |
| Documentos | `documentos_clinicos` ya admite `tipo_documento='RESULTADO_LAB'`; `id_paciente` nullable; `metadatos` JSONB; `estado` ACTIVO/ANULADO | `.../clinical_documents/models.py`, migración `004`/`006` |
| Pacientes | Modelo ORM `Paciente` existe en `medical_records/models.py` con `id_clinica` **nullable**, `id_usuario` único, `ci`, `complemento` (default `''`), `estado` | `app/modules/medical_records/models.py` |
| Sesión de base de datos | Solo existe `Session` síncrona: `create_engine`, `sessionmaker` y `get_db()`; sin `AsyncSession` en `app/`; `DATABASE_URL` usa `postgresql+psycopg2`; las pruebas usan SQLite en memoria con override de `get_db` | `app/core/database.py`, `app/core/config.py`, `tests/conftest.py` |
| Almacenamiento | Singleton `storage` con `store/read/delete/generate_download_url`, backends `local`, `minio`, `r2`, `s3`; todas las operaciones son **síncronas** | `.../clinical_documents/storage.py` |
| Subida de archivos | Ya hay `UploadFile` en `backup/` y `analytics/reportes`; `python-multipart` y `pillow` están en `requirements.txt` | `requirements.txt` |
| Permisos | Patrón SQL sobre `permisos`/`rol_permisos` con `p.estado = 'ACTIVO'`; matriz CU12 sembrada en migraciones `004` y `006` | `.../clinical_documents/dependencies.py` |
| Auditoría | `core/audit.py::registrar_auditoria` (hace `flush`, no `commit`); CU10/CU12 usan su propio `audit()` con `INSERT` crudo y `commit` | `app/core/audit.py`, `.../clinical_documents/service.py:234` |
| Registro de routers | Los routers de `medical_records` se agregan en un solo archivo | `app/modules/medical_records/router.py` |
| Cabeza de migraciones | `alembic heads` → `cu36_billing_overages_024 (head)` (cabeza única) | `alembic/versions/024_cu36_billing_overages.py` |
| Roles reales | ADMIN, MEDICO, RECEPCION, PACIENTE (sin LABORATORIO) | migraciones `004`, `006` |

**Matriz CU12 vigente (migraciones `004` y `006`)**: ADMIN, MEDICO y PACIENTE tienen los seis permisos `documents:*`; RECEPCION tiene todos salvo `documents:read:lab_results`. `clinical_documents/service.py:73` devuelve 403 a RECEPCION si filtra `RESULTADO_LAB`.

**Verificación de la asignación propuesta de permisos frente a `004` y `006` — conflictos encontrados:**

1. *Sin conflicto:* la restricción "RECEPCION no ve valores clínicos ni descarga" es coherente con que RECEPCION no tenga `documents:read:lab_results`. Se implementa **reutilizando ese permiso** (la descarga exige `lab_results:read` **y** `documents:read:lab_results`) en lugar de comparar nombres de rol o crear un quinto permiso.
2. *Matiz:* RECEPCION sí posee `documents:download` y `documents:search` en CU12. Por eso la descarga de CU11 no puede apoyarse en `documents:download` (permitiría a RECEPCION descargar); se usa `documents:read:lab_results`.
3. *Matiz (verificado, antes "por verificar"):* los roles se siembran con `UPPER(r.nombre) = ...` sobre todas las filas de `roles` (hay roles por clínica: `010_super_admin_global.py` inserta `roles` con `id_clinica`). La migración nueva usa el mismo patrón idempotente. El alta de clínicas **no** siembra permisos y crea solo el rol administrador; el detalle y sus consecuencias están en D9.
4. *Matiz:* los verificadores de rol de CU10/CU12 dan acceso total a `id_rol == 1`. En CU11 el acceso se decide solo por `rol_permisos` y por la clínica de la sesión; una cuenta global sin clínica recibe 403.

## Goals / Non-Goals

**Goals:**
- Resultado `INCORPORADO` solo con paciente, estudio y orden consistentes dentro de la misma clínica; todo lo demás queda en `PENDIENTE_REVISION` sin tocar ningún expediente.
- Idempotencia fuerte por `(id_clinica, fuente, id_externo)` aplicada también en base de datos, y reintento seguro.
- Reutilizar almacenamiento, permisos y la tabla `documentos_clinicos` sin modificar CU10 ni CU12.
- Trazabilidad atómica: auditoría en la misma transacción que el cambio.
- Cumplir el resto de AGENTS.md con la excepción acotada de sesión síncrona de CU11 (D14): `select()/execute()/scalars()`, sin `session.query()`, filtro de clínica en toda consulta.

**Non-Goals:**
- **Infraestructura asíncrona compartida** (`AsyncSession`, `get_async_db`): trabajo futuro transversal (D14), sin tareas en este change.
- **Webhook HMAC / polling a laboratorios externos.** Extensión futura (ver D12). No hay requisitos ni tareas.
- **Notificaciones** (médico solicitante o paciente): las cubre CU20. CU11 no inserta en `notificaciones` ni envía push.
- **Valores clínicos estructurados** (analitos, rangos, interpretación automática). El resultado es archivo + metadatos.
- **Modificar `create_document` de CU12** (brecha R1) ni su `content_type` fijo (ver D6): deuda conocida, change aparte.
- **Documentar CU10 y CU12 completos** en OpenSpec: ver D13.
- Rol `LABORATORIO`, edición de `AGENTS.md` o excepciones nuevas a sus reglas.
- Edición de un resultado ya incorporado (solo se anula y, si hace falta, se carga de nuevo).

## Decisions

### D1. Modelo de datos (migración nueva)

Convenciones del módulo vecino: `id_clinica BIGINT` con FK a `clinicas.id_clinica`, propiedad `tenant_id` como alias en el modelo, PK `BigInteger().with_variant(Integer, "sqlite")`, `JSONB().with_variant(JSON(), "sqlite")`, `server_default=func.now()`. Las pruebas del repositorio usan SQLite en memoria, por lo que las restricciones se escriben compatibles con ambos motores.

**`fuentes_laboratorio`**

| Columna | Tipo | Restricción |
|---|---|---|
| `id_fuente` | BIGINT PK autoincrement | |
| `id_clinica` | BIGINT | NOT NULL, FK `clinicas.id_clinica`, índice |
| `codigo` | VARCHAR(50) | NOT NULL, mayúsculas |
| `nombre` | VARCHAR(200) | NOT NULL |
| `activa` | VARCHAR(2) | NOT NULL, default `'SI'`, CHECK IN (`SI`,`NO`) |
| `created_at`, `updated_at` | TIMESTAMPTZ | NOT NULL, default now |

Único: `uq_fuentes_lab_clinica_codigo (id_clinica, codigo)`.

**`resultados_laboratorio`**

| Columna | Tipo | Restricción |
|---|---|---|
| `id_resultado` | BIGINT PK autoincrement | |
| `id_clinica` | BIGINT | NOT NULL, FK, índice |
| `id_paciente` | BIGINT | NULL, FK `pacientes.id_paciente`; nulo solo en `PENDIENTE_REVISION` |
| `id_orden` | BIGINT | NULL, FK `ordenes_laboratorio.id_orden` |
| `id_examen` | BIGINT | NULL, FK `examenes_laboratorio.id_examen` |
| `codigo_examen` | VARCHAR(50) | NOT NULL (copia del código recibido/elegido) |
| `nombre_examen` | VARCHAR(200) | NULL (copia del catálogo al incorporar) |
| `laboratorio_origen` | VARCHAR(200) | NOT NULL |
| `fecha_realizacion` | DATE | NOT NULL |
| `observaciones` | TEXT | NULL (≤2000 validado en esquema) |
| `estado` | VARCHAR(20) | NOT NULL, CHECK IN (`INCORPORADO`,`PENDIENTE_REVISION`,`ANULADO`) |
| `origen` | VARCHAR(12) | NOT NULL, CHECK IN (`MANUAL`,`SINCRONIZADO`) |
| `id_fuente` | BIGINT | NULL, FK `fuentes_laboratorio.id_fuente` |
| `id_externo` | VARCHAR(100) | NULL |
| `id_sincronizacion` | BIGINT | NULL, FK `sincronizaciones_laboratorio` |
| `motivo_pendiente` | VARCHAR(40) | NULL |
| `datos_correspondencia` | JSONB | NULL (`ci`, `complemento`, `codigo_examen`, `id_orden` crudos) |
| `nombre_archivo` | VARCHAR(255) | NOT NULL (saneado) |
| `archivo_url` | VARCHAR(500) | NOT NULL (clave de almacenamiento) |
| `hash_archivo` | VARCHAR(64) | NOT NULL (SHA-256 hex) |
| `content_type` | VARCHAR(50) | NOT NULL, CHECK IN (`application/pdf`,`image/jpeg`,`image/png`) |
| `tamano_bytes` | BIGINT | NOT NULL, CHECK `> 0 AND <= 10485760` |
| `id_documento` | BIGINT | NULL, FK `documentos_clinicos.id_documento` |
| `registrado_por` | BIGINT | NULL, FK `usuarios.id_usuario` |
| `proceso` | VARCHAR(50) | NULL |
| `registrado_en` | TIMESTAMPTZ | NOT NULL, default now (fecha de registro) |
| `resuelto_por` | BIGINT | NULL, FK `usuarios.id_usuario` |
| `resuelto_en` | TIMESTAMPTZ | NULL |
| `motivo_resolucion` | TEXT | NULL |
| `updated_at` | TIMESTAMPTZ | NOT NULL, default now, onupdate |

Restricciones de integridad:
- `uq_resultado_lab_fuente_externo (id_clinica, id_fuente, id_externo)`: en PostgreSQL los `NULL` son distintos, así que no afecta a las cargas manuales.
- `uq_resultado_lab_manual_hash` único parcial `(id_clinica, id_paciente, hash_archivo)` `WHERE origen = 'MANUAL' AND estado = 'INCORPORADO'` (`postgresql_where` y `sqlite_where`).
- `ck_resultado_incorporado_completo`: `estado <> 'INCORPORADO' OR (id_paciente IS NOT NULL AND id_examen IS NOT NULL)`.
- `ck_resultado_pendiente_sin_expediente`: `estado <> 'PENDIENTE_REVISION' OR (id_paciente IS NULL AND id_documento IS NULL)`.
- `ck_resultado_origen_fuente`: `(origen = 'SINCRONIZADO' AND id_fuente IS NOT NULL AND id_externo IS NOT NULL) OR (origen = 'MANUAL' AND id_fuente IS NULL AND id_externo IS NULL)`.
- `ck_resultado_responsable`: `registrado_por IS NOT NULL OR proceso IS NOT NULL`.
- Índices: `(id_clinica, id_paciente, estado)`, `(id_clinica, estado, registrado_en)`, `(id_clinica, fecha_realizacion)`.

Las FK por sí solas no garantizan que paciente, orden y examen pertenezcan a la misma clínica del resultado; esa regla la aplica el servicio (D3, D4) y la cubren pruebas de aislamiento. No se agregan FK compuestas porque `pacientes`, `ordenes_laboratorio` y `examenes_laboratorio` no exponen una clave única `(id, id_clinica)`.

**`sincronizaciones_laboratorio`**

| Columna | Tipo | Restricción |
|---|---|---|
| `id_sincronizacion` | BIGINT PK autoincrement | |
| `id_clinica` | BIGINT | NOT NULL, FK, índice |
| `id_fuente` | BIGINT | NOT NULL, FK `fuentes_laboratorio` |
| `tipo` | VARCHAR(10) | NOT NULL, default `'LOTE'`, CHECK IN (`LOTE`) |
| `estado` | VARCHAR(30) | NOT NULL, CHECK IN (`EN_PROCESO`,`COMPLETADA`,`COMPLETADA_CON_ERRORES`,`FALLIDA`) |
| `total_items`, `incorporados`, `pendientes`, `duplicados`, `con_error`, `reintentos` | INTEGER | NOT NULL, default 0, CHECK `>= 0` |
| `id_usuario` | BIGINT | NULL, FK `usuarios.id_usuario` |
| `proceso` | VARCHAR(50) | NULL; CHECK `id_usuario IS NOT NULL OR proceso IS NOT NULL` |
| `iniciado_en`, `finalizado_en` | TIMESTAMPTZ | `iniciado_en` NOT NULL default now |

**`sincronizaciones_laboratorio_items`**

| Columna | Tipo | Restricción |
|---|---|---|
| `id_item` | BIGINT PK autoincrement | |
| `id_sincronizacion` | BIGINT | NOT NULL, FK |
| `id_clinica` | BIGINT | NOT NULL, FK, índice |
| `id_externo` | VARCHAR(100) | NOT NULL |
| `resultado` | VARCHAR(20) | NOT NULL, CHECK IN (`INCORPORADO`,`PENDIENTE_REVISION`,`DUPLICADO`,`ERROR`) |
| `id_resultado` | BIGINT | NULL, FK `resultados_laboratorio` |
| `codigo_error` | VARCHAR(50) | NULL |
| `detalle` | TEXT | NULL |
| `intento` | INTEGER | NOT NULL, default 1 |
| `procesado_en` | TIMESTAMPTZ | NOT NULL, default now |

Único: `uq_sync_item (id_sincronizacion, id_externo)`.

**Por qué una tabla propia y no solo `documentos_clinicos` + `metadatos`:** los estados, la unicidad, los `CHECK` y los índices por paciente/estudio no pueden expresarse sobre un JSONB, y un pendiente no debe existir en `documentos_clinicos` (D2). **Alternativa descartada:** columnas nuevas en `documentos_clinicos`, porque modificaría una tabla de CU12 que este change no puede tocar.

### D2. Estados, transiciones y relación con `documentos_clinicos`

```
                 carga manual válida
                 o sync con correspondencia única
 (entrada) ------------------------------------> INCORPORADO ----anular (review)----> ANULADO
     |                                                ^                                  ^
     | sync sin correspondencia                       | resolver ASIGNAR (review)        |
     v                                                |                                  |
 PENDIENTE_REVISION ----------------------------------+                                  |
     |                                                                                   |
     +---------------- resolver DESCARTAR (review, motivo) ------------------------------+

 ANULADO es terminal. No hay otras transiciones.
```

- La carga manual nunca produce `PENDIENTE_REVISION`: si paciente, estudio u orden no son válidos responde 404/409 sin persistir.
- `documentos_clinicos` se escribe **solo** al llegar a `INCORPORADO`: `tipo_documento='RESULTADO_LAB'`, mismo `archivo_url` y `hash_archivo`, `firmado_por` = usuario responsable (o el que resolvió), `fecha_documento = fecha_realizacion`, `metadatos = {id_resultado_laboratorio, id_orden, codigo_examen, laboratorio_origen, content_type, origen}`. El resultado guarda `id_documento`. El archivo se almacena **una sola vez**.
- Al anular, el documento asociado pasa a `estado='ANULADO'` (misma baja lógica que CU12). Un pendiente descartado no tiene documento.
- **Efecto sobre CU12 (consecuencia conocida):** los documentos `RESULTADO_LAB` de CU11 serán visibles en el listado de CU12 para quien tenga `documents:read:lab_results`. Su descarga por los endpoints de CU12 sirve `application/pdf` fijo, incorrecto para JPG/PNG (ver D6). La web y el móvil de CU11 abren el archivo siempre por el endpoint de CU11.

### D3. Idempotencia, concurrencia y reintento (criterios 6 y 8)

Clave de idempotencia: `(id_clinica, id_fuente, id_externo)`, garantizada por `uq_resultado_lab_fuente_externo`.

Algoritmo por ítem de un lote (cada ítem se escribe dentro de un `SAVEPOINT` —`begin_nested()`— y se confirma con su propio `commit` al terminar, de modo que el fallo de un ítem deshace solo ese ítem y nunca revierte ni aborta a los demás; lo ya integrado sobrevive a una caída a mitad del lote). Con el driver `pysqlite` de las pruebas el `SAVEPOINT` solo se anida de verdad si el motor emite un `BEGIN` explícito (receta de SQLAlchemy aplicada en `tests/cu11_support.py`); en PostgreSQL funciona sin ajustes:

```
1. validar campos del ítem y archivo (firma, extensión, tamaño)        -> ERROR (codigo ARCHIVO_*)
2. buscar resultado existente por (clinica, fuente, id_externo)
     - existe y hash igual                                              -> DUPLICADO (sin almacenar)
     - existe y hash distinto                                           -> ERROR CONTENIDO_DISTINTO
3. calcular correspondencia (D4)  -> INCORPORADO | PENDIENTE_REVISION
4. almacenar archivo (clave generada, ver D5)                           -> ERROR ALMACENAMIENTO_FALLIDO
5. INSERT resultado (+ documento si INCORPORADO) + auditoría, commit
     - IntegrityError sobre uq_resultado_lab_fuente_externo (carrera)   -> borrar archivo, releer y registrar DUPLICADO
     - cualquier otra excepción                                         -> rollback, borrar archivo, ERROR
```

- La verificación del paso 2 es una optimización; la garantía real es la restricción única, que resuelve la carrera entre dos peticiones simultáneas.
- Los ítems en `ERROR` **no crean fila en `resultados_laboratorio`**, por lo que un reintento no choca con la restricción única.
- `sincronizaciones_laboratorio_items` guarda un registro por `(sincronizacion, id_externo)`. El reintento `POST .../{id}/reintentos` solo acepta `id_externo` cuyo ítem esté en `ERROR`, reejecuta el algoritmo y **actualiza** ese ítem (`intento + 1`), luego recalcula contadores y estado. Reenviar el lote completo sin usar `/reintentos` también es seguro: lo ya integrado queda `DUPLICADO`.
- Un `id_externo` ya existente en estado `ANULADO` o `PENDIENTE_REVISION` sigue siendo `DUPLICADO` (la fuente no puede reactivar ni duplicar un resultado revisado).
- Carga manual: duplicado por `uq_resultado_lab_manual_hash` (mismo paciente y mismo SHA-256 mientras siga `INCORPORADO`) → 409 `RESULTADO_DUPLICADO`.
- **Criterio de cierre de lote:** `COMPLETADA` / `COMPLETADA_CON_ERRORES` / `FALLIDA` se recalcula desde los ítems (spec `laboratory-sync`).
- **Cabecera y cierre:** la sincronización se crea `EN_PROCESO` y se confirma antes de procesar el primer ítem. La auditoría de cierre (`EJECUTAR_SINCRONIZACION_LABORATORIO` o `REINTENTAR_SINCRONIZACION_LABORATORIO`) se escribe **al final, en la misma transacción que el recálculo de contadores y estado**; si falla, esa transacción se revierte. Si el proceso muere antes del cierre, la sincronización queda `EN_PROCESO` (sin `finalizado_en`) con sus ítems ya confirmados y las trazas de cada ítem, pero **sin traza de cierre**; reenviar el lote completo es seguro (lo integrado queda `DUPLICADO`).
- **Reintento:** `reintentos` de la sincronización sube en 1 por petición de reintento y el contador por ítem es `intento`. Si algún `id_externo` de la petición no es un ítem `ERROR` de esa sincronización, se rechaza la petición completa (`422 ITEM_NO_REINTENTABLE`) antes de procesar nada.
- **Fallo inesperado en un ítem:** cualquier excepción no prevista (incluido un `IntegrityError` que no corresponde a la clave de idempotencia) deja el ítem en `ERROR` con código `ERROR_INTERNO` y detalle genérico; la causa se registra solo en el log. Dos partes `archivos` con el mismo nombre rechazan el lote (`LOTE_INVALIDO`).
- **Tope por petición:** se aplica con `app/core/body_limit.py::ContentLengthLimitedRoute` (FastAPI lee el multipart antes de resolver las dependencias, así que un `Depends` no puede cortarlo). El envoltorio `async` vive en `app/core/` porque los módulos de CU11 no pueden declarar `async def`. Consecuencia: una petición de más de 100 MB recibe `422 LOTE_INVALIDO` antes de autenticar (no `401`). Un manifiesto de más de 1 MB lo rechaza Starlette con `400` de texto plano.
- Límites: 50 ítems por lote, 10 MB por archivo y un tope por petición de 100 MB que aplica la propia API (comprobando `Content-Length` antes de leer el cuerpo; el rechazo usa `422 LOTE_INVALIDO`, porque `413` no está en los códigos de AGENTS.md). Hallazgos de configuración (verificados en el repositorio): `render.yaml` y el `Dockerfile` arrancan `uvicorn` sin proxy ni límite de cuerpo, `frontend_Telemedicina/proxy.conf.json` es un proxy de desarrollo sin límite, `app/core/config.py` no define ningún máximo de subida, y Starlette 1.6.0 limita a 1 MB solo los campos de texto del multipart (`max_part_size`), no los archivos (se vuelcan a disco temporal). Por tanto el campo `manifiesto` no debe superar 1 MB (con 50 ítems queda muy por debajo). Si Render impone un tope propio no es visible en el repositorio: verificación previa Q2 en `tasks.md`. Verificación Q2 del 2026-11-18 contra la API desplegada en Render: peticiones sin token de 11 MB y de 101 MB llegaron a la aplicación (HTTP 401), así que la plataforma no corta antes de 101 MB y el tope de 100 MB por petición se mantiene; ya figura en la fila `LOTE_INVALIDO` del contrato.

### D4. Correspondencia (paciente, estudio, orden)

Se aplica en el orden siguiente y la primera falla fija `motivo_pendiente`:

1. **Paciente:** `select(Paciente)` por `Paciente.ci == ci`, `func.coalesce(Paciente.complemento, '') == complemento` (el complemento recibido nulo se normaliza a `''`; en Neon `pacientes.complemento` es nullable) **y** `Paciente.id_clinica == id_clinica_sesion`. 0 filas → `PACIENTE_NO_ENCONTRADO`; >1 filas → `PACIENTE_AMBIGUO`. Nunca se usa nombre ni aproximación.
   - **Regla de `NULL` en la pertenencia a la clínica (verificada contra Neon el 2026-11-18: 2 de 17 pacientes tienen `id_clinica` NULL):** toda validación de pertenencia es una igualdad simple `Modelo.id_clinica == id_clinica_sesion`, que en SQL nunca coincide con `NULL`. Quedan prohibidos `IS NOT DISTINCT FROM`, `COALESCE(id_clinica, ...)` y `OR id_clinica IS NULL`. El único `COALESCE` permitido es el de `complemento`. Un paciente con `id_clinica` NULL se comporta como inexistente: 404 en carga manual y resolución, `PACIENTE_NO_ENCONTRADO` en sincronización. Vale también para el alcance de PACIENTE (`pacientes.id_usuario` **y** `pacientes.id_clinica` iguales a los de la sesión). Las otras tablas referenciadas (`ordenes_laboratorio`, `examenes_laboratorio`, `fuentes_laboratorio`) tienen `id_clinica NOT NULL`.
2. **Estudio:** `examenes_laboratorio` por `codigo` (normalizado a mayúsculas), `id_clinica` y `activo = 'SI'`; si no → `EXAMEN_NO_VALIDO`.
3. **Orden (si viene `id_orden`):** misma clínica → si no, `ORDEN_NO_VALIDA`; mismo paciente → si no, `ORDEN_PACIENTE_NO_COINCIDE`; `estado = 'FIRMADA'` y el código figura en `examenes[].codigo` → si no, `ORDEN_NO_VALIDA`.

**Identificación del "estudio" (decisión 7):** el estudio canónico es el `codigo` del catálogo `examenes_laboratorio` de la clínica (`id_examen` en la tabla). El JSONB `ordenes_laboratorio.examenes` solo se usa para comprobar que el estudio forma parte de la orden indicada; no se usa como identidad del estudio porque no tiene `id` propio. Si la orden no se informa, no se infiere automáticamente (evita vincular al azar cuando hay varias órdenes del mismo estudio).

En la carga manual los mismos controles devuelven 404/409 y no se persiste nada; en sincronización producen `PENDIENTE_REVISION` guardando el archivo y los `datos_correspondencia` crudos con `id_paciente = NULL` aunque el paciente haya sido identificado (un pendiente jamás queda asociado a un expediente).

Resolución de un pendiente: se repiten los controles 1–3 con los datos que elige el revisor (`id_paciente` explícito de su clínica en lugar de la búsqueda por CI).

### D5. Archivos y almacenamiento

- **Reutilizar** el singleton `storage` de `clinical_documents/storage.py` (`store`, `read`, `delete`) tal cual. No se modifica.
- **Clave generada:** nombre `resultado-lab-<id_clinica>-<uuid4 hex>.<ext>` pasado a `storage.store(...)`. Así dos resultados con el mismo contenido nunca comparten objeto y `storage.delete` de compensación no puede borrar el archivo de otro resultado (el prefijo `documentos/<sha[:2]>/<sha[2:4]>/` lo agrega `store`). El nombre original va solo a `nombre_archivo` (saneado).
- **Validación previa a almacenar:** se lee el cuerpo en bloques hasta 10 MB + 1 byte; si lo excede se aborta con `ARCHIVO_TAMANO_EXCEDIDO` sin acumular más memoria. Extensión → firma (primeros 8 bytes) → `content_type` derivado. **Pillow** (ya en `requirements.txt`) puede abrir imágenes con `Image.verify()` como control opcional adicional; no se exige para cumplir el contrato.
- **Concurrencia:** `storage.*` es síncrono (E/S de disco o boto3). Los endpoints de CU11 son funciones `def` (no `async def`), como los de CU10 y CU12, por lo que FastAPI las ejecuta en su pool de hilos y `storage.*` se llama directamente sin bloquear el bucle de eventos.
- **Compensación:** si el `commit` falla después de `store`, se llama a `storage.delete(clave)`; si el borrado falla se registra en log (archivo huérfano inofensivo, nunca referenciado).
- **Descarga:** ver D6.

### D6. Entrega con `content_type` correcto (R3): endpoint propio de CU11

**Elección: endpoint de descarga propio `GET /api/v1/resultados-laboratorio/{id_resultado}/archivo`**, no corregir el `content_type` compartido de `clinical_documents`.

Justificación:
- `clinical_documents/service.py:231` y `router.py:308,328` fijan `application/pdf` y consumen también CU10 y CU16. Corregirlo exige tocar un módulo compartido con tres consumidores y su contrato de respuesta (`content_type` en `DocumentoClinicoDownloadResponse`), con riesgo de regresión en funciones ya entregadas. Este change no puede modificar CU12 (decisión 10).
- El endpoint propio es el cambio mínimo: lee `resultados_laboratorio.content_type` (derivado de la firma al guardar), llama a `storage.read(clave)` y responde con ese tipo, `Content-Disposition: attachment`, `X-Content-Type-Options: nosniff`. La auditoría de descarga se registra en CU11.
- **Alternativas descartadas:** (a) URL firmada/`generate_download_url`: en backend `local` apunta a un endpoint de CU12 que sirve PDF fijo; (b) adivinar el tipo por extensión en CU12: no aplica a los documentos existentes.
- **Costo asumido:** hay dos rutas de descarga para el mismo archivo (la de CU12 sigue accesible para el documento indexado). Se mitiga con la deuda registrada en D13 (corregir CU12 en un change aparte, usando `metadatos.content_type` que CU11 ya deja guardado).

### D7. Auditoría: `core/audit.py::registrar_auditoria`

**Elección: `registrar_auditoria`**, no el `audit()` de CU10/CU12.

- El `audit()` de CU10/CU12 hace `INSERT` y `commit` propios **después** del commit del dato (`create_document`, `firmar_orden`): si la auditoría falla, el cambio ya está confirmado. El spec exige atomicidad ("si la auditoría falla el cambio se revierte") y la lista de acciones incluye eventos del ítem de un lote.
- `registrar_auditoria` agrega la fila con `flush` sin `commit`, en la transacción activa, y es el helper que ya usan CU34/CU36; permite `datos_anteriores`/`datos_nuevos` (útil en resolver y anular).
- Con la sesión síncrona de CU11 (D14) se invoca directamente `registrar_auditoria(db, ...)` con la misma `Session` del servicio, y el servicio hace el único `commit` después.
- `tabla_afectada`/`accion` según la sección 5 del contrato. **Verificado (antes Q5):** el filtro de CU21 no usa lista blanca. `app/modules/auth/audit/service.py` filtra con `ilike` sobre `accion` y `tabla_afectada` (líneas ~124-127), los esquemas de `audit/schemas.py` los tipan como `str` libre y `audit/router.py` los recibe como `Query` de texto; la UI (`core/services/audit.service.ts`, `features/auth/audit/bitacora-page.ts`) envía el filtro como texto. Las tablas y acciones nuevas aparecen sin cambios en CU21; solo se agrega una prueba que lo confirme (tarea 3.13).

### D8. Resolución de la clínica (tenant)

Cada operación obtiene la clínica de `current_user.id_clinica` y responde 403 si es nula. **No se usa `get_required_tenant_id`**: tiene un fallback `if current_user.id_rol == 4: return 1` (`app/modules/auth/dependencies.py`, tras la rama del superadmin) que asignaría la clínica 1 a un rol 4 sin clínica; no es aceptable para datos clínicos. `get_current_tenant_id` tampoco sirve solo porque devuelve `None` en lugar de fallar y acepta `X-Tenant-ID` para cuentas sin clínica. Se creará una dependencia local de CU11 que exija `id_clinica` y use el encabezado únicamente como verificación de coherencia (debe coincidir si viene). Esto se anota como deuda de seguridad conocida del helper compartido.

### D9. Permisos y siembra

- Migración idempotente (patrón `NOT EXISTS`, como `006_tablas_documentos_cu12.py`): inserta en `permisos` (`nombre`, `descripcion`, `modulo='laboratory_results'`, `accion` = `create|read|review|sync`, `estado='ACTIVO'`) y asigna en `rol_permisos` por nombre de rol:

| Rol | create | read | review | sync |
|---|---|---|---|---|
| ADMIN | ✔ | ✔ | ✔ | ✔ |
| MEDICO | ✔ | ✔ | ✔ | |
| RECEPCION | ✔ | ✔ | | |
| PACIENTE | | ✔ | | |

- Chequeo: copia del patrón `user_has_permission` (SQL sobre `rol_permisos`/`permisos`) en el módulo nuevo; no se importa desde CU10/CU12 para no acoplarse a sus dependencias síncronas.
- Alcance PACIENTE: se resuelve `pacientes.id_usuario = current_user.id_usuario` **y** `pacientes.id_clinica = clínica de la sesión`.
- Alcance MEDICO: igual que CU12 (`_apply_role_scope` no restringe a MEDICO por médico tratante): todos los pacientes de la clínica.
- RECEPCION: `ResultadoLaboratorio` sin `observaciones`, `hash_archivo` ni `datos_correspondencia`; la descarga falla porque exige `documents:read:lab_results`.
- **Siembra de roles y permisos al crear una clínica (verificado, antes Q3):**
  - Hay dos rutas de alta: `app/modules/auth/clinicas/service.py` (crea un rol llamado `Administrador`) y `app/modules/tenants/tenant_management/service.py` (aprobación de solicitud; crea un rol llamado `ADMIN`). **Ninguna inserta en `rol_permisos`** ni crea los roles MEDICO, RECEPCION o PACIENTE.
  - Los permisos de un rol se asignan después por el módulo `auth/roles_permissions` (`list_permissions` devuelve todo lo que haya en la tabla `permisos`; la asignación escribe `RolPermiso`) o por migraciones SQL por nombre de rol.
  - Consecuencia: **no hay nada que tocar en el alta de clínicas** para agregar `lab_results:*`; es el mismo comportamiento que ya tienen `documents:*` y `lab_orders:*`. Los permisos nuevos aparecen solos en el listado de permisos y no hay catálogo de permisos fijado en la web ni en el móvil (búsqueda de `documents:read` y `lab_orders:` en `frontend_Telemedicina/src` y `mobile_telemedicina/lib` sin resultados).
  - Alcance real de la migración: solo asigna a filas de `roles` existentes cuyo `UPPER(nombre)` sea `ADMIN`, `MEDICO`, `RECEPCION` o `PACIENTE`. Un rol `Administrador` creado por la ruta `auth/clinicas` **no coincide** con `ADMIN` y no recibiría los permisos por migración (tampoco los de CU10 ni CU12; esos controles además comparan el nombre `ADMIN`). Se registra como limitación conocida: su administrador puede asignar los permisos desde el módulo de roles. No se agrega ningún alias de nombre en este change.
- **Estado del paciente (decisión, antes Q6):** CU11 **no** filtra por `Paciente.estado` (`ACTIVO`/`INACTIVO`/`SUSPENDIDO`). Solo exige que el paciente exista y pertenezca a la clínica de la sesión. Justificación: el expediente de un paciente inactivo o suspendido sigue siendo clínico y un resultado ya emitido por el laboratorio no debe rechazarse ni quedar pendiente por un cambio administrativo de estado; CU12 tampoco filtra por estado del paciente al listar o indexar documentos. Si más adelante se quisiera bloquear altas de pacientes `INACTIVO`, es un cambio de una condición en el servicio de correspondencia.

### D10. Integración con rutas y módulos (R5)

Estructura (por caso de uso, según AGENTS.md):

```
app/modules/medical_records/
  laboratory_results/   router.py  service.py  schemas.py  models.py  dependencies.py  files.py
  laboratory_sync/      router.py  service.py  schemas.py  models.py  dependencies.py
  router.py             <- se agregan dos include_router (único archivo compartido que se toca)
```

- `app/main.py` **no se modifica**: `medical_records_router` ya se registra allí (`app/main.py:128`). Los dos routers nuevos se incluyen en `medical_records/router.py` con prefijos `/api/v1/resultados-laboratorio`, `/api/v1/fuentes-laboratorio` y `/api/v1/sincronizaciones-laboratorio`; el listado por expediente usa el prefijo `/api/v1/pacientes` como CU12 (`pacientes_doc_router`). Se declara `/me` antes de `/{id_resultado}`.
- Las tablas nuevas se importan en `alembic/env.py` (lista de modelos importados) para que `Base.metadata` las incluya.
- Esperamos conflictos solo en `medical_records/router.py` y `alembic/env.py` (ambos con imports/`include_router` aditivos); se resuelven conservando ambos lados, igual que en `app/main.py`.
- Los errores de dominio no usan un handler global (registrarlo obligaría a tocar `app/main.py`, donde ya hubo conflictos de merge): cada router captura la excepción del servicio y la traduce a `HTTPException` con el cuerpo `{"detail": {"codigo", "mensaje"}}`, igual que `_http_error` en CU10/CU12. Sin cambios en `main.py`.

### D11. Web y móvil

- **Web:** todo bajo `src/app/features/medical-records/documentos/` (la carpeta vigente: las rutas `documentos` y `documentos/:id` cargan sus componentes en `app.routes.ts`). **No se toca `documents/`** (duplicada). Sub-carpeta `resultados-laboratorio/` con componentes standalone + signals, formularios reactivos tipados, modelos derivados del contrato (sin `any`) y servicio con `HttpClient` (los interceptores de `core/interceptors` ya añaden `Authorization` y `X-Tenant-ID`). Rutas nuevas bajo `/admin/resultados-laboratorio...` con `staffGuard` como `ordenes-laboratorio`.
- **Móvil (solo lectura, I-116) — decisión: provider propio, CU12 intacto (antes "por verificar").** Análisis de `lib/features/medical_records/`:
  - `ClinicalDocumentsProvider` (168 líneas) está acoplado a los casos de uso de CU12 (`GetMyDocumentsUseCase`, `GetTenantDocumentsUseCase`, `GetDocumentDetailUseCase`, `DownloadDocumentUseCase`) y a la entidad `ClinicalDocument` (sin `metadatos`, `content_type`, estudio ni laboratorio); su carga bifurca por rol hacia `/api/v1/documentos/me` o `/api/v1/documentos`.
  - `document_viewer_screen.dart` (513 líneas) es solo PDF: guarda `_pdfBytes`, usa `SfPdfViewer.memory`, y guarda/comparte con extensión `pdf` y `MimeType.pdf` fijos, descargando por el provider de CU12.
  - `documents_list_screen.dart` ya tiene el chip `RESULTADO_LAB` ("Resultados de Lab.") y navega al visor de CU12 con `idDocumento`.
  - Reutilizar el provider obligaría a ensanchar la entidad, el modelo y el servicio de CU12 y a hacer el visor multimedia, con riesgo sobre `test/clinical_document_unit_test.dart` y el flujo CU12 ya entregado.
  - **Se crea `LaboratoryResultsProvider` propio** (más entidad `LaboratoryResult`, modelo con `fromJson/toJson`, servicio, repositorio y casos de uso para `GET /api/v1/resultados-laboratorio/me` y `/{id}/archivo`) y dos pantallas nuevas: listado y visor (PDF con `SfPdfViewer` e imagen JPG/PNG con `Image.memory`, extensión y MIME según `content_type`). De `documents_list_screen.dart` solo se reutilizan la estética y el chip: al tocar el chip `RESULTADO_LAB`, o un elemento de tipo `RESULTADO_LAB`, se navega a la pantalla de resultados de CU11 en lugar de abrir el visor de CU12. Cambio mínimo y localizado en esa pantalla; `ClinicalDocumentsProvider`, `ClinicalDocument` y `document_viewer_screen.dart` no se modifican.
  - Esto ajusta la decisión 9 de "reutilizar `documents_list_screen` con filtro" a "reutilizar su punto de entrada": la causa es el acoplamiento anterior.

### D12. Extensión futura: webhook con HMAC (no es requisito)

Documentada para no cerrar la puerta: un endpoint público `POST /api/v1/integraciones/laboratorio/{codigo_fuente}/resultados` firmado con HMAC-SHA256 sobre el cuerpo y un secreto por fuente (mismo patrón de tolerancia temporal que los webhooks de Stripe: `STRIPE_WEBHOOK_SECRET`, `STRIPE_WEBHOOK_TOLERANCE_SECONDS`). Reutilizaría tal cual el algoritmo por ítem de D3 y las tablas de D1; solo requeriría una columna `secreto` (cifrado) en `fuentes_laboratorio`, `proceso='WEBHOOK'` con `registrado_por` NULL (el `CHECK ck_resultado_responsable` ya lo permite) y rate limiting. Variante por consulta periódica (polling) seguiría el patrón de `tenants/usage_billing/worker.py`. Ninguna de las dos se especifica ni se implementa en este change.

### D13. Deuda conocida y siguiente change

- **R1 (CU12):** `create_document` valida el paciente con `SELECT id_paciente FROM pacientes WHERE id_paciente = :id` sin filtrar por clínica (`clinical_documents/service.py`, validación en `create_document`), por lo que un ADMIN/MEDICO puede indexar un documento sobre un paciente de otra clínica. CU11 **no** lo reutiliza (valida con `Paciente.id_clinica` explícito) y no lo modifica. Abrir change aparte.
- **R3 (CU12):** `content_type` fijo `application/pdf` en `generate_download_url`, `/file` y descargas de CU10. Change aparte que use `metadatos.content_type`. Análisis del cierre (sin implementar): el listado de CU12 muestra el documento `RESULTADO_LAB` sin tipo ni extensión; `GET /{id}/download` devuelve `content_type: "application/pdf"` aunque el archivo sea JPG o PNG (`clinical_documents/service.py::generate_download_url`), y con almacenamiento local `serve_local_file_endpoint` y `serve_document_file_endpoint` (`clinical_documents/router.py`) sirven los bytes con `media_type="application/pdf"`, por lo que un visor de PDF (web embebido o móvil CU12) falla; con S3/MinIO la URL firmada sí entrega el tipo real porque CU11 guarda el objeto con su `ContentType`. Corrección mínima propuesta: una función `content_type_de(doc)` (primero `metadatos["content_type"]`, luego la extensión de `archivo_url`, por defecto PDF) usada en esos tres puntos y en el argumento de `storage.generate_download_url`, más una prueba por formato. Alternativa que no toca CU12: abrir todo `RESULTADO_LAB` por el endpoint de CU11 (la web y el móvil de CU11 ya lo hacen; el móvil solo desde el chip).
- **R4:** CU10 y CU12 no tienen spec ni contrato en `openspec/`. **Recomendación:** abrir después de CU11 un change `contratos-cu10-cu12` que documente lo implementado (tablas, permisos `lab_orders:*` y `documents:*`, endpoints) para cerrar la brecha SDD. CU11 se limita a la requirement "Puntos de integración" de `laboratory-results`.
- **R6:** el nuevo `down_revision` es `cu36_billing_overages_024` (cabeza única según `alembic heads` al diseñar). Con la revisión 025 la cabeza pasa a ser `cu11_resultados_laboratorio_025`; la prueba preexistente `test_integrated_migration_graph_has_one_head` (que ya fallaba antes de este change y espera `cu35_cu18_convergencia_023`) sigue fallando y no es de CU11.
- **Hallazgo adicional:** CU10 usa `db.query()` en `laboratory_orders/router.py` (viola AGENTS.md); no se corrige aquí.
- **Seguridad — `get_required_tenant_id` (junto con R1, para un change aparte):** en `app/modules/auth/dependencies.py`, si el usuario no tiene `id_clinica` y no es superadministrador con encabezado válido, el helper devuelve la clínica `1` cuando `current_user.id_rol == 4`, en lugar de rechazar. Asignaría datos a una clínica arbitraria. CU11 exige `id_clinica` de la sesión (D8) y **no modifica** ese helper ni sus consumidores. Abrir change aparte junto con R1, porque ambos son brechas de aislamiento preexistentes.

### D14. Sesión de base de datos síncrona acotada (cierre de Q1)

**Decisión (usuario, 2026-11-18): opción C.** CU11 usa `Session` síncrona, acotada a `app/modules/medical_records/laboratory_results/` y `app/modules/medical_records/laboratory_sync/`, igual que CU10 y CU12, con el precedente de CU34. La excepción quedó registrada en `AGENTS.md` (sección 5, "Excepción acotada — CU11 (sesión síncrona)"); no se amplió a otros módulos.

**Justificación (hechos verificados):** el backend no tiene infraestructura asíncrona. `app/core/database.py` solo define `create_engine`, `sessionmaker` y `get_db()`; no existe `AsyncSession` en `app/`; `DATABASE_URL` usa `postgresql+psycopg2`; `get_current_user` depende de `get_db` síncrono y los módulos vecinos, `storage` y `registrar_auditoria` son síncronos. Crear la infraestructura asíncrona tocaría la autenticación y el arranque de toda la aplicación, y un endpoint asíncrono abriría una segunda conexión solo para autenticar.

**Cómo se implementa:**
- Endpoints `def` (no `async def`) con `db: Session = Depends(get_db)` importado de `app.core.database`.
- Consultas solo con `db.execute(select(...))`, `.scalars()` y `.scalar_one_or_none()`; **prohibido `db.query()`** (CU10 sí lo usa; CU11 no lo copia). Filtro `id_clinica` explícito en cada consulta y mutación.
- `registrar_auditoria(db, ...)` y `storage.*` se llaman directamente; un único `db.commit()` por unidad de trabajo (por ítem en sincronización).
- Pruebas con SQLite en memoria y override de `get_db`, como el resto de la suite (`tests/conftest.py`); sin `aiosqlite`. El motor de pruebas de CU11 emite un `BEGIN` explícito (`tests/cu11_support.py`) para que los `SAVEPOINT` por ítem se aniden como en PostgreSQL.
- **Único `async def` relacionado con CU11:** el envoltorio `ContentLengthLimitedRoute` de `app/core/body_limit.py` (rechazo por `Content-Length` antes de leer el cuerpo). Vive en `app/core/` porque FastAPI lee el multipart antes de resolver dependencias y el envoltorio debe ser `async`; no usa base de datos ni sesión. Los directorios `laboratory_results/` y `laboratory_sync/` siguen sin `async def` (lo verifica `tests/test_cu11_conventions.py`).
- **Logs:** los servicios registran solo la clase de la excepción (`descripcion_segura`), nunca su mensaje, porque las excepciones de SQLAlchemy incluyen los parámetros de la sentencia (CI, datos de correspondencia) y las de almacenamiento pueden incluir rutas locales (`tests/test_cu11_logs.py`).

**Alternativa registrada como trabajo futuro (opción A, sin tareas en este change):** infraestructura asíncrona compartida y transversal (motor asíncrono con `psycopg`, dependencia `get_async_db`, base de pruebas asíncrona, migración de `get_current_user` y de los módulos). Cuando se haga, CU11 migrará junto con el resto y se retirará la excepción de `AGENTS.md`. Los servicios de CU11 se mantienen sin lógica específica del tipo de sesión para facilitar esa migración.

## Risks / Trade-offs

- **[Excepción de sesión síncrona]** AGENTS.md exige `AsyncSession` y CU11 la incumple de forma autorizada y acotada (D14) → no se extiende a otros módulos, se prohíbe `session.query()` y se registra la migración transversal como trabajo futuro.
- **[CU12 sirve imágenes como PDF]** Los documentos `RESULTADO_LAB` JPG/PNG indexados serán visibles en CU12 con descarga errónea → la UI de CU11 usa su propio endpoint; deuda D13 para CU12.
- **[Pendientes con datos personales]** `datos_correspondencia` guarda CI recibida de una fuente externa en un resultado sin paciente → solo visible con `lab_results:review`, nunca en listados de expediente; se limita a los campos del manifiesto.
- **[Lote parcial]** Si el proceso muere a mitad de un lote, la sincronización queda `EN_PROCESO` → el reenvío del lote completo es idempotente (los ítems ya integrados quedan `DUPLICADO`). Una sincronización `EN_PROCESO` antigua se muestra tal cual, con su fecha de inicio; no se reconcilia automáticamente.
- **[Memoria y disco]** 50 ítems × 10 MB serían 500 MB en una petición → Starlette vuelca los archivos a disco temporal, se leen por bloques, y la API rechaza peticiones de más de 100 MB (D3); el tope real de la plataforma se confirma con la verificación previa Q2.
- **[Sin FK compuestas]** La coherencia de clínica entre resultado y paciente/orden/examen vive en el servicio → pruebas de aislamiento obligatorias por cada entidad referenciada.
- **[Permisos en clínicas nuevas]** El alta de clínicas no siembra permisos (D9): las clínicas creadas después de la migración, y los roles `Administrador` de la ruta `auth/clinicas`, no tendrán `lab_results:*` hasta que se asignen desde el módulo de roles. Es el mismo comportamiento de CU10 y CU12 → se prueba que la asignación manual funciona (tarea 2.6).
- **[Dos rutas de descarga]** Aceptado conscientemente (D6).

## Migration Plan

1. **Cabeza:** ejecutar `alembic heads` → `cu36_billing_overages_024 (head)` el 2026-11-18 (cabeza única). Antes de aplicar, repetirlo: si cambió, rebasar `down_revision`.
2. **Nueva revisión:** archivo `alembic/versions/025_resultados_laboratorio_cu11.py`, `revision = "cu11_resultados_laboratorio_025"` (convención de identificadores `cuNN_nombre_NNN` de las migraciones 022–024), `down_revision = "cu36_billing_overages_024"`.
3. **Contenido:** (a) `fuentes_laboratorio`, `sincronizaciones_laboratorio`, `resultados_laboratorio`, `sincronizaciones_laboratorio_items` en ese orden por dependencias de FK; (b) restricciones e índices de D1; (c) siembra idempotente de los cuatro permisos y su asignación por rol (D9).
4. **Downgrade:** quitar `rol_permisos` y `permisos` de `lab_results:*`, luego las cuatro tablas en orden inverso. No toca ninguna tabla existente.
5. **Neon:** la migración no altera tablas existentes; es aditiva y reversible. Hacer respaldo antes de aplicar (práctica ya documentada en `render.yaml`). Antes de aplicar, ejecutar las verificaciones previas Q2 y Q4 de `tasks.md` (grupo 0): `pacientes.id_clinica` debe existir en la base real de Neon y se debe conocer cuántos pacientes tienen `id_clinica` nulo.
6. **Despliegue:** primero migración, después backend, después web y móvil. Rollback: `alembic downgrade cu36_billing_overages_024` y revertir el código; no hay datos de otros casos de uso que dependan de las tablas nuevas.

## Open Questions

Estado de las preguntas (Q1 a Q7) tras la actualización del 2026-11-18:

| # | Tema | Estado | Dónde queda |
|---|---|---|---|
| Q1 | Sesión asíncrona | **Resuelta** (opción C, excepción acotada en `AGENTS.md` §5) | D14; grupo 1 de `tasks.md` |
| Q2 | Límite de tamaño del multipart en Render | **Pendiente del usuario** (no se resuelve leyendo código) | Verificación previa 0.1 de `tasks.md` |
| Q3 | Siembra de permisos en clínicas nuevas | **Resuelta**: nada que tocar en el alta de clínicas | D9; tareas 2.3 y 2.6 |
| Q4 | `pacientes.id_clinica` en Neon | **Pendiente del usuario** (consulta SQL de solo lectura) | Verificación previa 0.2 de `tasks.md` |
| Q5 | Filtro de la bitácora CU21 | **Resuelta**: sin lista blanca | D7; tarea 3.13 |
| Q6 | Filtro por `Paciente.estado` | **Resuelta**: no se filtra | D9 |
| Q7 | Carpeta duplicada `documents/` en la web | **Fuera de este change** (tarea aparte 9.1) | `tasks.md` 9.1 |
| — | Reutilización móvil de `ClinicalDocumentsProvider` | **Resuelta**: provider propio | D11 |

**Resultados de las verificaciones previas (2026-11-18):** Q2 confirmó que no hay un tope de plataforma por debajo de 101 MB y el tope de 100 MB ya figura en el contrato. Q4 confirmó el esquema esperado de `pacientes`, con un hallazgo abierto de calidad de datos: 2 de 17 pacientes sin `id_clinica` (ver `verification.md`); no bloquea el change.
