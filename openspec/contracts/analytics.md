# Contrato CU22 y CU27-reportes — etapa backend

Estado: etapa 1. Prefijo `/analytics/reportes`; no cambia rutas de agenda, CU25, bitácora, recetas ni otros documentos. JSON UTF-8 salvo exportación binaria. `Authorization: Bearer <JWT>` obligatorio. `X-Tenant-ID` puede llegar desde clientes existentes pero no determina ni amplía el ámbito; el servidor usa `Usuario.id_clinica` de la cuenta autenticada (BIGINT). No se acepta `id_clinica`, `tenant_id`, `tabla_origen` ni SQL en el body (`extra=forbid`). ADMIN con usuario, rol y clínica activos únicamente.

## Catálogo y límites

`GET /analytics/reportes/catalogo` devuelve `reportes`, `metricas_no_disponibles`, `formatos` y `limites`. IDs: `encuentros`, `citas`, `cancelaciones`, `pacientes_unicos`. `ausentismo` tiene `disponible:false`, `valor:null`, `causa:"SIN_ESTADO_AUSENCIA"`. Período inclusivo de hasta 366 días; máximo 8 filtros, 2 dimensiones agrupadas, 6 columnas, `tamano_pagina` 1–100 y 5.000 grupos por exportación. Los reportes usan `eq` para filtros catalogados. Cada reporte publica dimensiones, filtros y métricas permitidas. Modalidad: `PRESENCIAL`, `TELEMEDICINA`, `CONFLICTO`, `DESCONOCIDA`, `OTRA`.

`categorias_nulas.id_especialidad = "Sin especialidad registrada"` indica que `id_especialidad:null` forma una categoría propia al agrupar; no se infiere una especialidad histórica a partir de la asociación actual del médico.

Cada entrada de `reportes` contiene `dimensiones`, `columnas`, `ordenables`, `filtros:[{campo,operadores}]`, `metricas` y `metrica_principal`. El orden requiere que el campo esté en `columnas`; una dimensión ordenable también debe estar en `agrupacion`.

`GET /analytics/reportes/opciones` devuelve `medicos:[{id_medico,nombre}]` de usuarios médicos de la clínica y `especialidades:[{id_especialidad,nombre}]` usadas en sus citas. No carga `Medico` como entidad. Valores ajenos no aparecen. Las opciones no modifican datos.

## Consulta

`POST /analytics/reportes/consulta` recibe:

```json
{
  "reporte":"encuentros",
  "periodo":{"desde":"2026-09-01","hasta":"2026-09-30"},
  "filtros":[{"campo":"id_medico","operador":"eq","valor":20}],
  "columnas":["fecha","id_medico","encuentros","pacientes_unicos"],
  "agrupacion":["fecha","id_medico"],
  "orden":[{"campo":"fecha","direccion":"asc"}],
  "pagina":1,"tamano_pagina":20
}
```

`periodo`, `reporte` obligatorios. `filtros`, `columnas`, `agrupacion`, `orden` admiten listas vacías; los últimos tres se normalizan a defaults de catálogo. No se admiten duplicados. Todas las dimensiones agrupadas y la métrica principal deben estar en `columnas`; métricas secundarias pueden omitirse. Un orden solo usa dimensión agrupada o métrica seleccionada. Doctor ajeno o inexistente: 404 sin revelar existencia; especialidad ajena/no usada: 404. Filtros incompatibles: 422. La fecha del encuentro se deriva de `Consulta.fecha_consulta`; la de cita de `Cita.fecha_cita`. Se excluyen relaciones clínicas inconsistentes. `Paciente.id_clinica` no filtra.

Respuesta 200 de ejemplo sintético:

