# Design

## Context

Ver `proposal.md`. El backend usa `Session` síncrona e `id_clinica BIGINT`. `Cita` no guarda clínica; se atribuye por `Cita.id_medico -> Medico.id_usuario -> Usuario.id_clinica`. `Consulta` guarda `id_clinica` e `id_historia`. El ORM `Medico` declara una columna que la última verificación histórica de Neon no halló. Los SQL/TXT originales no están en el workspace y la conexión de lectura viva no se estableció en la auditoría anterior.

## Goals / Non-Goals

**Goals:** consultas de columnas concretas compatibles con el esquema observado, aislamiento en cada ruta, métricas de grano explícito, resultados agrupados paginables y cuatro exportaciones descargables.

**Non-Goals:** cambiar producción de citas/HCE, migrar esquema, guardar plantillas, registrar ausencia, integrar proveedor de IA/voz, enviar eMail o implementar clientes.

## Decisions

1. **Autorización local.** Dependencia específica de analytics sobre `get_current_user`: comprobar nombre de rol ADMIN/ADMINISTRADOR/ADMINISTRACION normalizado, estado activo de rol y clínica, y `Usuario.id_clinica`. No usar `get_current_tenant_id`, que permite un header cuando el usuario carece de clínica. Alternativa descartada: confiar en `require_admin` sin comprobar rol y clínica activos.
2. **Grano de consulta.** Las selecciones SQLAlchemy serán de columnas, no entidades `Medico`; así el join por usuario no solicita `medicos.id_clinica`. Encuentros unen Consulta, Historia, Cita, Medico y Usuario, exigen coincidencia de clínica, historia/paciente y médico/cita. Inconsistencias se excluyen sin revelar datos ajenos. No filtrar por `Paciente.id_clinica`. Alternativa descartada: reutilizar CU25, que no tiene ámbito en sus consultas.
3. **Agregación.** Crear una subconsulta de filas elegibles y agregados SQL `COUNT(DISTINCT ...)`; `fecha_consulta` define el período de encuentros y `fecha_cita` el de citas. Métricas globales se calculan aparte de los grupos sobre la misma base. `total` es número de grupos, `filas` la página de grupos. Un mismo paciente en dos grupos cuenta una vez en el global.
4. **Catálogo.** Cuatro IDs: `encuentros`, `citas`, `cancelaciones`, `pacientes_unicos`. Los dos primeros y sus vistas relacionadas comparten fuentes, pero tienen métricas principales distintas. Agrupaciones máximas de dos dimensiones; columnas incluyen todas las agrupaciones y la métrica principal, con métricas secundarias opcionales. Filtros permitidos: `id_medico`, `id_especialidad`, `estado` donde corresponde y `modalidad`; operador `eq` únicamente. Orden por dimensión agrupada o métrica seleccionada, con desempate estable. Período inclusivo máximo de 366 días, 8 filtros, página hasta 100 y 5.000 grupos exportables.
5. **Modalidad.** Normalizar espacios/caja; si ambos campos reconocidos coinciden, usar ese valor; si difieren, `CONFLICTO`; si faltan, `DESCONOCIDA`; otro valor, `OTRA`. Esto evita atribuir retrospectivamente modalidad real a un valor por defecto.
6. **Ausentismo.** Catálogo y respuestas incluyen `{disponible:false, valor:null, causa:"SIN_ESTADO_AUSENCIA"}`. No hay reporte ejecutable de no-show. Sin tasa de cancelación en esta etapa: se ofrecen conteos, sin inventar fecha histórica de cancelación.
7. **Exportación.** El mismo servicio devuelve todas las filas agrupadas bajo el límite, sin página; la consulta y la exportación pueden ver estados distintos si cambió la BD entre peticiones. CSV, XLSX (OpenXML), HTML y PDF se producirán con biblioteca estándar, sin fallbacks de formato falso. XLSX usa cadenas inline y nunca celdas de fórmula; CSV antepone apóstrofo a texto con prefijo de fórmula; HTML escapa contenido. PDF A4 horizontal con fuente estándar WinAnsi para acentos españoles, anchos controlados, texto envuelto, nueva página con cabecera repetida. Los metadatos del reporte se incorporan a cada archivo. No guardar archivos en servidor.
8. **Organización por caso de uso.** Siguiendo `appointments/router.py`, `analytics/router.py` solo compone `reportes.router` y `exportacion.router`. Catálogo, autorización, esquemas de consulta y agregados quedan en `analytics/reportes/`; el esquema de exportación, ruta y generador de archivos quedan en `analytics/exportacion/`. Exportación importa el servicio y la dependencia ADMIN de reportes, sin copiar SQL ni resolver otra clínica. `app/main.py` mantiene un único registro del router compuesto.

