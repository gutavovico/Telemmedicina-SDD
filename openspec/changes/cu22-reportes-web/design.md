# Design

## Context

Ver `proposal.md` y `openspec/contracts/analytics.md`. `/analitica` es un placeholder protegido solo por `authGuard`; `AuthService` puede contener un perfil almacenado mientras `/auth/me` se revalida. El backend expone catálogo, opciones, consulta y exportación con `id_clinica BIGINT` tomado de la sesión. El frontend ya usa componentes standalone, Signals, formularios reactivos, Header/Footer, Tailwind y un interceptor Bearer.

## Goals / Non-Goals

**Goals:** misma definición validada para consulta, paginación y exportación; guard de perfil fresco; descarga Blob segura; estados accesibles y pantalla adaptable.

**Non-Goals:** ampliar API, seleccionar clínica, crear métricas, integrar IA/voz/eMail, tocar CU05 o alterar permisos ajenos.

## Decisions

1. **Límite de acceso.** El guard de `/analitica` pedirá un perfil fresco a `AuthService.fetchUserProfile()` y verificará `normalizeAppRole(rol)`, estado activo y clínica asignada. El menú usa la representación textual ya normalizada, nunca `id_rol`. La autorización final sigue en el backend, que verifica rol y clínica activos. Un perfil guardado sin resolver no basta para el guard.
2. **Distribución.** `features/analytics/reportes/` contendrá página, modelos, servicio de catálogo/consulta y validación de definición. `features/analytics/exportacion/` contendrá servicio de exportación y descarga Blob; reutiliza los modelos y la definición normalizada, sin duplicar consultas. El antiguo placeholder deja de ser la ruta activa.
3. **Constructor.** Un formulario reactivo tipado administra reporte, fechas y filtros simples. Signals administran listas de columnas, agrupaciones y orden para preservar secuencia e interacciones. Al cambiar tipo se restablecen filtros, columnas, agrupaciones, orden y resultado incompatibles. La validación cruza límites del catálogo y campos; el backend vuelve a validar.
4. **Concurrencia.** Cada consulta cancela la anterior y usa un número de versión; ediciones del borrador invalidan una respuesta en vuelo y marcan el resultado visible como desactualizado. La paginación usa la última definición normalizada, no el borrador. Exportación solo está activa cuando borrador y resultado coinciden.
5. **Exportación.** `HttpClient` pide `blob` con respuesta completa para leer `Content-Disposition`. El archivo se descarga con URL temporal y enlace `download`, con revocación diferida. Nombre y extensión se saneán; JSON en errores Blob se decodifica. 413 ofrece reducir conjunto. No se usa `window.open` ni se navega.
6. **Diseño.** Header/Footer y tokens de `styles.css`; composición de título, filtros, indicadores y tabla. Controles con label y foco, tabla con scroll propio. `analitica` tendrá RenderMode.Client por guard/sesión del navegador.

## Risks / Trade-offs

- Perfil almacenado desactualizado → guard espera perfil fresco y el backend mantiene la autoridad; menú no concede acceso a la API.
- Catálogo incompleto o API caída → error visible, sin datos de demostración ni filtros inventados.
- Respuestas y filtros cambiantes → versión de solicitud y bloqueo de exportación hasta regenerar.
- `Content-Disposition` ausente o bloqueado por navegador → nombre local seguro con extensión correcta.
- La imagen de referencia no llegó en el adjunto disponible → se aplica la composición descrita y el sistema visual del frontend existente.

## Migration Plan

Sustituir solo la ruta placeholder `/analitica`, añadir guard y entrada ADMIN en Header, y mantener rutas backend y demás secciones intactas. Reversión: restaurar la ruta placeholder y retirar el área web; no hay datos persistidos ni migración.
