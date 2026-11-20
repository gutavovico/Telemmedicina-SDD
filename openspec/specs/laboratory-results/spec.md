# CU11 — Resultados de laboratorio (carga y consulta)

## Purpose

Permite al personal autorizado de una entidad de salud cargar resultados de laboratorio, vincularlos con el paciente, el estudio y la orden correspondiente, y consultarlos en el expediente, sin cruzar datos entre clínicas. La trazabilidad de cada incorporación y el estado `PENDIENTE_REVISION` impiden que un resultado sin correspondencia válida llegue a un expediente incorrecto.

Trazabilidad con CU11: cada escenario lleva entre corchetes el criterio de aceptación que cubre ([C1] a [C9]). Los criterios 4, 6 y 8 se cubren en la capacidad `laboratory-sync`.

## Requirements

### Requirement: Selección de paciente y registro del resultado [C1]
El sistema SHALL permitir a un usuario con el permiso `lab_results:create` seleccionar un paciente de su propia clínica y registrar un resultado de laboratorio para ese paciente. El sistema SHALL resolver la clínica exclusivamente desde la sesión autenticada y SHALL NOT aceptar `tenant_id` ni `id_clinica` en el cuerpo de la petición. El sistema SHALL ignorar por completo el encabezado `X-Tenant-ID` en estos endpoints: nunca cambia ni amplía la clínica de la sesión.

#### Scenario: [C1] Registro exitoso para un paciente de la clínica
- **GIVEN** un usuario RECEPCION con `lab_results:create` de la clínica 1 y un paciente activo de la clínica 1
- **WHEN** registra un resultado con un archivo válido para ese paciente
- **THEN** la respuesta es 201 con el resultado en estado `INCORPORADO` y `id_clinica` igual a 1

#### Scenario: [C1] Paciente de otra clínica
- **GIVEN** un paciente que pertenece a la clínica 2
- **WHEN** un usuario de la clínica 1 intenta registrar un resultado para ese paciente
- **THEN** la respuesta es 404 y no se crea ningún resultado ni se almacena ningún archivo

#### Scenario: [C1] Cuerpo con identificador de clínica
- **WHEN** la petición incluye un campo `id_clinica` o `tenant_id`
- **THEN** el sistema la rechaza con 422 y no crea nada; esos campos no están declarados en la documentación OpenAPI del endpoint

#### Scenario: [C1] Encabezado de otra clínica
- **GIVEN** un usuario de la clínica 1
- **WHEN** envía la petición con el encabezado `X-Tenant-ID` de la clínica 2
- **THEN** el sistema lo ignora: el resultado se registra en la clínica 1 y los pacientes de la clínica 2 siguen respondiendo 404

#### Scenario: [C1] Sin permiso de carga
- **GIVEN** un usuario PACIENTE sin `lab_results:create`
- **WHEN** intenta registrar un resultado
- **THEN** la respuesta es 403 y no se crea nada

### Requirement: Carga manual con identificación del estudio [C2]
El sistema SHALL exigir en la carga manual el archivo del resultado, el código del estudio, la fecha de realización y el laboratorio de origen. El estudio SHALL identificarse por el `codigo` de un examen activo del catálogo `examenes_laboratorio` de la misma clínica. La fecha de realización SHALL NOT ser posterior a la fecha actual. El sistema SHALL aceptar de forma opcional una observación libre de hasta 2000 caracteres.

#### Scenario: [C2] Carga completa
- **WHEN** el usuario envía archivo, `codigo_examen` activo del catálogo de su clínica, `fecha_realizacion` válida y `laboratorio_origen`
- **THEN** el resultado queda con origen `MANUAL`, el nombre y código del estudio resueltos desde el catálogo y el laboratorio de origen guardado

#### Scenario: [C2] Estudio inexistente o de otra clínica
- **WHEN** el `codigo_examen` no existe en el catálogo de la clínica, está inactivo (`activo = 'NO'`) o solo existe en otra clínica
- **THEN** la respuesta es 404 y no se persiste nada