## Risks / Trade-offs

- **Neon aún no verificado** → fixture SQLite con tabla física `medicos` sin la columna; comprobación SELECT viva pendiente antes de despliegue.
- **Datos históricos incoherentes** → excluir relaciones inválidas, clasificar conflictos de modalidad y advertir que encuentros registrados no equivalen a todas las atenciones históricas.
- **Grupos con valores nulos o múltiples consultas** → agrupar por columnas de cita y contar IDs distintos; total global independiente de suma de grupos.
- **PDF sin tipografía Unicode completa** → soportar acentos españoles con WinAnsi; caracteres ajenos a esa codificación se reemplazan. La selección de columnas y el salto de línea evitan desbordes.
- **Resultados cambian entre llamadas** → comunicar `generado_en` y no prometer una instantánea compartida.

## Migration Plan

Sin migración. Registrar router de analytics y desplegar código después de probar la estructura real con SELECT. Reversión: quitar el registro del router y el módulo; no hay datos persistidos nuevos. La discrepancia `medicos.id_clinica` se revisará tras el merge grupal.

## Verificación local de esta etapa

- Los SQL/TXT e imagen mencionados no estaban accesibles en el workspace ni en los adjuntos recibidos. Se contrastaron ORM, Alembic y contratos presentes. El intento anterior de conexión Neon de solo lectura falló antes de una consulta; no se obtuvo una verificación viva ni se escribieron datos. La compatibilidad se probó en SQLite con `medicos` físico sin `id_clinica`.
- `tests/test_cu22_reports.py`: seis pruebas de dos clínicas, aislamiento y denegaciones en las cuatro rutas, duplicados, modalidad y especialidad nula, validación, paginación, límite 413, formatos y cabeceras. Regresiones pertinentes: `test_cu25_consultas.py` (7) y `test_cu28_hce.py` (8), todas correctas. Se ejecutaron con Python local que dispone de dependencias desde dos entornos existentes; la instalación desde `requirements.txt` en un entorno nuevo falló por red bloqueada. `compileall` del módulo y `app/main.py` pasó.
- PDF: estructura, acentos codificados, salto de página y repetición de cabecera comprobados por prueba. La inspección visual de páginas queda pendiente: no hay Poppler, biblioteca de renderizado ni interfaz de renderizado accesible en este entorno.
- OpenSpec: `doctor` correcto; `validate --specs` validó cinco specs principales sin errores; `validate cu22-reportes-backend` correcto. No se agregaron tablas ni migraciones. Los cambios previos de CU05 y los repositorios web/móvil se conservaron.
- Reorganización posterior: cuatro rutas registradas una sola vez. El bloque OpenAPI de `/analytics/reportes` conservó exactamente su SHA-256 `257944cd4260e5a7b36cf720912840cc22c42b5a5b3870492f671481fabacc7d` antes y después del movimiento de archivos.
- Pendientes posteriores: lectura SELECT de Neon antes de desplegar, Angular, Flutter, interpretación de texto con proveedor acordado, transcripción de voz, transición explícita de ausentismo, eMail y reconciliación de `medicos.id_clinica` después del merge. CU22 y CU27 globales no se declaran completos.
