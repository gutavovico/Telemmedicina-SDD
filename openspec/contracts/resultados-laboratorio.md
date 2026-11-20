# Contrato de API REST: Resultados de Laboratorio (CU11 - Cargar, Sincronizar e Integrar Resultados de Laboratorio)

**Versión del Contrato:** 1.0.0 (SaaS Multitenant)  
**Estándar:** OpenAPI 3.1 / RESTful JSON (carga y lotes en `multipart/form-data`)  
**Rutas Base:** `/api/v1/resultados-laboratorio`, `/api/v1/fuentes-laboratorio`, `/api/v1/sincronizaciones-laboratorio`, `/api/v1/pacientes/{id_paciente}/resultados-laboratorio`  
**Seguridad Global:** `BearerAuth` (`Authorization: Bearer <JWT_ACCESS_TOKEN>`)  
**Encabezado Multitenant:** `X-Tenant-ID: <INT>` (la clínica efectiva siempre es la de la sesión; el encabezado nunca amplía el acceso)  
**Dominio:** `medical_records` / `laboratory_results` y `laboratory_sync`  
**Specs:** `openspec/changes/cu11-resultados-laboratorio/specs/laboratory-results/spec.md`, `.../laboratory-sync/spec.md`  
**Relacionados:** CU10 (`ordenes_laboratorio`, `examenes_laboratorio`), CU12 (`documentos_clinicos`, permisos `documents:*`), CU21 (auditoría)

---

## 1. Convenciones Multitenant y Seguridad

- **Clínica efectiva:** se toma de la sesión autenticada (`Usuario.id_clinica`). Una cuenta sin clínica recibe `403 Forbidden`. El contrato usa `id_clinica` (BIGINT) como en CU10/CU12; `tenant_id` es solo un alias de lectura en el servidor y **no** se acepta ni se devuelve como campo de entrada. El encabezado `X-Tenant-ID` se **ignora por completo** en los endpoints de la sección 3 (aunque venga con otra clínica o con un valor no numérico): nunca cambia ni amplía la clínica de la sesión.
- **Prevención de Tenant Injection:** `id_clinica` y `tenant_id` NO son campos de ningún request. Si aparecen en un cuerpo JSON o en el manifiesto de un lote se responde `422 Unprocessable Entity`. En el multipart de la carga manual (3.1) se rechazan con `422` los campos `id_clinica`, `tenant_id`, `estado` y `origen` (los decide el servidor) y **no** están declarados en OpenAPI.
- **Aislamiento:** paciente, orden, examen, fuente, resultado y sincronización de otra clínica responden `404 Not Found`, indistinguible de "no existe".
- **Permisos:** `lab_results:create`, `lab_results:read`, `lab_results:review`, `lab_results:sync` (tabla `permisos`, asignados vía `rol_permisos`). La descarga de archivo exige además `documents:read:lab_results` (CU12).
- **Matriz de roles:**

| Rol | create | read | review | sync | Descarga (`documents:read:lab_results`) |
|---|---|---|---|---|---|
| ADMIN | Sí | Sí | Sí | Sí | Sí |
| MEDICO | Sí | Sí | Sí | No | Sí |
| RECEPCION | Sí | Sí (solo metadatos) | No | No | No (CU12 no se lo otorga) |
| PACIENTE | No | Sí (solo lo propio) | No | No | Sí |

- **Códigos HTTP:** `200`, `201`, `400`, `401`, `403`, `404`, `409`, `422`. No se usa `413`: tamaño, formato y firma inválidos responden `422` con código de dominio.
- **Formato de error:** errores de dominio de CU11 (404, 409, 422 `ARCHIVO_*` y 500 de almacenamiento) → `{"detail": {"codigo": "<CODIGO>", "mensaje": "<texto>"}}`. Los errores de validación de campos (campos faltantes o inválidos, fecha futura, campos prohibidos, cuerpo JSON inválido) usan la forma de lista de FastAPI: `{"detail": [{"type": "...", "loc": ["body", "<campo>"], "msg": "<texto>"}]}`. Los errores de autenticación y permisos mantienen el formato estándar con texto: `401` `{"detail": "No autenticado"}` y `403` `{"detail": "Permiso denegado. Se requiere el permiso '<permiso>'."}` (o `"La cuenta autenticada no está asociada a una clínica"` para una cuenta sin clínica). Un cliente DEBE aceptar las tres formas de `detail` (objeto, lista y texto).
- **Sin borrado físico:** no existe ningún `DELETE` en este contrato. Las bajas son lógicas (`ANULADO`).

