# Spec Delta

## ADDED Requirements

### Requirement: Interpretación móvil de reportes

The system SHALL permitir solo a ADMIN elegible enviar texto de hasta 1000 caracteres a `/analytics/reportes/interpretar` con fecha local de referencia. SHALL reemplazar la definición visible completa solo ante `valida` compatible con catálogo y opciones. SHALL consultar con la definición devuelta únicamente mediante Enviar; Aplicar filtros no consulta. SHALL conservar configuración y resultados al limpiar solo el texto.

#### Scenario: Enviar y aplicar

- **GIVEN** ADMIN y un texto con reporte y período suficientes
- **WHEN** elige Enviar o Aplicar filtros
- **THEN** ambas acciones interpretan una vez y reemplazan la definición completa
- **AND** solo Enviar consulta el reporte

#### Scenario: Aclaración o error

- **GIVEN** una interpretación `aclaracion`, `no_admitida` o error HTTP
- **WHEN** llega la respuesta
- **THEN** no se aplican controles parcialmente ni se consulta

### Requirement: Dictado móvil temporal

The system SHALL grabar tras permiso explícito hasta 60 segundos, construir audio WAV real de hasta 5 MiB y enviarlo como `audio` multipart a `/analytics/reportes/transcribir`. SHALL conservar texto anterior y ediciones concurrentes mediante dictado pendiente. SHALL liberar el grabador al salir, cambiar de cuenta o pasar a segundo plano.

#### Scenario: Detención manual y automática

- **GIVEN** «Enviar al terminar» desactivado al abrir pantalla
- **WHEN** ADMIN dicta y pulsa Detener
- **THEN** la transcripción queda editable sin interpretación ni consulta
- **AND** si la opción estaba activa al iniciar, la detención explícita usa el flujo de Enviar una vez
- **AND** el límite de duración, error, edición, dictado pendiente, cuenta distinta o salida impiden autoenvío

#### Scenario: Respuesta tardía

- **GIVEN** una transcripción o interpretación pendiente
- **WHEN** cambia texto, definición, cuenta o ciclo de vida
- **THEN** la respuesta obsoleta no aplica filtros ni genera resultados
