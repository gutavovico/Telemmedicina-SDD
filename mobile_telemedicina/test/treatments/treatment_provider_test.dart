import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_telemedicina/core/network/api_client_interface.dart';
import 'package:mobile_telemedicina/core/network/api_exceptions.dart';
import 'package:mobile_telemedicina/features/treatments/data/models/dosis_model.dart';
import 'package:mobile_telemedicina/features/treatments/data/services/dose_operation_recovery_service.dart';
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

class FakeTreatmentRepository implements TreatmentRepository {
  List<TreatmentPlan> treatmentsToReturn = [];
  int totalTreatmentsToReturn = 0;
  bool shouldFailTreatments = false;

  TreatmentPlan? detailToReturn;
  bool shouldFailDetail = false;

  CronogramaDia? cronogramaToReturn;
  bool shouldFailCronograma = false;

  Adherencia? adherenciaToReturn;
  bool shouldFailAdherencia = false;

  Dosis? recordedDosisToReturn;
  bool shouldFailRecordDose = false;
  bool shouldThrow401OnRecord = false;

  List<Aviso> avisosToReturn = [];
  int totalAvisosToReturn = 0;
  bool shouldFailAvisos = false;

  Aviso? readAvisoToReturn;

  @override
  Future<TreatmentPage> getTreatments({String? estado, int skip = 0, int limit = 20}) async {
    if (shouldFailTreatments) throw NetworkException('Fallo de red');
    return TreatmentPage(
      items: treatmentsToReturn,
      total: totalTreatmentsToReturn,
      skip: skip,
      limit: limit,
    );
  }

  @override
  Future<TreatmentPlan> getTreatmentDetail(int idTratamiento) async {
    if (shouldFailDetail) throw NotFoundException('Plan no encontrado');
    return detailToReturn ??
        TreatmentPlan(
          idTratamiento: idTratamiento,
          idClinica: 1,
          idConsulta: 10,
          idPaciente: 20,
          idMedico: 30,
          fechaInicio: '2026-11-01',
          fechaFin: '2026-11-15',
          zonaHoraria: 'America/La_Paz',
          estado: 'ACTIVO',
          medicamentos: const [],
        );
  }

  @override
  Future<CronogramaDia> getCronograma(int idTratamiento, String fecha) async {
    if (shouldFailCronograma) throw NetworkException('Error de servidor');
    return cronogramaToReturn ??
        CronogramaDia(
          idTratamiento: idTratamiento,
          fecha: fecha,
          zonaHoraria: 'America/La_Paz',
          dosis: const [],
        );
  }

  @override
  Future<Adherencia> getAdherencia(int idTratamiento) async {
    if (shouldFailAdherencia) throw NetworkException('Error adherencia');
    return adherenciaToReturn ??
        const Adherencia(
          numeradorPuntual: 8,
          denominadorProgramado: 10,
          porcentaje: 80.0,
          nivel: 'OPTIMA',
        );
  }

  @override
  Future<Dosis> registrarDosis(int idDosis, String idempotencyKey, Map<String, dynamic> body) async {
    if (shouldThrow401OnRecord) throw UnauthorizedException('Sesión expirada');
    if (shouldFailRecordDose) throw ConflictException('Conflicto de registro');
    return recordedDosisToReturn ??
        Dosis(
          idDosis: idDosis,
          idMedicamentoPlan: 1,
          programadaEn: '2026-11-01T12:00:00Z',
          programadaHoraLocal: '08:00',
          zonaHoraria: 'America/La_Paz',
          estado: body['estado'] as String? ?? 'INGERIDA',
          vencida: false,
          efectivaEn: body['efectiva_en'] as String?,
          nota: body['nota'] as String?,
          puntual: true,
        );
  }

  @override
  Future<AvisoPage> getAvisos({int skip = 0, int limit = 20, bool noLeidos = false}) async {
    if (shouldFailAvisos) throw NetworkException('Error avisos');
    return AvisoPage(
      items: avisosToReturn,
      total: totalAvisosToReturn,
      skip: skip,
      limit: limit,
    );
  }