### 1.1 Catálogo de códigos de error de dominio

| Código | HTTP | Cuándo |
|---|---|---|
| `ARCHIVO_TIPO_NO_PERMITIDO` | 422 | Extensión fuera de `.pdf`, `.jpg`, `.jpeg`, `.png`, o tipo de contenido declarado que no es PDF, JPEG ni PNG (ni genérico) |
| `ARCHIVO_FIRMA_INVALIDA` | 422 | Los magic bytes no corresponden a la extensión, o el tipo de contenido declarado contradice el contenido real |
| `ARCHIVO_TAMANO_EXCEDIDO` | 422 | Más de 10 485 760 bytes |
| `ARCHIVO_VACIO` | 422 | 0 bytes |
| `ARCHIVO_AUSENTE` | 422 / ítem | Archivo no enviado o no referenciado por el manifiesto |
| `PACIENTE_NO_ENCONTRADO` | 404 / motivo | Paciente inexistente, de otra clínica o con `id_clinica` nulo; también `GET /me` de una cuenta sin perfil de paciente en su clínica |
| `RESULTADO_NO_ENCONTRADO` | 404 | Resultado inexistente, de otra clínica, o no visible para el usuario (pendiente o anulado sin `lab_results:review`, o de otro paciente) |
| `ARCHIVO_NO_ENCONTRADO` | 404 | El resultado existe pero su archivo no está en el almacenamiento |
| `EXAMEN_NO_ENCONTRADO` | 404 | `codigo_examen` inexistente, inactivo o de otra clínica |
| `ORDEN_NO_ENCONTRADA` | 404 | Orden inexistente o de otra clínica |
| `ORDEN_PACIENTE_NO_COINCIDE` | 409 / motivo | La orden es de otro paciente |
| `ORDEN_NO_FIRMADA` | 409 | La orden no está `FIRMADA` |
| `ORDEN_SIN_EXAMEN` | 409 | La orden no incluye el `codigo_examen` |
| `RESULTADO_DUPLICADO` | 409 | Carga manual con el mismo SHA-256 y paciente ya `INCORPORADO` |
| `ESTADO_NO_PERMITIDO` | 409 | Transición no permitida |
| `FUENTE_NO_ENCONTRADA` | 404 | Fuente inexistente o de otra clínica |
| `FUENTE_INACTIVA` | 409 | La fuente tiene `activa = 'NO'` |
| `FUENTE_DUPLICADA` | 409 | Código de fuente repetido en la clínica |
| `LOTE_INVALIDO` | 422 | Manifiesto inválido, más de 50 ítems, `id_externo` repetido, campos `id_clinica`/`tenant_id` o dos partes `archivos` con el mismo nombre; `fuente` del manifiesto distinta de la de la sincronización en un reintento; también una petición de ingestión o reintento mayor a 100 MB (tope por petición, rechazada por `Content-Length` antes de leer el cuerpo y antes de autenticar, ver 4.4) |
| `CONTENIDO_DISTINTO` | ítem | Mismo `id_externo` con SHA-256 distinto |
| `ALMACENAMIENTO_FALLIDO` | 500 / ítem | El almacenamiento falló al guardar el archivo (500 en la carga manual; resultado de ítem en la sincronización) |
| `ITEM_NO_REINTENTABLE` | 422 | El `id_externo` no es un ítem `ERROR` de esa sincronización: se rechaza la petición completa antes de procesar nada (ver 4.7) |
| `SINCRONIZACION_NO_ENCONTRADA` | 404 | Sincronización inexistente o de otra clínica (`GET .../{id_sincronizacion}` y `POST .../{id_sincronizacion}/reintentos`) |
| `ERROR_INTERNO` | ítem | Fallo inesperado (no previsto en este catálogo) al procesar un ítem: el ítem queda `ERROR` con el detalle genérico «Error interno al procesar el ítem.» (la causa solo se registra en el log del servidor), sin resultado ni archivo, y no afecta a los demás ítems del lote |

Motivos de pendiente (campo `motivo_pendiente`): `PACIENTE_NO_ENCONTRADO`, `PACIENTE_AMBIGUO`, `EXAMEN_NO_VALIDO`, `ORDEN_NO_VALIDA`, `ORDEN_PACIENTE_NO_COINCIDE`.

