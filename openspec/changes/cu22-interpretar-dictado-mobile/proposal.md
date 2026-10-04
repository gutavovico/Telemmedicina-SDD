# Interpretación y dictado móvil CU22

La pantalla móvil de Reportes incorpora solicitud editable, interpretación por texto y dictado para ADMIN elegible. Enviar interpreta y consulta; Aplicar filtros interpreta sin consultar. El dictado conserva el texto manual salvo que «Enviar al terminar» esté activo desde el inicio y la detención sea explícita y segura.

El backend mantiene los contratos de `/interpretar`, `/transcribir` y `/consulta` y resuelve `id_clinica` desde la sesión. No se modifica backend, web, esquema de datos ni exportación CU27. No hay integración directa con Groq en el móvil.
