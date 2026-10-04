# CU5: alcance de corrección local tras merge

Este complemento documenta únicamente la corrección local autorizada. No reemplaza el contrato histórico CU5 ausente en esta copia ni certifica que la implementación coincida con él.

## API utilizada

Desarrollo: http://localhost:8000; Angular: http://localhost:4200. Producción conserva Render. Autenticación Bearer; la clínica se resuelve por el usuario autenticado, no por datos del body.

GET /auth/me publica `rol: string | null` junto a id_usuario, id_rol e id_clinica. CU5 normaliza el nombre para MEDICO, RECEPCION, ADMIN/ADMINISTRADOR/ADMINISTRACION; desconocidos no reciben acciones. No se requiere acceso a /auth/roles.

Rutas actuales compartidas por Angular y FastAPI (sin cambio de payload):
- GET /appointments/agenda/servicios
- GET y POST /appointments/agenda/horarios
- PATCH /appointments/agenda/horarios/{id_horario}/estado
- GET y POST /appointments/agenda/bloqueos
- PATCH /appointments/agenda/bloqueos/{id_bloqueo}/{aprobar|rechazar|liberar}
- GET /appointments/agenda/disponibilidad?id_medico=20&id_servicio=1&fecha=2026-09-10

La disponibilidad conserva slots con hora_inicio/hora_fin ISO, disponible boolean, citas_verificadas boolean y advertencias string[]. Las citas `CANCELADA` no ocupan slots y no se notifican al aprobar un bloqueo. Las demás citas conservan su intervalo real: si falta `hora_fin` o una hora heredada es inválida, CU05 no infiere la duración desde el servicio, responde HTTP 200 con `citas_verificadas=false`, un aviso identificable y todos los slots no disponibles. No se agrega ningún campo ni endpoint.

El escritor actual de CU25 puede crear citas sin `hora_fin` y solo completa `fecha_hora_inicio`; ese inicio y la duración nominal de un servicio no demuestran el fin real de una cita antigua. CU05 deja esos casos sin horarios anunciados hasta que exista un intervalo verificable, sin editar la cita.

La lectura READ ONLY del esquema Neon confirmó `medicos.id_clinica`. CU05 resuelve al médico desde `medicos.id_usuario` para la cuenta médica y limita las operaciones a la `id_clinica` del usuario autenticado. Esta corrección no cambia esas relaciones ni el esquema.
