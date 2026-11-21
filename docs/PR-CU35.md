Documentar integración CU31/CU34/CU35 y despliegue con historia CU18

Concreta el catálogo común versiones_plan.id, aceptación de renovación, importes BOB mensuales, prorrateo HALF_UP, fechas efectivas y solicitudes aisladas por entidad. Actualiza el contrato y los diagramas del delta; conserva SI2-Grupo3.md y documenta las excepciones acotadas de AGENTS para la arquitectura existente.

Registra la convergencia 023 de CU18/CU35 sin reescribir revisiones aplicadas y el requisito de ancla original explícita para datos existentes. No aprueba inferir versiones por nombre ni el ancla desde las fechas actuales. Se excluyen demo, configuración local, credenciales y archivos Flutter.

Evidencia: backend 159 aprobadas (5 PG omitidas ahí), selección PostgreSQL 77 aprobadas, frontend 292 aprobadas/5 skips y build aprobado. Los pagos fueron simulados; copia Neon y Stripe sandbox quedan pendientes de despliegue; el mapa de anclas 5/5 ya está autorizado y preparado fuera de Git.

Pendiente antes de aprobar este PR: ejecutar openspec doctor y openspec validate --specs en un entorno con CLI disponible (CommandNotFoundException en esta PC). No se instaló ni se modificó la base compartida.
