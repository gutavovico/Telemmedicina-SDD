# Proposal

## Why

El backend CU22/CU27-reportes ya expone cuatro rutas autorizadas, pero `/analitica` sigue siendo un placeholder sin consulta ni descarga. ADMIN necesita una interfaz web que construya definiciones válidas desde el catálogo y presente resultados y archivos sin alterar el ámbito de clínica.

## What Changes

- Sustituir el placeholder por un área de reportes con selección de tipo, período, filtros, columnas ordenables, agrupación, orden de resultados, indicadores y tabla paginada.
- Proteger la ruta directa y la navegación mediante el rol textual verificado de `/auth/me`, con 401/403 tratados en la interfaz; el backend conserva la autorización final.
- Incorporar una acción de exportación CU27 de PDF, XLSX, CSV y HTML para la definición normalizada del reporte generado, usando Blob y los formatos del catálogo.
- Mantener el indicador de ausentismo como no disponible. Texto libre, voz, eMail, móvil y comprobación viva de Neon continúan pendientes.

## Capabilities

### New Capabilities

- `analytics-web-reporting`: acceso ADMIN, constructor de reportes CU22, resultados y estado de consulta.
- `analytics-web-export`: descarga CU27 de reportes generados y manejo de límites/errores de archivo.

### Modified Capabilities

Ninguna. El contrato de `openspec/contracts/analytics.md` y las rutas backend permanecen sin cambios.

## Impact

Solo Angular en `frontend_Telemedicina/src/app/features/analytics/`, su ruta, guard y navegación; OpenSpec y pruebas web. Sin nuevas dependencias, tablas, migraciones ni cambios de API. La web envía JWT con el interceptor existente y nunca solicita ni envía `id_clinica`; el backend delimita con `Usuario.id_clinica` BIGINT. Los patrones genéricos de UUID/tenant de `openspec/project.md` no describen esta implementación local y no autorizan una refactorización de backend. Flutter consumirá el contrato en una etapa posterior.
