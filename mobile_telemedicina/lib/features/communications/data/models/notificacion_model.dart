import '../../domain/entities/notificacion_entity.dart';

/// Modelo serializable alineado con el contrato REST `/api/v1/notificaciones/bandeja`.
class NotificacionModel extends NotificacionEntity {
  const NotificacionModel({
    required super.id,
    super.idClinica,
    required super.idUsuario,
    super.rolDestinatario,
    required super.tipo,
    required super.categoria,
    required super.canal,
    required super.canalBadge,
    required super.titulo,
    required super.mensaje,
    super.recursoTipo,
    super.recursoId,
    super.enlaceAccion,
    required super.creadaEn,
    super.leidaEn,
    required super.estado,
  });

  factory NotificacionModel.fromJson(Map<String, dynamic> json) {
    final createdRaw = json['created_at']?.toString() ??
        json['fecha_programada']?.toString() ??
        DateTime.now().toIso8601String();
    final leidaRaw = json['fecha_lectura']?.toString();

    return NotificacionModel(
      id: (json['id_notificacion'] as num?)?.toInt() ?? 0,
      idClinica: (json['id_clinica'] as num?)?.toInt(),
      idUsuario: (json['id_usuario'] as num?)?.toInt() ?? 0,
      rolDestinatario: json['rol_destinatario']?.toString(),
      tipo: json['tipo']?.toString() ?? 'SISTEMA',
      categoria: (json['categoria']?.toString() ?? 'SISTEMA').toUpperCase(),
      canal: (json['canal']?.toString() ?? 'PUSH').toUpperCase(),
      canalBadge: json['canal_badge']?.toString() ?? 'Push',
      titulo: json['titulo']?.toString() ?? 'Notificación',
      mensaje: json['mensaje']?.toString() ?? '',
      recursoTipo: json['recurso_tipo']?.toString(),
      recursoId: json['recurso_id']?.toString(),
      enlaceAccion: json['enlace_accion']?.toString(),
      creadaEn: DateTime.tryParse(createdRaw)?.toLocal() ?? DateTime.now(),
      leidaEn: leidaRaw != null ? DateTime.tryParse(leidaRaw)?.toLocal() : null,
      estado: json['estado']?.toString() ?? 'PENDIENTE',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_notificacion': id,
      'id_clinica': idClinica,
      'id_usuario': idUsuario,
      'rol_destinatario': rolDestinatario,
      'tipo': tipo,
      'categoria': categoria,
      'canal': canal,
      'canal_badge': canalBadge,
      'titulo': titulo,
      'mensaje': mensaje,
      'recurso_tipo': recursoTipo,
      'recurso_id': recursoId,
      'enlace_accion': enlaceAccion,
      'created_at': creadaEn.toIso8601String(),
      'fecha_lectura': leidaEn?.toIso8601String(),
      'estado': estado,
    };
  }

  NotificacionModel copyWith({DateTime? leidaEn, String? estado}) {
    return NotificacionModel(
      id: id,
      idClinica: idClinica,
      idUsuario: idUsuario,
      rolDestinatario: rolDestinatario,
      tipo: tipo,
      categoria: categoria,
      canal: canal,
      canalBadge: canalBadge,
      titulo: titulo,
      mensaje: mensaje,
      recursoTipo: recursoTipo,
      recursoId: recursoId,
      enlaceAccion: enlaceAccion,
      creadaEn: creadaEn,
      leidaEn: leidaEn ?? this.leidaEn,
      estado: estado ?? this.estado,
    );
  }
}