  @override
  Future<Aviso> leerAviso(int idAviso) async {
    return readAvisoToReturn ??
        Aviso(
          idAviso: idAviso,
          idTratamiento: 1,
          tipo: 'RECORDATORIO',
          canal: 'WEB',
          estado: 'ENVIADO',
          leidaEn: '2026-11-01T14:00:00Z',
        );
  }

  @override
  Future<OperacionIdempotencia> consultarIdempotencia(int idDosis, String idempotencyKey) async {
    throw UnimplementedError();
  }

  @override
  Future<void> eliminarDispositivo(int idDispositivo) async {}

  @override
  Future<OperacionIdempotencia> iniciarIntentoDosis(int idDosis, String idempotencyKey, String requestHash) async {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> registrarDispositivo(String token, String plataforma) async {
    return {'id_dispositivo': 1, 'plataforma': plataforma};
  }

  @override
  Future<OperacionIdempotencia> resolverOperacionAbandonada(int idDosis, String idempotencyKey) async {
    throw UnimplementedError();
  }
}

class FakeTreatmentApiClient implements ApiClientInterface {
  final FakeTreatmentRepository repo;
  dynamic Function(String url, {dynamic body, Map<String, String>? headers})? onPost;
  dynamic Function(String url, {Map<String, String>? headers})? onGet;

  FakeTreatmentApiClient(this.repo);

  @override
  Future<dynamic> post(
    String url, {
    dynamic body,
    bool includeAuth = true,
    Map<String, String>? headers,
  }) async {
    if (repo.shouldThrow401OnRecord) {
      throw UnauthorizedException('Sesión expirada');
    }
    if (repo.shouldFailRecordDose) {
      throw ConflictException('Conflicto de registro');
    }
    if (onPost != null) {
      return onPost!(url, body: body, headers: headers);
    }
    if (url.contains('/intentos')) {
      return {
        'estado': 'EN_CURSO',
        'confirmado': false,
        'en_curso': true,
        'id_dosis': 501,
        'idempotency_key': headers?['Idempotency-Key'] ?? 'test-key',
      };
    }
    if (url.contains('/resolver')) {
      return {
        'estado': 'RECHAZADA',
        'confirmado': false,
        'rechazado': true,
        'id_dosis': 501,
        'idempotency_key': headers?['Idempotency-Key'] ?? 'test-key',
      };
    }
    if (url.contains('/registros')) {
      final idDosis = int.tryParse(RegExp(r'/dosis/(\d+)').firstMatch(url)?.group(1) ?? '') ?? 501;
      final dosis = repo.recordedDosisToReturn != null
          ? DosisModel.fromEntity(repo.recordedDosisToReturn!).toJson()
          : {
              'id_dosis': idDosis,
              'id_medicamento_plan': 1,
              'programada_en': '2026-11-02T12:00:00Z',
              'programada_hora_local': '08:00',
              'zona_horaria': 'America/La_Paz',
              'estado': body is Map ? (body['estado'] ?? 'INGERIDA') : 'INGERIDA',
              'vencida': false,
              'efectiva_en': body is Map ? body['efectiva_en'] : null,
              'nota': body is Map ? body['nota'] : null,
              'puntual': true,
            };
      return {
        'estado': 'CONFIRMADA',
        'confirmado': true,
        'id_dosis': idDosis,
        'idempotency_key': headers?['Idempotency-Key'] ?? 'test-key',
        'dosis': dosis,
      };
    }
    return {'estado': 'CONFIRMADA', 'confirmado': true};
  }

  @override
  Future<dynamic> get(
    String url, {
    bool includeAuth = true,
    String? authToken,
    Map<String, String>? headers,
  }) async {
    if (onGet != null) {
      return onGet!(url, headers: headers);
    }
    return {
      'estado': 'CONFIRMADA',
      'confirmado': true,
      'id_dosis': 501,
      'idempotency_key': 'test-key',
    };
  }

