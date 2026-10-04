# Tasks

## 1. Acceso y navegación web

- [x] 1.1 Proteger `/analitica` con perfil fresco ADMIN activo y clínica asignada; verificar guard con ADMIN, roles ajenos, perfil tardío y navegación directa.
- [x] 1.2 Mostrar enlace de reportes solo a ADMIN en Header escritorio/móvil y declarar ruta cliente SSR; verificar pruebas de Header y rutas sin alterar otras entradas.

## 2. Definición y consulta CU22

- [x] 2.1 Crear modelos tipados y servicio de las tres rutas CU22 según `openspec/contracts/analytics.md`; verificar solicitudes y respuestas en pruebas HTTP sintéticas.
- [x] 2.2 Implementar formulario de catálogo, opciones, período, filtros, columnas ordenadas, agrupación y orden, con reset por tipo y validación de límites; verificar errores y cuerpo sin `id_clinica`.
- [x] 2.3 Presentar carga, métricas, ausentismo no disponible, filas, paginación, advertencias y estado vacío; verificar respuesta normalizada, pacientes únicos globales y respuestas obsoletas.
- [x] 2.4 Aplicar diseño Header/Footer adaptable y accesible; verificar en DOM y build que tabla se limita a su contenedor y que los controles tienen etiquetas/foco.

## 3. Exportación CU27-reportes

- [x] 3.1 Crear servicio Blob para cuatro formatos, nombre seguro y errores JSON/413; verificar MIME, `Content-Disposition`, URL temporal y limpieza en pruebas.
- [x] 3.2 Integrar descarga de la definición generada, bloquear borrador desactualizado y clics duplicados; verificar los cuatro formatos y restauración de controles.

## 4. Integración de la etapa

- [x] 4.1 Ejecutar pruebas Angular pertinentes, build de producción y validaciones OpenSpec; registrar resultados y límites de prueba en navegador/backend aislado.
- [x] 4.2 Revisar estado Git y confirmar que CU05, backend y móvil existentes permanecen intactos, sin commit, merge ni migración.

## Resultado de verificación local (2026-10-03)

- Angular: `npm test -- --watch=false` pasó (23 archivos, 126 pruebas); `npm run build` pasó (cliente y SSR).
- OpenSpec: `doctor`, `validate --specs` (5 especificaciones) y `validate cu22-reportes-web` pasaron sin errores ni advertencias.
- La pantalla y el Header se comprobaron con DOM de Angular en pruebas; los servicios HTTP y Blob se comprobaron con fixtures sintéticos del contrato.
- No se ejecutó una sesión de navegador con backend aislado ni una prueba viva con Neon. Quedan pendientes la revisión visual en viewport de escritorio/móvil y la descarga real administrada por el navegador.