#### Scenario: [C2] Falta un campo obligatorio
- **WHEN** falta el archivo, `codigo_examen`, `fecha_realizacion`, `laboratorio_origen` o `id_paciente`
- **THEN** la respuesta es 422 indicando el campo faltante

#### Scenario: [C2] Fecha de realización futura
- **WHEN** `fecha_realizacion` es posterior a la fecha actual
- **THEN** la respuesta es 422

### Requirement: Vínculo opcional con la orden de laboratorio [C2]
El sistema SHALL aceptar un `id_orden` opcional. Si se informa, la orden SHALL pertenecer a la misma clínica y al mismo paciente, SHALL estar en estado `FIRMADA` y SHALL incluir el `codigo_examen` entre los elementos de su lista `examenes`. Si se omite, el resultado SHALL quedar sin orden asociada.

#### Scenario: [C2] Orden válida
- **GIVEN** una orden FIRMADA del mismo paciente y clínica que incluye el código `HEMOGRAMA`
- **WHEN** se registra un resultado de `HEMOGRAMA` con ese `id_orden`
- **THEN** el resultado queda vinculado a la orden

#### Scenario: [C2] Orden de otra clínica
- **WHEN** el `id_orden` pertenece a otra clínica
- **THEN** la respuesta es 404

#### Scenario: [C2] Orden de otro paciente
- **WHEN** el `id_orden` pertenece a la misma clínica pero a otro paciente
- **THEN** la respuesta es 409 y no se persiste nada

#### Scenario: [C2] Orden no firmada o sin el estudio
- **WHEN** la orden está en `BORRADOR` o `ANULADA`, o no incluye el `codigo_examen` indicado
- **THEN** la respuesta es 409 y no se persiste nada

### Requirement: Validación de datos y archivos antes de guardar [C3]
El sistema SHALL validar todos los campos y el archivo antes de persistir cualquier dato o almacenar cualquier archivo. El archivo SHALL tener extensión `.pdf`, `.jpg`, `.jpeg` o `.png`, SHALL tener un tamaño mayor que 0 y de hasta 10 MB (10 485 760 bytes), y su contenido SHALL comenzar con la firma de archivo (magic bytes) correspondiente: `%PDF-` para PDF, `FF D8 FF` para JPEG y `89 50 4E 47 0D 0A 1A 0A` para PNG. El tipo de contenido guardado SHALL derivarse de la firma detectada y no del encabezado declarado por el cliente. El sistema SHALL validar además el tipo de contenido declarado: uno que no sea PDF, JPEG ni PNG SHALL rechazarse como tipo no permitido, y uno permitido que contradiga el contenido real SHALL rechazarse como firma inválida; se SHALL aceptar un tipo genérico (`application/octet-stream`), la ausencia de tipo, los parámetros del tipo (`; charset=...`) y los alias `image/jpg`, `image/pjpeg` y `application/x-pdf`. El nombre de archivo SHALL sanearse y SHALL NOT usarse para construir rutas de almacenamiento.

#### Scenario: [C3] Extensión no permitida
- **WHEN** se sube un archivo `resultado.exe` o `resultado.docx`
- **THEN** la respuesta es 422 con el código `ARCHIVO_TIPO_NO_PERMITIDO` y no se persiste ni almacena nada

#### Scenario: [C3] Firma que no corresponde a la extensión
- **WHEN** se sube un archivo llamado `resultado.pdf` cuyo contenido no comienza con `%PDF-`
- **THEN** la respuesta es 422 con el código `ARCHIVO_FIRMA_INVALIDA`

#### Scenario: [C3] Tipo de contenido declarado no permitido
- **WHEN** se sube un archivo `resultado.pdf` válido con el tipo declarado `text/html`
- **THEN** la respuesta es 422 con el código `ARCHIVO_TIPO_NO_PERMITIDO` y no se persiste ni almacena nada

#### Scenario: [C3] Tipo de contenido declarado que contradice el contenido
- **WHEN** se sube un PDF válido con extensión `.pdf` y el tipo declarado `image/png`
- **THEN** la respuesta es 422 con el código `ARCHIVO_FIRMA_INVALIDA`