---

## 2. Esquemas de Datos (Data Schemas)

### 2.1 Reglas de archivo

| Regla | Valor |
|---|---|
| Extensiones | `.pdf`, `.jpg`, `.jpeg`, `.png` (sin distinguir mayúsculas) |
| Tamaño máximo | 10 485 760 bytes (10 MB); mínimo 1 byte |
| Firma (magic bytes) | PDF `25 50 44 46 2D` (`%PDF-`); JPEG `FF D8 FF`; PNG `89 50 4E 47 0D 0A 1A 0A` |
| `content_type` guardado | Derivado de la firma: `application/pdf`, `image/jpeg`, `image/png` |
| Tipo de contenido declarado | Se valida además de la extensión y la firma. Se ignoran los parámetros (`; charset=...`) y se aceptan los alias `image/jpg`, `image/pjpeg` y `application/x-pdf`. Se acepta un tipo genérico (`application/octet-stream`, `binary/octet-stream`) o ausente. Un tipo declarado que no sea PDF, JPEG ni PNG → `ARCHIVO_TIPO_NO_PERMITIDO`; uno permitido que contradiga el contenido real → `ARCHIVO_FIRMA_INVALIDA` |
| Orden de las validaciones | Extensión → tipo declarado → tamaño (1 byte a 10 485 760) → firma contra la extensión → tipo declarado contra la firma. La primera que falla fija el código |
| Nombre original | Se sanea y se guarda solo como metadato (`nombre_archivo`, máx. 255); nunca forma parte de la ruta de almacenamiento |

### 2.2 `ResultadoLaboratorio` (respuesta)
```json
{
  "id_resultado": 15,
  "id_clinica": 1,
  "estado": "INCORPORADO",
  "origen": "MANUAL",
  "id_paciente": 10,
  "paciente_nombre": "Carlos Alberto Mamani",
  "id_orden": 7,
  "id_examen": 3,
  "codigo_examen": "HEMOGRAMA",
  "nombre_examen": "Hemograma completo",
  "laboratorio_origen": "Laboratorio Central",
  "fecha_realizacion": "2026-11-10",
  "observaciones": "Muestra en ayunas",
  "nombre_archivo": "hemograma.pdf",
  "content_type": "application/pdf",
  "tamano_bytes": 182340,
  "hash_archivo": "a3f1...(64 hex)",
  "id_documento": 88,
  "id_fuente": null,
  "fuente_codigo": null,
  "id_externo": null,
  "id_sincronizacion": null,
  "motivo_pendiente": null,
  "datos_correspondencia": null,
  "registrado_por": 4,
  "registrado_por_nombre": "Recepción Central",
  "proceso": null,
  "registrado_en": "2026-11-18T14:05:00Z",
  "resuelto_por": null,
  "resuelto_en": null,
  "motivo_resolucion": null
}
```

| Campo | Tipo | Notas |
|---|---|---|
| `id_resultado` | integer (BIGINT) | PK |
| `id_clinica` | integer | Solo lectura |
| `estado` | string enum | `INCORPORADO`, `PENDIENTE_REVISION`, `ANULADO` |
| `origen` | string enum | `MANUAL`, `SINCRONIZADO` |
| `id_paciente` | integer \| null | Nulo si `PENDIENTE_REVISION` |
| `id_orden` | integer \| null | Orden de CU10 (`ordenes_laboratorio.id_orden`) |
| `id_examen` | integer \| null | `examenes_laboratorio.id_examen`; nulo si el estudio no es válido |
| `codigo_examen` | string (≤50) | Código recibido/seleccionado (copia) |
| `nombre_examen` | string \| null | Copia del catálogo al incorporar |
| `laboratorio_origen` | string (≤200) | Obligatorio |
| `fecha_realizacion` | date (`YYYY-MM-DD`) | No futura |
| `observaciones` | string \| null (≤2000) | Se omite (`null`) para quien no tenga `documents:read:lab_results` |
| `nombre_archivo`, `content_type`, `tamano_bytes`, `hash_archivo` | string / string / integer / string(64) | Metadatos del archivo; `hash_archivo` SHA-256 hex minúsculas |
| `id_documento` | integer \| null | `documentos_clinicos.id_documento`; nulo mientras no esté `INCORPORADO` |
| `id_fuente`, `fuente_codigo`, `id_externo`, `id_sincronizacion` | integer / string / string(≤100) / integer | Solo `SINCRONIZADO` |
| `motivo_pendiente` | string \| null | Ver catálogo; solo en `PENDIENTE_REVISION` |
| `datos_correspondencia` | object \| null | Datos crudos recibidos (`ci`, `complemento`, `codigo_examen`, `id_orden`); visible solo con `lab_results:review` |
| `registrado_por`, `proceso`, `registrado_en` | integer \| null / string \| null / datetime | Al menos uno de `registrado_por` o `proceso` está informado |
| `resuelto_por`, `resuelto_en`, `motivo_resolucion` | integer \| null / datetime \| null / string \| null | Resolución, descarte o anulación |

