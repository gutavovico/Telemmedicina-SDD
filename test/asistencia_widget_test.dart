import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mobile_telemedicina/core/network/api_exceptions.dart';
import 'package:mobile_telemedicina/core/theme/app_theme.dart';
import 'package:mobile_telemedicina/features/ai_assistant/domain/entities/asistencia_tratamiento.dart';
import 'package:mobile_telemedicina/features/ai_assistant/domain/repositories/asistencia_repository.dart';
import 'package:mobile_telemedicina/features/ai_assistant/presentation/providers/asistencia_provider.dart';
import 'package:mobile_telemedicina/features/ai_assistant/presentation/screens/ai_assistant_screen.dart';

/// Fake repository configurable para pruebas de widget.
class MockAsistenciaRepo implements AsistenciaRepository {
  EvaluacionTratamiento? evaluacionToReturn;
  Exception? exceptionToThrow;

  @override
  Future<EvaluacionTratamiento> evaluarTratamiento({bool forzarRecalculo = false}) async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    return evaluacionToReturn!;
  }

  @override
  Future<HistorialEvaluacion> getHistorial({int page = 1, int limit = 10}) async {
    return const HistorialEvaluacion(
      items: [],
      total: 0,
      page: 1,
      limit: 10,
      totalPaginas: 0,
    );
  }

  @override
  Future<EvaluacionTratamiento> getEvaluacionById(int idEvaluacion) async {
    return evaluacionToReturn!;
  }
}

Widget createTestableWidget({required AsistenciaProvider provider}) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: ChangeNotifierProvider<AsistenciaProvider>.value(
      value: provider,
      child: const AiAssistantScreen(),
    ),
  );
}

