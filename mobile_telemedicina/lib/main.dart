import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
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
import 'features/treatments/data/services/dose_operation_recovery_service.dart';
import 'features/treatments/presentation/providers/treatment_provider.dart';
import 'features/treatments/presentation/screens/avisos_inbox_screen.dart';
import 'features/treatments/presentation/screens/cronograma_screen.dart';
import 'features/treatments/presentation/screens/treatment_detail_screen.dart';
import 'features/treatments/presentation/screens/treatments_list_screen.dart';
import 'features/treatments/presentation/session/treatment_session_coordinator.dart';
import 'features/treatments/presentation/session/android_push_session_coordinator.dart';

import 'features/appointments/presentation/screens/mis_citas_screen.dart';
import 'features/cola_virtual/presentation/providers/cola_provider.dart';
import 'features/cola_virtual/presentation/screens/cola_operativa_screen.dart';
import 'features/cola_virtual/presentation/screens/mi_turno_screen.dart';
import 'features/waitlist/presentation/providers/waitlist_provider.dart';
import 'features/waitlist/presentation/screens/waitlist_screen.dart';
import 'features/payments/presentation/providers/payment_provider.dart';
import 'features/payments/presentation/screens/payment_checkout_screen.dart';
import 'features/payments/presentation/screens/payment_history_screen.dart';
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
  var firebasePushReady = false;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      await Firebase.initializeApp();
      firebasePushReady = true;
    } catch (_) {
      // La atención clínica y la bandeja siguen disponibles sin push.
    }
  }

  // CU19: push solo en la APK Android; en web no hace nada.
  await PushService.instance.initialize();

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

  runApp(TelemedicinaApp(firebasePushReady: firebasePushReady));
}

class TelemedicinaApp extends StatelessWidget {
  final bool firebasePushReady;

  const TelemedicinaApp({super.key, this.firebasePushReady = false});

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
        ChangeNotifierProvider(create: (_) => WaitlistProvider()),
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
        // CU17: Gestión y Monitoreo de Tratamientos Médicos.
        // Sincroniza la sesión con AuthController y maneja 401 de forma desacoplada.
        ChangeNotifierProxyProvider<AuthController, TreatmentProvider>(
          create: (_) => TreatmentProvider(
            recoveryService: DoseOperationRecoveryService(),
          ),
          update: (_, auth, treatment) {
            final provider =
                treatment ??
                TreatmentProvider(
                  recoveryService: DoseOperationRecoveryService(),
                );
            provider.onSessionExpired = () => handlePrescriptionSessionExpired(
              authController: auth,
              navigatorKey: prescriptionNavigatorKey,
            );
            provider.syncAuthSession(
              isAuthenticated: auth.isAuthenticated,
              userId: auth.currentUser?.idUsuario,
              clinicId: auth.currentUser?.idClinica,
            );
            return provider;
          },
        ),
        // Coordinador de ciclo de vida de sesión y reconciliación de tomas CU17
        ChangeNotifierProxyProvider2<
          AuthController,
          TreatmentProvider,
          TreatmentSessionCoordinator
        >(
          lazy: false,
          create: (context) {
            final treatment = Provider.of<TreatmentProvider>(
              context,
              listen: false,
            );
            final auth = Provider.of<AuthController>(context, listen: false);
            final recovery = treatment.recoveryService;
            return TreatmentSessionCoordinator(
              recoveryService: recovery,
              treatmentProvider: treatment,
              authController: auth,
            );
          },
          update: (_, auth, treatment, coordinator) {
            final recovery = treatment.recoveryService;
            final coord =
                coordinator ??
                TreatmentSessionCoordinator(
                  recoveryService: recovery,
                  treatmentProvider: treatment,
                  authController: auth,
                );
            coord.attachTreatmentProvider(treatment);
            coord.onSessionStateChanged(
              userId: auth.currentUser?.idUsuario,
              clinicId: auth.currentUser?.idClinica,
            );
            return coord;
          },
        ),
        ProxyProvider<AuthController, AndroidPushSessionCoordinator>(
          lazy: false,
          update: (_, auth, coordinator) {
            final push =
                coordinator ??
                AndroidPushSessionCoordinator(
                  tokenSource: firebasePushReady
                      ? FirebaseAndroidPushTokenSource()
                      : null,
                );
            auth.onBeforeLogout = push.beforeLogout;
            push.syncSession(
              isPatient:
                  auth.isPatient &&
                  (auth.currentUser?.notificacionesPush ?? false),
              isProfileVerified: auth.isProfileVerified,
              userId: auth.currentUser?.idUsuario,
              clinicId: auth.currentUser?.idClinica,
            );
            return push;
          },
          dispose: (_, coordinator) => coordinator.dispose(),
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
          '/especialistas': (context) => SpecialistSearchScreen(
            provider: context.read<SpecialistSearchProvider>(),
          ),
          '/appointments': (context) => const AppointmentsScreen(),
          '/citas': (context) => const MisCitasScreen(),
          '/mis-citas': (context) => const MisCitasScreen(),
          '/mi-cola': (context) => const MiTurnoScreen(),
          '/cola': (context) => const ColaOperativaScreen(),
          '/lista-espera': (context) =>
              const PatientOnlyRoute(child: WaitlistScreen()),
          '/fichas': (context) => const FichasScreen(),
          '/fichas/nueva': (context) => const BookFichaScreen(),
          '/documentos': (context) =>
              const PatientOnlyRoute(child: DocumentsListScreen()),
          '/mis-documentos': (context) =>
              const PatientOnlyRoute(child: DocumentsListScreen()),
          '/recetas': (context) =>
              const PatientOnlyRoute(child: MisRecetasScreen()),
          // Rutas CU17 protegidas por PatientOnlyRoute
          '/tratamientos': (context) =>
              const PatientOnlyRoute(child: TreatmentsListScreen()),
          '/tratamientos/detalle': (context) =>
              const PatientOnlyRoute(child: TreatmentDetailScreen()),
          '/tratamientos/cronograma': (context) =>
              const PatientOnlyRoute(child: CronogramaScreen()),
          '/tratamientos/avisos': (context) =>
              const PatientOnlyRoute(child: AvisosInboxScreen()),
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
          '/notificaciones': (context) => const NotificacionesScreen(),
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
