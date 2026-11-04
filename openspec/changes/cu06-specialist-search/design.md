# Design: CU06 Buscar Especialistas y Disponibilidad

## Context

El CU se implementa en FastAPI, Angular y Flutter. El backend actual usa `id_clinica BIGINT`, mientras `openspec/project.md` exige `tenant_id UUID`; este cambio define el contrato objetivo UUID y señala la migración de persistencia como dependencia. Los servicios médicos actuales son globales y no contienen modalidad; los horarios se relacionan con médico y servicio.

## Goals / Non-Goals

**Goals:** búsqueda filtrada, disponibilidad real, payloads compartidos, aislamiento y respuesta menor a 2 segundos.

**Non-Goals:** reservar cita, procesar pagos, cambiar la agenda, exponer datos de pacientes ni implementar búsqueda global entre tenants.

## Decisions

1. **Módulo backend:** `app/modules/appointments/specialist_search/` con `router.py`, `service.py`, `schemas.py` y `dependencies.py`; reutiliza modelos de médicos, especialidades, servicios, horarios, citas y bloqueos.
2. **Alcance:** el tenant se obtiene del JWT/header según `get_current_tenant`; el cliente nunca envía `tenant_id`. Los roles permitidos son PACIENTE y RECEPCION; MEDICO y ADMIN pueden consultar la misma capacidad dentro de su tenant.
3. **Servicios por tenant:** `servicios_medicos.tenant_id` será UUID NOT NULL tras migración y tendrá `modalidad` (`PRESENCIAL` o `TELECONSULTA`). La unicidad será `UNIQUE(tenant_id, nombre)`.
4. **Disponibilidad:** para cada fecha del rango se combinan `horarios_medicos` activos, duración del servicio, `citas` ocupantes y `bloqueos_agenda` aprobados. Un slot sólo es libre si cabe completo, no intersecta y pertenece al tenant.
5. **Búsqueda:** `GET /api/v1/especialistas/buscar` acepta `nombre`, `especialidad_id`, `modalidad`, `costo_min`, `costo_max`, `fecha_inicio`, `fecha_fin`, `page` y `per_page`. `modalidad=AMBAS` significa cualquiera; el resto es exacto.
6. **Detalle:** `GET /api/v1/especialistas/{id_medico}/disponibilidad` reutiliza el mismo calculador para una persona y rango de fechas.
7. **Privacidad:** la respuesta sólo contiene información profesional y slots; nunca motivo de consulta, paciente, diagnóstico ni datos clínicos.
8. **Rendimiento:** índice compuesto para `servicios_medicos(tenant_id, modalidad, costo)` y consultas paginadas; meta `total`. Objetivo p95 < 2 s con 100 profesionales y 31 días.

## Risks / Trade-offs

- La migración UUID es transversal: no se puede mantener `id_clinica` en endpoints nuevos si se promete el contrato de `project.md`.
- La disponibilidad puede variar entre la búsqueda y la reserva; la reserva debe revalidar el slot en CU05/CU25.
- Los datos legacy sin modalidad/costo requieren backfill explícito, no valores implícitos inseguros.