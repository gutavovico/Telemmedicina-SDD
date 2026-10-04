# Diseño

Se amplían el modelo, repositorio, controlador y pantalla existentes en `analytics/reportes`. El cliente HTTP compartido incorpora únicamente transporte multipart autenticado, con las mismas cabeceras y errores existentes. La captura se abstrae para pruebas y la implementación usa `record` 6.2.1 en modo PCM16, mono, 16 kHz; construye un WAV en memoria, sin almacenamiento persistente. El audio enviado es `dictado.wav` con MIME `audio/wav`, y se limita a 5 MiB y 60 segundos.

El controlador conserva una generación para resultados y otra para interpretación/captura. Ediciones de texto se cuentan aun cuando se reviertan. Cambios de definición, acciones de reporte, cuenta, salida y segundo plano invalidan el autoenvío. Las respuestas `aclaracion` y `no_admitida` nunca aplican una definición parcial. La respuesta válida reemplaza toda la definición visible y se valida contra catálogo y opciones antes de consultar.

No se ejecutan Flutter, Dart ni resolución de dependencias en este equipo. `pubspec.lock` no se modifica a mano.

## Verificación diferida

La guía reproducible de `mobile_telemedicina/README.md` cubre Flutter web en Chrome o Edge con el backend SQLite aislado, origen `127.0.0.1:4200`, `API_BASE_URL` de desarrollo, cuentas sintéticas de dos clínicas, roles rechazados, texto, voz y exportaciones. La ruta web directa usa el hash predeterminado (`/#/analytics`). El lanzador de backend escucha solo en loopback; otro equipo requiere una instancia de pruebas accesible, CORS para el origen exacto y HTTPS para conservar el contexto seguro del micrófono. No se cambia la configuración de producción.

La revisión estática contrastó `record` 6.2.1, `file_saver` 0.4.0 y `http_parser` 4.1.2 con sus APIs publicadas. El controlador serializa `stop` y `cancel` al salir, y descarta respuestas pendientes por generación y cuenta. Esta revisión no acredita compilación, funcionamiento del hardware, guardado real ni presentación visual; Flutter web y Android/iOS se verifican por separado en un equipo preparado.