`archivo_url` (clave de almacenamiento) **nunca** se expone.

Para el rol RECEPCION (sin `documents:read:lab_results`) la respuesta omite `observaciones` (`null`), `hash_archivo` y `datos_correspondencia`.

### 2.3 `ResultadoLaboratorioListResponse`
```json
{ "items": [ { "...": "ResultadoLaboratorio resumido (sin observaciones ni datos_correspondencia)" } ],
  "total": 2, "page": 1, "page_size": 10, "total_pages": 1 }
```

### 2.4 `ResolverPendienteRequest` (JSON)
```json
{ "accion": "ASIGNAR", "id_paciente": 10, "codigo_examen": "HEMOGRAMA", "id_orden": 7 }
```
```json
{ "accion": "DESCARTAR", "motivo": "El archivo corresponde a otra institución" }
```

| Campo | Tipo | Reglas |
|---|---|---|
| `accion` | enum | `ASIGNAR` o `DESCARTAR` |
| `id_paciente` | integer | Obligatorio con `ASIGNAR` |
| `codigo_examen` | string | Obligatorio con `ASIGNAR` |
| `id_orden` | integer \| null | Opcional con `ASIGNAR` |
| `motivo` | string (3–500) | Obligatorio con `DESCARTAR` |

### 2.5 `AnularResultadoRequest` (JSON)
```json
{ "motivo": "Resultado cargado en el paciente equivocado" }
```
`motivo`: string (3–500), obligatorio.

### 2.6 `FuenteLaboratorio`
```json
{ "id_fuente": 2, "codigo": "LAB-CENTRAL", "nombre": "Laboratorio Central S.R.L.", "activa": "SI",
  "created_at": "2026-11-18T14:00:00Z", "updated_at": "2026-11-18T14:00:00Z" }
```

| Campo | Tipo | Reglas |
|---|---|---|
| `codigo` | string | 2–50, se normaliza a mayúsculas, `^[A-Z0-9_-]+$`; único por clínica |
| `nombre` | string | 3–200 |
| `activa` | string enum | `SI`, `NO` (misma convención que `examenes_laboratorio.activo`) |

`FuenteLaboratorioCreateRequest`: `{ "codigo", "nombre" }`. `FuenteLaboratorioUpdateRequest`: `{ "nombre"?, "activa"? }` (el código no se modifica).

### 2.7 Manifiesto de lote (`manifiesto`, JSON dentro del multipart)
```json
{
  "fuente": "LAB-CENTRAL",
  "items": [
    {
      "id_externo": "LAB-2026-000123",
      "ci": "1234567",
      "complemento": "",
      "codigo_examen": "HEMOGRAMA",
      "laboratorio_origen": "Laboratorio Central S.R.L.",
      "fecha_realizacion": "2026-11-10",
      "nombre_archivo": "hemograma.pdf",
      "id_orden": 7,
      "observaciones": null
    }
  ]
}
```

| Campo | Tipo | Reglas |
|---|---|---|
| `fuente` | string | Código de una fuente activa de la clínica |
| `items` | array | 1 a 50 elementos; `id_externo` único dentro del lote |
| `items[].id_externo` | string | 1–100; clave de idempotencia junto con la clínica y la fuente |
| `items[].ci` | string | 1–20; correspondencia por `pacientes.ci` |
| `items[].complemento` | string \| null | ≤10; por defecto `""` (como `pacientes.complemento`) |
| `items[].codigo_examen` | string | 1–50 |
| `items[].laboratorio_origen` | string | 1–200 |
| `items[].fecha_realizacion` | date | No futura |
| `items[].nombre_archivo` | string | Debe coincidir con el nombre de una parte `archivos` del multipart |
| `items[].id_orden`, `items[].observaciones` | integer \| null / string \| null | Opcionales |