#### Scenario: [C3] Tipo de contenido genérico o alias
- **WHEN** se sube un PDF válido declarado como `application/octet-stream`, o un JPEG válido declarado como `image/jpg`
- **THEN** el archivo se acepta y el tipo guardado es el detectado (`application/pdf` o `image/jpeg`)

#### Scenario: [C3] Archivo demasiado grande
- **WHEN** el archivo supera 10 485 760 bytes
- **THEN** la respuesta es 422 con el código `ARCHIVO_TAMANO_EXCEDIDO` y no se almacena nada

#### Scenario: [C3] Archivo vacío
- **WHEN** el archivo tiene 0 bytes
- **THEN** la respuesta es 422 con el código `ARCHIVO_VACIO`

#### Scenario: [C3] Nombre de archivo malicioso
- **WHEN** el nombre del archivo contiene `../` o separadores de ruta
- **THEN** el archivo se almacena bajo una clave generada por el sistema y el nombre original saneado solo se conserva como metadato

### Requirement: Estados del resultado y no incorporación sin correspondencia [C5]
El sistema SHALL mantener cada resultado en exactamente uno de los estados `INCORPORADO`, `PENDIENTE_REVISION` o `ANULADO`. Un resultado `PENDIENTE_REVISION` SHALL tener `id_paciente` nulo, SHALL NOT estar indexado en `documentos_clinicos` y SHALL NOT aparecer en el expediente de ningún paciente, en los listados de pacientes ni en las consultas de CU12. Un resultado `INCORPORADO` SHALL tener paciente y estudio válidos de la misma clínica. Las transiciones permitidas SHALL ser únicamente `PENDIENTE_REVISION → INCORPORADO`, `PENDIENTE_REVISION → ANULADO` e `INCORPORADO → ANULADO`; `ANULADO` SHALL ser terminal.

#### Scenario: [C5] Un pendiente no aparece en ningún expediente
- **GIVEN** un resultado en `PENDIENTE_REVISION` cuyos datos crudos mencionan la CI de un paciente existente
- **WHEN** un médico consulta el expediente de ese paciente
- **THEN** el resultado no figura en el listado ni en los documentos clínicos del paciente

#### Scenario: [C5] Transición no permitida
- **WHEN** se intenta resolver un resultado que ya está `INCORPORADO` o `ANULADO` como si fuera pendiente
- **THEN** la respuesta es 409 y el estado no cambia

#### Scenario: [C5] Estado forzado por el cliente
- **WHEN** el cliente envía un campo `estado` u `origen` en la carga manual
- **THEN** el sistema lo rechaza con 422 y no crea nada; el estado inicial de una carga manual válida es siempre `INCORPORADO` y su origen `MANUAL`

### Requirement: Revisión y resolución de pendientes [C5]
El sistema SHALL permitir a un usuario con `lab_results:review` listar los resultados `PENDIENTE_REVISION` de su clínica, con el motivo por el que no se pudo corresponder y los datos crudos de correspondencia recibidos, y resolverlos de dos formas: asignando paciente, estudio y orden opcional válidos de la misma clínica (pasa a `INCORPORADO` e indexa el archivo en `documentos_clinicos`), o descartándolos con un motivo obligatorio (pasa a `ANULADO`). Al asignar, aplican las mismas validaciones de paciente, estudio y orden que en la carga manual.

#### Scenario: [C5] Asignar un pendiente
- **GIVEN** un resultado `PENDIENTE_REVISION` con motivo `PACIENTE_NO_ENCONTRADO`
- **WHEN** un médico con `lab_results:review` lo asigna a un paciente y estudio válidos de su clínica
- **THEN** el resultado pasa a `INCORPORADO`, queda enlazado a un documento `RESULTADO_LAB` y se registra quién lo resolvió y cuándo

#### Scenario: [C5] Asignar a un paciente de otra clínica
- **WHEN** el revisor intenta asignar el pendiente a un paciente de otra clínica
- **THEN** la respuesta es 404 y el resultado sigue `PENDIENTE_REVISION`

#### Scenario: [C5] Descartar con motivo
- **WHEN** el revisor descarta un pendiente indicando un motivo
- **THEN** el resultado pasa a `ANULADO` y el motivo queda registrado

