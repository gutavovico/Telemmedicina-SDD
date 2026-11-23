import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mobile_telemedicina/features/auth/data/models/auth_models.dart';
import 'package:mobile_telemedicina/features/auth/presentation/controllers/auth_controller.dart';
import 'package:mobile_telemedicina/features/auth/presentation/widgets/patient_only_route.dart';

class _AuthForRouteTest extends AuthController {
  final UserModel? user;

  _AuthForRouteTest(String? role)
    : user = role == null
          ? null
          : UserModel(
              idUsuario: 1,
              nombres: 'Usuario',
              apellidos: 'Prueba',
              correo: 'usuario@hospital.com',
              rolNombre: role,
            );

  @override
  UserModel? get currentUser => user;

  @override
  bool get isAuthenticated => user != null;

  @override
  bool get isPatient => user?.isPatient ?? false;

  @override
  Future<bool> checkAuthStatus() async => isAuthenticated;
}

void main() {
  Future<void> pumpGuardedRoute(WidgetTester tester, String? role) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>(
        create: (_) => _AuthForRouteTest(role),
        child: MaterialApp(
          initialRoute: '/recetas',
          routes: {
            '/home': (_) => const Scaffold(body: Text('Inicio')),
            '/login': (_) => const Scaffold(body: Text('Ingreso')),
            '/recetas': (_) => const PatientOnlyRoute(
              child: Scaffold(body: Text('Recetas del paciente')),
            ),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('PACIENTE puede abrir la vista protegida', (tester) async {
    await pumpGuardedRoute(tester, 'PACIENTE');
    expect(find.text('Recetas del paciente'), findsOneWidget);
  });

  for (final role in ['ADMIN', 'MEDICO']) {
    testWidgets('$role no puede abrir la vista por URL directa', (
      tester,
    ) async {
      await pumpGuardedRoute(tester, role);
      expect(find.text('Inicio'), findsOneWidget);
      expect(find.text('Recetas del paciente'), findsNothing);
    });
  }

  testWidgets('Una persona sin sesión vuelve al ingreso', (tester) async {
    await pumpGuardedRoute(tester, null);
    expect(find.text('Ingreso'), findsOneWidget);
    expect(find.text('Recetas del paciente'), findsNothing);
  });
}
