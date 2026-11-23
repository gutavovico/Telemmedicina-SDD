import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mobile_telemedicina/core/theme/app_theme.dart';
import 'package:mobile_telemedicina/features/auth/presentation/controllers/auth_controller.dart';
import 'package:mobile_telemedicina/features/auth/presentation/screens/login_screen.dart';
import 'package:mobile_telemedicina/features/auth/presentation/screens/register_screen.dart';
import 'package:mobile_telemedicina/features/auth/presentation/screens/splash_screen.dart';

void main() {
  Widget createTestWidget(Widget child) {
    return ChangeNotifierProvider(
      create: (_) => AuthController(),
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: child,
      ),
    );
  }

  testWidgets('SplashScreen displays hospital branding', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createTestWidget(const SplashScreen(autoRedirect: false)));

    expect(find.text('SAN JUAN DE DIOS'), findsOneWidget);
    expect(find.text('Portal de Telemedicina'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('LoginScreen displays all required inputs and action buttons', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createTestWidget(const LoginScreen()));

    expect(find.text('Iniciar Sesión'), findsOneWidget);
    expect(find.text('Correo Electrónico'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('Recordar sesión'), findsOneWidget);
    expect(find.text('Ingresar al Portal'), findsOneWidget);
    expect(find.text('Regístrate aquí'), findsOneWidget);
  });

  testWidgets('RegisterScreen displays all patient registration inputs', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createTestWidget(const RegisterScreen()));

    expect(find.text('Crear Cuenta'), findsOneWidget);
    expect(find.text('Nombres'), findsOneWidget);
    expect(find.text('Apellidos'), findsOneWidget);
    expect(find.text('Correo Electrónico'), findsOneWidget);
    expect(find.text('Teléfono (Opcional)'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('Confirmar Contraseña'), findsOneWidget);
    expect(find.text('Registrar Cuenta de Paciente'), findsOneWidget);
    expect(find.text('Inicia sesión'), findsOneWidget);
  });
}
