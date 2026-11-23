import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_telemedicina/features/auth/presentation/controllers/auth_controller.dart';
import 'package:mobile_telemedicina/features/medical_records/presentation/session/prescription_session_coordinator.dart';

class FakeAuthController extends AuthController {
  int logoutCalls = 0;
  FakeAuthController() : super();

  @override
  Future<void> logout() async {
    logoutCalls++;
    // No llama a super: evita red y storage nativo en pruebas.
  }
}

void main() {
  group('Coordinador de sesión CU16', () {
    testWidgets('limpia sesión y redirige a /login con mensaje', (
      tester,
    ) async {
      final auth = FakeAuthController();
      final key = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          initialRoute: '/home',
          routes: {
            '/home': (_) => const Scaffold(body: Text('HOME')),
            '/login': (_) => const Scaffold(body: Text('LOGIN')),
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);

      await handlePrescriptionSessionExpired(
        authController: auth,
        navigatorKey: key,
      );
      await tester.pumpAndSettle();

      expect(auth.logoutCalls, 1);
      expect(find.text('LOGIN'), findsOneWidget);
      // Mensaje comprensible propagado al AuthController (visible en login).
      expect(
        auth.errorMessage,
        'Tu sesión ha expirado. Por favor, inicia sesión nuevamente.',
      );
    });
  });
}
