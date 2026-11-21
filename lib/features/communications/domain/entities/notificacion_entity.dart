/// Entidad de dominio pura para notificaciones y recordatorios multicanal (CU20).
class NotificacionEntity {
  final int id;
  final int? idClinica;
  final int idUsuario;
  final String? rolDestinatario;
  final String tipo;
  final String categoria; // CITAS | DOCUMENTOS | SISTEMA
  final String canal; // MULTI | PUSH | EMAIL | SMS
  final String canalBadge; // Push | Correo | WhatsApp | SMS
  final String titulo;
  final String mensaje;
  final String? recursoTipo;
  final String? recursoId;
  final String? enlaceAccion;
  final DateTime creadaEn;
  final DateTime? leidaEn;
  final String estado;

  const NotificacionEntity({
    required this.id,
    this.idClinica,
    required this.idUsuario,
    this.rolDestinatario,
    required this.tipo,
    required this.categoria,
    required this.canal,
    required this.canalBadge,
    required this.titulo,
    required this.mensaje,
    this.recursoTipo,
    this.recursoId,
    this.enlaceAccion,
    required this.creadaEn,
    this.leidaEn,
    required this.estado,
  });

  bool get estaLeida => leidaEn != null || estado.toUpperCase() == 'LEIDA';
}