Cualquier campo `id_clinica` o `tenant_id` (en la raíz o en un ítem) → `422`.

### 2.8 `SincronizacionLaboratorio` (respuesta)
```json
{
  "id_sincronizacion": 31,
  "id_fuente": 2,
  "fuente_codigo": "LAB-CENTRAL",
  "tipo": "LOTE",
  "estado": "COMPLETADA_CON_ERRORES",
  "total_items": 4,
  "incorporados": 1,
  "pendientes": 1,
  "duplicados": 1,
  "con_error": 1,
  "reintentos": 0,
  "id_usuario": 2,
  "proceso": null,
  "iniciado_en": "2026-11-18T14:10:00Z",
  "finalizado_en": "2026-11-18T14:10:03Z",
  "items": [
    { "id_externo": "LAB-2026-000123", "resultado": "INCORPORADO", "id_resultado": 15, "codigo_error": null, "detalle": null, "intento": 1 },
    { "id_externo": "LAB-2026-000124", "resultado": "PENDIENTE_REVISION", "id_resultado": 16, "codigo_error": null, "detalle": "PACIENTE_NO_ENCONTRADO", "intento": 1 },
    { "id_externo": "LAB-2026-000100", "resultado": "DUPLICADO", "id_resultado": 9, "codigo_error": null, "detalle": null, "intento": 1 },
    { "id_externo": "LAB-2026-000125", "resultado": "ERROR", "id_resultado": null, "codigo_error": "ARCHIVO_TIPO_NO_PERMITIDO", "detalle": "Extensión .exe no permitida", "intento": 1 }
  ]
}
```

| Campo | Valores |
|---|---|
| `estado` | `EN_PROCESO`, `COMPLETADA`, `COMPLETADA_CON_ERRORES`, `FALLIDA` |
| `items[].resultado` | `INCORPORADO`, `PENDIENTE_REVISION`, `DUPLICADO`, `ERROR` |
| Regla de estado | `COMPLETADA` si no hay ítems en error; `FALLIDA` si todos están en error; `COMPLETADA_CON_ERRORES` en otro caso |
| `reintentos` / `items[].intento` | `reintentos` cuenta las peticiones de reintento recibidas (sube 1 por petición); `intento` es el número de intentos de cada ítem (empieza en 1 y sube 1 cada vez que el ítem se reintenta) |
| `EN_PROCESO` | Estado transitorio mientras se procesa el lote. Si el proceso muere a mitad del lote, la sincronización queda `EN_PROCESO` (sin `finalizado_en`) con los ítems ya confirmados; reenviar el lote completo es seguro (lo integrado queda `DUPLICADO`) |

El listado devuelve la misma estructura sin `items`. El detalle los incluye.

---

## 3. Endpoints — Carga y consulta (Bloque A)

### 3.1 `POST /api/v1/resultados-laboratorio`
Carga manual de un resultado.
* **Permiso:** `lab_results:create`
* **Content-Type:** `multipart/form-data`
* **Partes:**

| Parte | Tipo | Obligatoria |
|---|---|---|
| `archivo` | file | Sí |
| `id_paciente` | integer | Sí |
| `codigo_examen` | string | Sí |
| `fecha_realizacion` | date | Sí |
| `laboratorio_origen` | string | Sí |
| `id_orden` | integer | No |
| `observaciones` | string | No |

* **Respuestas:**
  * `201 Created` → `ResultadoLaboratorio` (`estado = INCORPORADO`, `origen = MANUAL`, `id_documento` informado)
  * `401` Token inválido o ausente · `403` Sin permiso o sin clínica
  * `404` Paciente (`PACIENTE_NO_ENCONTRADO`), examen (`EXAMEN_NO_ENCONTRADO`) u orden (`ORDEN_NO_ENCONTRADA`) inexistente o de otra clínica
  * `409` `RESULTADO_DUPLICADO`, `ORDEN_PACIENTE_NO_COINCIDE`, `ORDEN_NO_FIRMADA`, `ORDEN_SIN_EXAMEN`
  * `422` Campos faltantes o inválidos, fecha futura, campos `id_clinica`, `tenant_id`, `estado` u `origen` en el cuerpo (forma de lista de FastAPI), o errores de archivo (`ARCHIVO_*`, forma de objeto)
  * `500` `ALMACENAMIENTO_FALLIDO` si el almacenamiento no pudo guardar el archivo (no queda ninguna fila)

