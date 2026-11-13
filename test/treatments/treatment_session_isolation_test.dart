import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_telemedicina/core/network/api_client_interface.dart';
import 'package:mobile_telemedicina/core/network/api_exceptions.dart';
import 'package:mobile_telemedicina/features/treatments/data/services/dose_operation_recovery_service.dart';
import 'package:mobile_telemedicina/features/treatments/domain/entities/treatment_entities.dart';
import 'package:mobile_telemedicina/features/treatments/domain/repositories/treatment_repository.dart';
import 'package:mobile_telemedicina/features/treatments/domain/usecases/get_adherencia_usecase.dart';
import 'package:mobile_telemedicina/features/treatments/domain/usecases/get_avisos_usecase.dart';
import 'package:mobile_telemedicina/features/treatments/domain/usecases/get_cronograma_usecase.dart';
import 'package:mobile_telemedicina/features/treatments/domain/usecases/get_treatments_usecase.dart';
import 'package:mobile_telemedicina/features/treatments/presentation/providers/treatment_provider.dart';
import 'package:mobile_telemedicina/features/treatments/presentation/session/treatment_session_coordinator.dart';

class IsolationFakeApiClient implements ApiClientInterface {
  final List<String> resolvedKeys = [];
  dynamic Function(String url, {dynamic body, Map<String, String>? headers})?
  onPost;
  dynamic Function(String url, {Map<String, String>? headers})? onGet;

  @override
  Future<dynamic> post(
    String url, {
    dynamic body,
    bool includeAuth = true,
    Map<String, String>? headers,
  }) async {
    if (onPost != null) {
      return onPost!(url, body: body, headers: headers);
    }
    if (url.contains('/resolver')) {
      final key =
          headers?['Idempotency-Key'] ?? url.split('/').reversed.skip(1).first;
      resolvedKeys.add(key);
      return {
        'estado': 'RECHAZADA',
        'confirmado': false,
        'en_curso': false,
        'rechazado': true,
        'id_dosis': 900,
        'idempotency_key': key,
      };
    }
    if (url.contains('/intentos')) {
      final idDosis =
          int.tryParse(
            RegExp(r'/dosis/(\d+)').firstMatch(url)?.group(1) ?? '',
          ) ??
          501;
      return {
        'estado': 'EN_CURSO',
        'confirmado': false,
        'en_curso': true,
        'id_dosis': idDosis,
        'idempotency_key': headers?['Idempotency-Key'] ?? 'test-key',
      };
    }
    if (url.contains('/registros')) {
      final idDosis =
          int.tryParse(
            RegExp(r'/dosis/(\d+)').firstMatch(url)?.group(1) ?? '',
          ) ??
          501;
      return {
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
    return {'estado': 'CONFIRMADA', 'confirmado': true};
  }

  @override
  Future<dynamic> patch(
    String url, {
    dynamic body,
    bool includeAuth = true,
    Map<String, String>? headers,
  }) async {
    return {};
  }

  @override
  Future<dynamic> delete(
    String url, {
    bool includeAuth = true,
    Map<String, String>? headers,
  }) async {
    return {};
  }

  @override
  Future<Uint8List> downloadBytes(String url, {bool includeAuth = true}) async {
    return Uint8List(0);
  }
}

class DelayFakeTreatmentRepository implements TreatmentRepository {
  Completer<TreatmentPage>? treatmentsCompleter;
  Completer<CronogramaDia>? cronogramaCompleter;
  Completer<TreatmentPlan>? detailCompleter;
  Completer<Adherencia>? adherenciaCompleter;
  Completer<AvisoPage>? avisosCompleter;
  TreatmentPage? directTreatments;

  @override
  Future<TreatmentPage> getTreatments({
    String? estado,
    int skip = 0,
    int limit = 20,
  }) async {
    if (treatmentsCompleter != null) {
      return treatmentsCompleter!.future;
    }
    return directTreatments ?? const TreatmentPage(items: [], total: 0);
  }

  @override
  Future<CronogramaDia> getCronograma(int idTratamiento, String fecha) async {
    if (cronogramaCompleter != null) {
      return cronogramaCompleter!.future;
    }
    return CronogramaDia(
      idTratamiento: idTratamiento,
      fecha: fecha,
      zonaHoraria: 'America/La_Paz',
      dosis: const [],
    );
  }

  @override
  Future<TreatmentPlan> getTreatmentDetail(int idTratamiento) async {
    if (detailCompleter != null) {
      return detailCompleter!.future;
    }
    throw UnimplementedError();
  }

  @override
  Future<Adherencia> getAdherencia(int idTratamiento) async {
    if (adherenciaCompleter != null) {
      return adherenciaCompleter!.future;
    }
    return const Adherencia(
      numeradorPuntual: 0,
      denominadorProgramado: 0,
      porcentaje: 0,
      nivel: 'SIN_DATOS',
    );
  }

  @override
  Future<AvisoPage> getAvisos({
    int skip = 0,
    int limit = 20,
    bool noLeidos = false,
  }) async {
    if (avisosCompleter != null) {
      return avisosCompleter!.future;
    }
    return const AvisoPage(items: [], total: 0);
  }

  @override
  Future<Dosis> registrarDosis(
    int idDosis,
    String idempotencyKey,
    Map<String, dynamic> body,
  ) async => throw UnimplementedError();
  @override
  Future<Aviso> leerAviso(int idAviso) async => throw UnimplementedError();
  @override
  Future<OperacionIdempotencia> consultarIdempotencia(
    int idDosis,
    String idempotencyKey,
  ) async => throw UnimplementedError();
  @override
  Future<void> eliminarDispositivo(int idDispositivo) async {}
  @override
  Future<OperacionIdempotencia> iniciarIntentoDosis(
    int idDosis,
    String idempotencyKey,
    String requestHash,
  ) async => throw UnimplementedError();
  @override
  Future<Map<String, dynamic>> registrarDispositivo(
    String token,
    String plataforma,
  ) async => {};
  @override
  Future<OperacionIdempotencia> resolverOperacionAbandonada(
    int idDosis,
    String idempotencyKey,
  ) async => throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late IsolationFakeApiClient fakeApi;
  late DoseOperationRecoveryService recoveryService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    fakeApi = IsolationFakeApiClient();
    recoveryService = DoseOperationRecoveryService(
      apiClient: fakeApi,
      prefs: prefs,
    );
  });

