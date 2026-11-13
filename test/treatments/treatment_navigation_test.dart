import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mobile_telemedicina/features/auth/data/models/auth_models.dart';
import 'package:mobile_telemedicina/features/auth/presentation/controllers/auth_controller.dart';
import 'package:mobile_telemedicina/features/auth/presentation/widgets/patient_only_route.dart';
import 'package:mobile_telemedicina/features/medical_records/presentation/screens/home_screen.dart';
import 'package:mobile_telemedicina/features/treatments/domain/entities/treatment_entities.dart';
import 'package:mobile_telemedicina/features/treatments/domain/repositories/treatment_repository.dart';
import 'package:mobile_telemedicina/features/treatments/domain/usecases/get_adherencia_usecase.dart';
import 'package:mobile_telemedicina/features/treatments/domain/usecases/get_avisos_usecase.dart';
import 'package:mobile_telemedicina/features/treatments/domain/usecases/get_cronograma_usecase.dart';
import 'package:mobile_telemedicina/features/treatments/domain/usecases/get_treatment_detail_usecase.dart';
import 'package:mobile_telemedicina/features/treatments/domain/usecases/get_treatments_usecase.dart';
import 'package:mobile_telemedicina/features/treatments/domain/usecases/mark_aviso_read_usecase.dart';
import 'package:mobile_telemedicina/features/treatments/domain/usecases/record_dose_usecase.dart';
import 'package:mobile_telemedicina/features/treatments/presentation/providers/treatment_provider.dart';
import 'package:mobile_telemedicina/features/treatments/presentation/screens/avisos_inbox_screen.dart';
import 'package:mobile_telemedicina/features/treatments/presentation/screens/cronograma_screen.dart';
import 'package:mobile_telemedicina/features/treatments/presentation/screens/treatment_detail_screen.dart';
import 'package:mobile_telemedicina/features/treatments/presentation/screens/treatments_list_screen.dart';

class _FakeAuthForNav extends AuthController {
  final UserModel? user;

