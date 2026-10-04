# Proposal

## Why

El sprint requiere reportes clínicos y administrativos personalizables para ADMIN. El backend actual tiene citas y consultas, pero no ofrece un catálogo de métricas aislado por clínica ni exportación de esos reportes; las rutas CU25 existentes no aplican el ámbito necesario.

## What Changes

- Incorporar en `analytics` un catálogo cerrado y consultas bajo demanda de encuentros con consulta, actividad de citas, cancelaciones y pacientes únicos, con columnas, filtros, agrupación, orden y paginación validados.
- Publicar el ausentismo como métrica no disponible hasta contar con una transición explícita de ausencia; no producir un cero ficticio.
- Incorporar la integración CU27 para descargar el conjunto filtrado en PDF, XLSX, CSV y HTML, manteniendo el acceso ADMIN y el ámbito de clínica.
- Definir un contrato común para las etapas posteriores de Angular y Flutter. Interpretación de texto, transcripción, interfaz y eMail quedan pendientes, sin endpoints funcionales fingidos.
- Mantener `id_clinica` BIGINT, `Session` síncrona y relaciones locales. No modificar CU05, CU25, HCE, pacientes ni `medicos.id_clinica`; no agregar tablas ni migraciones en esta etapa.

## Capabilities

### New Capabilities

- `analytics-reports`: catálogo, autorización, definiciones y consulta de reportes CU22.
- `report-export`: exportación CU27 limitada a los reportes CU22.

### Modified Capabilities

Ninguna. La divergencia histórica de `system-design` sobre UUID/AsyncSession se documenta en este cambio y requiere reconciliación documental posterior, no una refactorización global.

## Impact

Backend FastAPI en `app/modules/analytics/reportes/` y `app/modules/analytics/exportacion/`; `app/modules/analytics/router.py` compone ambos casos de uso y `app/main.py` lo registra una vez. Contrato `openspec/contracts/analytics.md`; pruebas locales SQLite. Angular y Flutter consumirán este contrato en etapas posteriores. El ámbito se obtiene del ADMIN autenticado (`Usuario.id_clinica`), nunca de `X-Tenant-ID` o del body. Los reportes sobre citas usan `Cita.id_medico -> Medico.id_usuario -> Usuario.id_clinica`, y los encuentros además contrastan `Consulta.id_clinica`, sin exigir pertenencia de `Paciente.id_clinica`. La discrepancia estructural de `Medico.id_clinica` queda para después del merge.
