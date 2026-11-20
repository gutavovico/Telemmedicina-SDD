## Purpose

Permite sincronizar por lote los resultados que entrega una fuente de laboratorio configurada para la clínica, vinculándolos con el paciente y el estudio correspondientes, sin duplicar resultados ya integrados, dejando en revisión lo que no corresponde y registrando errores para reintentar de forma segura.

Trazabilidad con CU11: cada escenario lleva entre corchetes el criterio de aceptación que cubre ([C1] a [C9]). Los criterios 1, 2, 3 y 7 se cubren en la capacidad `laboratory-results`. El webhook o la consulta periódica a laboratorios externos no forman parte de esta capacidad (ver no-objetivos en `design.md`).

## ADDED Requirements

### Requirement: Fuentes de laboratorio configuradas por clínica [C4]
El sistema SHALL mantener por clínica un catálogo de fuentes de laboratorio con código único dentro de la clínica, nombre y estado activa o inactiva. Un usuario con `lab_results:sync` SHALL poder listar, crear y activar o desactivar fuentes de su clínica. El código SHALL normalizarse a mayúsculas y SHALL contener solo letras, dígitos, guion y guion bajo, con 2 a 50 caracteres. El sistema SHALL NOT ofrecer eliminación de fuentes. Una fuente SHALL pertenecer a una sola clínica y SHALL NOT ser visible ni utilizable desde otra.

#### Scenario: [C4] Crear una fuente
- **WHEN** un ADMIN con `lab_results:sync` crea una fuente con código `lab-central` y nombre válido
- **THEN** la respuesta es 201, el código queda `LAB-CENTRAL`, la fuente queda activa y se audita la creación

#### Scenario: [C4] Código repetido en la misma clínica
- **GIVEN** una fuente `LAB-CENTRAL` en la clínica 1
- **WHEN** se intenta crear otra con el mismo código en la clínica 1
- **THEN** la respuesta es 409

#### Scenario: [C4] Mismo código en otra clínica
- **WHEN** la clínica 2 crea una fuente con el código `LAB-CENTRAL`
- **THEN** la creación es válida porque la unicidad es por clínica

#### Scenario: [C4] Fuente de otra clínica
- **WHEN** un usuario de la clínica 1 intenta consultar o modificar una fuente de la clínica 2
- **THEN** la respuesta es 404

#### Scenario: [C4] Gestión sin permiso
- **GIVEN** un usuario MEDICO sin `lab_results:sync`
- **WHEN** intenta crear o modificar una fuente
- **THEN** la respuesta es 403

### Requirement: Ingestión por lote desde una fuente activa [C4]
El sistema SHALL aceptar un lote de hasta 50 resultados enviado por un usuario con `lab_results:sync` y asociado a una fuente activa de su clínica. El lote SHALL componerse de un manifiesto con los datos de cada ítem y de los archivos referenciados por el manifiesto. Cada ítem SHALL informar un `id_externo` único dentro del lote, la CI del paciente, el código del estudio, el laboratorio de origen, la fecha de realización y el nombre del archivo. El sistema SHALL rechazar el lote completo, sin crear nada, si la fuente no existe en la clínica, está inactiva, el manifiesto es inválido, supera 50 ítems, repite un `id_externo` o el envío trae dos archivos con el mismo nombre.

#### Scenario: [C4] Lote válido de una fuente activa
- **GIVEN** una fuente activa de la clínica y un lote de 3 ítems con pacientes y estudios válidos
- **WHEN** un usuario con `lab_results:sync` envía el lote
- **THEN** los 3 resultados quedan `INCORPORADO`, con origen `SINCRONIZADO`, la fuente y su `id_externo`, y se crea un registro de sincronización `COMPLETADA`

#### Scenario: [C4] Fuente inexistente o de otra clínica
- **WHEN** el lote indica el código de una fuente que no existe en la clínica del usuario
- **THEN** la respuesta es 404 y no se crea sincronización ni resultado alguno

