import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_telemedicina/core/network/api_exceptions.dart';
import 'package:mobile_telemedicina/features/ai_assistant/domain/entities/asistencia_tratamiento.dart';
import 'package:mobile_telemedicina/features/ai_assistant/domain/repositories/asistencia_repository.dart';
import 'package:mobile_telemedicina/features/ai_assistant/presentation/providers/asistencia_provider.dart';

/// Fake repository para simular respuestas y errores controlados en pruebas del provider.
class FakeAsistenciaRepository implements AsistenciaRepository {
  EvaluacionTratamiento? evaluacionToReturn;
  HistorialEvaluacion? historialToReturn;
  Exception? exceptionToThrow;
  int evaluateCallCount = 0;
  int historyCallCount = 0;
  int detailCallCount = 0;

  @override
  Future<EvaluacionTratamiento> evaluarTratamiento({bool forzarRecalculo = false}) async {
    evaluateCallCount++;
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return evaluacionToReturn ??
        EvaluacionTratamiento(
          idEvaluacion: 105,
          idPaciente: 32,
          fechaEvaluacion: DateTime.now(),
          estadoEvaluacion: 'COMPLETADA',
          nivelRiesgoGlobal: 'ALTO',
          totalMedicamentosAnalizados: 2,
          totalAlertasDetectadas: 1,
          resumenEjecutivo: 'Resumen',
          avisoLegal: 'Aviso',
          medicamentosAnalizados: const [],
          alertas: const [],
          recomendaciones: const [],
        );
  }

  @override
  Future<HistorialEvaluacion> getHistorial({int page = 1, int limit = 10}) async {
    historyCallCount++;
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return historialToReturn ??
        HistorialEvaluacion(
          items: [
            EvaluacionResumen(
              idEvaluacion: 105,
              idPaciente: 32,
              fechaEvaluacion: DateTime.now(),
              estadoEvaluacion: 'COMPLETADA',
              nivelRiesgoGlobal: 'ALTO',
              totalMedicamentosAnalizados: 2,
              totalAlertasDetectadas: 1,
            ),
          ],
          total: 1,
          page: page,
          limit: limit,
          totalPaginas: 1,
        );
  }

  @override
  Future<EvaluacionTratamiento> getEvaluacionById(int idEvaluacion) async {
    detailCallCount++;
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return evaluacionToReturn ??
        EvaluacionTratamiento(
          idEvaluacion: idEvaluacion,
          idPaciente: 32,
          fechaEvaluacion: DateTime.now(),
          estadoEvaluacion: 'COMPLETADA',
          nivelRiesgoGlobal: 'ALTO',
          totalMedicamentosAnalizados: 2,
          totalAlertasDetectadas: 1,
          avisoLegal: 'Aviso',
          medicamentosAnalizados: const [],
          alertas: const [],
          recomendaciones: const [],
        );
  }
}

void main() {
  group('AsistenciaProvider - Pruebas Unitarias de Gestión de Estado', () {
    late FakeAsistenciaRepository fakeRepo;
    late AsistenciaProvider provider;

    setUp(() {
      fakeRepo = FakeAsistenciaRepository();
      provider = AsistenciaProvider(repository: fakeRepo);
    });

    test('Estado inicial está limpio', () {
      expect(provider.status, equals(AsistenciaStatus.initial));
      expect(provider.evaluacionActual, isNull);
      expect(provider.errorMessage, isNull);
      expect(provider.isLoading, isFalse);
      expect(provider.historyStatus, equals(AsistenciaHistoryStatus.initial));
      expect(provider.historialItems, isEmpty);
    });

    test('solicitarEvaluacion éxito: transiciona a loading y luego success', () async {
      await provider.solicitarEvaluacion();

      expect(provider.status, equals(AsistenciaStatus.success));
      expect(provider.evaluacionActual, isNotNull);
      expect(provider.evaluacionActual!.idEvaluacion, equals(105));
      expect(fakeRepo.evaluateCallCount, equals(1));
    });

    test('solicitarEvaluacion ante 429: establece RATE_LIMIT_EXCEEDED y retryAfter', () async {
      fakeRepo.exceptionToThrow = ApiException(
        message: 'Límite de 10 evaluaciones por hora superado',
        statusCode: 429,
        details: {'detail': 'Límite de 10 evaluaciones por hora superado', 'code': 'RATE_LIMIT_EXCEEDED'},
      );

      await provider.solicitarEvaluacion();

      expect(provider.status, equals(AsistenciaStatus.error));
      expect(provider.isRateLimited, isTrue);
      expect(provider.errorCode, equals('RATE_LIMIT_EXCEEDED'));
      expect(provider.retryAfterSeconds, equals(3600));
    });

    test('solicitarEvaluacion conserva la última evaluación visible ante error posterior', () async {
      // 1. Primera llamada exitosa
      await provider.solicitarEvaluacion();
      expect(provider.evaluacionActual, isNotNull);

      // 2. Segunda llamada falla por red
      fakeRepo.exceptionToThrow = NetworkException();
      await provider.solicitarEvaluacion();

      expect(provider.status, equals(AsistenciaStatus.error));
      expect(provider.evaluacionActual, isNotNull); // Sigue visible el resultado anterior
      expect(provider.evaluacionActual!.idEvaluacion, equals(105));
    });

    test('Evita doble envío cuando una evaluación ya está en curso', () async {
      fakeRepo.evaluacionToReturn = EvaluacionTratamiento(
        idEvaluacion: 200,
        idPaciente: 32,
        fechaEvaluacion: DateTime.now(),
        estadoEvaluacion: 'COMPLETADA',
        nivelRiesgoGlobal: 'ALTO',
        totalMedicamentosAnalizados: 2,
        totalAlertasDetectadas: 1,
        avisoLegal: 'Aviso',
        medicamentosAnalizados: const [],
        alertas: const [],
        recomendaciones: const [],
      );

      // Disparar dos solicitudes concurrentes
      final future1 = provider.solicitarEvaluacion();
      final future2 = provider.solicitarEvaluacion();

      await Future.wait([future1, future2]);

      expect(fakeRepo.evaluateCallCount, equals(1)); // Solo se ejecutó una
    });

    test('cargarHistorial transiciona a empty si no hay registros', () async {
      fakeRepo.historialToReturn = const HistorialEvaluacion(
        items: [],
        total: 0,
        page: 1,
        limit: 10,
        totalPaginas: 0,
      );

      await provider.cargarHistorial();

      expect(provider.historyStatus, equals(AsistenciaHistoryStatus.empty));
      expect(provider.historialItems, isEmpty);
    });

    test('verDetalleEvaluacion y limpiarDetalle gestionan el estado de detalle', () async {
      await provider.verDetalleEvaluacion(105);

      expect(provider.detailStatus, equals(AsistenciaDetailStatus.loaded));
      expect(provider.selectedEvaluacion?.idEvaluacion, equals(105));

      provider.limpiarDetalle();

      expect(provider.detailStatus, equals(AsistenciaDetailStatus.initial));
      expect(provider.selectedEvaluacion, isNull);
    });
  });
}