  group('Aislamiento estricto por usuario y clínica', () {
    test(
      'filtra marcadores únicamente por el usuario y clínica activos',
      () async {
        // Guardar marcadores pertenecientes a diferentes usuarios y clínicas
        await recoveryService.saveMarker(
          const DoseRecoveryMarker(
            userId: 101,
            clinicId: 1,
            idDosis: 501,
            idempotencyKey: 'key-user101-clinic1',
            timestamp: '2026-11-01T10:00:00Z',
          ),
        );

        await recoveryService.saveMarker(
          const DoseRecoveryMarker(
            userId: 101,
            clinicId: 2,
            idDosis: 502,
            idempotencyKey: 'key-user101-clinic2',
            timestamp: '2026-11-01T10:05:00Z',
          ),
        );

        await recoveryService.saveMarker(
          const DoseRecoveryMarker(
            userId: 102,
            clinicId: 1,
            idDosis: 503,
            idempotencyKey: 'key-user102-clinic1',
            timestamp: '2026-11-01T10:10:00Z',
          ),
        );

        // 1. Consultar para Usuario 101 en Clínica 1
        final markers101C1 = await recoveryService.getPendingMarkers(
          userId: 101,
          clinicId: 1,
        );
        expect(markers101C1.length, equals(1));
        expect(
          markers101C1.first.idempotencyKey,
          equals('key-user101-clinic1'),
        );
        expect(markers101C1.first.idDosis, equals(501));

        // 2. Consultar para Usuario 101 en Clínica 2
        final markers101C2 = await recoveryService.getPendingMarkers(
          userId: 101,
          clinicId: 2,
        );
        expect(markers101C2.length, equals(1));
        expect(
          markers101C2.first.idempotencyKey,
          equals('key-user101-clinic2'),
        );

        // 3. Consultar para Usuario 102 en Clínica 1
        final markers102C1 = await recoveryService.getPendingMarkers(
          userId: 102,
          clinicId: 1,
        );
        expect(markers102C1.length, equals(1));
        expect(
          markers102C1.first.idempotencyKey,
          equals('key-user102-clinic1'),
        );

        // 4. Usuario ajeno o no registrado
        final markersEmpty = await recoveryService.getPendingMarkers(
          userId: 999,
          clinicId: 1,
        );
        expect(markersEmpty, isEmpty);
      },
    );

    test(
      'reconciliación de una cuenta jamás intenta resolver marcadores de otra',
      () async {
        await recoveryService.saveMarker(
          const DoseRecoveryMarker(
            userId: 101,
            clinicId: 1,
            idDosis: 501,
            idempotencyKey: 'op-user-101',
            timestamp: '2026-11-01T10:00:00Z',
          ),
        );

        await recoveryService.saveMarker(
          const DoseRecoveryMarker(
            userId: 202,
            clinicId: 1,
            idDosis: 601,
            idempotencyKey: 'op-user-202',
            timestamp: '2026-11-01T10:00:00Z',
          ),
        );

        // Inicia sesión usuario 202 y reconcilia
        final results = await recoveryService.reconciliarMarcadoresPendientes(
          userId: 202,
          clinicId: 1,
        );

        expect(results.length, equals(1));
        expect(results.first.idempotencyKey, equals('op-user-202'));
        // Verificamos que jamás se envió la clave de user 101
        expect(fakeApi.resolvedKeys, contains('op-user-202'));
        expect(fakeApi.resolvedKeys, isNot(contains('op-user-101')));

        // El marcador de 101 permanece intacto para cuando ese usuario inicie sesión
        final remainingUser101 = await recoveryService.getPendingMarkers(
          userId: 101,
          clinicId: 1,
        );
        expect(remainingUser101.length, equals(1));
        expect(remainingUser101.first.idempotencyKey, equals('op-user-101'));
      },
    );

    test(
      'TreatmentProvider aísla marcadores: Usuario B jamás ve ni procesa marcadores pendientes de Usuario A',
      () async {
        final delayRepo = DelayFakeTreatmentRepository();
        final provider = TreatmentProvider(
          getTreatmentsUseCase: GetTreatmentsUseCase(repository: delayRepo),
          getCronogramaUseCase: GetCronogramaUseCase(repository: delayRepo),
          recoveryService: recoveryService,
        );

        // Marcador pendiente creado para Usuario A (101) en Clínica 1
        await recoveryService.saveMarker(
          const DoseRecoveryMarker(
            userId: 101,
            clinicId: 1,
            idDosis: 501,
            idempotencyKey: 'marker-user-101-dose-501',
            timestamp: '2026-11-01T12:00:00Z',
          ),
        );

        // Inicia sesión Usuario B (202) en Clínica 2
        provider.syncAuthSession(
          isAuthenticated: true,
          userId: 202,
          clinicId: 2,
        );

        final markersB = await provider.loadPendingMarkers();
        expect(markersB, isEmpty);
        expect(provider.pendingMarkers, isEmpty);
        expect(provider.isDoseLocked(501), isFalse);
        expect(provider.lockedDoses.contains(501), isFalse);

        // Usuario B ejecuta reconciliación: jamás reconcilia ni resuelve el marcador de A
        final resultsB = await provider.checkPendingMarkersAndReconcile();
        expect(resultsB, isEmpty);
        expect(
          fakeApi.resolvedKeys,
          isNot(contains('marker-user-101-dose-501')),
        );

        // El marcador de A sigue intacto en almacenamiento local
        final remainingA = await recoveryService.getPendingMarkers(
          userId: 101,
          clinicId: 1,
        );
        expect(remainingA.length, equals(1));
        expect(remainingA.first.idDosis, equals(501));
      },
    );
  });