#### Scenario: [C5] Descartar sin motivo
- **WHEN** el revisor descarta un pendiente sin motivo
- **THEN** la respuesta es 422 y el estado no cambia

#### Scenario: [C5] Revisión sin permiso
- **GIVEN** un usuario RECEPCION sin `lab_results:review`
- **WHEN** intenta listar pendientes o resolver uno
- **THEN** la respuesta es 403

### Requirement: Anulación lógica de resultados incorporados [C9]
El sistema SHALL permitir a un usuario con `lab_results:review` anular un resultado `INCORPORADO` indicando un motivo, mediante baja lógica. La anulación SHALL conservar el archivo y los metadatos, SHALL marcar el documento clínico asociado como `ANULADO` y SHALL excluir el resultado de las consultas del expediente. El sistema SHALL NOT ofrecer eliminación física de resultados.

#### Scenario: [C9] Anular un resultado incorporado
- **WHEN** un revisor anula un resultado `INCORPORADO` con motivo
- **THEN** el resultado y su documento clínico quedan `ANULADO`, dejan de listarse en el expediente y se registra una traza de auditoría

#### Scenario: [C9] Eliminación física
- **WHEN** se intenta eliminar un resultado con cualquier método HTTP de borrado
- **THEN** no existe tal operación y la respuesta es 404 o 405

### Requirement: Consulta de resultados en el expediente [C7]
El sistema SHALL poner a disposición de los usuarios autorizados los resultados `INCORPORADO` de un paciente de su clínica, con listado paginado, filtros por estudio, laboratorio, rango de fecha de realización y origen, y detalle individual. El alcance SHALL depender del rol: ADMIN y MEDICO consultan los resultados de cualquier paciente de la clínica; RECEPCION consulta únicamente metadatos; PACIENTE consulta únicamente los suyos. Un resultado `ANULADO` o `PENDIENTE_REVISION` SHALL NOT aparecer en el expediente.

#### Scenario: [C7] El médico consulta el expediente
- **GIVEN** un paciente con dos resultados `INCORPORADO` y uno `ANULADO`
- **WHEN** un médico con `lab_results:read` lista los resultados del paciente
- **THEN** recibe solo los dos incorporados, con estudio, laboratorio de origen, fecha de realización y origen

#### Scenario: [C7] El paciente consulta lo propio
- **WHEN** un PACIENTE con `lab_results:read` lista sus resultados
- **THEN** recibe solo los suyos, aunque envíe el `id_paciente` de otra persona

#### Scenario: [C7] Un paciente intenta ver otro paciente
- **WHEN** un PACIENTE solicita el detalle de un resultado de otro paciente de la misma clínica
- **THEN** la respuesta es 404

#### Scenario: [C7] Cuenta sin perfil de paciente consulta sus resultados
- **GIVEN** una cuenta de personal, o una cuenta de paciente cuyo registro de paciente no tiene clínica
- **WHEN** solicita sus propios resultados (`/me`)
- **THEN** la respuesta es 404 porque no tiene perfil de paciente en su clínica; el perfil se determina por el enlace del paciente con la cuenta dentro de la clínica de la sesión y no por el nombre del rol

#### Scenario: [C7] Recepción solo ve metadatos
- **GIVEN** un usuario RECEPCION con `lab_results:read` pero sin `documents:read:lab_results`
- **WHEN** consulta el detalle de un resultado
- **THEN** recibe los metadatos sin el campo `observaciones` y la descarga del archivo responde 403

#### Scenario: [C7] Acceso cruzado entre clínicas
- **WHEN** un usuario de la clínica 1 solicita el detalle de un resultado de la clínica 2
- **THEN** la respuesta es 404

### Requirement: Descarga del archivo con tipo de contenido correcto [C7]
El sistema SHALL entregar el archivo de un resultado `INCORPORADO` solo a usuarios con `lab_results:read` y `documents:read:lab_results`, con el `Content-Type` real del archivo guardado (`application/pdf`, `image/jpeg` o `image/png`), un nombre de archivo saneado y la cabecera `X-Content-Type-Options: nosniff`. Cada descarga SHALL registrar una traza de auditoría. El sistema SHALL NOT servir un archivo `PENDIENTE_REVISION` ni `ANULADO` mediante este endpoint.

