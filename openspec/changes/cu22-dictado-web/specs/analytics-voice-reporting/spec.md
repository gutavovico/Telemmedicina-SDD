# Spec Delta

## ADDED Requirements

### Requirement: Transcripción acotada y autorizada

The system SHALL permitir solo a un ADMIN elegible transcribir una grabación breve y SHALL devolver únicamente texto, sin ejecutar interpretación, consulta o exportación. SHALL limitar tamaño, comprobar formato real y liberar recursos sin persistir audio.

#### Scenario: Audio válido

- **GIVEN** un ADMIN activo y un audio admitido menor a 5 MiB
- **WHEN** llama a `/analytics/reportes/transcribir`
- **THEN** recibe `{"texto":"..."}` sin crear resultados de reporte

#### Scenario: Audio o proveedor inválido

- **GIVEN** archivo vacío, formato incompatible o proveedor sin texto
- **WHEN** solicita transcripción
- **THEN** recibe un error semántico sin transcripción inventada ni secretos

### Requirement: Dictado controlado por la persona

The system SHALL iniciar grabación solo por acción explícita, detenerla y liberar tracks al salir o cambiar de cuenta. SHALL añadir el texto transcrito al cuadro editable y SHALL preservar ediciones concurrentes ofreciendo incorporación explícita. SHALL mantener «Enviar al terminar» desactivado al abrir la pantalla y solo interpretará y consultará automáticamente cuando la opción estaba activa al iniciar y el usuario pulse Detener explícitamente sin cambios posteriores que invaliden la operación.

#### Scenario: Editar durante la transcripción

- **GIVEN** una grabación detenida y una petición de transcripción pendiente
- **WHEN** la persona cambia el cuadro antes de la respuesta
- **THEN** el texto editado permanece y el dictado queda pendiente de incorporación voluntaria

#### Scenario: Envío tras detener explícitamente

- **GIVEN** «Enviar al terminar» activo al iniciar y una transcripción no vacía sin edición ni cambio de contexto
- **WHEN** el usuario pulsa Detener
- **THEN** el texto se añade y se usa el mismo flujo de Enviar una vez
- **AND** una aclaración o solicitud no admitida impide consultar y aplicar parcialmente filtros

#### Scenario: Detención automática o cambio durante el dictado

- **GIVEN** la opción activa al iniciar
- **WHEN** se alcanza el límite de duración, falla la captura, cambia el texto o los filtros, o se abandona la pantalla
- **THEN** no se inicia interpretación automática
- **AND** el texto recibido cuando corresponda queda disponible para revisión manual