```json
{
  "definicion":{"reporte":"encuentros","periodo":{"desde":"2026-09-01","hasta":"2026-09-30"},"filtros":[{"campo":"id_medico","operador":"eq","valor":20}],"columnas":["fecha","id_medico","encuentros","pacientes_unicos"],"agrupacion":["fecha","id_medico"],"orden":[{"campo":"fecha","direccion":"asc"}],"pagina":1,"tamano_pagina":20},
  "semantica":"Citas distintas con consulta registrada; fecha de consulta; no equivale al total exhaustivo histórico.",
  "metricas":{"encuentros":{"disponible":true,"valor":2,"causa":null},"pacientes_unicos":{"disponible":true,"valor":2,"causa":null},"ausentismo":{"disponible":false,"valor":null,"causa":"SIN_ESTADO_AUSENCIA"}},
  "total":1,"filas":[{"fecha":"2026-09-10","id_medico":20,"encuentros":2,"pacientes_unicos":2}],
  "advertencias":["Los pacientes únicos globales no se obtienen sumando grupos."],"generado_en":"2026-10-03T12:00:00Z"
}
```

`total` cuenta grupos filtrados, no citas. Sin registros: `total=0`, `filas=[]`, métricas calculables en 0; ausentismo conserva valor nulo. La paginación afecta filas, nunca las métricas globales. Conteos: encuentros `COUNT(DISTINCT Consulta.id_cita)`; citas `COUNT(DISTINCT Cita.id_cita)`; cancelaciones citas con `estado=CANCELADA`; pacientes únicos `COUNT(DISTINCT Cita.id_paciente)` entre encuentros válidos. Una cita con varias consultas cuenta una vez en cada grupo de fecha en que hubo consulta; el global del período la cuenta una vez. No se suman grupos para inferir un total global distinto.

## Exportación CU27-reportes

`POST /analytics/reportes/exportar` recibe la misma definición y `formato` (`pdf`, `xlsx`, `csv`, `html`):

```json
{"reporte":"citas","periodo":{"desde":"2026-09-01","hasta":"2026-09-30"},"agrupacion":["fecha"],"columnas":["fecha","citas","cancelaciones"],"orden":[{"campo":"fecha","direccion":"asc"}],"formato":"xlsx"}
```

`pagina` y `tamano_pagina` se aceptan por compatibilidad pero se ignoran al exportar: se incluyen todos los grupos filtrados hasta 5.000, sin truncar. Si excede, 413. MIME: `application/pdf`, `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`, `text/csv; charset=utf-8`, `text/html; charset=utf-8`. `Content-Disposition: attachment; filename="reporte_<id>_<fecha>.<ext>"`; `Access-Control-Expose-Headers: Content-Disposition`. El archivo lleva título, ámbito de clínica, período, filtros, columnas, orden, fecha de generación y filas. Los valores de texto externos no se ejecutan como fórmulas. Una exportación posterior puede diferir de la consulta si cambió la base.

## Errores y capacidades pendientes

401 sin autenticación o token inválido; 403 por rol/estado/clínica; 404 por médico/especialidad ajena o inexistente; 422 por validación, incluido `reporte=ausentismo` con `SIN_ESTADO_AUSENCIA`; 413 por límite de exportación. FastAPI conserva la forma de error de validación existente; las causas de negocio se devuelven en `detail`.

La interpretación de texto y el dictado se describen a continuación. La adaptación móvil está escrita, pendiente de resolución de dependencias, compilación y pruebas Flutter; eMail sigue **PENDIENTE**. CU27 de otros documentos conserva sus permisos.

## Interpretación de lenguaje natural — etapa backend

`POST /analytics/reportes/interpretar` exige el mismo ADMIN activo y `Authorization` que las otras rutas. Body (`extra=forbid`): `texto` (1–1000 caracteres no blancos) y `fecha_referencia` (fecha ISO opcional). No acepta configuración anterior: **siempre construye una definición nueva completa**. El cliente reemplaza la configuración visible únicamente con `estado=valida`; no retiene filtros anteriores. `id_clinica` se toma de la cuenta, nunca del texto, proveedor ni body.

Ejemplo de solicitud sintética:

```json
{"texto":"Citas de septiembre de 2026 por fecha y médico, ordenadas por fecha","fecha_referencia":"2026-10-03"}
```