void main() {
  group('AiAssistantScreen - Pruebas de Widgets y Escenarios Gherkin', () {
    late MockAsistenciaRepo mockRepo;
    late AsistenciaProvider provider;

    setUp(() {
      mockRepo = MockAsistenciaRepo();
      provider = AsistenciaProvider(repository: mockRepo);
    });

    testWidgets('Muestra cabecera estética con pastilla IA y botón de solicitud', (tester) async {
      await tester.pumpWidget(createTestableWidget(provider: provider));
      await tester.pumpAndSettle();

      expect(find.text('IA'), findsOneWidget);
      expect(find.text('Asistencia Inteligente'), findsOneWidget);
      expect(find.text('Solicitar evaluación asistida'), findsOneWidget);
      expect(find.textContaining('La IA nunca modifica diagnósticos'), findsOneWidget);
    });

    testWidgets('ESCENARIO 3C: Paciente hipertenso con Ibuprofeno + Aspirina muestra alerta GRAVE roja y botón de urgencias', (tester) async {
      mockRepo.evaluacionToReturn = EvaluacionTratamiento(
        idEvaluacion: 105,
        idPaciente: 32,
        fechaEvaluacion: DateTime.now(),
        estadoEvaluacion: 'COMPLETADA',
        nivelRiesgoGlobal: 'ALTO',
        totalMedicamentosAnalizados: 2,
        totalAlertasDetectadas: 1,
        resumenEjecutivo: 'Interacción detectada',
        avisoLegal: 'Aviso legal RF-25',
        medicamentosAnalizados: const [
          MedicamentoAnalizado(
            nombre: 'Ibuprofeno 400 mg',
            principioActivo: 'ibuprofeno',
            dosis: '400 mg',
            frecuencia: 'Cada 8 horas',
          ),
          MedicamentoAnalizado(
            nombre: 'Aspirina 100 mg',
            principioActivo: 'acido acetilsalicilico',
            dosis: '100 mg',
            frecuencia: 'Cada 24 horas',
          ),
        ],
        alertas: const [
          AlertaInteraccion(
            principioActivo1: 'acido acetilsalicilico',
            principioActivo2: 'ibuprofeno',
            medicamento1Nombre: 'Aspirina 100 mg',
            medicamento2Nombre: 'Ibuprofeno 400 mg',
            severidad: 'GRAVE',
            colorAlerta: 'ROJO',
            mensajeAlerta: 'Riesgo de interacción: aumento de riesgo de sangrado',
            pautaPrecaucion: 'Incrementa riesgo de hemorragia gastrointestinal.',
          ),
        ],
        recomendaciones: const [
          RecomendacionTratamiento(
            categoria: 'ESTILO_VIDA',
            titulo: 'Monitoreo tensional por hipertensión',
            detalle: 'Controle su presión al menos una vez al día.',
            origen: 'IA_GENERATIVA',
          ),
        ],
      );

      await tester.pumpWidget(createTestableWidget(provider: provider));
      await tester.pumpAndSettle();

      // Pulsar botón de evaluación
      await tester.tap(find.text('Solicitar evaluación asistida'));
      await tester.pumpAndSettle();

      // Verificar elementos de la alerta grave
      expect(find.text('SEVERIDAD GRAVE'), findsOneWidget);
      expect(find.text('Aspirina 100 mg + Ibuprofeno 400 mg'), findsOneWidget);
      expect(find.text('Riesgo de interacción: aumento de riesgo de sangrado'), findsOneWidget);
      expect(find.text('Qué hacer ante una urgencia'), findsOneWidget);

      // Al pulsar "Qué hacer ante una urgencia", muestra diálogo explicativo
      await tester.tap(find.text('Qué hacer ante una urgencia'));
      await tester.pumpAndSettle();

      expect(find.textContaining('acuda de inmediato al centro de urgencias más cercano'), findsOneWidget);
      expect(find.textContaining('Consulte con su médico tratante antes de continuar'), findsOneWidget);

      // Cerrar diálogo
      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();

      // Verificar recomendación por hipertensión
      expect(find.text('Monitoreo tensional por hipertensión'), findsOneWidget);
      expect(find.text('ALTO'), findsOneWidget);
    });

    testWidgets('ESCENARIO CRITERIO 5: Tratamiento sin interacciones muestra mensaje claro', (tester) async {
      mockRepo.evaluacionToReturn = EvaluacionTratamiento(
        idEvaluacion: 106,
        idPaciente: 45,
        fechaEvaluacion: DateTime.now(),
        estadoEvaluacion: 'COMPLETADA',
        nivelRiesgoGlobal: 'SIN_RIESGO',
        totalMedicamentosAnalizados: 1,
        totalAlertasDetectadas: 0,
        resumenEjecutivo: 'No se detectaron interacciones adversas entre sus medicamentos vigentes.',
        avisoLegal: 'Aviso legal RF-25',
        medicamentosAnalizados: const [],
        alertas: const [],
        recomendaciones: const [],
      );

      await tester.pumpWidget(createTestableWidget(provider: provider));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Solicitar evaluación asistida'));
      await tester.pumpAndSettle();

      expect(find.text('No se detectaron interacciones adversas entre sus medicamentos vigentes.'), findsOneWidget);
      expect(find.text('SIN_RIESGO'), findsOneWidget);
      expect(find.text('SEVERIDAD GRAVE'), findsNothing);
    });

    testWidgets('ESCENARIO SIN TRATAMIENTO: Muestra aviso de ausencia de recetas activas', (tester) async {
      mockRepo.evaluacionToReturn = EvaluacionTratamiento(
        idEvaluacion: null,
        idPaciente: 50,
        fechaEvaluacion: DateTime.now(),
        estadoEvaluacion: 'SIN_TRATAMIENTO_VIGENTE',
        nivelRiesgoGlobal: 'SIN_RIESGO',
        totalMedicamentosAnalizados: 0,
        totalAlertasDetectadas: 0,
        resumenEjecutivo: 'No cuenta con recetas ni medicamentos vigentes registrados en la clínica en este momento.',
        avisoLegal: 'Aviso legal RF-25',
        medicamentosAnalizados: const [],
        alertas: const [],
        recomendaciones: const [],
      );

      await tester.pumpWidget(createTestableWidget(provider: provider));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Solicitar evaluación asistida'));
      await tester.pumpAndSettle();

      expect(find.text('Sin tratamiento activo'), findsOneWidget);
      expect(find.textContaining('No cuenta con recetas ni medicamentos vigentes'), findsOneWidget);
    });

    testWidgets('ESCENARIO DEGRADADO: Muestra banner de advertencia sobre reglas clínicas base', (tester) async {
      mockRepo.evaluacionToReturn = EvaluacionTratamiento(
        idEvaluacion: 107,
        idPaciente: 32,
        fechaEvaluacion: DateTime.now(),
        estadoEvaluacion: 'DEGRADADO_REGLAS_BASE',
        nivelRiesgoGlobal: 'ALTO',
        totalMedicamentosAnalizados: 2,
        totalAlertasDetectadas: 1,
        avisoLegal: 'Aviso legal RF-25',
        medicamentosAnalizados: const [],
        alertas: const [
          AlertaInteraccion(
            principioActivo1: 'acido acetilsalicilico',
            principioActivo2: 'ibuprofeno',
            medicamento1Nombre: 'Aspirina 100 mg',
            medicamento2Nombre: 'Ibuprofeno 400 mg',
            severidad: 'GRAVE',
            colorAlerta: 'ROJO',
            mensajeAlerta: 'Riesgo de interacción',
            pautaPrecaucion: 'Precaución',
          ),
        ],
        recomendaciones: const [],
      );

      await tester.pumpWidget(createTestableWidget(provider: provider));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Solicitar evaluación asistida'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Evaluación con reglas clínicas base'), findsOneWidget);
      expect(find.text('SEVERIDAD GRAVE'), findsOneWidget);
    });

    testWidgets('ESCENARIO 429: Muestra banner explicativo de límite de evaluaciones por hora alcanzado', (tester) async {
      mockRepo.exceptionToThrow = ApiException(
        message: 'Límite de 10 evaluaciones por hora superado',
        statusCode: 429,
        details: {'detail': 'Límite de 10 evaluaciones por hora superado', 'code': 'RATE_LIMIT_EXCEEDED'},
      );

      await tester.pumpWidget(createTestableWidget(provider: provider));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Solicitar evaluación asistida'));
      await tester.pumpAndSettle();

      expect(find.text('Límite de solicitudes alcanzado (429)'), findsOneWidget);
      expect(find.textContaining('Has alcanzado el límite de 10 evaluaciones por hora'), findsOneWidget);
    });
  });
}