  group('Borrado de datos clínicos en memoria tras logout o cambio de usuario', () {
    test(
      'onSessionLogout elimina inmediatamente todos los cuerpos clínicos en memoria',
      () async {
        const key = 'user1-pending-clinical-body';
        final clinicalData = {
          'estado': 'INGERIDA',
          'efectiva_en': '2026-11-01T12:00:00Z',
          'nota': 'Dosis con malestar estomacal',
        };

        // Simular que User 1 inició la operación
        await recoveryService.saveMarker(
          const DoseRecoveryMarker(
            userId: 101,
            clinicId: 1,
            idDosis: 700,
            idempotencyKey: key,
            timestamp: '2026-11-01T12:00:00Z',
          ),
        );
        recoveryService.setPendingBodyForTesting(key, clinicalData);
        recoveryService.lockDose(700);

        expect(recoveryService.hasPendingBody(key), isTrue);
        expect(
          recoveryService.getPendingBody(key)?['nota'],
          equals('Dosis con malestar estomacal'),
        );
        expect(recoveryService.isDoseLocked(700), isTrue);

        // User 1 cierra sesión
        recoveryService.onSessionLogout();

        // Verificación de borrado estricto de memoria clínica
        expect(recoveryService.hasPendingBody(key), isFalse);
        expect(recoveryService.getPendingBody(key), isNull);
        expect(recoveryService.isDoseLocked(700), isFalse);

        // Solo el marcador opaco indispensable para el backend se conserva
        final markers = await recoveryService.getPendingMarkers(
          userId: 101,
          clinicId: 1,
        );
        expect(markers.length, equals(1));
        expect(markers.first.idempotencyKey, equals(key));
        // El marcador persistente NO contiene nota ni estado clínico
        expect(markers.first.toJson().containsKey('nota'), isFalse);
        expect(markers.first.toJson().containsKey('estado'), isFalse);
      },
    );

    test(
      'cambio de usuario o clínica en TreatmentSessionCoordinator borra inmediatamente cuerpos clínicos',
      () {
        final coordinator = TreatmentSessionCoordinator(
          recoveryService: recoveryService,
        );

        coordinator.onSessionStateChanged(userId: 101, clinicId: 1);

        const key = 'user101-body';
        recoveryService.setPendingBodyForTesting(key, {
          'estado': 'INGERIDA',
          'nota': 'Nota privada',
        });
        expect(recoveryService.hasPendingBody(key), isTrue);

        // Cambio a clínica 2
        coordinator.onSessionStateChanged(userId: 101, clinicId: 2);
        expect(recoveryService.hasPendingBody(key), isFalse);

        // Inyectar de nuevo
        recoveryService.setPendingBodyForTesting('user101-c2', {
          'estado': 'INGERIDA',
        });
        expect(recoveryService.hasPendingBody('user101-c2'), isTrue);

        // Cambio a otro usuario (202)
        coordinator.onSessionStateChanged(userId: 202, clinicId: 2);
        expect(recoveryService.hasPendingBody('user101-c2'), isFalse);

        coordinator.dispose();
      },
    );
  });