#### Scenario: [C4] Fuente inactiva
- **GIVEN** una fuente con `activa = 'NO'`
- **WHEN** se envía un lote asociado a esa fuente
- **THEN** la respuesta es 409 y no se crea nada

#### Scenario: [C4] Manifiesto con `id_externo` repetido
- **WHEN** dos ítems del mismo lote tienen el mismo `id_externo`
- **THEN** la respuesta es 422 y no se procesa ningún ítem

#### Scenario: [C4] Lote sin permiso de sincronización
- **GIVEN** un usuario RECEPCION sin `lab_results:sync`
- **WHEN** envía un lote
- **THEN** la respuesta es 403

### Requirement: Validación por ítem y errores aislados [C3]
El sistema SHALL aplicar a cada archivo del lote las mismas reglas de formato, firma y tamaño que la carga manual. Un ítem con error SHALL registrarse como `ERROR` con un código y detalle, SHALL NOT persistir resultado ni archivo, y SHALL NOT impedir el procesamiento de los demás ítems del lote.

#### Scenario: [C3] Un archivo inválido no frena el lote
- **GIVEN** un lote de 3 ítems donde el segundo contiene un archivo `.exe`
- **WHEN** se procesa el lote
- **THEN** el primero y el tercero se procesan normalmente, el segundo queda `ERROR` con código `ARCHIVO_TIPO_NO_PERMITIDO` y la sincronización queda `COMPLETADA_CON_ERRORES`

#### Scenario: [C3] Archivo declarado pero ausente
- **WHEN** el manifiesto referencia un archivo que no viene en el lote
- **THEN** ese ítem queda `ERROR` con código `ARCHIVO_AUSENTE`

### Requirement: Correspondencia con paciente, estudio y orden [C5]
El sistema SHALL corresponder cada ítem con un paciente de la misma clínica por CI y complemento, con un examen activo del catálogo de la clínica por código y, si el ítem trae `id_orden`, con una orden de la misma clínica y paciente que esté `FIRMADA` e incluya el código del estudio. Si la correspondencia es única y válida, el resultado SHALL quedar `INCORPORADO`. Si el paciente no existe en la clínica, es ambiguo, el estudio no es válido o la orden no es válida, el resultado SHALL quedar `PENDIENTE_REVISION` con `id_paciente` nulo, sin documento clínico, con el motivo (`PACIENTE_NO_ENCONTRADO`, `PACIENTE_AMBIGUO`, `EXAMEN_NO_VALIDO`, `ORDEN_NO_VALIDA` u `ORDEN_PACIENTE_NO_COINCIDE`) y con los datos crudos de correspondencia recibidos. El sistema SHALL NOT asociar nunca un resultado a un paciente de otra clínica ni a un paciente elegido por aproximación de nombre.

#### Scenario: [C5] Paciente no encontrado
- **WHEN** un ítem trae una CI que no existe entre los pacientes de la clínica
- **THEN** el resultado se guarda `PENDIENTE_REVISION` con motivo `PACIENTE_NO_ENCONTRADO`, sin paciente, sin documento clínico y con la CI recibida en los datos crudos

#### Scenario: [C5] La CI existe solo en otra clínica
- **GIVEN** un paciente con esa CI en la clínica 2 y ninguno en la clínica 1
- **WHEN** la clínica 1 sincroniza un ítem con esa CI
- **THEN** el resultado queda `PENDIENTE_REVISION` en la clínica 1 y no se asocia al paciente de la clínica 2

#### Scenario: [C5] Estudio inválido
- **WHEN** el código de estudio no existe o está inactivo en el catálogo de la clínica
- **THEN** el resultado queda `PENDIENTE_REVISION` con motivo `EXAMEN_NO_VALIDO` aunque el paciente exista

#### Scenario: [C5] Orden de otro paciente
- **WHEN** el ítem trae un `id_orden` de la clínica que pertenece a otro paciente
- **THEN** el resultado queda `PENDIENTE_REVISION` con motivo `ORDEN_PACIENTE_NO_COINCIDE`