### 3.2 `GET /api/v1/resultados-laboratorio`
Listado paginado de la clínica.
* **Permiso:** `lab_results:read`
* **Query:** `page` (≥1, def. 1), `page_size` (1–100, def. 10), `id_paciente`, `codigo_examen`, `laboratorio_origen`, `origen`, `id_fuente`, `fecha_desde`, `fecha_hasta`, `estado`.
* **Reglas de estado:** por defecto solo `INCORPORADO`. `estado=PENDIENTE_REVISION` o `estado=ANULADO` exigen `lab_results:review` (si no → `403`). Un PACIENTE siempre queda restringido a sus propios resultados `INCORPORADO` aunque envíe otro `id_paciente`.
* **Respuestas:** `200 OK` → `ResultadoLaboratorioListResponse` · `401` · `403` · `422` parámetros inválidos

### 3.3 `GET /api/v1/pacientes/{id_paciente}/resultados-laboratorio`
Resultados `INCORPORADO` en el expediente de un paciente (mismo patrón que `/api/v1/pacientes/{id_paciente}/documentos` de CU12).
* **Permiso:** `lab_results:read`
* **Query:** `page`, `page_size`, `codigo_examen`, `laboratorio_origen`, `origen`, `fecha_desde`, `fecha_hasta`.
* **Respuestas:** `200 OK` → `ResultadoLaboratorioListResponse` · `401` · `403` · `404` Paciente inexistente o de otra clínica, o PACIENTE consultando a otra persona

### 3.4 `GET /api/v1/resultados-laboratorio/me`
Resultados `INCORPORADO` del paciente autenticado (consumo móvil).
* **Permiso:** `lab_results:read` (rol PACIENTE)
* **Query:** `page`, `page_size`, `codigo_examen`, `fecha_desde`, `fecha_hasta`.
* **Respuestas:** `200 OK` → `ResultadoLaboratorioListResponse` · `401` · `403` · `404` (`PACIENTE_NO_ENCONTRADO`) El usuario no tiene perfil de paciente en su clínica. El perfil se determina por el enlace `pacientes.id_usuario` dentro de la clínica de la sesión, no por el nombre del rol: cualquier cuenta sin ese perfil (personal de la clínica, o un paciente cuyo registro no tiene clínica) recibe `404`.

### 3.5 `GET /api/v1/resultados-laboratorio/{id_resultado}`
Detalle.
* **Permiso:** `lab_results:read`
* **Respuestas:** `200 OK` → `ResultadoLaboratorio` · `401` · `403` · `404` Inexistente, de otra clínica, `PENDIENTE_REVISION`/`ANULADO` para quien no tenga `lab_results:review`, o de otro paciente para un PACIENTE

### 3.6 `GET /api/v1/resultados-laboratorio/{id_resultado}/archivo`
Descarga el archivo.
* **Permiso:** `lab_results:read` **y** `documents:read:lab_results`
* **Respuesta `200 OK`:** cuerpo binario con `Content-Type` real (`application/pdf`, `image/jpeg` o `image/png`), `Content-Disposition: attachment; filename="<nombre saneado>"` y `X-Content-Type-Options: nosniff`. Registra auditoría `DESCARGAR_RESULTADO_LABORATORIO`.
* **Otras:** `401` · `403` Falta alguno de los dos permisos · `404` Inexistente, de otra clínica, no `INCORPORADO`, o archivo no encontrado en el almacenamiento

### 3.7 `POST /api/v1/resultados-laboratorio/{id_resultado}/resolver`
Resuelve un resultado `PENDIENTE_REVISION`.
* **Permiso:** `lab_results:review`
* **Body:** `ResolverPendienteRequest`
* **Respuestas:**
  * `200 OK` → `ResultadoLaboratorio` (`INCORPORADO` con `id_documento`, o `ANULADO` con `motivo_resolucion`)
  * `404` Resultado, paciente, examen u orden inexistentes o de otra clínica
  * `409` `ESTADO_NO_PERMITIDO` (no está `PENDIENTE_REVISION`), `ORDEN_PACIENTE_NO_COINCIDE`, `ORDEN_NO_FIRMADA`, `ORDEN_SIN_EXAMEN`
  * `422` Campos obligatorios faltantes según la acción (`motivo` en `DESCARTAR`)
  * `401` · `403`

