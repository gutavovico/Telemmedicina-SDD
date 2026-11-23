import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_telemedicina/features/treatments/domain/entities/treatment_entities.dart';
import 'package:mobile_telemedicina/features/treatments/domain/repositories/treatment_repository.dart';
import 'package:mobile_telemedicina/features/treatments/domain/usecases/get_adherencia_usecase.dart';
import 'package:mobile_telemedicina/features/treatments/domain/usecases/get_avisos_usecase.dart';
import 'package:mobile_telemedicina/features/treatments/domain/usecases/get_cronograma_usecase.dart';
import 'package:mobile_telemedicina/features/treatments/domain/usecases/get_treatment_detail_usecase.dart';
import 'package:mobile_telemedicina/features/treatments/domain/usecases/get_treatments_usecase.dart';
import 'package:mobile_telemedicina/features/treatments/domain/usecases/mark_aviso_read_usecase.dart';
import 'package:mobile_telemedicina/features/treatments/domain/usecases/record_dose_usecase.dart';

class MockTreatmentRepository implements TreatmentRepository {
  @override
  Future<TreatmentPage> getTreatments({
    String? estado,
    int skip = 0,
    int limit = 20,
  }) async {
    return const TreatmentPage(items: [], total: 0);
  }

  @override
  Future<TreatmentPlan> getTreatmentDetail(int idTratamiento) async {
    return TreatmentPlan(
      idTratamiento: idTratamiento,
      idClinica: 1,
      idConsulta: 1,
      idPaciente: 1,
      idMedico: 1,
      fechaInicio: '2026-11-01',
      fechaFin: '2026-11-15',
      zonaHoraria: 'America/La_Paz',
      estado: 'ACTIVO',
      medicamentos: [],
    );
  }

  @override
  Future<CronogramaDia> getCronograma(int idTratamiento, String fecha) async {
    return CronogramaDia(
      idTratamiento: idTratamiento,
      fecha: fecha,
      zonaHoraria: 'America/La_Paz',
      dosis: [],
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
  Future<OperacionIdempotencia> iniciarIntentoDosis(
    int idDosis,
    String idempotencyKey,
    String requestHash,
  ) async {
    return OperacionIdempotencia(
      idDosis: idDosis,
      idempotencyKey: idempotencyKey,
      estado: 'EN_CURSO',
      confirmado: false,
      enCurso: true,
      rechazado: false,
    );
  }

  @override
  Future<Dosis> registrarDosis(
    int idDosis,
    String idempotencyKey,
    Map<String, dynamic> body,
  ) async {
    return Dosis(
      idDosis: idDosis,
      idMedicamentoPlan: 1,
      programadaEn: '2026-11-01T12:00:00Z',
      programadaHoraLocal: '08:00',
      zonaHoraria: 'America/La_Paz',
      estado: body['estado'] as String,
      vencida: false,
      efectivaEn: body['efectiva_en'] as String?,
      nota: body['nota'] as String?,
    );
  }

  @override
  Future<OperacionIdempotencia> consultarIdempotencia(
    int idDosis,
    String idempotencyKey,
  ) async {
    return OperacionIdempotencia(
      idDosis: idDosis,
      idempotencyKey: idempotencyKey,
      estado: 'CONFIRMADA',
      confirmado: true,
      enCurso: false,
      rechazado: false,
    );
  }

  @override
  Future<OperacionIdempotencia> resolverOperacionAbandonada(
    int idDosis,
    String idempotencyKey,
  ) async {
    return OperacionIdempotencia(
      idDosis: idDosis,
      idempotencyKey: idempotencyKey,
      estado: 'RECHAZADA',
      confirmado: false,
      enCurso: false,
      rechazado: true,
    );
  }

  @override
  Future<AvisoPage> getAvisos({
    int skip = 0,
    int limit = 20,
    bool noLeidos = false,
  }) async {
    return const AvisoPage(items: [], total: 0);
  }

  @override
  Future<Aviso> leerAviso(int idAviso) async {
    return Aviso(
      idAviso: idAviso,
      idTratamiento: 1,
      tipo: 'RECORDATORIO',
      canal: 'WEB',
      estado: 'ENVIADO',
      leidaEn: '2026-11-01T10:00:00Z',
    );
  }

  @override
  Future<Map<String, dynamic>> registrarDispositivo(
    String token,
    String plataforma,
  ) async =>
      {'id_dispositivo': 1};

  @override
  Future<void> eliminarDispositivo(int idDispositivo) async {}
}

void main() {
  late MockTreatmentRepository repository;

  setUp(() {
    repository = MockTreatmentRepository();
  });

  group('Treatment Use Cases (CU17)', () {
    test('GetTreatmentsUseCase delega al repositorio', () async {
      final useCase = GetTreatmentsUseCase(repository: repository);
      final result = await useCase();
      expect(result.items, isEmpty);
    });

    test('GetTreatmentDetailUseCase devuelve el plan', () async {
      final useCase = GetTreatmentDetailUseCase(repository: repository);
      final result = await useCase(12);
      expect(result.idTratamiento, equals(12));
    });

    test('GetCronogramaUseCase consulta fecha específica', () async {
      final useCase = GetCronogramaUseCase(repository: repository);
      final result = await useCase(12, '2026-11-01');
      expect(result.fecha, equals('2026-11-01'));
    });

    test('GetAdherenciaUseCase consulta métrica acumulada', () async {
      final useCase = GetAdherenciaUseCase(repository: repository);
      final result = await useCase(12);
      expect(result.esOptima, isTrue);
    });

    test('RecordDoseUseCase registra toma e interactúa con idempotencia', () async {
      final useCase = RecordDoseUseCase(repository: repository);

      final dosis = await useCase(
        idDosis: 50,
        idempotencyKey: 'key-1',
        estado: 'INGERIDA',
        efectivaEn: '2026-11-01T12:00:00Z',
        nota: 'Sin problemas',
      );
      expect(dosis.idDosis, equals(50));
      expect(dosis.esIngerida, isTrue);

      final attempt = await useCase.startAttempt(
        idDosis: 50,
        idempotencyKey: 'key-1',
        estado: 'INGERIDA',
        efectivaEn: '2026-11-01T12:00:00Z',
        nota: 'Sin problemas',
      );
      expect(attempt.enCurso, isTrue);

      final status = await useCase.checkIdempotency(
        idDosis: 50,
        idempotencyKey: 'key-1',
      );
      expect(status.confirmado, isTrue);

      final resolved = await useCase.resolveAbandoned(
        idDosis: 50,
        idempotencyKey: 'key-1',
      );
      expect(resolved.rechazado, isTrue);
    });

    test('GetAvisosUseCase y MarkAvisoReadUseCase', () async {
      final getAvisos = GetAvisosUseCase(repository: repository);
      final avisos = await getAvisos();
      expect(avisos.items, isEmpty);

      final markRead = MarkAvisoReadUseCase(repository: repository);
      final read = await markRead(10);
      expect(read.estaLeido, isTrue);
    });
  });
}