#### Scenario: [C5] Correspondencia válida
- **WHEN** la CI identifica a un único paciente de la clínica y el estudio es válido
- **THEN** el resultado queda `INCORPORADO` y se indexa un documento `RESULTADO_LAB` del paciente

### Requirement: Control de duplicados por fuente [C6]
El sistema SHALL tratar `(id_clinica, fuente, id_externo)` como clave de idempotencia. Un ítem cuya clave ya exista, en cualquier estado del resultado incluido `ANULADO` y `PENDIENTE_REVISION`, SHALL registrarse como `DUPLICADO`, SHALL NOT crear un resultado ni un documento clínico nuevos y SHALL NOT almacenar de nuevo el archivo. Si el contenido (SHA-256) difiere del ya integrado para la misma clave, el ítem SHALL registrarse como `ERROR` con código `CONTENIDO_DISTINTO` y el resultado existente SHALL permanecer sin cambios. Dos fuentes distintas de la misma clínica SHALL poder usar el mismo `id_externo` sin conflicto.

#### Scenario: [C6] Reenvío del mismo lote
- **GIVEN** un lote ya sincronizado con 3 resultados
- **WHEN** se envía de nuevo el mismo lote de la misma fuente
- **THEN** los 3 ítems quedan `DUPLICADO`, el total de resultados no cambia y no se almacenan archivos nuevos

#### Scenario: [C6] Duplicado de un pendiente
- **GIVEN** un resultado `PENDIENTE_REVISION` ya registrado con cierto `id_externo`
- **WHEN** la fuente lo reenvía
- **THEN** el ítem queda `DUPLICADO` y no se crea un segundo pendiente

#### Scenario: [C6] Duplicado de un resultado anulado
- **GIVEN** un resultado `ANULADO` con cierto `id_externo`
- **WHEN** la fuente lo reenvía
- **THEN** el ítem queda `DUPLICADO` y el resultado anulado no se reactiva

#### Scenario: [C6] Mismo identificador con contenido distinto
- **WHEN** la fuente reenvía un `id_externo` ya integrado con un archivo de distinto SHA-256
- **THEN** el ítem queda `ERROR` con código `CONTENIDO_DISTINTO` y el resultado original no se modifica

#### Scenario: [C6] Mismo identificador en otra fuente
- **WHEN** otra fuente de la misma clínica envía un ítem con el mismo `id_externo`
- **THEN** se procesa como un resultado independiente

#### Scenario: [C6] Carrera entre dos envíos simultáneos
- **WHEN** dos peticiones envían a la vez el mismo `id_externo` de la misma fuente
- **THEN** exactamente un resultado queda creado y el otro ítem se registra como `DUPLICADO`

### Requirement: Registro de sincronizaciones y errores [C8]
El sistema SHALL registrar cada lote como una sincronización de la clínica con fuente, usuario o proceso responsable, fecha de inicio y fin, estado (`EN_PROCESO`, `COMPLETADA`, `COMPLETADA_CON_ERRORES`, `FALLIDA`), contadores de ítems incorporados, pendientes, duplicados y con error, y el detalle por ítem (identificador externo, resultado, código de error y detalle). El sistema SHALL informar en la respuesta el resultado de cada ítem y SHALL permitir consultar el listado y el detalle de sincronizaciones de la clínica. El estado SHALL ser `COMPLETADA` si ningún ítem queda en error, `COMPLETADA_CON_ERRORES` si algunos sí y otros no, y `FALLIDA` si todos los ítems quedaron en error.

#### Scenario: [C8] Informe del lote
- **WHEN** se procesa un lote con 1 incorporado, 1 pendiente, 1 duplicado y 1 error
- **THEN** la respuesta y el detalle de la sincronización muestran esos cuatro resultados por ítem, los contadores 1/1/1/1 y el estado `COMPLETADA_CON_ERRORES`

