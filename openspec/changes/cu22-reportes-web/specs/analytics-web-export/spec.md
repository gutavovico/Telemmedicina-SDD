# Spec Delta

## Purpose

Permite descargar desde la pantalla web los resultados autorizados de CU22 en los formatos portables del contrato CU27, usando la definición generada.

## ADDED Requirements

### Requirement: Descarga de la definición generada
The system SHALL ofrecer PDF, XLSX, CSV y HTML publicados por el catálogo y enviar a `POST /analytics/reportes/exportar` la definición normalizada del último reporte generado, sin usar solo la página visible ni un borrador posterior. SHALL impedir clics duplicados y comunicar la preparación sin afirmar que el archivo se guardó físicamente.

#### Scenario: Exportación tras paginar
- **GIVEN** un reporte válido con varias páginas y formato `xlsx` disponible
- **WHEN** ADMIN exporta después de ver la segunda página
- **THEN** el cuerpo conserva la definición generada y la descarga representa el conjunto completo permitido por backend

### Requirement: Nombre, MIME y errores de descarga
The system SHALL descargar Blob en la misma pantalla sin abrir otra pestaña, conservar extensión y MIME del formato, usar un nombre seguro de `Content-Disposition` o uno seguro de respaldo y liberar la URL temporal. SHALL decodificar errores JSON recibidos como Blob; para 413 SHALL pedir reducir período o ajustar filtros/agrupación y no SHALL truncar ni repetir descargas silenciosamente.

#### Scenario: Formatos y límite
- **GIVEN** un formato publicado por el catálogo o una respuesta 413 con cuerpo JSON Blob
- **WHEN** ADMIN solicita la exportación
- **THEN** el navegador inicia un archivo del tipo correcto o muestra la indicación de reducir el conjunto, restaura controles y permanece en la pantalla
