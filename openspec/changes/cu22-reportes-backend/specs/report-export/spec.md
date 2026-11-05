# Spec Delta

## Purpose

Permite descargar los resultados autorizados de CU22 en formatos portables sin cambiar los permisos de otros documentos del CU27.

## ADDED Requirements

### Requirement: Exportación administrativa de reportes
The system SHALL exportar PDF, XLSX, CSV y HTML reales para ADMIN activo de su clínica, usando la misma definición validada, período, ámbito, columnas y orden del reporte; SHALL incluir todos los grupos filtrados hasta el límite publicado y SHALL rechazar el exceso sin truncamiento silencioso.

#### Scenario: Exportación completa frente a página visible
- **GIVEN** un reporte con tres grupos y página de tamaño uno
- **WHEN** ADMIN exporta la definición en CSV
- **THEN** el archivo incluye los tres grupos en el mismo orden, sin datos de otra clínica

#### Scenario: Límite de exportación
- **GIVEN** un resultado que supera el límite publicado
- **WHEN** ADMIN solicita exportación
- **THEN** recibe 413 y ningún archivo parcial

### Requirement: Archivos legibles y seguros
The system SHALL entregar MIME y `Content-Disposition: attachment` correctos, nombre seguro, metadatos de período, filtros, columnas, orden, ámbito y generación, HTML escapado y texto externo neutralizado ante fórmulas en CSV/XLSX. SHALL producir PDF legible con acentos, encabezados repetidos y tratamiento de texto largo.

#### Scenario: Texto con fórmula y acentos
- **GIVEN** una etiqueta sintética que inicia con `=` y contiene `ñ`
- **WHEN** ADMIN exporta CSV, XLSX, HTML y PDF
- **THEN** CSV/XLSX la tratan como texto, HTML no interpreta marcado y PDF muestra la `ñ` y cabeceras legibles

### Requirement: Métricas no disponibles y alcance CU27
The system SHALL evitar exportar ausentismo como cifra y SHALL conservar los permisos de bitácora, recetas y demás documentos de CU27 sin cambios. eMail SHALL figurar como pendiente y no como capacidad de envío implementada.

#### Scenario: Exportación no soportada
- **GIVEN** el catálogo indica que ausentismo no está disponible
- **WHEN** ADMIN solicita exportarlo
- **THEN** recibe un error de validación con causa `SIN_ESTADO_AUSENCIA`