#### Scenario: [C8] Todos los ítems fallan
- **WHEN** todos los ítems del lote quedan en error
- **THEN** la sincronización queda `FALLIDA`

#### Scenario: [C8] Fallo de almacenamiento
- **WHEN** el almacenamiento falla al guardar el archivo de un ítem
- **THEN** ese ítem queda `ERROR` con código `ALMACENAMIENTO_FALLIDO`, no queda resultado ni archivo huérfano y los demás ítems se procesan

#### Scenario: [C8] Consulta de sincronizaciones de otra clínica
- **WHEN** un usuario de la clínica 1 consulta una sincronización de la clínica 2
- **THEN** la respuesta es 404

### Requirement: Reintento sin duplicar [C8]
El sistema SHALL permitir a un usuario con `lab_results:sync` reintentar los ítems en `ERROR` de una sincronización de su clínica reenviando solo esos ítems y sus archivos. El reintento SHALL aplicar la misma clave de idempotencia, SHALL actualizar el ítem y los contadores de la misma sincronización incrementando el número de intento del ítem y el contador de reintentos de la sincronización en 1 por petición, y SHALL NOT crear resultados duplicados de ítems ya integrados. El reintento SHALL rechazar con 422 la petición completa, antes de procesar ningún ítem, si algún `id_externo` no es un ítem en `ERROR` de esa sincronización.

#### Scenario: [C8] Reintento exitoso tras corregir el archivo
- **GIVEN** una sincronización con un ítem en `ERROR` por archivo inválido
- **WHEN** se reenvía ese ítem con un archivo válido
- **THEN** el ítem pasa a `INCORPORADO` o `PENDIENTE_REVISION` según su correspondencia, el contador de errores baja y el estado de la sincronización se recalcula

#### Scenario: [C8] Reintento de ítems ya integrados
- **WHEN** el reintento incluye un `id_externo` que ya quedó integrado
- **THEN** la respuesta es 422 para la petición completa, no se procesa ningún ítem de ella y no se crea ningún resultado

#### Scenario: [C8] Reintento tras una caída a mitad del lote
- **GIVEN** un lote en el que se integraron algunos ítems antes de una interrupción
- **WHEN** el cliente reenvía el lote completo
- **THEN** los ítems ya integrados quedan `DUPLICADO` y solo se crean los que faltaban

#### Scenario: [C8] Reintento de una sincronización ajena
- **WHEN** un usuario de la clínica 1 reintenta una sincronización de la clínica 2
- **THEN** la respuesta es 404

### Requirement: Trazabilidad y aislamiento de la sincronización [C9]
El sistema SHALL conservar en cada resultado sincronizado el origen `SINCRONIZADO`, la fuente, el `id_externo`, el identificador de la sincronización, la fecha de registro y el usuario o proceso responsable. El sistema SHALL registrar una traza de auditoría de la clínica por cada sincronización, reintento y cambio de fuente, dentro de la misma transacción del cambio. Toda consulta de fuentes, sincronizaciones e ítems SHALL filtrar por la clínica de la sesión autenticada y SHALL NOT aceptar `tenant_id` ni `id_clinica` en el cuerpo de la petición.

#### Scenario: [C9] Trazabilidad de un resultado sincronizado
- **WHEN** un lote incorpora un resultado
- **THEN** el resultado guarda origen `SINCRONIZADO`, `id_fuente`, `id_externo`, `id_sincronizacion`, el usuario que ejecutó el lote y la fecha de registro, y existe una traza de auditoría de la sincronización

#### Scenario: [C9] Lote con identificador de clínica en el cuerpo
- **WHEN** el manifiesto incluye `id_clinica` o `tenant_id`
- **THEN** el sistema lo rechaza con 422 y no procesa el lote

#### Scenario: [C9] Sin autenticación
- **WHEN** se invoca cualquier endpoint de fuentes o sincronizaciones sin token válido
- **THEN** la respuesta es 401
