# Tasks

## 1. Esquema y contrato

- [x] 1.1 Contrastar SQL/TXT accesibles y ORM/Alembic, y registrar verificación Neon o límite en design.md; verificar que no se agreguen migraciones ni tablas.
- [x] 1.2 Completar contrato `openspec/contracts/analytics.md` para catálogo, opciones, consulta, exportación y flujos pendientes; verificar con `openspec validate cu22-reportes-backend`.

## 2. Backend: seguridad y catálogo

- [x] 2.1 Implementar dependencia ADMIN activo con clínica activa y catálogo/opciones de columnas concretas; verificar con pruebas de dos clínicas, rol inactivo y tabla física sin `medicos.id_clinica`.
- [x] 2.2 Implementar esquemas y validación cerrada de período, filtros, columnas, agrupación y orden; verificar con pruebas de entradas inválidas y ausentismo no disponible.

## 3. Backend: consultas

- [x] 3.1 Implementar encuentros y pacientes únicos sin duplicados ni filtro de pertenencia del paciente; verificar con consultas múltiples por cita y paciente atendido en dos clínicas.
- [x] 3.2 Implementar citas, cancelaciones, modalidad y especialidad; verificar con estados, conflictos de modalidad y especialidad nula.
- [x] 3.3 Implementar totales, grupos, orden y paginación estable; verificar paridad de ámbito/filtros y pacientes únicos globales frente a grupos.

## 4. Backend: exportación CU27-reportes

- [x] 4.1 Implementar CSV, XLSX y HTML reales con metadatos, escape y neutralización de fórmulas; verificar parseo de archivos y paridad en dataset estable.
- [x] 4.2 Implementar PDF legible con acentos, texto largo y cabecera repetida; verificar estructura, páginas y revisión visual sintética si hay renderizador disponible.
- [x] 4.3 Integrar ruta de exportación con MIME, nombre seguro y límite sin truncamiento; verificar cuatro formatos, acceso entre clínicas, 413 y `Content-Disposition`.

## 5. Integración de la etapa

- [x] 5.1 Registrar router sin cambiar rutas existentes; ejecutar regresiones backend pertinentes y comprobar que Git conserva CU05, web y móvil.
- [x] 5.2 Ejecutar `openspec doctor`, `openspec validate --specs` y validación del cambio; documentar resultados reales y pendientes de Neon, web, móvil, IA/voz, ausentismo y eMail.

## 6. Corrección de organización por caso de uso

- [x] 6.1 Separar `analytics/reportes/` y `analytics/exportacion/` con router compuesto; comprobar imports, cuatro rutas únicas, OpenAPI idéntico, pruebas y validaciones OpenSpec.