#### Scenario: [C7] Descarga de una imagen
- **GIVEN** un resultado `INCORPORADO` con archivo PNG
- **WHEN** un médico lo descarga
- **THEN** la respuesta es 200 con `Content-Type: image/png` y el contenido es idéntico al archivo cargado (mismo SHA-256)

#### Scenario: [C7] Descarga de un resultado anulado
- **WHEN** se solicita el archivo de un resultado `ANULADO`
- **THEN** la respuesta es 404

#### Scenario: [C7] Descarga sin permiso de lectura de resultados
- **GIVEN** un usuario sin `documents:read:lab_results`
- **WHEN** solicita el archivo
- **THEN** la respuesta es 403 y no se registra descarga

### Requirement: Trazabilidad e integridad de cada incorporación [C9]
El sistema SHALL conservar en cada resultado el origen (`MANUAL` o `SINCRONIZADO`), la fuente y el identificador externo cuando exista, la fecha de registro, el usuario responsable o el proceso responsable, el SHA-256 del archivo y, cuando corresponda, quién resolvió el pendiente y cuándo. El sistema SHALL registrar una traza de auditoría de la clínica por cada creación, resolución, anulación y descarga, dentro de la misma transacción que el cambio de datos, de modo que si la auditoría falla el cambio se revierte. El sistema SHALL impedir registrar de nuevo el mismo archivo para el mismo paciente en carga manual mientras el resultado anterior siga `INCORPORADO`.

#### Scenario: [C9] Trazabilidad de la carga manual
- **WHEN** un usuario registra un resultado manual válido
- **THEN** el resultado guarda origen `MANUAL`, el usuario responsable, la fecha de registro y el SHA-256, y existe una traza de auditoría de la acción con el id del resultado

#### Scenario: [C9] Falla de auditoría
- **WHEN** la auditoría no puede registrarse durante una creación
- **THEN** la transacción se revierte, no queda resultado ni documento clínico y el archivo almacenado se elimina

#### Scenario: [C9] Carga manual duplicada
- **GIVEN** un resultado manual `INCORPORADO` de un paciente con un archivo de cierto SHA-256
- **WHEN** se vuelve a cargar el mismo archivo para el mismo paciente
- **THEN** la respuesta es 409 con el código `RESULTADO_DUPLICADO` y no se crea un segundo registro

#### Scenario: [C9] Duplicado tras anulación
- **GIVEN** que el resultado anterior está `ANULADO`
- **WHEN** se carga el mismo archivo para el mismo paciente
- **THEN** la carga se acepta

### Requirement: Permisos y asignación por rol [C9]
El sistema SHALL definir los permisos `lab_results:create`, `lab_results:read`, `lab_results:review` y `lab_results:sync`, sembrados por migración y evaluados contra `permisos` y `rol_permisos`. La asignación SHALL ser: ADMIN todos; MEDICO `create`, `read` y `review`; RECEPCION `create` y `read`; PACIENTE solo `read`. El sistema SHALL NOT crear un rol `LABORATORIO`. La descarga del archivo SHALL requerir además `documents:read:lab_results`, que RECEPCION no posee según la matriz de CU12.

#### Scenario: [C9] Matriz de permisos sembrada
- **WHEN** se aplica la migración sobre una base con los roles ADMIN, MEDICO, RECEPCION y PACIENTE
- **THEN** cada rol queda con exactamente los permisos `lab_results:*` de la matriz y no existe un rol `LABORATORIO`

#### Scenario: [C9] Sesión sin clínica
- **GIVEN** una cuenta global sin `id_clinica`
- **WHEN** invoca cualquier endpoint de resultados
- **THEN** la respuesta es 403

#### Scenario: [C9] Sin autenticación
- **WHEN** se invoca cualquier endpoint sin token válido
- **THEN** la respuesta es 401

