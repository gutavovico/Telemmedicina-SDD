# Spec Delta

## ADDED Requirements

### Requirement: Acciones de interpretación por texto en web
The system SHALL mostrar en `/analitica` una barra editable para ADMIN elegible con acciones Enviar y Aplicar filtros. SHALL enviar texto y fecha local a `/analytics/reportes/interpretar` sin `id_clinica`. Enviar y Enter SHALL aplicar solo una definición válida completa y llamar a `/consulta`; Aplicar filtros SHALL aplicar la definición sin consultar. Shift+Enter SHALL insertar una línea y la composición de texto SHALL evitar envío.

#### Scenario: Enviar válido
- **GIVEN** un ADMIN con catálogo y opciones cargados
- **WHEN** envía una solicitud que devuelve `valida`
- **THEN** todos los controles reflejan la definición normalizada y se consulta esa definición
- **AND** la interpretación por sí sola no trae filas ni exporta

#### Scenario: Aplicar filtros válido
- **GIVEN** un resultado anterior y una solicitud nueva válida
- **WHEN** el ADMIN pulsa Aplicar filtros
- **THEN** la configuración visible se reemplaza y la exportación anterior queda bloqueada si cambió la definición efectiva
- **AND** no se llama a `/consulta` hasta Generar reporte

### Requirement: Aclaración y concurrencia seguras
The system SHALL conservar texto y controles ante `aclaracion`, `no_admitida` o fallo del proveedor, mostrando resumen y advertencias. SHALL descartar respuestas obsoletas tras edición, nueva solicitud, salida o cambio de cuenta. SHALL mantener filtros manuales disponibles y SHALL bloquear envíos duplicados.

#### Scenario: Año ambiguo
- **GIVEN** una solicitud «Citas de septiembre»
- **WHEN** el backend pide aclarar `periodo`
- **THEN** la pantalla muestra el campo pendiente sin aplicar configuración parcial ni generar

#### Scenario: Respuesta tardía
- **GIVEN** una interpretación pendiente
- **WHEN** el usuario cambia un filtro o sale de la cuenta
- **THEN** la respuesta anterior no modifica controles ni resultados
