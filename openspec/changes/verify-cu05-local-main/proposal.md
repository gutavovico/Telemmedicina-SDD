## Why

Verificar CU5 tras el merge a main sin migraciones ni escrituras en Neon. La instalación limpia falla por selección implícita del driver PostgreSQL; Angular development apunta a Render; Recepción no usa el rol publicado por /auth/me; citas almacena horas varchar en Neon.

## What Changes

- Fijar explícitamente el driver psycopg2 instalado.
- Usar localhost para Angular development y el rol autenticado de /auth/me en CU5.
- Normalizar horas de citas TIME/varchar, conservando el comportamiento conservador ante datos inválidos.
- Agregar regresiones y un lanzador de demostración aislado con SQLite y claves CU16 efímeras.
- Documentar la diferencia medicos.id_clinica sin modificar Neon ni debilitar aislamiento.

## Capabilities

### New Capabilities
- `cu05-local-verification`: ejecución local y compatibilidad de CU5 tras merge.

## Impact

Backend, frontend, pruebas y documentación local. Sin nuevas rutas ni migraciones. El contrato histórico CU5 no está en main de la raíz; el gitlink backend specs d70af589 no se puede recuperar del remoto. No se certifica conformidad histórica completa. Los contratos raíz de auth/doctors aún usan /api/v1 y UUID, diferentes de los endpoints actuales; se registra esta discrepancia sin reescribirlos.
