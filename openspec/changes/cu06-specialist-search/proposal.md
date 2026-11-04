# Proposal: CU06 Buscar Especialistas y Disponibilidad

## Why

La web y la app móvil sólo permiten listar médicos por nombre/especialidad; no existe una búsqueda compuesta por costo, modalidad y fecha, ni una respuesta que combine perfil, servicios y disponibilidad real. El endpoint actual de disponibilidad exige un médico y servicio ya conocidos y no está integrado con el directorio. El módulo de pagos Stripe existente corresponde a CU19 y no interviene en este caso de uso.

## What Changes

- Incorporar una consulta de búsqueda en el tenant actual que combine texto, especialidad, modalidad, costo y rango de fechas.
- Devolver perfiles profesionales, servicios, precios y disponibilidad efectiva por profesional, calculada desde horarios, citas y bloqueos.
- Exponer el mismo contrato a Angular y Flutter, con adaptación responsiva y estados explícitos de carga, vacío, error y resultado.
- Reemplazar el uso de datos simulados o listados legacy cuando no representen el tenant, costo, modalidad y disponibilidad solicitados.
- Mantener aislamiento estricto: ningún perfil, servicio, horario, cita ni bloqueo de otro tenant puede ser visible.

## Capabilities

### New Capabilities

- `specialist-search-backend`: búsqueda filtrada, disponibilidad real, aislamiento y contrato API.
- `specialist-search-web`: directorio y calendario de especialistas en Angular.
- `specialist-search-mobile`: directorio y calendario de especialistas en Flutter.

### Modified Capabilities

Ninguna. Los listados legacy de médicos y la disponibilidad CU05 se conservan, pero la nueva capacidad no los usa como sustituto de la búsqueda compuesta.

## Impact

Backend FastAPI en `app/modules/appointments/specialist_search/`; Angular en `features/appointments/specialist-search/`; Flutter en `lib/features/appointments/specialist_search/`; contrato `openspec/contracts/specialist-search.md`. Requiere migrar servicios médicos al discriminador UUID por tenant y agregar modalidad/costo por servicio. No modifica pagos ni reservas.