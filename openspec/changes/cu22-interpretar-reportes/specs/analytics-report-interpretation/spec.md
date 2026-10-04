# Spec Delta

## ADDED Requirements

### Requirement: Interpretación sin ejecución
The system SHALL permitir a un ADMIN activo interpretar texto en una definición completa de CU22 sin consultar filas ni exportar. SHALL devolver `valida`, `aclaracion` o `no_admitida` con resumen, advertencias y campos por aclarar. SHALL construir siempre una definición nueva y no conservar filtros anteriores ocultos.

#### Scenario: Definición válida
- **GIVEN** un ADMIN de una clínica activa y texto con reporte y período inequívocos
- **WHEN** llama a `/analytics/reportes/interpretar`
- **THEN** recibe una definición normalizada que podrá enviar a `/consulta` después de una acción explícita
- **AND** no se ejecuta ninguna consulta de resultados ni exportación

#### Scenario: Ambigüedad
- **GIVEN** texto con «septiembre» sin año, «este mes» sin referencia o un médico con nombre duplicado
- **WHEN** se solicita interpretación
- **THEN** recibe `aclaracion`, los campos faltantes y ninguna definición parcial

#### Scenario: Rango explícito en español
- **GIVEN** un ADMIN que pide citas «desde el 1 de enero de 2026 hasta el 3 de octubre de 2026» o «desde el primero de enero de 2026 hasta el tres de octubre de 2026»
- **WHEN** llama a `/analytics/reportes/interpretar` con una respuesta estructurada válida del proveedor
- **THEN** recibe `periodo.desde=2026-01-01` y `periodo.hasta=2026-10-03` en la definición normalizada
- **AND** interpretar no consulta filas ni exporta

#### Scenario: Año compartido y período inválido
- **GIVEN** un rango enlazado «del 1 de enero al 3 de octubre de 2026» con un único año explícito
- **WHEN** solicita interpretación
- **THEN** el año indicado se aplica a ambos extremos
- **AND** fechas imposibles, extremos invertidos, rangos de más de 366 días o un rango sin ningún año reciben `aclaracion` sin llamar al proveedor

#### Scenario: Preferencias opcionales omitidas

- **GIVEN** un ADMIN que pide citas o encuentros de un mes y año explícitos sin desglose, columnas ni orden
- **WHEN** el proveedor solicita aclarar únicamente esas preferencias omitidas
- **THEN** el sistema devuelve `valida` con la agrupación, columnas y orden predeterminados del catálogo
- **AND** no ejecuta la consulta ni descarta preferencias expresamente solicitadas

### Requirement: Catálogo, autorización y límites del proveedor
The system SHALL reutilizar el catálogo y la autorización actuales y resolver `id_clinica` únicamente desde la sesión autenticada. SHALL validar la salida estructurada del proveedor con Pydantic y las reglas de CU22, sin permitir SQL, campos arbitrarios ni IDs de otra clínica. SHALL rechazar ausentismo como no disponible. SHALL limitar texto, tiempo y tamaño de respuesta y mantener la generación manual disponible ante fallo del proveedor.

#### Scenario: Opción ajena o rol sin permiso
- **GIVEN** un usuario de otro rol o una referencia a opción fuera de su clínica
- **WHEN** intenta interpretar
- **THEN** la autorización rechaza al rol o la interpretación no devuelve una definición con esa opción

#### Scenario: Respuesta inválida o proveedor indisponible
- **GIVEN** una salida no conforme, timeout o configuración ausente
- **WHEN** se solicita interpretación
- **THEN** se obtiene un error semántico sin revelar claves ni respuesta cruda del proveedor
- **AND** las rutas manuales existentes siguen disponibles
