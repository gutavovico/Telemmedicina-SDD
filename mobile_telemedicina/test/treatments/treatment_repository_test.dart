import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_telemedicina/core/network/api_exceptions.dart';
import 'package:mobile_telemedicina/features/treatments/data/datasources/treatment_remote_datasource.dart';
import 'package:mobile_telemedicina/features/treatments/data/models/adherencia_model.dart';
import 'package:mobile_telemedicina/features/treatments/data/models/aviso_model.dart';
import 'package:mobile_telemedicina/features/treatments/data/models/cronograma_dia_model.dart';
import 'package:mobile_telemedicina/features/treatments/data/models/dosis_model.dart';
import 'package:mobile_telemedicina/features/treatments/data/models/operacion_idempotencia_model.dart';
import 'package:mobile_telemedicina/features/treatments/data/models/treatment_plan_model.dart';
import 'package:mobile_telemedicina/features/treatments/data/repositories/treatment_repository_impl.dart';

class FakeTreatmentDatasource extends TreatmentRemoteDatasource {
  Map<String, dynamic>? treatmentsResponse;
  TreatmentPlanModel? detailResponse;
  CronogramaDiaModel? cronogramaResponse;
  AdherenciaModel? adherenciaResponse;
  OperacionIdempotenciaModel? operacionResponse;
  DosisModel? dosisResponse;
  Map<String, dynamic>? avisosResponse;
  AvisoModel? avisoModelResponse;
  Map<String, dynamic>? dispositivoResponse;
  Exception? errorToThrow;

  @override
  Future<Map<String, dynamic>> getTreatments({
    String? estado,
    int skip = 0,
    int limit = 20,
  }) async {
    if (errorToThrow != null) throw errorToThrow!;
    return treatmentsResponse ?? {'items': <TreatmentPlanModel>[], 'total': 0};
  }

  @override
  Future<TreatmentPlanModel> getTreatmentDetail(int idTratamiento) async {
    if (errorToThrow != null) throw errorToThrow!;
    return detailResponse!;
  }

  @override
  Future<CronogramaDiaModel> getCronograma(
    int idTratamiento,
    String fecha,
  ) async {
    if (errorToThrow != null) throw errorToThrow!;
    return cronogramaResponse!;
  }

  @override
  Future<AdherenciaModel> getAdherencia(int idTratamiento) async {
    if (errorToThrow != null) throw errorToThrow!;
    return adherenciaResponse!;
  }

  @override
  Future<OperacionIdempotenciaModel> iniciarIntentoDosis(
    int idDosis,
    String idempotencyKey,
    String requestHash,
  ) async {
    if (errorToThrow != null) throw errorToThrow!;
    return operacionResponse!;
  }

  @override
  Future<DosisModel> registrarDosis(
    int idDosis,
    String idempotencyKey,
    Map<String, dynamic> body,
  ) async {
    if (errorToThrow != null) throw errorToThrow!;
    return dosisResponse!;
  }

  @override
  Future<OperacionIdempotenciaModel> consultarIdempotencia(
    int idDosis,
    String idempotencyKey,
  ) async {
    if (errorToThrow != null) throw errorToThrow!;
    return operacionResponse!;
  }

  @override
  Future<OperacionIdempotenciaModel> resolverOperacionAbandonada(
    int idDosis,
    String idempotencyKey,
  ) async {
    if (errorToThrow != null) throw errorToThrow!;
    return operacionResponse!;
  }

  @override
  Future<Map<String, dynamic>> getAvisos({
    int skip = 0,
    int limit = 20,
    bool noLeidos = false,
  }) async {
    if (errorToThrow != null) throw errorToThrow!;
    return avisosResponse ?? {'items': <AvisoModel>[], 'total': 0};
  }

  @override
  Future<AvisoModel> leerAviso(int idAviso) async {
    if (errorToThrow != null) throw errorToThrow!;
    return avisoModelResponse!;
  }

  @override
  Future<Map<String, dynamic>> registrarDispositivo(
    String token,
    String plataforma,
  ) async {
    if (errorToThrow != null) throw errorToThrow!;
    return dispositivoResponse ?? {'id_dispositivo': 1};
  }

  @override
  Future<void> eliminarDispositivo(int idDispositivo) async {
    if (errorToThrow != null) throw errorToThrow!;
  }
}

