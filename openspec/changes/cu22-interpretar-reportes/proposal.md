# CU22 — interpretación de solicitudes de reportes

## Propósito

Agregar al backend de Analytics una interpretación estructurada de solicitudes en lenguaje natural para ADMIN. La respuesta prepara una definición de CU22; consultar y exportar siguen siendo acciones separadas.

## Alcance

- Integrar Groq con configuración de entorno y cliente sustituible en pruebas.
- Validar el resultado contra el catálogo, el esquema y las opciones de la clínica autenticada.
- Devolver definición completa, aclaración o solicitud no admitida sin ejecutar consultas.
- Documentar el flujo futuro de web y móvil para texto y voz.

## Fuera de alcance

No se implementan web, móvil, grabación, transcripción, eMail, nuevas tablas ni cambios de permisos de CU27. No se altera `id_clinica` ni el esquema de datos.
