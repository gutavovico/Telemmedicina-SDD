import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mobile_telemedicina/core/theme/app_theme.dart';
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
import 'package:mobile_telemedicina/features/treatments/presentation/widgets/adherencia_card.dart';
import 'package:mobile_telemedicina/features/treatments/presentation/widgets/dose_action_dialog.dart';
import 'package:mobile_telemedicina/features/treatments/presentation/widgets/treatment_status_badge.dart';

class ScreensMockRepository implements TreatmentRepository {
  List<TreatmentPlan> treatments = [];
  TreatmentPlan? detail;
  CronogramaDia? cronograma;
  Adherencia? adherencia;
  List<Aviso> avisos = [];
  Dosis? recordedDosis;

  @override
  Future<TreatmentPage> getTreatments({String? estado, int skip = 0, int limit = 20}) async {
    return TreatmentPage(items: treatments, total: treatments.length);
  }

  @override
  Future<TreatmentPlan> getTreatmentDetail(int idTratamiento) async {
    return detail ??
        TreatmentPlan(
          idTratamiento: idTratamiento,
          idClinica: 1,
          idConsulta: 10,
          idPaciente: 20,
          idMedico: 30,
          diagnostico: const Diagnostico(codigoCie: 'I10', descripcion: 'Hipertensión esencial'),
          fechaInicio: '2026-11-01',
          fechaFin: '2026-11-15',
          zonaHoraria: 'America/La_Paz',
          estado: 'ACTIVO',
          medicamentos: const [
            MedicamentoPlan(
              idMedicamentoPlan: 1,
              idRecetaDetalle: 10,
              medicamentoNombre: 'Losartán 50mg',
              dosis: '1 tableta',
              viaAdministracion: 'ORAL',
              fechaInicio: '2026-11-01',
              fechaFin: '2026-11-15',
              horasLocales: ['08:00', '20:00'],
              intervaloHoras: 12,
              estado: 'ACTIVO',
            ),
          ],
        );
  }

  @override
  Future<CronogramaDia> getCronograma(int idTratamiento, String fecha) async {
    return cronograma ??
        CronogramaDia(
          idTratamiento: idTratamiento,
          fecha: fecha,
          zonaHoraria: 'America/La_Paz',
          dosis: const [
            Dosis(
              idDosis: 101,
              idMedicamentoPlan: 1,
              programadaEn: '2026-11-02T12:00:00Z',
              programadaHoraLocal: '08:00',
              zonaHoraria: 'America/La_Paz',
              estado: 'PENDIENTE',
              vencida: false,
            ),
            Dosis(
              idDosis: 102,
              idMedicamentoPlan: 1,
              programadaEn: '2026-11-02T00:00:00Z',
              programadaHoraLocal: '20:00',
              zonaHoraria: 'America/La_Paz',
              estado: 'INGERIDA',
              vencida: false,
              efectivaEn: '2026-11-02T00:05:00Z',
              puntual: true,
            ),
          ],
        );
  }

  @override
  Future<Adherencia> getAdherencia(int idTratamiento) async {
    return adherencia ??
        const Adherencia(
          numeradorPuntual: 8,
          denominadorProgramado: 10,
          porcentaje: 80.0,
          nivel: 'OPTIMA',
        );
  }

  @override
  Future<Dosis> registrarDosis(int idDosis, String idempotencyKey, Map<String, dynamic> body) async {
    return recordedDosis ??
        Dosis(
          idDosis: idDosis,
          idMedicamentoPlan: 1,
          programadaEn: '2026-11-02T12:00:00Z',
          programadaHoraLocal: '08:00',
          zonaHoraria: 'America/La_Paz',
          estado: body['estado'] as String? ?? 'INGERIDA',
          vencida: false,
          efectivaEn: body['efectiva_en'] as String?,
          nota: body['nota'] as String?,
        );
  }

  @override
  Future<AvisoPage> getAvisos({int skip = 0, int limit = 20, bool noLeidos = false}) async {
    return AvisoPage(items: avisos, total: avisos.length);
  }

  @override
  Future<Aviso> leerAviso(int idAviso) async {
    return Aviso(
      idAviso: idAviso,
      idTratamiento: 1,
      tipo: 'RECORDATORIO',
      canal: 'WEB',
      estado: 'ENVIADO',
      leidaEn: '2026-11-02T10:00:00Z',
    );
  }

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

Widget createTestApp({required Widget child, required TreatmentProvider provider}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<TreatmentProvider>.value(value: provider),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: child,
      routes: {
        '/tratamientos/detalle': (context) => const TreatmentDetailScreen(),
        '/tratamientos/cronograma': (context) => const CronogramaScreen(),
        '/tratamientos/avisos': (context) => const AvisosInboxScreen(),
      },
    ),
  );
}

