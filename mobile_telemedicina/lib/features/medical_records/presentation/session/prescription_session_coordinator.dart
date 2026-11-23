import 'package:flutter/material.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';

/// Llave global de navegación para redirigir a `/login` ante un 401.
///
/// Se usa porque el provider no debe navegar directamente (capa
/// Presentation coordinada de forma desacoplada vía callback).
final GlobalKey<NavigatorState> prescriptionNavigatorKey =
    GlobalKey<NavigatorState>();

/// Coordinador desacoplado de sesión expirada CU16.
///
/// Reutiliza [AuthController.logout] (que limpia JWT, refresh token, tenant
/// y usuario vía `SecureStorageService` y actualiza el estado de
/// autenticación). No duplica lógica de limpieza ni navega desde Domain/Data:
/// solo es invocado una vez por [PrescriptionProvider] ante 401.
///
/// Funciona para listado, detalle y descarga porque el provider centraliza
/// todos los 401 en un único evento `sessionExpired`.
Future<void> handlePrescriptionSessionExpired({
  required AuthController authController,
  GlobalKey<NavigatorState>? navigatorKey,
  String message =
      'Tu sesión ha expirado. Por favor, inicia sesión nuevamente.',
}) async {
  try {
    await authController.logout();
  } catch (_) {
    // Best-effort: aunque falle el logout remoto, la sesión local ya se
    // intenta limpiar dentro de AuthController.
  }
  // Mensaje comprensible visible en LoginScreen (AuthBanner).
  try {
    authController.setErrorMessage(message);
  } catch (_) {}
  final key = navigatorKey ?? prescriptionNavigatorKey;
  final navigator = key.currentState;
  if (navigator == null) return;
  // Redirección única a /login. El provider garantiza una sola invocación
  // aunque distintas solicitudes reciban 401 al mismo tiempo.
  navigator.pushNamedAndRemoveUntil('/login', (route) => false);
}