### 3.8 `POST /api/v1/resultados-laboratorio/{id_resultado}/anular`
Baja lógica de un resultado `INCORPORADO`.
* **Permiso:** `lab_results:review`
* **Body:** `AnularResultadoRequest`
* **Respuestas:** `200 OK` → `ResultadoLaboratorio` (`ANULADO`; su documento `RESULTADO_LAB` también queda `ANULADO`) · `404` · `409` `ESTADO_NO_PERMITIDO` · `422` · `401` · `403`

> Los endpoints estáticos (`/me`) se declaran antes que `/{id_resultado}` para evitar colisiones de ruta.

---

## 4. Endpoints — Fuentes y sincronización (Bloque B)

### 4.1 `GET /api/v1/fuentes-laboratorio`
* **Permiso:** `lab_results:sync` · **Query:** `activa` (`SI`/`NO`), `page`, `page_size`
* **Respuestas:** `200 OK` → lista paginada de `FuenteLaboratorio` · `401` · `403`

### 4.2 `POST /api/v1/fuentes-laboratorio`
* **Permiso:** `lab_results:sync` · **Body:** `FuenteLaboratorioCreateRequest`
* **Respuestas:** `201 Created` → `FuenteLaboratorio` (activa `SI`) · `409` `FUENTE_DUPLICADA` · `422` · `401` · `403`

### 4.3 `PATCH /api/v1/fuentes-laboratorio/{id_fuente}`
* **Permiso:** `lab_results:sync` · **Body:** `FuenteLaboratorioUpdateRequest`
* **Respuestas:** `200 OK` → `FuenteLaboratorio` · `404` Inexistente o de otra clínica · `422` · `401` · `403`

### 4.4 `POST /api/v1/sincronizaciones-laboratorio`
Ingestión de un lote.
* **Permiso:** `lab_results:sync`
* **Content-Type:** `multipart/form-data`
* **Partes:** `manifiesto` (string JSON, ver 2.7) y `archivos` (uno o más archivos; el nombre de cada parte debe coincidir con `items[].nombre_archivo`).
* **Idempotencia:** clave `(id_clinica, fuente, id_externo)` por ítem; reenviar un lote completo es seguro.
* **Respuestas:**
  * `201 Created` → `SincronizacionLaboratorio` con `items` (incluso si algunos ítems quedaron en `ERROR` o `DUPLICADO`; el estado de cada ítem va en el cuerpo)
  * `404` `FUENTE_NO_ENCONTRADA` · `409` `FUENTE_INACTIVA`
  * `422` `LOTE_INVALIDO` (manifiesto inválido o ausente, >50 ítems, `id_externo` repetido, campos de clínica en el manifiesto o como parte del formulario, dos partes `archivos` con el mismo nombre); en estos casos no se crea nada
  * `401` · `403`
* **Reglas del lote:**
  * Un ítem cuyo `nombre_archivo` no coincide con ninguna parte `archivos` queda `ERROR` (`ARCHIVO_AUSENTE`) sin afectar a los demás; varios ítems pueden referenciar la misma parte; las partes no referenciadas se ignoran; dos partes con el mismo nombre son ambiguas y rechazan el lote.
  * **Tope por petición:** una petición con `Content-Length` mayor a 100 MB (104 857 600 bytes; 100 MB exactos se aceptan) responde `422 LOTE_INVALIDO` **antes de leer el cuerpo y antes de autenticar** (por eso un cliente sin token recibe `422` y no `401` con una petición de ese tamaño). Aplica también a 4.7.
  * **Manifiesto de más de 1 MB:** lo rechaza Starlette antes de llegar a la aplicación con `400 Bad Request` y cuerpo `{"detail": "Part exceeded maximum size of 1024KB."}` (texto plano, **no** es `LOTE_INVALIDO`). Un manifiesto de 50 ítems pesa muy por debajo de ese límite (≈110 KB con observaciones de 2000 caracteres en todos); un cliente DEBE tratar este `400` como error de manifiesto.
  * Cada ítem se procesa en su propia unidad de trabajo (SAVEPOINT más `commit` por ítem): el fallo de un ítem nunca revierte a los demás ni aborta el lote.

### 4.5 `GET /api/v1/sincronizaciones-laboratorio`
* **Permiso:** `lab_results:sync` · **Query:** `page`, `page_size`, `id_fuente`, `estado`, `fecha_desde`, `fecha_hasta`
* **Respuestas:** `200 OK` → lista paginada de `SincronizacionLaboratorio` sin `items` · `401` · `403` · `422`

