# Diseño

`analytics/reportes` conserva los modelos tipados, el cliente HTTP y la página. La barra usa el `FormControl` existente de Angular y los botones comparten una única llamada de interpretación. Se envía `fecha_referencia` calculada con año, mes y día locales; no se serializa un instante UTC.

La respuesta válida se comprueba contra el catálogo y las opciones cargadas antes de reemplazar de una vez reporte, período, filtros, grupos, columnas y orden. Enviar pasa la definición recibida al flujo común de `/consulta`; Aplicar filtros no consulta. La igualdad de configuración omite solo el número de página y mantiene habilitada la exportación cuando el resultado vigente conserva la misma definición efectiva. Una definición distinta muestra el resultado anterior como pendiente de actualizar y bloquea exportación.

Versiones de solicitud, cancelación de suscripciones y huella de cuenta impiden que respuestas de interpretación, catálogo, consulta o descarga de otra sesión sustituyan la vista. Las aclaraciones conservan el texto para editar una solicitud completa. Los errores de proveedor dejan disponibles los filtros manuales. La barra respeta SSR y usa iconos y estilos existentes.
