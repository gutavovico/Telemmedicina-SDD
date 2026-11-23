/// CU19: implementación vacía de PushService para web y otras plataformas.
///
/// En web y Flutter web no se inicializa Firebase ni se piden permisos de
/// notificaciones. Todos los métodos son no-ops silenciosos.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  /// No-op en web.
  Future<void> initialize() async {}

  /// No-op en web.
  Future<void> registerCurrentToken() async {}

  /// No-op en web.
  Future<void> unregisterDevice() async {}
}
