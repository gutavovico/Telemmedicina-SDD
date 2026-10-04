# Pendientes de integración CU05 → CU25 (solo diagnóstico)

Este documento no cambia CU25. Las correcciones de CU05 solo afectan `/appointments/agenda/*`; la reserva y la disponibilidad pública de citas siguen en CU25.

- **Disponibilidad común:** `app/modules/appointments/consultas/service.py::obtener_horarios_disponibles` usa `HORARIOS_ESTANDAR` y citas existentes. Debe consumir las reglas de servicio, día, horario y bloqueos PENDIENTE/APROBADO de CU05 antes de ofrecer un turno.
- **Servicio al reservar:** `CitaCreate` y la pantalla de CU25 no eligen `id_servicio`; sin esa referencia no pueden determinar de forma inequívoca duración ni bloque horario. Acordar el contrato con el responsable de CU25 antes de cambiarlo.
- **Solapes y concurrencia:** `crear_cita` compara solo `hora_inicio`, sin verificar intervalos, bloqueos ni horario recurrente. La validación de reserva debe repetirse bajo una estrategia de concurrencia adecuada, no depender solo de una lista consultada previamente.
- **Autorización y clínica:** el router exige autenticación, pero `crear_cita` no recibe el usuario para limitar paciente y médico a `id_clinica`. El responsable de CU25 debe definir permisos por rol y rechazar referencias ajenas a la clínica.
- **Éxito ficticio en web:** `frontend_Telemedicina/src/app/features/appointments/consultas/consultas.ts` agrega una cita solo en memoria y muestra éxito cuando falla `crearCita`. Debe informar el error real antes de usar ese flujo para comprobar la integración.

La prueba de esta integración requiere una rama temporal de Neon con datos sintéticos y operaciones de escritura autorizadas. El lanzador Neon READ ONLY no permite validar creación de citas. No modificar CU25 desde el trabajo de CU05.