  @override
  Future<dynamic> patch(String url, {dynamic body, bool includeAuth = true, Map<String, String>? headers}) async => {};

  @override
  Future<dynamic> delete(String url, {bool includeAuth = true, Map<String, String>? headers}) async => {};

  @override
  Future<Uint8List> downloadBytes(String url, {bool includeAuth = true}) async => Uint8List(0);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TreatmentProvider CU17 Tests', () {
    late FakeTreatmentRepository fakeRepo;
    late FakeTreatmentApiClient fakeApiClient;
    late DoseOperationRecoveryService recoveryService;
    late TreatmentProvider provider;
    bool sessionExpiredCalled = false;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      fakeRepo = FakeTreatmentRepository();
      fakeApiClient = FakeTreatmentApiClient(fakeRepo);
      recoveryService = DoseOperationRecoveryService(
        apiClient: fakeApiClient,
        prefs: prefs,
      );
      sessionExpiredCalled = false;
      provider = TreatmentProvider(
        getTreatmentsUseCase: GetTreatmentsUseCase(repository: fakeRepo),
        getDetailUseCase: GetTreatmentDetailUseCase(repository: fakeRepo),
        getCronogramaUseCase: GetCronogramaUseCase(repository: fakeRepo),
        getAdherenciaUseCase: GetAdherenciaUseCase(repository: fakeRepo),
        recordDoseUseCase: RecordDoseUseCase(repository: fakeRepo),
        getAvisosUseCase: GetAvisosUseCase(repository: fakeRepo),
        markAvisoReadUseCase: MarkAvisoReadUseCase(repository: fakeRepo),
        recoveryService: recoveryService,
        onSessionExpired: () async {
          sessionExpiredCalled = true;
        },
      );
      provider.syncAuthSession(isAuthenticated: true, userId: 1, clinicId: 5);
    });

    test('Estado inicial del TreatmentProvider', () {
      expect(provider.listStatus, TreatmentListStatus.initial);
      expect(provider.detailStatus, TreatmentDetailStatus.initial);
      expect(provider.cronogramaStatus, CronogramaStatus.initial);
      expect(provider.adherenciaStatus, AdherenciaStatus.initial);
      expect(provider.recordDoseStatus, RecordDoseStatus.idle);
      expect(provider.avisosStatus, AvisosStatus.initial);
      expect(provider.treatments, isEmpty);
      expect(provider.unreadAvisosCount, 0);
      expect(provider.lockedDoses, isEmpty);
      expect(provider.currentUserId, 1);
      expect(provider.currentClinicId, 5);
    });

    test('loadTreatments maneja estados loaded y empty correctamente', () async {
      fakeRepo.treatmentsToReturn = [
        const TreatmentPlan(
          idTratamiento: 101,
          idClinica: 1,
          idConsulta: 5,
          idPaciente: 20,
          idMedico: 30,
          fechaInicio: '2026-11-01',
          fechaFin: '2026-11-10',
          zonaHoraria: 'America/La_Paz',
          estado: 'ACTIVO',
          medicamentos: [],
        ),
      ];
      fakeRepo.totalTreatmentsToReturn = 1;

      await provider.loadTreatments();

      expect(provider.listStatus, TreatmentListStatus.loaded);
      expect(provider.treatments.length, 1);
      expect(provider.treatments.first.idTratamiento, 101);

      // Empty case
      fakeRepo.treatmentsToReturn = [];
      fakeRepo.totalTreatmentsToReturn = 0;
      await provider.loadTreatments();
      expect(provider.listStatus, TreatmentListStatus.empty);
      expect(provider.treatments, isEmpty);
    });

    test('loadTreatments maneja errores atómicamente', () async {
      fakeRepo.shouldFailTreatments = true;
      await provider.loadTreatments();

      expect(provider.listStatus, TreatmentListStatus.error);
      expect(provider.listError, isNotNull);
    });

    test('loadTreatmentDetail carga detalle y adherencia vinculada', () async {
      fakeRepo.detailToReturn = const TreatmentPlan(
        idTratamiento: 202,
        idClinica: 1,
        idConsulta: 5,
        idPaciente: 20,
        idMedico: 30,
        fechaInicio: '2026-11-01',
        fechaFin: '2026-11-10',
        zonaHoraria: 'America/La_Paz',
        estado: 'ACTIVO',
        medicamentos: [],
        adherencia: Adherencia(
          numeradorPuntual: 5,
          denominadorProgramado: 5,
          porcentaje: 100.0,
          nivel: 'OPTIMA',
        ),
      );

      await provider.loadTreatmentDetail(202);

      expect(provider.detailStatus, TreatmentDetailStatus.loaded);
      expect(provider.selectedTreatment?.idTratamiento, 202);
      expect(provider.adherencia?.nivel, 'OPTIMA');
      expect(provider.adherencia?.porcentaje, 100.0);
    });

    test('loadCronograma y changeCronogramaDate actualizan día y dosis', () async {
      fakeRepo.cronogramaToReturn = const CronogramaDia(
        idTratamiento: 202,
        fecha: '2026-11-02',
        zonaHoraria: 'America/La_Paz',
        dosis: [
          Dosis(
            idDosis: 501,
            idMedicamentoPlan: 1,
            programadaEn: '2026-11-02T12:00:00Z',
            programadaHoraLocal: '08:00',
            zonaHoraria: 'America/La_Paz',
            estado: 'PENDIENTE',
            vencida: false,
          ),
        ],
      );

      await provider.loadCronograma(202, DateTime(2026, 11, 2));

      expect(provider.cronogramaStatus, CronogramaStatus.loaded);
      expect(provider.cronograma?.dosis.length, 1);
      expect(provider.cronograma?.dosis.first.idDosis, 501);

      // Cambiar fecha
      final newDate = DateTime(2026, 11, 3);
      await provider.changeCronogramaDate(newDate);
      expect(provider.selectedDate.day, 3);
    });

    test('recordDose bloquea dosis mientras se procesa y actualiza estado en memoria', () async {
      fakeRepo.cronogramaToReturn = const CronogramaDia(
        idTratamiento: 202,
        fecha: '2026-11-02',
        zonaHoraria: 'America/La_Paz',
        dosis: [
          Dosis(
            idDosis: 501,
            idMedicamentoPlan: 1,
            programadaEn: '2026-11-02T12:00:00Z',
            programadaHoraLocal: '08:00',
            zonaHoraria: 'America/La_Paz',
            estado: 'PENDIENTE',
            vencida: false,
          ),
        ],
      );
      await provider.loadCronograma(202, DateTime(2026, 11, 2));

      fakeRepo.recordedDosisToReturn = const Dosis(
        idDosis: 501,
        idMedicamentoPlan: 1,
        programadaEn: '2026-11-02T12:00:00Z',
        programadaHoraLocal: '08:00',
        zonaHoraria: 'America/La_Paz',
        estado: 'INGERIDA',
        vencida: false,
        efectivaEn: '2026-11-02T12:05:00Z',
        puntual: true,
      );

      final result = await provider.recordDose(
        idDosis: 501,
        estado: 'INGERIDA',
        efectivaEn: DateTime(2026, 11, 2, 8, 5),
        nota: 'Sin efectos secundarios',
      );

      expect(result.estado, 'INGERIDA');
      expect(provider.recordDoseStatus, RecordDoseStatus.success);
      expect(provider.lockedDoses.contains(501), isFalse);
      expect(provider.cronograma?.dosis.first.estado, 'INGERIDA');
    });

    test('recordDose rechaza ejecución si la dosis ya está bloqueada', () async {
      // Bloquear dosis directamente en provider y recovery
      provider.recordDose(
        idDosis: 501,
        estado: 'INGERIDA',
      );

      expect(
        () => provider.recordDose(idDosis: 501, estado: 'OMITIDA'),
        throwsA(isA<ConflictException>()),
      );
    });

    test('loadAvisos calcula unreadAvisosCount y markAvisoAsRead lo actualiza', () async {
      fakeRepo.avisosToReturn = [
        const Aviso(
          idAviso: 1,
          idTratamiento: 101,
          tipo: 'RECORDATORIO',
          canal: 'WEB',
          estado: 'PENDIENTE',
          leidaEn: null,
        ),
        const Aviso(
          idAviso: 2,
          idTratamiento: 101,
          tipo: 'OMISION',
          canal: 'WEB',
          estado: 'ENVIADO',
          leidaEn: '2026-11-01T10:00:00Z',
        ),
      ];
      fakeRepo.totalAvisosToReturn = 2;

      await provider.loadAvisos();

      expect(provider.avisosStatus, AvisosStatus.loaded);
      expect(provider.avisos.length, 2);
      expect(provider.unreadAvisosCount, 1);

      // Marcar como leído
      fakeRepo.readAvisoToReturn = const Aviso(
        idAviso: 1,
        idTratamiento: 101,
        tipo: 'RECORDATORIO',
        canal: 'WEB',
        estado: 'ENVIADO',
        leidaEn: '2026-11-01T12:00:00Z',
      );
      await provider.markAvisoAsRead(1);

      expect(provider.unreadAvisosCount, 0);
      expect(provider.avisos.first.estaLeido, isTrue);
    });

    test('syncAuthSession reinicia el estado ante logout', () {
      fakeRepo.treatmentsToReturn = [
        const TreatmentPlan(
          idTratamiento: 101,
          idClinica: 1,
          idConsulta: 5,
          idPaciente: 20,
          idMedico: 30,
          fechaInicio: '2026-11-01',
          fechaFin: '2026-11-10',
          zonaHoraria: 'America/La_Paz',
          estado: 'ACTIVO',
          medicamentos: [],
        ),
      ];
      provider.syncAuthSession(isAuthenticated: true, userId: 1, clinicId: 5);
      provider.loadTreatments();

      // Logout
      provider.syncAuthSession(isAuthenticated: false);

      expect(provider.treatments, isEmpty);
      expect(provider.selectedTreatment, isNull);
      expect(provider.cronograma, isNull);
      expect(provider.adherencia, isNull);
      expect(provider.avisos, isEmpty);
      expect(provider.listStatus, TreatmentListStatus.initial);
      expect(provider.currentUserId, isNull);
    });

    test('syncAuthSession con cambio de cuenta invalida consultas y llama a onSessionLogout', () {
      provider.syncAuthSession(isAuthenticated: true, userId: 1, clinicId: 5);
      provider.syncAuthSession(isAuthenticated: true, userId: 2, clinicId: 10);

      expect(provider.currentUserId, 2);
      expect(provider.currentClinicId, 10);
      expect(provider.treatments, isEmpty);
      expect(provider.listStatus, TreatmentListStatus.initial);
    });

    test('Error 401 en llamada dispara onSessionExpired', () async {
      provider.syncAuthSession(isAuthenticated: true, userId: 1, clinicId: 5);
      fakeRepo.shouldThrow401OnRecord = true;

      try {
        await provider.recordDose(idDosis: 999, estado: 'INGERIDA');
      } catch (_) {}

      expect(sessionExpiredCalled, isTrue);
    });

    test('Timeout en recordDose conserva el bloqueo en _lockedDoses', () async {
      fakeApiClient.onPost = (url, {body, headers}) {
        if (url.contains('/intentos')) {
          return {
            'estado': 'EN_CURSO',
            'confirmado': false,
            'en_curso': true,
            'id_dosis': 888,
          };
        }
        throw TimeoutException('Timeout de red simulado');
      };

      await expectLater(
        provider.recordDose(idDosis: 888, estado: 'INGERIDA'),
        throwsA(isA<TimeoutException>()),
      );

      expect(provider.isDoseLocked(888), isTrue);
      expect(provider.lockedDoses.contains(888), isTrue);
    });

    test('resolveAbandonedDose resuelve operacion y desbloquea dosis', () async {
      // Bloquear dosis y simular marcador
      await recoveryService.saveMarker(DoseRecoveryMarker(
        userId: 1,
        clinicId: 5,
        idDosis: 777,
        idempotencyKey: 'key-777',
        timestamp: DateTime.now().toUtc().toIso8601String(),
      ));
      await provider.loadPendingMarkers();
      expect(provider.isDoseLocked(777), isTrue);

      final res = await provider.resolveAbandonedDose(
        idDosis: 777,
        idempotencyKey: 'key-777',
      );

      expect(res.isRejected, isTrue);
      expect(provider.isDoseLocked(777), isFalse);
    });

    test('Sin identidad autenticada completa, loadPendingMarkers retorna lista vacía y no carga marcadores', () async {
      // Guardar marcador perteneciente a un usuario en almacenamiento local
      await recoveryService.saveMarker(const DoseRecoveryMarker(
        userId: 99,
        clinicId: 88,
        idDosis: 999,
        idempotencyKey: 'key-99',
        timestamp: '2026-11-01T12:00:00Z',
      ));

      // Provider sin usuario o clínica autenticados
      provider.syncAuthSession(isAuthenticated: false);
      expect(provider.currentUserId, isNull);
      expect(provider.currentClinicId, isNull);

      final markers = await provider.loadPendingMarkers();
      expect(markers, isEmpty);
      expect(provider.pendingMarkers, isEmpty);
      expect(provider.isDoseLocked(999), isFalse);
    });

    test('Sin identidad autenticada completa, operaciones críticas lanzan UnauthorizedException', () async {
      provider.syncAuthSession(isAuthenticated: false);

      expect(
        () => provider.recordDose(idDosis: 10, estado: 'INGERIDA'),
        throwsA(isA<UnauthorizedException>()),
      );

      expect(
        () => provider.checkPendingMarkersAndReconcile(),
        throwsA(isA<UnauthorizedException>()),
      );

      expect(
        () => provider.resolveAbandonedDose(idDosis: 10, idempotencyKey: 'k'),
        throwsA(isA<UnauthorizedException>()),
      );

      expect(
        () => provider.retryDoseWithPendingBody(idDosis: 10, idempotencyKey: 'k'),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('recordDose PROHÍBE fabricar dosis cuando backend devuelve dosis nula', () async {
      fakeApiClient.onPost = (url, {body, headers}) {
        if (url.contains('/intentos')) {
          // Intento dice confirmado (ej. idempotencia repetida previa) pero sin objeto dosis
          return {
            'estado': 'CONFIRMADA',
            'confirmado': true,
            'id_dosis': 501,
            'dosis': null,
          };
        }
        return {'estado': 'CONFIRMADA', 'confirmado': true};
      };

      await expectLater(
        provider.recordDose(idDosis: 501, estado: 'INGERIDA'),
        throwsA(isA<ConflictException>().having(
          (e) => e.message,
          'message',
          contains('no confirmada o de resultado incierto'),
        )),
      );

      expect(provider.recordDoseStatus, RecordDoseStatus.error);
    });

    test('recordDose maneja rechazo del backend, arroja ConflictException y desbloquea dosis', () async {
      fakeApiClient.onPost = (url, {body, headers}) {
        if (url.contains('/intentos')) {
          return {
            'estado': 'RECHAZADA',
            'confirmado': false,
            'rechazado': true,
            'en_curso': false,
            'id_dosis': 501,
            'mensaje': 'Toma fuera de ventana horaria permitida',
          };
        }
        return {'estado': 'RECHAZADA', 'confirmado': false, 'rechazado': true};
      };

      await expectLater(
        provider.recordDose(idDosis: 501, estado: 'INGERIDA'),
        throwsA(isA<ConflictException>().having(
          (e) => e.message,
          'message',
          contains('Toma fuera de ventana horaria permitida'),
        )),
      );

      expect(provider.recordDoseStatus, RecordDoseStatus.error);
      expect(provider.isDoseLocked(501), isFalse);
    });
  });
}