### Requirement: Forma uniforme de los errores
El sistema SHALL responder los errores de dominio (recurso no encontrado, conflictos, archivo inválido, fallo del almacenamiento) con un objeto `{"detail": {"codigo": "<CODIGO>", "mensaje": "<texto>"}}`; los errores de validación de campos con la forma de lista de FastAPI (`{"detail": [{"type", "loc", "msg"}]}`); y los de autenticación y permisos con un texto (`{"detail": "<mensaje>"}`). Las respuestas de error SHALL NOT incluir datos de otra clínica.

#### Scenario: Error de dominio con código
- **WHEN** se solicita un resultado de otra clínica
- **THEN** la respuesta es 404 con `detail.codigo` igual a `RESULTADO_NO_ENCONTRADO`, indistinguible de la de un resultado inexistente

#### Scenario: Error de validación de campos
- **WHEN** falta un campo obligatorio o la fecha de realización es futura
- **THEN** la respuesta es 422 y `detail` es una lista cuyos elementos indican el campo en `loc`

#### Scenario: Error de permisos
- **WHEN** un usuario sin `lab_results:create` intenta cargar un resultado
- **THEN** la respuesta es 403 y `detail` es un texto que nombra el permiso requerido

### Requirement: Integridad y unicidad de los datos
El sistema SHALL garantizar que un resultado `INCORPORADO` siempre tenga paciente y estudio, que un resultado `PENDIENTE_REVISION` no tenga paciente ni documento clínico, que todo resultado tenga usuario o proceso responsable, y que el identificador externo y la fuente solo existan juntos en resultados `SINCRONIZADO`. La combinación `(id_clinica, fuente, id_externo)` SHALL ser única. Estas reglas SHALL aplicarse también a nivel de base de datos.

#### Scenario: Incorporado sin paciente
- **WHEN** una operación intenta dejar un resultado `INCORPORADO` con `id_paciente` nulo
- **THEN** la base de datos rechaza el cambio

#### Scenario: Pendiente con paciente asignado
- **WHEN** una operación intenta guardar un resultado `PENDIENTE_REVISION` con `id_paciente` informado
- **THEN** la base de datos rechaza el cambio

### Requirement: Puntos de integración con CU10 y CU12
El sistema SHALL depender únicamente de las siguientes tablas y permisos existentes de CU10 y CU12 y SHALL NOT modificar su comportamiento ni su esquema. CU11 SHALL NOT modificar `create_document` de CU12.

| Elemento existente | Uso en CU11 |
|---|---|
| Tabla `examenes_laboratorio` (`id_examen`, `id_clinica`, `codigo`, `nombre`, `activo`; único por `id_clinica`, `codigo`) | Catálogo que identifica el estudio |
| Tabla `ordenes_laboratorio` (`id_orden`, `id_clinica`, `id_paciente`, `estado`, `examenes`) | Vínculo opcional; debe estar `FIRMADA` |
| Tabla `documentos_clinicos` (`tipo_documento = 'RESULTADO_LAB'`, `archivo_url`, `hash_archivo`, `metadatos`, `estado`) | Índice del resultado incorporado en el expediente |
| Tabla `pacientes` (`id_paciente`, `id_clinica`, `id_usuario`, `ci`, `complemento`) | Selección y correspondencia de pacientes |
| Permisos `documents:read:lab_results`, `documents:download`, `documents:search` | Descarga del archivo y coherencia con la matriz de CU12 |
| Tablas `permisos`, `rol_permisos`, `roles`, `auditoria` | Permisos y trazabilidad |
| Almacenamiento de `clinical_documents` (`STORAGE_BACKEND`) | Persistencia del archivo |

#### Scenario: Orden y documento coexisten
- **WHEN** un resultado incorporado se vincula a una orden
- **THEN** la orden conserva su estado `FIRMADA`, su PDF y su documento `ORDEN_LAB` sin modificación

#### Scenario: Documento clínico del resultado
- **WHEN** un resultado pasa a `INCORPORADO`
- **THEN** existe un documento `RESULTADO_LAB` activo de la misma clínica y paciente cuyo `metadatos` referencia el id del resultado