  _FakeAuthForNav(String? role)
      : user = role == null
            ? null
            : UserModel(
                idUsuario: 10,
                idClinica: 1,
                nombres: 'Carlos',
                apellidos: 'Paciente',
                correo: 'carlos@hospital.com',
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

class _NavTestRepository implements TreatmentRepository {
  @override
  Future<TreatmentPage> getTreatments({String? estado, int skip = 0, int limit = 20}) async {
    return const TreatmentPage(
      items: [
        TreatmentPlan(
          idTratamiento: 777,
          idClinica: 1,
          idConsulta: 5,
          idPaciente: 10,
          idMedico: 2,
          diagnostico: Diagnostico(codigoCie: 'I10', descripcion: 'Hipertensión'),
          fechaInicio: '2026-11-01',
          fechaFin: '2026-11-20',
          zonaHoraria: 'America/La_Paz',
          estado: 'ACTIVO',
          medicamentos: [
            MedicamentoPlan(
              idMedicamentoPlan: 1,
              idRecetaDetalle: 10,
              medicamentoNombre: 'Enalapril 10mg',
              dosis: '1 tableta',
              viaAdministracion: 'ORAL',
              fechaInicio: '2026-11-01',
              fechaFin: '2026-11-20',
              horasLocales: ['08:00'],
              estado: 'ACTIVO',
            ),
          ],
        ),
      ],
      total: 1,
    );
  }

  @override
  Future<TreatmentPlan> getTreatmentDetail(int idTratamiento) async {
    return const TreatmentPlan(
      idTratamiento: 777,
      idClinica: 1,
      idConsulta: 5,
      idPaciente: 10,
      idMedico: 2,
      diagnostico: Diagnostico(codigoCie: 'I10', descripcion: 'Hipertensión'),
      fechaInicio: '2026-11-01',
      fechaFin: '2026-11-20',
      zonaHoraria: 'America/La_Paz',
      estado: 'ACTIVO',
      medicamentos: [
        MedicamentoPlan(
          idMedicamentoPlan: 1,
          idRecetaDetalle: 10,
          medicamentoNombre: 'Enalapril 10mg',
          dosis: '1 tableta',
          viaAdministracion: 'ORAL',
          fechaInicio: '2026-11-01',
          fechaFin: '2026-11-20',
          horasLocales: ['08:00'],
          estado: 'ACTIVO',
        ),
      ],
    );
  }

  @override
  Future<CronogramaDia> getCronograma(int idTratamiento, String fecha) async {
    return CronogramaDia(
      idTratamiento: idTratamiento,
      fecha: fecha,
      zonaHoraria: 'America/La_Paz',
      dosis: const [],
    );
  }

  @override
  Future<Adherencia> getAdherencia(int idTratamiento) async {
    return const Adherencia(
      numeradorPuntual: 5,
      denominadorProgramado: 5,
      porcentaje: 100.0,
      nivel: 'OPTIMA',
    );
  }

  @override
  Future<AvisoPage> getAvisos({int skip = 0, int limit = 20, bool noLeidos = false}) async {
    return const AvisoPage(items: [], total: 0);
  }

  @override
  Future<Dosis> registrarDosis(int idDosis, String idempotencyKey, Map<String, dynamic> body) async => throw UnimplementedError();
  @override
  Future<Aviso> leerAviso(int idAviso) async => throw UnimplementedError();
  @override
  Future<OperacionIdempotencia> consultarIdempotencia(int idDosis, String idempotencyKey) async => throw UnimplementedError();
  @override
  Future<void> eliminarDispositivo(int idDispositivo) async {}
  @override
  Future<OperacionIdempotencia> iniciarIntentoDosis(int idDosis, String idempotencyKey, String requestHash) async => throw UnimplementedError();
  @override
  Future<Map<String, dynamic>> registrarDispositivo(String token, String plataforma) async => {};
  @override
  Future<OperacionIdempotencia> resolverOperacionAbandonada(int idDosis, String idempotencyKey) async => throw UnimplementedError();
}

Widget createFullNavApp({
  required String initialRoute,
  required String? role,
}) {
  final repo = _NavTestRepository();
  final treatmentProvider = TreatmentProvider(
    getTreatmentsUseCase: GetTreatmentsUseCase(repository: repo),
    getDetailUseCase: GetTreatmentDetailUseCase(repository: repo),
    getCronogramaUseCase: GetCronogramaUseCase(repository: repo),
    getAdherenciaUseCase: GetAdherenciaUseCase(repository: repo),
    recordDoseUseCase: RecordDoseUseCase(repository: repo),
    getAvisosUseCase: GetAvisosUseCase(repository: repo),
    markAvisoReadUseCase: MarkAvisoReadUseCase(repository: repo),
  );

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthController>(create: (_) => _FakeAuthForNav(role)),
      ChangeNotifierProvider<TreatmentProvider>.value(value: treatmentProvider),
    ],
    child: MaterialApp(
      initialRoute: initialRoute,
      routes: {
        '/login': (_) => const Scaffold(body: Text('Pantalla de Login')),
        '/home': (_) => const HomeScreen(),
        '/tratamientos': (_) => const PatientOnlyRoute(child: TreatmentsListScreen()),
        '/tratamientos/detalle': (_) => const PatientOnlyRoute(child: TreatmentDetailScreen()),
        '/tratamientos/cronograma': (_) => const PatientOnlyRoute(child: CronogramaScreen()),
        '/tratamientos/avisos': (_) => const PatientOnlyRoute(child: AvisosInboxScreen()),
      },
    ),
  );
}

