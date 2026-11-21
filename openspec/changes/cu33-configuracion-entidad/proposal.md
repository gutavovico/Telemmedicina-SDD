## Why
El administrador necesita mantener la identidad y el catálogo de su clínica desde el portal web.
## What Changes
Agregar configuración autorizada por clínica. CU33 usa Session síncrona e id_clinica BIGINT siguiendo el runtime vigente y la decisión expresa del responsable.
## Impact
Backend FastAPI y portal Angular. Reservas, disponibilidad, cobros, medición de sedes y activación DNS quedan para integración posterior.
