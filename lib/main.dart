import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'features/ai_assistant/presentation/screens/ai_assistant_screen.dart';
import 'features/analytics/reportes/presentation/screens/reports_screen.dart';
import 'features/appointments/presentation/controllers/doctor_controller.dart';
import 'features/appointments/presentation/providers/appointment_provider.dart';
import 'features/appointments/presentation/screens/appointments_screen.dart';
import 'features/appointments/presentation/screens/doctor_catalog_screen.dart';
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
import 'features/teleconsulta/presentation/providers/teleconsulta_provider.dart';
import 'features/teleconsulta/presentation/screens/teleconsultas_list_screen.dart';
import 'features/teleconsulta/presentation/screens/sala_espera_screen.dart';
import 'features/teleconsulta/presentation/screens/videollamada_movil_screen.dart';
import 'features/communications/data/models/notificacion_model.dart';
import 'features/communications/data/services/local_headsup_notification_service.dart';
import 'features/communications/presentation/providers/notificacion_provider.dart';
import 'features/communications/presentation/screens/notificaciones_screen.dart';
import 'features/communications/presentation/services/notificacion_navigation_handler.dart';
import 'features/communications/presentation/widgets/in_app_notification_banner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Navegación al pulsar una notificación emergente nativa de Android (tipo WhatsApp)
  LocalHeadsUpNotificationService.instance.onTapNotificacion = (payload) {
    final nav = prescriptionNavigatorKey.currentState;
    final ctx = prescriptionNavigatorKey.currentContext;
    if (nav == null || ctx == null) return;
    final auth = Provider.of<AuthController>(ctx, listen: false);
    final ruta = NotificacionNavigationHandler.resolverRuta(
      tipo: (payload['tipo'] ?? 'SISTEMA').toString(),
      recursoTipo: payload['recurso_tipo']?.toString(),
      rolUsuario: auth.userRole,
      enlaceAccion: payload['enlace_accion']?.toString(),
    );
    if (!auth.isAuthenticated) {
      nav.pushNamedAndRemoveUntil('/login', (_) => false);
      return;
    }
    nav.pushNamed(ruta);
  };

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
        ChangeNotifierProvider(create: (_) => AppointmentProvider()),
        ChangeNotifierProvider(create: (_) => TeleconsultaProvider()),
        ChangeNotifierProvider(create: (_) => ColaProvider()),
        ChangeNotifierProvider(create: (_) => FichaProvider()),
        ChangeNotifierProvider(create: (_) => ClinicalDocumentsProvider()),
        ChangeNotifierProxyProvider<AuthController, NotificacionProvider>(
          create: (_) => NotificacionProvider(),
          update: (_, auth, notif) {
            final provider = notif ?? NotificacionProvider();
            provider.sincronizarSesion(isAuthenticated: auth.isAuthenticated);
            return provider;
          },
        ),
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
        builder: (context, child) {
          return Stack(
            children: [
              ?child,
              Consumer2<NotificacionProvider, AuthController>(
                builder: (ctx, notifProvider, auth, _) {
                  final banner = notifProvider.bannerActivo;
                  return Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      transitionBuilder: (widget, animation) {
                        final offset = Tween<Offset>(
                          begin: const Offset(0, -1),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          ),
                        );
                        return SlideTransition(
                          position: offset,
                          child: FadeTransition(
                            opacity: animation,
                            child: widget,
                          ),
                        );
                      },
                      child: banner == null
                          ? const SizedBox.shrink()
                          : InAppNotificationBanner(
                              key: ValueKey('global_banner_${banner.id}'),
                              mensaje: banner,
                              onDismiss: notifProvider.descartarBannerInApp,
                              onTap: () {
                                notifProvider.descartarBannerInApp();
                                final navCtx =
                                    prescriptionNavigatorKey.currentContext;
                                if (navCtx == null) return;
                                NotificacionNavigationHandler
                                    .navegarDesdeNotificacion(
                                  navCtx,
                                  NotificacionModel(
                                    id: int.tryParse(banner.id) ?? 0,
                                    idUsuario:
                                        auth.currentUser?.idUsuario ?? 0,
                                    tipo: banner.tipo,
                                    categoria: 'CITAS',
                                    canal: 'PUSH',
                                    canalBadge: banner.canalBadge,
                                    titulo: banner.titulo,
                                    mensaje: banner.cuerpo,
                                    recursoTipo: banner.recursoTipo,
                                    recursoId: banner.recursoId,
                                    creadaEn: banner.recibidaEn,
                                    estado: 'ENVIADO',
                                  ),
                                );
                              },
                            ),
                    ),
                  );
                },
              ),
            ],
          );
        },
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
          '/communications': (context) => const TeleconsultasListScreen(),
          '/notificaciones': (context) => const NotificacionesScreen(),
          '/teleconsultas': (context) => const TeleconsultasListScreen(),
          '/teleconsulta/sala-espera': (context) => const SalaEsperaScreen(),
          '/teleconsulta/videollamada': (context) => const VideollamadaMovilScreen(),
          '/analytics': (context) => const ReportsScreen(),
          '/ai-assistant': (context) => const AiAssistantScreen(),
        },
      ),
    );
  }
}
