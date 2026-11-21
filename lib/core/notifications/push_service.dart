/// CU19: punto de entrada común para notificaciones push.
///
/// En Android se usa [PushService] de `push_service_android.dart` (con Firebase).
/// En web se usa el stub vacío de `push_service_stub.dart` (no-op).
/// La importación condicional de Dart selecciona la implementación correcta
/// según la plataforma de compilación.
export 'push_service_android.dart' if (dart.library.html) 'push_service_stub.dart';