Respuesta 200 válida (el orden y columnas concretas corresponden al catálogo):

```json
{"estado":"valida","definicion":{"reporte":"citas","periodo":{"desde":"2026-09-01","hasta":"2026-09-30"},"filtros":[],"columnas":["fecha","id_medico","citas"],"agrupacion":["fecha","id_medico"],"orden":[{"campo":"fecha","direccion":"asc"}],"pagina":1,"tamano_pagina":20},"resumen":"Actividad de citas del 2026-09-01 al 2026-09-30. Agrupado por fecha, id_medico.","campos_aclaracion":[],"advertencias":["Citas distintas por fecha programada; una cita no demuestra una atención efectiva.","Ausentismo no disponible: SIN_ESTADO_AUSENCIA."]}
```

`estado=aclaracion` o `no_admitida` devuelve `definicion:null`, `resumen`, `campos_aclaracion` (por ejemplo `reporte`, `periodo`, `id_medico`) y `advertencias`. Para «este mes» se requiere `fecha_referencia`; se usa su mes y año, sin inferir la zona horaria del servidor. «Septiembre» sin año pide aclaración incluso si se proporcionó referencia. Se aceptan dos fechas ISO explícitas, un mes nombrado con año y rangos españoles completos con «desde… hasta…» o «del… al…»: días numéricos o escritos (incluido «primero»), mes nombrado en cada extremo, o mes compartido en «del 1 al 15 de septiembre de 2026». Si solo un extremo declara el año dentro de un único rango enlazado, ese año explícito se aplica a ambos; nunca se toma del reloj ni de `fecha_referencia` para completar un año ausente en el texto. Fechas inexistentes, rangos invertidos, superiores a 366 días, sin año o con más de una interpretación piden aclaración antes de llamar al proveedor. Nombres duplicados de médicos/especialidades también piden aclaración. Ausentismo es `no_admitida` con `SIN_ESTADO_AUSENCIA`; nunca se cambia por cancelaciones. La interpretación no calcula métricas ni ejecuta `/consulta` o `/exportar`.

Ejemplo adicional, con la misma solicitud/respuesta HTTP: `{"texto":"Citas agrupadas por fecha desde el 1 de enero de 2026 hasta el 3 de octubre de 2026"}` propone `periodo:{"desde":"2026-01-01","hasta":"2026-10-03"}` cuando el proveedor devuelve una definición válida; interpretar por sí mismo no genera filas.

Si el texto no pide agrupación, se usa `agrupacion:[]`. Si tampoco pide columnas ni orden, se aplican los valores predeterminados de `/consulta`: columna de métrica principal y orden vacío cuando no hay grupos. Esto rige para todos los reportes del catálogo, incluso si el proveedor propone dimensiones adicionales o pide aclarar únicamente preferencias opcionales que el texto omitió. Una preferencia solicitada explícitamente conserva su validación y puede requerir aclaración; período incompleto y opciones clínicas ambiguas también la requieren. Campos ajenos o incompatibles del proveedor producen 502 recuperable; no convierten una solicitud catalogada y válida en `no_admitida`.

Las comprobaciones locales de período, catálogo, ámbito y texto pueden devolver `aclaracion` o `no_admitida` **sin llamar a Groq**. Una respuesta `valida` requiere una salida estructurada del proveedor y validación posterior del servidor. Se leen únicamente opciones autorizadas para resolver referencias; no se consultan filas de resultados.

Errores HTTP: 401/403 como las otras rutas; 422 para cuerpo inválido; 429 por límite del proveedor; 503 si falta `GROQ_API_KEY` o el proveedor no está disponible; 504 por timeout; 502 por respuesta inválida. Ninguno expone secretos ni cuerpos crudos de Groq. La generación manual no depende de esta ruta.