void main() {
  group('Treatment Navigation & Route Protection Tests', () {
    testWidgets('PACIENTE puede abrir /tratamientos y ver la lista', (tester) async {
      await tester.pumpWidget(createFullNavApp(initialRoute: '/tratamientos', role: 'PACIENTE'));
      await tester.pumpAndSettle();

      expect(find.text('Mis Tratamientos'), findsOneWidget);
      expect(find.textContaining('Hipertensión'), findsOneWidget);
    });

    testWidgets('MEDICO es bloqueado de /tratamientos por PatientOnlyRoute y va a /home', (tester) async {
      await tester.pumpWidget(createFullNavApp(initialRoute: '/tratamientos', role: 'MEDICO'));
      await tester.pumpAndSettle();

      // Redirige a /home
      expect(find.text('Mis Tratamientos'), findsNothing);
      expect(find.text('Servicios Disponibles'), findsOneWidget);
    });

    testWidgets('MEDICO es bloqueado de /tratamientos/cronograma y redirigido a /home', (tester) async {
      await tester.pumpWidget(createFullNavApp(initialRoute: '/tratamientos/cronograma', role: 'MEDICO'));
      await tester.pumpAndSettle();

      expect(find.text('Cronograma de Tomas'), findsNothing);
      expect(find.text('Servicios Disponibles'), findsOneWidget);
    });

    testWidgets('MEDICO es bloqueado de /tratamientos/avisos y redirigido a /home', (tester) async {
      await tester.pumpWidget(createFullNavApp(initialRoute: '/tratamientos/avisos', role: 'MEDICO'));
      await tester.pumpAndSettle();

      expect(find.text('Avisos y Recordatorios'), findsNothing);
      expect(find.text('Servicios Disponibles'), findsOneWidget);
    });

    testWidgets('Usuario sin sesión es bloqueado de /tratamientos y va a /login', (tester) async {
      await tester.pumpWidget(createFullNavApp(initialRoute: '/tratamientos', role: null));
      await tester.pumpAndSettle();

      expect(find.text('Pantalla de Login'), findsOneWidget);
    });

    testWidgets('Usuario sin sesión es bloqueado de /tratamientos/cronograma y va a /login', (tester) async {
      await tester.pumpWidget(createFullNavApp(initialRoute: '/tratamientos/cronograma', role: null));
      await tester.pumpAndSettle();

      expect(find.text('Pantalla de Login'), findsOneWidget);
    });

    testWidgets('Usuario sin sesión es bloqueado de /tratamientos/avisos y va a /login', (tester) async {
      await tester.pumpWidget(createFullNavApp(initialRoute: '/tratamientos/avisos', role: null));
      await tester.pumpAndSettle();

      expect(find.text('Pantalla de Login'), findsOneWidget);
    });

    testWidgets('HomeScreen muestra tarjeta "Mis Tratamientos" solo si es paciente', (tester) async {
      // Como PACIENTE:
      await tester.pumpWidget(createFullNavApp(initialRoute: '/home', role: 'PACIENTE'));
      await tester.pumpAndSettle();

      expect(find.text('Mis Tratamientos'), findsOneWidget);
      expect(find.byIcon(Icons.healing_rounded), findsOneWidget);

      // Asegurar visibilidad de la tarjeta en el scroll
      await tester.ensureVisible(find.text('Mis Tratamientos'));
      await tester.pumpAndSettle();

      // Tap en Mis Tratamientos navega a /tratamientos
      await tester.tap(find.text('Mis Tratamientos'));
      await tester.pumpAndSettle();

      expect(find.text('Mis Tratamientos'), findsOneWidget);
      expect(find.textContaining('Hipertensión'), findsOneWidget);
    });

    testWidgets('HomeScreen oculta tarjeta "Mis Tratamientos" si es médico', (tester) async {
      await tester.pumpWidget(createFullNavApp(initialRoute: '/home', role: 'MEDICO'));
      await tester.pumpAndSettle();

      expect(find.text('Mis Tratamientos'), findsNothing);
    });

    testWidgets('Flujo de navegación completo: Lista -> Detalle -> Cronograma y Avisos', (tester) async {
      await tester.pumpWidget(createFullNavApp(initialRoute: '/tratamientos', role: 'PACIENTE'));
      await tester.pumpAndSettle();

      // 1. En lista, tocar botón de avisos en AppBar
      await tester.tap(find.byTooltip('Bandeja de avisos'));
      await tester.pumpAndSettle();
      expect(find.text('Avisos y Recordatorios'), findsOneWidget);

      // Volver a la lista
      Navigator.of(tester.element(find.text('Avisos y Recordatorios'))).pop();
      await tester.pumpAndSettle();
      expect(find.text('Mis Tratamientos'), findsOneWidget);

      // 2. Tocar tarjeta de tratamiento para ir a Detalle
      await tester.tap(find.textContaining('Hipertensión'));
      await tester.pumpAndSettle();
      expect(find.text('Detalle del Tratamiento'), findsOneWidget);
      expect(find.text('Ver Cronograma de Tomas'), findsOneWidget);

      // 3. Tocar "Ver Cronograma de Tomas" para ir a Cronograma
      await tester.tap(find.text('Ver Cronograma de Tomas'));
      await tester.pumpAndSettle();
      expect(find.text('Cronograma de Tomas'), findsOneWidget);
    });
  });
}