  group('TreatmentSessionCoordinator y respuestas tardías', () {
    test(
      'detecta cambio de usuario o logout y limpia datos clínicos en memoria',
      () {
        final coordinator = TreatmentSessionCoordinator(
          recoveryService: recoveryService,
        );

        // Sesión 1: Usuario 101
        coordinator.onSessionStateChanged(userId: 101, clinicId: 1);
        expect(coordinator.currentUserId, equals(101));
        expect(coordinator.currentClinicId, equals(1));

        // Inyectar cuerpo clínico en sesión
        const key = 'session-key-1';
        recoveryService.setPendingBodyForTesting(key, {'estado': 'INGERIDA'});
        expect(recoveryService.hasPendingBody(key), isTrue);

        // Cambio de cuenta: Usuario 202
        coordinator.onSessionStateChanged(userId: 202, clinicId: 1);
        expect(coordinator.currentUserId, equals(202));
        // Debe haber borrado la memoria clínica de sesión del usuario anterior
        expect(recoveryService.hasPendingBody(key), isFalse);

        // Cierre de sesión explícito
        recoveryService.setPendingBodyForTesting('session-key-2', {
          'estado': 'OMITIDA',
        });
        coordinator.onSessionLogout();
        expect(coordinator.currentUserId, isNull);
        expect(coordinator.currentClinicId, isNull);
        expect(recoveryService.hasPendingBody('session-key-2'), isFalse);

        coordinator.dispose();
      },
    );

    test(
      'reconcileSessionMarkers no ejecuta nada si no hay sesión activa',
      () async {
        final coordinator = TreatmentSessionCoordinator(
          recoveryService: recoveryService,
        );

        final results = await coordinator.reconcileSessionMarkers();
        expect(results, isEmpty);
        expect(fakeApi.resolvedKeys, isEmpty);

        coordinator.dispose();
      },
    );

    test(
      'reconcileSessionMarkers ejecuta reconciliación solo para usuario autenticado',
      () async {
        await recoveryService.saveMarker(
          const DoseRecoveryMarker(
            userId: 55,
            clinicId: 3,
            idDosis: 88,
            idempotencyKey: 'marker-user55',
            timestamp: '2026-11-01T12:00:00Z',
          ),
        );

        final coordinator = TreatmentSessionCoordinator(
          recoveryService: recoveryService,
        );
        coordinator.onSessionStateChanged(userId: 55, clinicId: 3);

        final results = await coordinator.reconcileSessionMarkers();
        expect(results.length, equals(1));
        expect(results.first.idempotencyKey, equals('marker-user55'));
        expect(coordinator.lastReconciliationResults.length, equals(1));

        coordinator.dispose();
      },
    );

    test(
      'cierre de sesión durante reconciliación asíncrona descarta la respuesta tardía en coordinator',
      () async {
        final completer = Completer<dynamic>();
        fakeApi.onPost = (url, {body, headers}) {
          if (url.contains('/resolver')) {
            final key =
                headers?['Idempotency-Key'] ??
                url.split('/').reversed.skip(1).first;
            fakeApi.resolvedKeys.add(key);
            return completer.future;
          }
          return {'estado': 'CONFIRMADA', 'confirmado': true};
        };

        await recoveryService.saveMarker(
          const DoseRecoveryMarker(
            userId: 101,
            clinicId: 1,
            idDosis: 777,
            idempotencyKey: 'marker-async-logout',
            timestamp: '2026-11-01T12:00:00Z',
          ),
        );

        final coordinator = TreatmentSessionCoordinator(
          recoveryService: recoveryService,
        );
        coordinator.onSessionStateChanged(userId: 101, clinicId: 1);

        final reconcileFuture = coordinator.reconcileSessionMarkers();
        expect(coordinator.isReconciling, isTrue);

        // Logout mientras la respuesta de red está pendiente
        coordinator.onSessionLogout();
        expect(coordinator.currentUserId, isNull);

        // Ahora responde el backend tardíamente
        completer.complete({
          'estado': 'CONFIRMADA',
          'confirmado': true,
          'en_curso': false,
          'rechazado': false,
          'id_dosis': 777,
          'idempotency_key': 'marker-async-logout',
        });

        final results = await reconcileFuture;
        expect(results, isEmpty);
        expect(coordinator.lastReconciliationResults, isEmpty);
        expect(coordinator.currentUserId, isNull);

        coordinator.dispose();
      },
    );

    test(
      'cambio de usuario A a usuario B durante reconciliación de A descarta la respuesta tardía de A',
      () async {
        final completer = Completer<dynamic>();
        fakeApi.onPost = (url, {body, headers}) {
          if (url.contains('/resolver')) {
            final key =
                headers?['Idempotency-Key'] ??
                url.split('/').reversed.skip(1).first;
            fakeApi.resolvedKeys.add(key);
            return completer.future;
          }
          return {'estado': 'CONFIRMADA', 'confirmado': true};
        };

        await recoveryService.saveMarker(
          const DoseRecoveryMarker(
            userId: 101,
            clinicId: 1,
            idDosis: 777,
            idempotencyKey: 'marker-user101',
            timestamp: '2026-11-01T12:00:00Z',
          ),
        );

        final coordinator = TreatmentSessionCoordinator(
          recoveryService: recoveryService,
        );
        coordinator.onSessionStateChanged(userId: 101, clinicId: 1);

        // User 101 lanza reconciliación
        final reconcileFuture = coordinator.reconcileSessionMarkers();

        // Cambio de cuenta a User 202 antes de recibir la respuesta
        coordinator.onSessionStateChanged(userId: 202, clinicId: 1);
        expect(coordinator.currentUserId, equals(202));

        // Llega la respuesta de User 101
        completer.complete({
          'estado': 'CONFIRMADA',
          'confirmado': true,
          'en_curso': false,
          'rechazado': false,
          'id_dosis': 777,
          'idempotency_key': 'marker-user101',
        });

        final results = await reconcileFuture;
        expect(results, isEmpty);
        expect(coordinator.lastReconciliationResults, isEmpty);
        expect(coordinator.currentUserId, equals(202));

        coordinator.dispose();
      },
    );

    test(
      'TreatmentSessionCoordinator propaga explícitamente userId y clinicId a TreatmentProvider en onSessionStateChanged y onSessionLogout',
      () {
        final delayRepo = DelayFakeTreatmentRepository();
        final provider = TreatmentProvider(
          getTreatmentsUseCase: GetTreatmentsUseCase(repository: delayRepo),
          recoveryService: recoveryService,
        );

        final coordinator = TreatmentSessionCoordinator(
          recoveryService: recoveryService,
          treatmentProvider: provider,
        );

        // Simular login o cambio de sesión
        coordinator.onSessionStateChanged(userId: 42, clinicId: 7);
        expect(provider.currentUserId, equals(42));
        expect(provider.currentClinicId, equals(7));

        // Simular logout
        coordinator.onSessionLogout();
        expect(provider.currentUserId, isNull);
        expect(provider.currentClinicId, isNull);

        coordinator.dispose();
      },
    );
  });