### 4.6 `GET /api/v1/sincronizaciones-laboratorio/{id_sincronizacion}`
* **Permiso:** `lab_results:sync`
* **Respuestas:** `200 OK` → `SincronizacionLaboratorio` con `items` (incluye `codigo_error` y `detalle`) · `404` `SINCRONIZACION_NO_ENCONTRADA` (inexistente o de otra clínica) · `401` · `403`

### 4.7 `POST /api/v1/sincronizaciones-laboratorio/{id_sincronizacion}/reintentos`
Reintenta solo ítems `ERROR` de una sincronización.
* **Permiso:** `lab_results:sync`
* **Content-Type:** `multipart/form-data`
* **Partes:** `manifiesto` (mismo esquema que 2.7, solo con los ítems a reintentar; `fuente` debe coincidir con la de la sincronización) y `archivos`.
* **Reglas:** cada `id_externo` debe ser un ítem `ERROR` de esa sincronización; si alguno no lo es (integrado, pendiente, duplicado, ya reintentado con éxito, o que no pertenece a la sincronización) se rechaza la **petición completa** con `422 ITEM_NO_REINTENTABLE` antes de procesar nada, sin crear resultados ni modificar ítems. Se aplica la misma idempotencia. Por cada ítem reintentado se incrementa su `intento` en 1; el contador `reintentos` de la sincronización sube en **1 por petición de reintento** (no por ítem). Los contadores y el estado se recalculan desde los ítems.
* **Respuestas:** `200 OK` → `SincronizacionLaboratorio` actualizada · `404` `SINCRONIZACION_NO_ENCONTRADA` (inexistente o de otra clínica) · `409` `FUENTE_INACTIVA` · `422` `LOTE_INVALIDO` / `ITEM_NO_REINTENTABLE` · `401` · `403`

---

## 5. Auditoría (tabla `auditoria`)

Todas las acciones se registran con `id_clinica`, `id_usuario`, `tabla_afectada`, `registro_id` y `accion`, en la misma transacción del cambio.

| `accion` | `tabla_afectada` | Cuándo |
|---|---|---|
| `CREAR_RESULTADO_LABORATORIO` | `resultados_laboratorio` | Carga manual o incorporación en sincronización |
| `REGISTRAR_RESULTADO_PENDIENTE` | `resultados_laboratorio` | Ítem sincronizado que queda `PENDIENTE_REVISION` |
| `RESOLVER_RESULTADO_LABORATORIO` | `resultados_laboratorio` | Asignar o descartar un pendiente |
| `ANULAR_RESULTADO_LABORATORIO` | `resultados_laboratorio` | Anulación lógica |
| `DESCARGAR_RESULTADO_LABORATORIO` | `resultados_laboratorio` | Descarga del archivo |
| `EJECUTAR_SINCRONIZACION_LABORATORIO` | `sincronizaciones_laboratorio` | Ingestión de un lote |
| `REINTENTAR_SINCRONIZACION_LABORATORIO` | `sincronizaciones_laboratorio` | Reintento |
| `CREAR_FUENTE_LABORATORIO`, `ACTUALIZAR_FUENTE_LABORATORIO` | `fuentes_laboratorio` | Gestión de fuentes |

---

## 6. Restricciones de Base de Datos (resumen)

Detalle completo en `design.md`. Tablas nuevas: `resultados_laboratorio`, `fuentes_laboratorio`, `sincronizaciones_laboratorio`, `sincronizaciones_laboratorio_items`.

* `UNIQUE (id_clinica, codigo)` en `fuentes_laboratorio`.
* `UNIQUE (id_clinica, id_fuente, id_externo)` en `resultados_laboratorio` (idempotencia).
* Índice único parcial para carga manual duplicada: `(id_clinica, id_paciente, hash_archivo)` donde `origen = 'MANUAL'` y `estado = 'INCORPORADO'`.
* `CHECK`: `INCORPORADO` ⇒ `id_paciente` y `id_examen` no nulos; `PENDIENTE_REVISION` ⇒ `id_paciente` e `id_documento` nulos; `SINCRONIZADO` ⇔ `id_fuente` e `id_externo` informados; `registrado_por` o `proceso` informado.
* `UNIQUE (id_sincronizacion, id_externo)` en `sincronizaciones_laboratorio_items`.
