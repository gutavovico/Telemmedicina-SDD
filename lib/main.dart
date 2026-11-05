import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'features/ai_assistant/presentation/providers/asistencia_provider.dart';
import 'core/notifications/push_service.dart';
import 'features/ai_assistant/presentation/screens/ai_assistant_screen.dart';
import 'features/analytics/reportes/presentation/screens/reports_screen.dart';
import 'features/appointments/presentation/controllers/doctor_controller.dart';
import 'features/appointments/presentation/providers/appointment_provider.dart';
import 'features/appointments/presentation/screens/appointments_screen.dart';
import 'features/appointments/presentation/screens/doctor_catalog_screen.dart';
import 'features/appointments/specialist_search/data/repositories/specialist_search_repository_impl.dart';
import 'features/appointments/specialist_search/presentation/providers/specialist_search_provider.dart';
import 'features/appointments/specialist_search/presentation/screens/specialist_search_screen.dart';
import 'features/auth/presentation/controllers/auth_controller.dart';
import 'features/auth/presentation/screens/forgot_password_screen.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/register_screen.dart';
import 'features/auth/presentation/screens/reset_password_screen.dart';
import 'features/auth/presentation/screens/splash_screen.dart';
import 'features/auth/presentation/widgets/patient_only_route.dart';
import 'features/medical_records/presentation/providers/clinical_documents_provider.dart';
import 'features/medical_records/presentation/providers/ficha_provider.dart';
import 'features/medical_records/presentation/providers/patient_provider.dart';
import 'features/medical_records/presentation/providers/prescription_provider.dart';
import 'features/medical_records/presentation/screens/book_ficha_screen.dart';
import 'features/medical_records/presentation/screens/documents_list_screen.dart';
import 'features/medical_records/presentation/screens/fichas_screen.dart';
import 'features/medical_records/presentation/screens/home_screen.dart';
import 'features/medical_records/presentation/screens/mis_recetas_screen.dart';
import 'features/medical_records/presentation/screens/patient_profile_screen.dart';
import 'features/medical_records/triage/presentation/pages/triage_page.dart';
import 'features/medical_records/presentation/session/prescription_session_coordinator.dart';

import 'features/appointments/presentation/screens/mis_citas_screen.dart';
import 'features/cola_virtual/presentation/providers/cola_provider.dart';
import 'features/cola_virtual/presentation/screens/cola_operativa_screen.dart';
import 'features/cola_virtual/presentation/screens/mi_turno_screen.dart';
import 'features/payments/presentation/providers/payment_provider.dart';
import 'features/payments/presentation/screens/payment_checkout_screen.dart';
import 'features/payments/presentation/screens/payment_history_screen.dart';
import 'features/teleconsulta/presentation/providers/teleconsulta_provider.dart';
import 'features/teleconsulta/presentation/screens/teleconsultas_list_screen.dart';
import 'features/teleconsulta/presentation/screens/sala_espera_screen.dart';
import 'features/teleconsulta/presentation/screens/videollamada_movil_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // CU19: push solo en la APK Android; en web no hace nada.
  await PushService.instance.initialize();

  // Set status bar styling
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  runApp(const TelemedicinaApp());
}

class TelemedicinaApp extends StatelessWidget {
  const TelemedicinaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(create: (_) => PatientProvider()),
        ChangeNotifierProvider(create: (_) => DoctorController()),
        ChangeNotifierProvider(
          create: (_) => SpecialistSearchProvider(
            repository: SpecialistSearchRepositoryImpl(),
          ),
        ),
        ChangeNotifierProvider(create: (_) => AppointmentProvider()),
        ChangeNotifierProvider(create: (_) => TeleconsultaProvider()),
        ChangeNotifierProvider(create: (_) => ColaProvider()),
        ChangeNotifierProvider(create: (_) => FichaProvider()),
        ChangeNotifierProvider(create: (_) => ClinicalDocumentsProvider()),
        ChangeNotifierProvider(create: (_) => AsistenciaProvider()),
        // CU19: pagos en línea y comprobantes digitales.
        ChangeNotifierProvider(create: (_) => PaymentProvider()),
        // CU16: el provider emite `sessionExpired` una sola vez por ciclo ante 401.
        // El coordinador reutiliza AuthController.logout (limpieza segura) y
        // redirige a /login sin navegar desde Domain/Data.
        // Sincronización explícita del ciclo de autenticación (sin JWT):
        // solo false -> true re-arma el evento 401; un éxito nunca lo limpia.
        ChangeNotifierProxyProvider<AuthController, PrescriptionProvider>(
          create: (_) => PrescriptionProvider(),
          update: (_, auth, prescription) {
            final provider = prescription ?? PrescriptionProvider();
            provider.onSessionExpired = () => handlePrescriptionSessionExpired(
              authController: auth,
              navigatorKey: prescriptionNavigatorKey,
            );
            provider.syncAuthSession(isAuthenticated: auth.isAuthenticated);
            return provider;
          },
        ),
      ],
      child: MaterialApp(
        title: 'Hospital San Juan de Dios - Telemedicina',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        navigatorKey: prescriptionNavigatorKey,
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/forgot-password': (context) => const ForgotPasswordScreen(),
          '/reset-password': (context) => const ResetPasswordScreen(),
          '/home': (context) => const HomeScreen(),
          '/patient-profile': (context) =>
              const PatientOnlyRoute(child: PatientProfileScreen()),
          '/triage': (context) => TriagePage(),
          '/doctors': (context) => const DoctorCatalogScreen(),
          '/especialistas': (context) => SpecialistSearchScreen(
            provider: context.read<SpecialistSearchProvider>(),
          ),
          '/appointments': (context) => const AppointmentsScreen(),
          '/citas': (context) => const MisCitasScreen(),
          '/mis-citas': (context) => const MisCitasScreen(),
          '/mi-cola': (context) => const MiTurnoScreen(),
          '/cola': (context) => const ColaOperativaScreen(),
          '/fichas': (context) => const FichasScreen(),
          '/fichas/nueva': (context) => const BookFichaScreen(),
          '/documentos': (context) =>
              const PatientOnlyRoute(child: DocumentsListScreen()),
          '/mis-documentos': (context) =>
              const PatientOnlyRoute(child: DocumentsListScreen()),
          '/recetas': (context) =>
              const PatientOnlyRoute(child: MisRecetasScreen()),
          // CU19: pago de citas/teleconsultas y comprobantes.
          '/pagos': (context) =>
              const PatientOnlyRoute(child: PaymentHistoryScreen()),
          '/pagos/checkout': (context) {
            final args = ModalRoute.of(context)?.settings.arguments;
            int? idCita;
            if (args is int) {
              idCita = args;
            } else if (args is Map && args['idCita'] is int) {
              idCita = args['idCita'] as int;
            }
            return PatientOnlyRoute(
              child: PaymentCheckoutScreen(idCita: idCita),
            );
          },
          '/communications': (context) => const TeleconsultasListScreen(),
          '/teleconsultas': (context) => const TeleconsultasListScreen(),
          '/teleconsulta/sala-espera': (context) => const SalaEsperaScreen(),
          '/teleconsulta/videollamada': (context) =>
              const VideollamadaMovilScreen(),
          '/analytics': (context) => const ReportsScreen(),
          '/ai-assistant': (context) => const PatientOnlyRoute(child: AiAssistantScreen()),
        },
      ),
    );
  }
}