Flujo web y móvil de texto: Enviar/Enter usa este endpoint, reemplaza todos los controles visibles solo con respuesta válida y llama después a `/consulta` para generar. Aplicar filtros usa el mismo endpoint y reemplaza controles sin consultar; el usuario puede ajustar la definición y pulsar Generar reporte. Si hay aclaración o rechazo, ninguna acción aplica parcialmente ni genera. El texto queda editable para reenviar una solicitud completa. La fecha de referencia se obtiene del calendario local del usuario. El dictado coloca texto editable; con «Enviar al terminar» activado y una detención explícita segura, reutiliza Enviar después de transcribir. La implementación móvil de este flujo requiere todavía verificación con Flutter. No se persisten reportes ni se envían credenciales de Groq desde el cliente.

## Dictado — transcripción sin interpretación

`POST /analytics/reportes/transcribir` exige el mismo `Authorization` y ADMIN elegible. `multipart/form-data` contiene exactamente `audio` (archivo); no acepta identificadores de clínica ni configuración de reporte. Admite grabaciones `audio/webm`, `audio/ogg`, `audio/mp4` y `audio/wav`, con contenido compatible con WebM/EBML, Ogg, MP4 o RIFF/WAVE respectivamente; el servidor comprueba firma, MIME y extensión concordantes, pero no decodifica íntegramente el audio. Archivo no vacío y máximo 5 MiB. El cliente limita la grabación a 60 segundos; el servidor **no verifica la duración**. La carga se lee con límite y no se guarda en tablas ni logs. El parser multipart puede usar un archivo temporal para cargas grandes; `UploadFile` se cierra al terminar o rechazar la carga.

Respuesta 200 JSON: `{"texto":"Encuentros de septiembre de 2026"}`. La transcripción no interpreta, consulta ni exporta. Texto ausente o en blanco del proveedor: 502, sin inventar contenido. Audio inválido: 422; exceso de tamaño: 413; límite del proveedor: 429; proveedor inválido: 502; configuración ausente o proveedor indisponible: 503; timeout: 504; autenticación/autorización: 401/403. Las causas se expresan en `detail` sin exponer datos del proveedor. La clave permanece en backend; variables `GROQ_API_KEY`, `GROQ_TRANSCRIPTION_MODEL` y `GROQ_TRANSCRIPTION_TIMEOUT_SECONDS`. El modelo inicial es `whisper-large-v3`; se puede cambiar por uno de transcripción compatible.

El único botón web de micrófono inicia/detiene la grabación, indica duración y muestra «Transcribiendo…» durante la carga. El texto previo se conserva y la transcripción se añade con separación. Si el usuario edita durante la respuesta, se ofrece incorporar explícitamente el texto pendiente. «Enviar al terminar» empieza desactivado en cada apertura; no se puede cambiar durante grabación, transcripción, interpretación o generación. Solo la detención explícita con opción activa al inicio y sin texto editado, dictado pendiente, sesión distinta ni otra acción obsoleta llama al flujo vigente de Enviar. El límite de duración, errores, cancelación y salida nunca envían automáticamente. Incorporar un dictado pendiente tampoco envía. Enviar/Enter y Aplicar filtros se bloquean durante grabación y transcripción. Se liberan tracks al detener, cancelar, salir o cambiar de cuenta; respuestas tardías se descartan. El reconocimiento puede equivocarse o producir texto dudoso con silencio/ruido; con la opción desactivada o si el envío automático se descarta, el usuario revisa el texto editable antes de interpretarlo. No se activa micrófono sin pulsar el botón.

El móvil usa la misma ruta con `audio` multipart y las mismas reglas de autoenvío. Envía WAV PCM16 mono desde memoria, con nombre y MIME concordantes; su integración requiere aún compilación y pruebas en Flutter web, Android e iOS.

## Organización interna de referencia

`app/modules/analytics/router.py` incluye los routers de `reportes/` y `exportacion/` una sola vez, siguiendo el patrón de `appointments/router.py`. `reportes/` posee catálogo, autorización, esquemas y servicio de consulta; `exportacion/` posee su esquema, ruta y generador de archivos, y reutiliza el servicio y la autorización de reportes. Esta organización no cambia las cuatro rutas ni sus solicitudes o respuestas.