void main() {
  late FakeTreatmentDatasource fakeDatasource;
  late TreatmentRepositoryImpl repository;

  setUp(() {
    fakeDatasource = FakeTreatmentDatasource();
    repository = TreatmentRepositoryImpl(datasource: fakeDatasource);
  });

  group('TreatmentRepositoryImpl', () {
    test('getTreatments mapea lista de TreatmentPlanModel a entidades TreatmentPlan',
        () async {
      fakeDatasource.treatmentsResponse = {
        'items': [
          TreatmentPlanModel(
            idTratamiento: 10,
            idClinica: 1,
            idConsulta: 5,
            idPaciente: 20,
            idMedico: 3,
            fechaInicio: '2026-11-01',
            fechaFin: '2026-11-15',
            zonaHoraria: 'America/La_Paz',
            estado: 'ACTIVO',
            medicamentos: [],
          ),
        ],
        'total': 1,
      };

      final page = await repository.getTreatments(skip: 0, limit: 10);

      expect(page.items.length, equals(1));
      expect(page.total, equals(1));
      expect(page.items.first.idTratamiento, equals(10));
      expect(page.items.first.estaActivo, isTrue);
    });

    test('getTreatmentDetail mapea modelo a entidad con diagnóstico', () async {
      fakeDatasource.detailResponse = TreatmentPlanModel(
        idTratamiento: 42,
        idClinica: 1,
        idConsulta: 10,
        diagnostico: const DiagnosticoModel(
          codigoCie: 'K29',
          descripcion: 'Gastritis',
        ),
        idPaciente: 5,
        idMedico: 7,
        fechaInicio: '2026-11-01',
        fechaFin: '2026-11-15',
        zonaHoraria: 'America/La_Paz',
        estado: 'ACTIVO',
        medicamentos: [],
      );

      final plan = await repository.getTreatmentDetail(42);

      expect(plan.idTratamiento, equals(42));
      expect(plan.diagnostico?.codigoCie, equals('K29'));
    });

    test('getCronograma mapea día y dosis a entidades', () async {
      fakeDatasource.cronogramaResponse = const CronogramaDiaModel(
        idTratamiento: 42,
        fecha: '2026-11-02',
        zonaHoraria: 'America/La_Paz',
        dosis: [
          DosisModel(
            idDosis: 101,
            idMedicamentoPlan: 1,
            programadaEn: '2026-11-02T12:00:00Z',
            programadaHoraLocal: '08:00',
            zonaHoraria: 'America/La_Paz',
            estado: 'PENDIENTE',
            vencida: false,
          ),
        ],
        adherencia: null,
      );

      final cronograma = await repository.getCronograma(42, '2026-11-02');

      expect(cronograma.dosis.length, equals(1));
      expect(cronograma.dosis.first.idDosis, equals(101));
      expect(cronograma.dosis.first.esPendiente, isTrue);
    });

    test('getAdherencia mapea AdherenciaModel a entidad', () async {
      fakeDatasource.adherenciaResponse = const AdherenciaModel(
        numeradorPuntual: 8,
        denominadorProgramado: 10,
        porcentaje: 80.0,
        nivel: 'OPTIMA',
      );

      final adherencia = await repository.getAdherencia(42);

      expect(adherencia.esOptima, isTrue);
      expect(adherencia.porcentaje, equals(80.0));
    });

    test('registrarDosis mapea DosisModel a Dosis entidad', () async {
      fakeDatasource.dosisResponse = const DosisModel(
        idDosis: 501,
        idMedicamentoPlan: 1,
        programadaEn: '2026-11-01T12:00:00Z',
        programadaHoraLocal: '08:00',
        zonaHoraria: 'America/La_Paz',
        estado: 'INGERIDA',
        vencida: false,
        efectivaEn: '2026-11-01T12:05:00Z',
        puntual: true,
      );

      final dosis = await repository.registrarDosis(
        501,
        'key-idemp',
        {'estado': 'INGERIDA'},
      );

      expect(dosis.idDosis, equals(501));
      expect(dosis.esIngerida, isTrue);
      expect(dosis.esPuntual, isTrue);
    });

    test('iniciarIntentoDosis y consultarIdempotencia mapean OperacionIdempotencia',
        () async {
      fakeDatasource.operacionResponse = const OperacionIdempotenciaModel(
        idDosis: 501,
        idempotencyKey: 'key-test',
        estado: 'EN_CURSO',
        confirmado: false,
        enCurso: true,
        rechazado: false,
      );

      final opIntento = await repository.iniciarIntentoDosis(
        501,
        'key-test',
        'hash',
      );
      expect(opIntento.enCurso, isTrue);

      final opConsulta = await repository.consultarIdempotencia(
        501,
        'key-test',
      );
      expect(opConsulta.enCurso, isTrue);
    });

    test('getAvisos y leerAviso mapean AvisoPage y Aviso entidad', () async {
      fakeDatasource.avisosResponse = {
        'items': [
          const AvisoModel(
            idAviso: 1,
            idTratamiento: 42,
            tipo: 'RECORDATORIO_PREVIO',
            canal: 'WEB',
            estado: 'PENDIENTE',
          ),
        ],
        'total': 1,
      };

      final page = await repository.getAvisos();
      expect(page.items.length, equals(1));
      expect(page.items.first.idAviso, equals(1));

      fakeDatasource.avisoModelResponse = const AvisoModel(
        idAviso: 1,
        idTratamiento: 42,
        tipo: 'RECORDATORIO_PREVIO',
        canal: 'WEB',
        estado: 'ENVIADO',
        leidaEn: '2026-11-01T10:00:00Z',
      );

      final aviso = await repository.leerAviso(1);
      expect(aviso.estaLeido, isTrue);
    });

    test('Propaga excepciones directamente desde el datasource', () async {
      fakeDatasource.errorToThrow = NotFoundException('Tratamiento no encontrado');

      expect(
        () => repository.getTreatmentDetail(999),
        throwsA(isA<NotFoundException>()),
      );
    });
  });
}