  group(
    'TreatmentProvider y aislamiento ante respuestas tardías (Generación de Sesión)',
    () {
      test(
        'cierre de sesión invalida respuesta tardía de listado de tratamientos y no puebla memoria',
        () async {
          final delayRepo = DelayFakeTreatmentRepository();
          final provider = TreatmentProvider(
            getTreatmentsUseCase: GetTreatmentsUseCase(repository: delayRepo),
            recoveryService: recoveryService,
          );

          // Iniciar sesión como Usuario A
          provider.syncAuthSession(
            isAuthenticated: true,
            userId: 101,
            clinicId: 1,
          );

          // Petición lenta controlada por Completer
          final completer = Completer<TreatmentPage>();
          delayRepo.treatmentsCompleter = completer;

          final loadFuture = provider.loadTreatments();
          expect(provider.listStatus, equals(TreatmentListStatus.loading));

          // Usuario cierra sesión antes de que responda el backend
          provider.syncAuthSession(isAuthenticated: false);
          expect(provider.treatments, isEmpty);
          expect(provider.listStatus, equals(TreatmentListStatus.initial));

          // Llega la respuesta tardía de la petición iniciada por Usuario A
          completer.complete(
            const TreatmentPage(
              items: [
                TreatmentPlan(
                  idTratamiento: 999,
                  idClinica: 1,
                  idConsulta: 10,
                  idPaciente: 101,
                  idMedico: 2,
                  diagnostico: Diagnostico(
                    codigoCie: 'I10',
                    descripcion: 'Tratamiento Privado User 101',
                  ),
                  fechaInicio: '2026-11-01',
                  fechaFin: '2026-11-20',
                  zonaHoraria: 'America/La_Paz',
                  estado: 'ACTIVO',
                  medicamentos: [],
                ),
              ],
              total: 1,
            ),
          );

          await loadFuture;

          // Verificación crítica: La respuesta tardía NUNCA debe poblar el estado
          expect(provider.treatments, isEmpty);
          expect(provider.listStatus, equals(TreatmentListStatus.initial));
        },
      );

      test(
        'cambio de usuario A a usuario B no muestra datos del usuario A cuando llega la respuesta tardía de A',
        () async {
          final delayRepo = DelayFakeTreatmentRepository();
          final provider = TreatmentProvider(
            getTreatmentsUseCase: GetTreatmentsUseCase(repository: delayRepo),
            recoveryService: recoveryService,
          );

          // 1. Iniciar sesión como Usuario A (101)
          provider.syncAuthSession(
            isAuthenticated: true,
            userId: 101,
            clinicId: 1,
          );

          final completerA = Completer<TreatmentPage>();
          delayRepo.treatmentsCompleter = completerA;

          final loadFutureA = provider.loadTreatments();
          expect(provider.listStatus, equals(TreatmentListStatus.loading));

          // 2. Cambio a Usuario B (202) en la misma clínica
          provider.syncAuthSession(
            isAuthenticated: true,
            userId: 202,
            clinicId: 1,
          );
          expect(provider.treatments, isEmpty);
          expect(provider.listStatus, equals(TreatmentListStatus.initial));

          // 3. Usuario B lanza su propia consulta de tratamientos
          delayRepo.treatmentsCompleter = null;
          delayRepo.directTreatments = const TreatmentPage(
            items: [
              TreatmentPlan(
                idTratamiento: 222,
                idClinica: 1,
                idConsulta: 20,
                idPaciente: 202,
                idMedico: 3,
                diagnostico: Diagnostico(
                  codigoCie: 'E11',
                  descripcion: 'Tratamiento de Usuario B',
                ),
                fechaInicio: '2026-11-01',
                fechaFin: '2026-11-25',
                zonaHoraria: 'America/La_Paz',
                estado: 'ACTIVO',
                medicamentos: [],
              ),
            ],
            total: 1,
          );

          await provider.loadTreatments();
          expect(provider.treatments.length, equals(1));
          expect(
            provider.treatments.first.diagnostico?.descripcion,
            equals('Tratamiento de Usuario B'),
          );

          // 4. Ahora llega la respuesta demorada de la consulta lanzada por Usuario A
          completerA.complete(
            const TreatmentPage(
              items: [
                TreatmentPlan(
                  idTratamiento: 111,
                  idClinica: 1,
                  idConsulta: 10,
                  idPaciente: 101,
                  idMedico: 2,
                  diagnostico: Diagnostico(
                    codigoCie: 'I10',
                    descripcion: 'Tratamiento de Usuario A',
                  ),
                  fechaInicio: '2026-11-01',
                  fechaFin: '2026-11-20',
                  zonaHoraria: 'America/La_Paz',
                  estado: 'ACTIVO',
                  medicamentos: [],
                ),
              ],
              total: 1,
            ),
          );

          await loadFutureA;

          // Verificación crítica: Solo se muestran los datos de Usuario B, jamás los de A
          expect(provider.treatments.length, equals(1));
          expect(provider.treatments.first.idTratamiento, equals(222));
          expect(
            provider.treatments.first.diagnostico?.descripcion,
            equals('Tratamiento de Usuario B'),
          );
        },
      );

      test(
        'cierre de sesión invalida respuesta tardía de cronograma y no puebla memoria',
        () async {
          final delayRepo = DelayFakeTreatmentRepository();
          final provider = TreatmentProvider(
            getCronogramaUseCase: GetCronogramaUseCase(repository: delayRepo),
            recoveryService: recoveryService,
          );

          provider.syncAuthSession(
            isAuthenticated: true,
            userId: 101,
            clinicId: 1,
          );

          final completer = Completer<CronogramaDia>();
          delayRepo.cronogramaCompleter = completer;

          final futureCronograma = provider.loadCronograma(10);
          expect(provider.cronogramaStatus, equals(CronogramaStatus.loading));

          // Logout antes de que responda
          provider.syncAuthSession(isAuthenticated: false);
          expect(provider.cronograma, isNull);
          expect(provider.cronogramaStatus, equals(CronogramaStatus.initial));

          completer.complete(
            CronogramaDia(
              idTratamiento: 10,
              fecha: '2026-11-01',
              zonaHoraria: 'America/La_Paz',
              dosis: const [
                Dosis(
                  idDosis: 50,
                  idMedicamentoPlan: 1,
                  programadaEn: '2026-11-01T08:00:00Z',
                  programadaHoraLocal: '08:00',
                  zonaHoraria: 'America/La_Paz',
                  estado: 'PENDIENTE',
                  vencida: false,
                ),
              ],
            ),
          );

          await futureCronograma;

          // Verificación: Cronograma se mantiene nulo e initial
          expect(provider.cronograma, isNull);
          expect(provider.cronogramaStatus, equals(CronogramaStatus.initial));
        },
      );

      test(
        'cambio de clínica descarta respuestas tardías de la clínica anterior',
        () async {
          final delayRepo = DelayFakeTreatmentRepository();
          final provider = TreatmentProvider(
            getTreatmentsUseCase: GetTreatmentsUseCase(repository: delayRepo),
            recoveryService: recoveryService,
          );

          // Sesión en Clínica 1
          provider.syncAuthSession(
            isAuthenticated: true,
            userId: 101,
            clinicId: 1,
          );

          final completerC1 = Completer<TreatmentPage>();
          delayRepo.treatmentsCompleter = completerC1;

          final futureC1 = provider.loadTreatments();
          expect(provider.listStatus, equals(TreatmentListStatus.loading));

          // Mismo usuario cambia a Clínica 2
          provider.syncAuthSession(
            isAuthenticated: true,
            userId: 101,
            clinicId: 2,
          );
          expect(provider.treatments, isEmpty);
          expect(provider.listStatus, equals(TreatmentListStatus.initial));

          // Llega respuesta tardía de Clínica 1
          completerC1.complete(
            const TreatmentPage(
              items: [
                TreatmentPlan(
                  idTratamiento: 555,
                  idClinica: 1,
                  idConsulta: 10,
                  idPaciente: 101,
                  idMedico: 2,
                  diagnostico: Diagnostico(
                    codigoCie: 'I10',
                    descripcion: 'Tratamiento de Clínica 1',
                  ),
                  fechaInicio: '2026-11-01',
                  fechaFin: '2026-11-20',
                  zonaHoraria: 'America/La_Paz',
                  estado: 'ACTIVO',
                  medicamentos: [],
                ),
              ],
              total: 1,
            ),
          );

          await futureC1;

          // Estado permanece limpio, no muestra tratamientos de Clínica 1
          expect(provider.treatments, isEmpty);
          expect(provider.listStatus, equals(TreatmentListStatus.initial));
        },
      );

      test(
        'cierre de sesión invalida respuesta tardía de adherencia y no puebla memoria',
        () async {
          final delayRepo = DelayFakeTreatmentRepository();
          final provider = TreatmentProvider(
            getAdherenciaUseCase: GetAdherenciaUseCase(repository: delayRepo),
            recoveryService: recoveryService,
          );

          provider.syncAuthSession(
            isAuthenticated: true,
            userId: 101,
            clinicId: 1,
          );

          final completer = Completer<Adherencia>();
          delayRepo.adherenciaCompleter = completer;

          final futureAdherencia = provider.loadAdherencia(10);
          expect(provider.adherenciaStatus, equals(AdherenciaStatus.loading));

          // Cierre de sesión antes de que responda
          provider.syncAuthSession(isAuthenticated: false);
          expect(provider.adherencia, isNull);
          expect(provider.adherenciaStatus, equals(AdherenciaStatus.initial));

          completer.complete(
            const Adherencia(
              numeradorPuntual: 10,
              denominadorProgramado: 10,
              porcentaje: 100.0,
              nivel: 'OPTIMA',
            ),
          );

          await futureAdherencia;

          // Estado permanece limpio
          expect(provider.adherencia, isNull);
          expect(provider.adherenciaStatus, equals(AdherenciaStatus.initial));
        },
      );

      test(
        'cambio de usuario A a B invalida respuesta tardía de avisos de A y no los muestra en sesión de B',
        () async {
          final delayRepo = DelayFakeTreatmentRepository();
          final provider = TreatmentProvider(
            getAvisosUseCase: GetAvisosUseCase(repository: delayRepo),
            recoveryService: recoveryService,
          );

          // Usuario A inicia carga de avisos
          provider.syncAuthSession(
            isAuthenticated: true,
            userId: 101,
            clinicId: 1,
          );

          final completerA = Completer<AvisoPage>();
          delayRepo.avisosCompleter = completerA;

          final futureA = provider.loadAvisos();
          expect(provider.avisosStatus, equals(AvisosStatus.loading));

          // Cambia a Usuario B
          provider.syncAuthSession(
            isAuthenticated: true,
            userId: 202,
            clinicId: 1,
          );
          expect(provider.avisos, isEmpty);
          expect(provider.avisosStatus, equals(AvisosStatus.initial));

          // Llega respuesta tardía de avisos de Usuario A
          completerA.complete(
            const AvisoPage(
              items: [
                Aviso(
                  idAviso: 99,
                  idTratamiento: 10,
                  tipo: 'OMISION',
                  canal: 'APP',
                  estado: 'PENDIENTE',
                  leidaEn: null,
                ),
              ],
              total: 1,
            ),
          );

          await futureA;

          // La sesión de Usuario B no debe contener avisos de Usuario A
          expect(provider.avisos, isEmpty);
          expect(provider.avisosStatus, equals(AvisosStatus.initial));
        },
      );

      test(
        'respuesta tardía de recordDose tras cambio de usuario descarta mutación en cronograma de nueva sesión',
        () async {
          final delayRepo = DelayFakeTreatmentRepository();
          final provider = TreatmentProvider(
            getCronogramaUseCase: GetCronogramaUseCase(repository: delayRepo),
            recoveryService: recoveryService,
          );

          // 1. Sesión de Usuario A con cronograma para dosis 501
          provider.syncAuthSession(
            isAuthenticated: true,
            userId: 101,
            clinicId: 1,
          );
          delayRepo.cronogramaCompleter = null;
          await provider.loadCronograma(10);

          final completerDose = Completer<dynamic>();
          fakeApi.onPost = (url, {body, headers}) {
            if (url.contains('/intentos')) {
              return {
                'estado': 'EN_CURSO',
                'confirmado': false,
                'en_curso': true,
                'id_dosis': 501,
                'idempotency_key': headers?['Idempotency-Key'] ?? 'key-dose',
              };
            }
            if (url.contains('/registros')) {
              return completerDose.future;
            }
            return {'estado': 'CONFIRMADA', 'confirmado': true};
          };

          // Inicia recordDose para Usuario A
          final recordFutureA = provider.recordDose(
            idDosis: 501,
            estado: 'INGERIDA',
          );

          // 2. Cambio a Usuario B antes de que termine el registro
          provider.syncAuthSession(
            isAuthenticated: true,
            userId: 202,
            clinicId: 2,
          );
          expect(provider.cronograma, isNull);

          // Ahora se completa la petición asíncrona de Usuario A
          completerDose.complete({
            'id_dosis': 501,
            'id_medicamento_plan': 1,
            'programada_en': '2026-11-02T12:00:00Z',
            'programada_hora_local': '08:00',
            'zona_horaria': 'America/La_Paz',
            'estado': 'INGERIDA',
            'vencida': false,
            'puntual': true,
          });

          await expectLater(recordFutureA, throwsA(isA<ConflictException>()));

          // El cronograma de Usuario B sigue siendo null (no fue contaminado con la dosis de Usuario A)
          expect(provider.cronograma, isNull);
        },
      );

      test(
        'sin identidad autenticada completa recordDose lanza UnauthorizedException',
        () async {
          final provider = TreatmentProvider(recoveryService: recoveryService);

          provider.syncAuthSession(isAuthenticated: false);

          expect(
            () => provider.recordDose(idDosis: 501, estado: 'INGERIDA'),
            throwsA(isA<UnauthorizedException>()),
          );
        },
      );

      test(
        'recordDose arroja ConflictException cuando dosis es nula y no fabrica dosis',
        () async {
          final provider = TreatmentProvider(recoveryService: recoveryService);
          provider.syncAuthSession(
            isAuthenticated: true,
            userId: 101,
            clinicId: 1,
          );

          fakeApi.onPost = (url, {body, headers}) {
            if (url.contains('/intentos')) {
              // Devuelve intento confirmado pero dosis es nula (ej. idempotencia sin cuerpo dosis)
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
            throwsA(isA<ConflictException>()),
          );

          expect(provider.recordDoseStatus, equals(RecordDoseStatus.error));
        },
      );

      test(
        'mock de /registros devuelve Dosis completa y recordDose la asigna correctamente',
        () async {
          final delayRepo = DelayFakeTreatmentRepository();
          final provider = TreatmentProvider(
            getCronogramaUseCase: GetCronogramaUseCase(repository: delayRepo),
            recoveryService: recoveryService,
          );
          provider.syncAuthSession(
            isAuthenticated: true,
            userId: 101,
            clinicId: 1,
          );

          fakeApi.onPost =
              null; // usa la implementación por defecto que devuelve Dosis completa

          final dosis = await provider.recordDose(
            idDosis: 501,
            estado: 'INGERIDA',
            nota: 'Sin problemas',
          );

          expect(dosis.idDosis, equals(501));
          expect(dosis.estado, equals('INGERIDA'));
          expect(dosis.programadaEn, equals('2026-11-02T12:00:00Z'));
          expect(provider.recordDoseStatus, equals(RecordDoseStatus.success));
        },
      );
    },
  );
}