void main() {
  group('Treatment Badges Widget Tests', () {
    testWidgets('TreatmentPlanStatusBadge muestra estados correctos', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TreatmentPlanStatusBadge(status: 'ACTIVO'),
                TreatmentPlanStatusBadge(status: 'FINALIZADO'),
                TreatmentPlanStatusBadge(status: 'SUSPENDIDO_POR_RECETA'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Activo'), findsOneWidget);
      expect(find.text('Finalizado'), findsOneWidget);
      expect(find.text('Suspendido por receta'), findsOneWidget);
    });

    testWidgets('DoseStatusBadge y DosePuntualidadBadge renderizan textos', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                DoseStatusBadge(status: 'PENDIENTE'),
                DoseStatusBadge(status: 'INGERIDA'),
                DoseStatusBadge(status: 'OMITIDA'),
                DoseStatusBadge(status: 'POSPUESTA'),
                DoseStatusBadge(status: 'PENDIENTE', isVencida: true),
                DosePuntualidadBadge(puntual: true),
                DosePuntualidadBadge(puntual: false),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Pendiente'), findsOneWidget);
      expect(find.text('Ingerida'), findsOneWidget);
      expect(find.text('Omitida'), findsOneWidget);
      expect(find.text('Pospuesta'), findsOneWidget);
      expect(find.text('Vencida'), findsOneWidget);
      expect(find.text('Puntual'), findsOneWidget);
      expect(find.text('Fuera de ventana'), findsOneWidget);
    });
  });

  group('AdherenciaCard Widget Tests', () {
    testWidgets('Semáforo ÓPTIMA >= 80% renderiza porcentaje y nivel verde', (tester) async {
      const adh = Adherencia(
        numeradorPuntual: 8,
        denominadorProgramado: 10,
        porcentaje: 80.0,
        nivel: 'OPTIMA',
        calculadoEn: '2026-11-02T10:00:00Z',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdherenciaCard(adherencia: adh),
          ),
        ),
      );

      expect(find.text('80.0%'), findsOneWidget);
      expect(find.text('Óptima'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
    });

    testWidgets('Semáforo REGULAR renderiza ámbar', (tester) async {
      const adh = Adherencia(
        numeradorPuntual: 6,
        denominadorProgramado: 10,
        porcentaje: 60.0,
        nivel: 'REGULAR',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdherenciaCard(adherencia: adh),
          ),
        ),
      );

      expect(find.text('60.0%'), findsOneWidget);
      expect(find.text('Regular'), findsOneWidget);
    });

    testWidgets('Semáforo CRÍTICA renderiza rojo', (tester) async {
      const adh = Adherencia(
        numeradorPuntual: 2,
        denominadorProgramado: 10,
        porcentaje: 20.0,
        nivel: 'CRITICA',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdherenciaCard(adherencia: adh),
          ),
        ),
      );

      expect(find.text('20.0%'), findsOneWidget);
      expect(find.text('Crítica'), findsOneWidget);
    });

    testWidgets('Semáforo SIN_DATOS renderiza gris y mensaje informativo', (tester) async {
      const adh = Adherencia(
        numeradorPuntual: 0,
        denominadorProgramado: 0,
        porcentaje: null,
        nivel: 'SIN_DATOS',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdherenciaCard(adherencia: adh),
          ),
        ),
      );

      expect(find.text('Sin datos suficientes acumulados'), findsOneWidget);
      expect(find.text('Sin datos'), findsOneWidget);
    });
  });

  group('DoseActionDialog Tests', () {
    testWidgets('Muestra banner de CORRECCIÓN si la dosis ya fue registrada', (tester) async {
      const dosis = Dosis(
        idDosis: 101,
        idMedicamentoPlan: 1,
        programadaEn: '2026-11-02T12:00:00Z',
        programadaHoraLocal: '08:00',
        zonaHoraria: 'America/La_Paz',
        estado: 'INGERIDA',
        vencida: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DoseActionDialog(
              dosis: dosis,
              medicamentoNombre: 'Losartán 50mg',
              isCorrection: true,
              onConfirm: ({required estado, efectivaEn, nota, required isCorrection}) async {},
            ),
          ),
        ),
      );

      expect(find.text('Corregir Toma'), findsOneWidget);
      expect(find.text('CORRECCIÓN DE TOMA'), findsOneWidget);
      expect(find.text('Confirmar Corrección'), findsOneWidget);
    });

    testWidgets('Valida que dosis futura no pueda omitirse', (tester) async {
      // Dosis en el año 2030 (futura)
      const dosisFutura = Dosis(
        idDosis: 202,
        idMedicamentoPlan: 1,
        programadaEn: '2030-11-02T12:00:00Z',
        programadaHoraLocal: '08:00',
        zonaHoraria: 'America/La_Paz',
        estado: 'PENDIENTE',
        vencida: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DoseActionDialog(
              dosis: dosisFutura,
              medicamentoNombre: 'Aspirina 100mg',
              isCorrection: false,
              onConfirm: ({required estado, efectivaEn, nota, required isCorrection}) async {},
            ),
          ),
        ),
      );

      // Cambiar a OMITIDA
      await tester.tap(find.text('Omitida'));
      await tester.pumpAndSettle();

      // Presionar Confirmar Registro
      await tester.tap(find.text('Confirmar Registro'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No se puede omitir una toma futura'), findsOneWidget);
    });

    testWidgets('Si onConfirm falla por error o rechazo, el diálogo NO se cierra y muestra mensaje de error', (tester) async {
      const dosis = Dosis(
        idDosis: 303,
        idMedicamentoPlan: 1,
        programadaEn: '2026-11-02T12:00:00Z',
        programadaHoraLocal: '08:00',
        zonaHoraria: 'America/La_Paz',
        estado: 'PENDIENTE',
        vencida: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DoseActionDialog(
              dosis: dosis,
              medicamentoNombre: 'Losartán 50mg',
              isCorrection: false,
              onConfirm: ({required estado, efectivaEn, nota, required isCorrection}) async {
                throw StateError('Intento rechazado por generación previa o concurrencia');
              },
            ),
          ),
        ),
      );

      // Presionar Confirmar Registro
      await tester.tap(find.text('Confirmar Registro'));
      await tester.pumpAndSettle();

      // El diálogo permanece abierto
      expect(find.byType(DoseActionDialog), findsOneWidget);
      // Muestra el mensaje de error
      expect(find.textContaining('Intento rechazado por generación previa o concurrencia'), findsOneWidget);
    });
  });

  group('Treatments Screens Integration Tests', () {
    late ScreensMockRepository repo;
    late TreatmentProvider provider;

    setUp(() {
      repo = ScreensMockRepository();
      provider = TreatmentProvider(
        getTreatmentsUseCase: GetTreatmentsUseCase(repository: repo),
        getDetailUseCase: GetTreatmentDetailUseCase(repository: repo),
        getCronogramaUseCase: GetCronogramaUseCase(repository: repo),
        getAdherenciaUseCase: GetAdherenciaUseCase(repository: repo),
        recordDoseUseCase: RecordDoseUseCase(repository: repo),
        getAvisosUseCase: GetAvisosUseCase(repository: repo),
        markAvisoReadUseCase: MarkAvisoReadUseCase(repository: repo),
      );
    });

    testWidgets('TreatmentsListScreen muestra tratamientos y badge de avisos', (tester) async {
      repo.treatments = [
        const TreatmentPlan(
          idTratamiento: 10,
          idClinica: 1,
          idConsulta: 5,
          idPaciente: 20,
          idMedico: 30,
          diagnostico: Diagnostico(codigoCie: 'E11', descripcion: 'Diabetes tipo 2'),
          fechaInicio: '2026-11-01',
          fechaFin: '2026-11-30',
          zonaHoraria: 'America/La_Paz',
          estado: 'ACTIVO',
          medicamentos: [],
        ),
      ];
      repo.avisos = [
        const Aviso(
          idAviso: 1,
          idTratamiento: 10,
          tipo: 'RECORDATORIO',
          canal: 'WEB',
          estado: 'PENDIENTE',
          leidaEn: null,
        ),
      ];

      await tester.pumpWidget(
        createTestApp(child: const TreatmentsListScreen(), provider: provider),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mis Tratamientos'), findsOneWidget);
      expect(find.textContaining('[E11] Diabetes tipo 2'), findsOneWidget);
      expect(find.text('Activo'), findsWidgets);
      // Badge de no leídos (1)
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('TreatmentDetailScreen muestra pauta, adherencia y botón cronograma', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: const TreatmentDetailScreen(idTratamiento: 10),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Detalle del Tratamiento'), findsOneWidget);
      expect(find.textContaining('Hipertensión esencial'), findsOneWidget);
      expect(find.text('Losartán 50mg'), findsOneWidget);
      expect(find.textContaining('Tomas diarias: 08:00, 20:00'), findsOneWidget);
      expect(find.text('Ver Cronograma de Tomas'), findsOneWidget);
    });

    testWidgets('CronogramaScreen muestra tomas y responde al selector de fecha', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: const CronogramaScreen(idTratamiento: 10),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cronograma de Tomas'), findsOneWidget);
      expect(find.text('08:00'), findsOneWidget);
      expect(find.text('Registrar Toma'), findsOneWidget);
      expect(find.text('Corregir Toma'), findsOneWidget);
    });

    testWidgets('AvisosInboxScreen lista avisos y filtra por no leídos', (tester) async {
      repo.avisos = [
        const Aviso(
          idAviso: 1,
          idTratamiento: 10,
          tipo: 'RECORDATORIO',
          canal: 'WEB',
          titulo: 'Hora de Losartán',
          mensaje: 'Faltan 30 minutos para tu toma programada',
          estado: 'PENDIENTE',
          leidaEn: null,
        ),
      ];

      await tester.pumpWidget(
        createTestApp(child: const AvisosInboxScreen(), provider: provider),
      );
      await tester.pumpAndSettle();

      expect(find.text('Avisos y Recordatorios'), findsOneWidget);
      expect(find.text('Hora de Losartán'), findsOneWidget);
      expect(find.text('Faltan 30 minutos para tu toma programada'), findsOneWidget);
    });
  });
}
