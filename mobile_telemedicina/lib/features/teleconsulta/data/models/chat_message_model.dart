class ChatMessageModel {
  final int idMensaje;
  final int idRemitente;
  final String nombreRemitente;
  final String rolRemitente; // 'MEDICO' | 'PACIENTE' | 'SISTEMA'
  final String contenido;
  final String horaDisplay;
  final String? avatarUrl;
  final bool esPropio;
  final bool leido;
  final String? adjuntoNombre;
  final String? adjuntoTamano;
  final String? adjuntoUrl;

  const ChatMessageModel({
    required this.idMensaje,
    required this.idRemitente,
    required this.nombreRemitente,
    required this.rolRemitente,
    required this.contenido,
    required this.horaDisplay,
    this.avatarUrl,
    required this.esPropio,
    required this.leido,
    this.adjuntoNombre,
    this.adjuntoTamano,
    this.adjuntoUrl,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      idMensaje: json['idMensaje'] as int? ?? json['id_mensaje'] as int? ?? json['id'] as int? ?? 0,
      idRemitente: json['idRemitente'] as int? ?? json['id_remitente'] as int? ?? 0,
      nombreRemitente: json['nombreRemitente'] as String? ?? json['nombre_remitente'] as String? ?? 'Usuario',
      rolRemitente: json['rolRemitente'] as String? ?? json['rol_remitente'] as String? ?? 'PACIENTE',
      contenido: json['contenido'] as String? ?? '',
      horaDisplay: json['horaDisplay'] as String? ?? json['hora_display'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String? ?? json['avatar_url'] as String?,
      esPropio: json['esPropio'] as bool? ?? json['es_propio'] as bool? ?? false,
      leido: json['leido'] as bool? ?? true,
      adjuntoNombre: json['adjuntoNombre'] as String? ?? json['adjunto_nombre'] as String?,
      adjuntoTamano: json['adjuntoTamano'] as String? ?? json['adjunto_tamano'] as String?,
      adjuntoUrl: json['adjuntoUrl'] as String? ?? json['adjunto_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'idMensaje': idMensaje,
      'idRemitente': idRemitente,
      'nombreRemitente': nombreRemitente,
      'rolRemitente': rolRemitente,
      'contenido': contenido,
      'horaDisplay': horaDisplay,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      'esPropio': esPropio,
      'leido': leido,
      if (adjuntoNombre != null) 'adjuntoNombre': adjuntoNombre,
      if (adjuntoTamano != null) 'adjuntoTamano': adjuntoTamano,
      if (adjuntoUrl != null) 'adjuntoUrl': adjuntoUrl,
    };
  }

  ChatMessageModel copyWith({
    int? idMensaje,
    int? idRemitente,
    String? nombreRemitente,
    String? rolRemitente,
    String? contenido,
    String? horaDisplay,
    String? avatarUrl,
    bool? esPropio,
    bool? leido,
    String? adjuntoNombre,
    String? adjuntoTamano,
    String? adjuntoUrl,
  }) {
    return ChatMessageModel(
      idMensaje: idMensaje ?? this.idMensaje,
      idRemitente: idRemitente ?? this.idRemitente,
      nombreRemitente: nombreRemitente ?? this.nombreRemitente,
      rolRemitente: rolRemitente ?? this.rolRemitente,
      contenido: contenido ?? this.contenido,
      horaDisplay: horaDisplay ?? this.horaDisplay,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      esPropio: esPropio ?? this.esPropio,
      leido: leido ?? this.leido,
      adjuntoNombre: adjuntoNombre ?? this.adjuntoNombre,
      adjuntoTamano: adjuntoTamano ?? this.adjuntoTamano,
      adjuntoUrl: adjuntoUrl ?? this.adjuntoUrl,
    );
  }
}
