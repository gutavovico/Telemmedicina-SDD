# Tareas — etapa móvil

- [x] Contrastar `openspec/contracts/analytics.md`, backend y patrones de Flutter.
- [x] Organizar modelos, consulta, controlador y pantalla en `analytics/reportes/`.
- [x] Implementar descarga y guardado en `analytics/exportacion/`.
- [x] Restringir navegación y limpiar estado por sesión.
- [x] Añadir pruebas unitarias y de widget para acceso, definición, paginación, estado, respuestas atrasadas, binarios y sesión; revisar imports y rutas estáticamente.
- [x] Auditar componentes compartidos: login, «recordarme», 401/403, cambio de cuenta, URL base, permisos Android y compatibilidad documental de `file_saver`.
- [ ] Ejecutar `flutter analyze`, pruebas Flutter y build en un entorno con SDK.
- [ ] Verificar visualmente Android/iOS o Flutter web conectado al backend aislado.
- [ ] Ejecutar validaciones OpenSpec y registrar resultados.

El equipo de esta etapa no tiene Flutter/Dart ni espacio para instalarlos; por instrucción del usuario no se ejecutaron comandos Flutter ni se instalaron herramientas. `openspec` tampoco está disponible en PATH; `doctor` y `validate --specs` quedan pendientes en un equipo preparado. La revisión estática de imports relativos, rutas y cuerpo sin `id_clinica` no sustituye esas verificaciones.
