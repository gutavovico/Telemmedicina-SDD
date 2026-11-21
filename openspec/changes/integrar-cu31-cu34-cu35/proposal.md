# Integrar contratación y cambios con el catálogo versionado

CU31 duplicaba el catálogo en plan_versions y no referenciaba versiones_plan.
Se reutilizan las instantáneas CU34 para la contratación, pagos y CU35. Se
preservan identificadores y filas legacy; ningún enlace se infiere por nombre.
La migración exige un mapa explícito si existen versiones/referencias antiguas.

El alcance incluye upgrade pagado, programación y cancelación efectiva, sin
implementar CU36 ni reestructurar otros módulos. Se reutiliza la autenticación
para bloquear uso clínico por cancelación efectiva, conservando login y facturación.
Fuente: SI2-Grupo3.md §7.1 CU34/CU35 y §7.2.1.4–7.2.1.6, diagramas image132,
133, 137, 138, 149–152. Se conserva sin sobrescribir la edición local del SDD.
