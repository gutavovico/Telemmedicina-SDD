import 'dart:async';

/// Mensaje Push normalizado recibido en el dispositivo móvil (CU20).
class NotificacionMensajePush {
  final String id;
  final String titulo;
  final String cuerpo;
  final String tipo;
  final String? recursoTipo;
  final String? recursoId;
  final String canalBadge;
  final Map<String, dynamic> datos;
  final DateTime recibidaEn;

  NotificacionMensajePush({
    required this.id,
    required this.titulo,
    required this.cuerpo,
    this.tipo = 'SISTEMA',
    this.recursoTipo,
    this.recursoId,
    this.canalBadge = 'Push',
    this.datos = const {},
    DateTime? recibidaEn,
  }) : recibidaEn = recibidaEn ?? DateTime.now();
}

/// Contrato desacoplado de recepción Push (permite pruebas unitarias y
/// operación resiliente sin Google Play Services ni instalaciones externas).
abstract class FcmAdapter {
  Future<String?> obtenerToken();
  Future<bool> requestPermission();
  Future<NotificacionMensajePush?> getInitialMessage();
  Stream<String> get onTokenRefresh;
  Stream<NotificacionMensajePush> get onMessage;
  Stream<NotificacionMensajePush> get onMessageOpenedApp;
  Future<void> dispose();
}

/// Implementación segura por defecto (fallback resiliente sin requerir configuración
/// externa en el teléfono ni fallar en emuladores/entornos sin Google Play Services).
class SafeFallbackFcmAdapter implements FcmAdapter {
  final _tokenRefreshCtrl = StreamController<String>.broadcast();
  final _messageCtrl = StreamController<NotificacionMensajePush>.broadcast();
  final _openedCtrl = StreamController<NotificacionMensajePush>.broadcast();

  /// Permite simular o inyectar mensajes recibidos en primer plano / al abrir.
  void emitirMensajePrimerPlano(NotificacionMensajePush msg) {
    if (!_messageCtrl.isClosed) _messageCtrl.add(msg);
  }

  void emitirMensajeAbierto(NotificacionMensajePush msg) {
    if (!_openedCtrl.isClosed) _openedCtrl.add(msg);
  }

  @override
  Future<String?> obtenerToken() async => null;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<NotificacionMensajePush?> getInitialMessage() async => null;

  @override
  Stream<String> get onTokenRefresh => _tokenRefreshCtrl.stream;

  @override
  Stream<NotificacionMensajePush> get onMessage => _messageCtrl.stream;

  @override
  Stream<NotificacionMensajePush> get onMessageOpenedApp => _openedCtrl.stream;

  @override
  Future<void> dispose() async {
    await _tokenRefreshCtrl.close();
    await _messageCtrl.close();
    await _openedCtrl.close();
  }
}
