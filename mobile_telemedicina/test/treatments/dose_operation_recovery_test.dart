import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:mobile_telemedicina/core/network/api_client_interface.dart';
import 'package:mobile_telemedicina/core/network/api_exceptions.dart';
import 'package:mobile_telemedicina/features/treatments/data/services/dose_operation_recovery_service.dart';
import 'package:mobile_telemedicina/features/treatments/domain/usecases/record_dose_usecase.dart';
import 'package:mobile_telemedicina/features/treatments/domain/repositories/treatment_repository.dart';
import 'package:mobile_telemedicina/features/treatments/domain/entities/treatment_entities.dart';

/// Fake ApiClient para simular llamadas al backend CU17 de forma determinista.
class FakeApiClient implements ApiClientInterface {
  final List<Map<String, dynamic>> recordedCalls = [];
  dynamic Function(String url, {dynamic body, Map<String, String>? headers})?
  onPost;
  dynamic Function(String url, {Map<String, String>? headers})? onGet;
  dynamic Function(String url, {dynamic body, Map<String, String>? headers})?
  onPatch;
  dynamic Function(String url, {Map<String, String>? headers})? onDelete;

  @override
  Future<dynamic> post(
    String url, {
    dynamic body,
    bool includeAuth = true,
    Map<String, String>? headers,
  }) async {
    recordedCalls.add({
      'method': 'POST',
      'url': url,
      'body': body,
      'headers': headers,
    });
    if (onPost != null) {
      return onPost!(url, body: body, headers: headers);
    }
    if (url.endsWith('/registros')) {
      return {
        'id_dosis': 900,
        'id_medicamento_plan': 1,
        'programada_en': '2026-11-01T12:00:00Z',
        'programada_hora_local': '08:00',
        'zona_horaria': 'America/La_Paz',
        'estado': 'INGERIDA',
        'vencida': false,
        'efectiva_en': '2026-11-01T12:00:00Z',
        'registrada_en': '2026-11-01T12:01:00Z',
        'puntual': true,
      };
    }
    return {'estado': 'CONFIRMADA', 'confirmado': true, 'id_dosis': 900};
  }

  @override
  Future<dynamic> get(
    String url, {
    bool includeAuth = true,
    String? authToken,
    Map<String, String>? headers,
  }) async {
    recordedCalls.add({'method': 'GET', 'url': url, 'headers': headers});
    if (onGet != null) {
      return onGet!(url, headers: headers);
    }
    return {'estado': 'CONFIRMADA', 'confirmado': true, 'id_dosis': 900};
  }

  @override
  Future<dynamic> patch(
    String url, {
    dynamic body,
    bool includeAuth = true,
    Map<String, String>? headers,
  }) async {
    recordedCalls.add({
      'method': 'PATCH',
      'url': url,
      'body': body,
      'headers': headers,
    });
    if (onPatch != null) {
      return onPatch!(url, body: body, headers: headers);
    }
    return {};
  }

  @override
  Future<dynamic> delete(
    String url, {
    bool includeAuth = true,
    Map<String, String>? headers,
  }) async {
    recordedCalls.add({'method': 'DELETE', 'url': url, 'headers': headers});
    if (onDelete != null) {
      return onDelete!(url, headers: headers);
    }
    return {};
  }

  @override
  Future<Uint8List> downloadBytes(String url, {bool includeAuth = true}) async {
    return Uint8List(0);
  }
}

class FailingMarkerStore extends InMemorySharedPreferencesStore {
  FailingMarkerStore() : super.empty();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    return false;
  }
}

class FakeTreatmentRepository implements TreatmentRepository {
  Map<String, dynamic>? lastBody;
  String? lastIdempotencyKey;

  @override
  Future<Dosis> registrarDosis(
    int idDosis,
    String idempotencyKey,
    Map<String, dynamic> body,
  ) async {
    lastIdempotencyKey = idempotencyKey;
    lastBody = body;
    return Dosis(
      idDosis: idDosis,
      idMedicamentoPlan: 1,
      programadaEn: '2026-11-01T08:00:00Z',
      programadaHoraLocal: '08:00',
      zonaHoraria: 'America/La_Paz',
      estado: body['estado'] as String,
      vencida: false,
      efectivaEn: body['efectiva_en'] as String?,
      nota: body['nota'] as String?,
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeApiClient fakeApi;
  late DoseOperationRecoveryService recoveryService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    fakeApi = FakeApiClient();
    recoveryService = DoseOperationRecoveryService(
      apiClient: fakeApi,
      prefs: prefs,
    );
  });

  test('no envía la toma si falla la persistencia del marcador', () async {
    final originalStore = SharedPreferencesStorePlatform.instance;
    SharedPreferencesStorePlatform.instance = FailingMarkerStore();
    const key = 'marker-write-failure';
    const idDosis = 501;

    try {
      await expectLater(
        recoveryService.registrarDosisEnDosFases(
          userId: 101,
          clinicId: 1,
          idDosis: idDosis,
          estado: 'INGERIDA',
          customIdempotencyKey: key,
        ),
        throwsA(isA<StateError>()),
      );
      expect(fakeApi.recordedCalls, isEmpty);
      expect(recoveryService.isDoseLocked(idDosis), isFalse);
      expect(recoveryService.hasPendingBody(key), isFalse);
      expect(await recoveryService.getAllMarkers(), isEmpty);
    } finally {
      SharedPreferencesStorePlatform.instance = originalStore;
    }
  });

  group('CanonicalJsonHasher y hashCanonicalRegistroDosis', () {
    test(
      'ordena alfabéticamente las claves y genera hash SHA-256 consistente',
      () {
        final map1 = {
          'nota': 'Náusea leve',
          'estado': 'INGERIDA',
          'efectiva_en': '2026-11-01T10:08:00-04:00',
        };
        final canonical1 = CanonicalJsonHasher.canonicalize(map1);
        expect(
          canonical1,
          '{"efectiva_en":"2026-11-01T10:08:00-04:00","estado":"INGERIDA","nota":"Náusea leve"}',
        );

        final map2 = {
          'estado': 'INGERIDA',
          'efectiva_en': '2026-11-01T10:08:00-04:00',
          'nota': 'Náusea leve',
        };
        final canonical2 = CanonicalJsonHasher.canonicalize(map2);
        expect(canonical1, equals(canonical2));

        final hash1 = CanonicalJsonHasher.hash(map1);
        final hash2 = CanonicalJsonHasher.hash(map2);
        expect(hash1, equals(hash2));
        expect(
          hash1,
          equals(
            '97473bc2d514a9780f07a3156dbe337a5453901a5795020fbd8c4de5b524eb43',
          ),
        );

        final hashHelper = hashCanonicalRegistroDosis(
          estado: 'INGERIDA',
          efectivaEnRaw: '2026-11-01T10:08:00-04:00',
          nota: 'Náusea leve',
        );
        expect(hashHelper, equals(hash1));
      },
    );

    test('serializa nulls correctamente en formato canónico', () {
      final map = {'estado': 'OMITIDA', 'efectiva_en': null, 'nota': null};
      final canonical = CanonicalJsonHasher.canonicalize(map);
      expect(canonical, '{"efectiva_en":null,"estado":"OMITIDA","nota":null}');
      expect(
        CanonicalJsonHasher.hash(map),
        equals(
          'e1c957e50de95d78022e7ea6c9a47da8c7e9e79e0e5bbdd9992bc79c25a9c1bf',
        ),
      );
    });
  });

  group('DoseRecoveryMarker y Reglas de Privacidad', () {
    test('prohíbe estrictamente datos clínicos en el marcador persistente', () {
      expect(
        () => DoseRecoveryMarker.validateNoClinicalData({
          'userId': 1,
          'medicamento': 'Paracetamol',
        }),
        throwsArgumentError,
      );

      expect(
        () => DoseRecoveryMarker.validateNoClinicalData({
          'userId': 1,
          'diagnostico': 'Hipertensión',
        }),
        throwsArgumentError,
      );

      expect(
        () => DoseRecoveryMarker.validateNoClinicalData({
          'userId': 1,
          'nota': 'Tomar con leche',
        }),
        throwsArgumentError,
      );

      expect(
        () => DoseRecoveryMarker.validateNoClinicalData({
          'userId': 1,
          'estado': 'INGERIDA',
        }),
        throwsArgumentError,
      );

      expect(
        () => DoseRecoveryMarker.validateNoClinicalData({
          'userId': 1,
          'indicaciones': '1 tableta cada 8h',
        }),
        throwsArgumentError,
      );

      // Marcador válido: solo claves opacas de coordinación
      final validMarker = DoseRecoveryMarker(
        userId: 10,
        clinicId: 2,
        idDosis: 50,
        idempotencyKey: 'key-1234',
        timestamp: '2026-11-01T10:00:00Z',
      );
      expect(validMarker.toJson()['userId'], equals(10));
      expect(validMarker.toJson().containsKey('medicamento'), isFalse);
      expect(validMarker.toJson().containsKey('diagnostico'), isFalse);
    });
  });

  group('Aislamiento por userId y clinicId', () {
    test(
      'getPendingMarkers filtra estrictamente por userId y clinicId',
      () async {
        await recoveryService.saveMarker(
          const DoseRecoveryMarker(
            userId: 1,
            clinicId: 10,
            idDosis: 101,
            idempotencyKey: 'key-user1-clinic10',
            timestamp: '2026-11-01T10:00:00Z',
          ),
        );
        await recoveryService.saveMarker(
          const DoseRecoveryMarker(
            userId: 2,
            clinicId: 10,
            idDosis: 102,
            idempotencyKey: 'key-user2-clinic10',
            timestamp: '2026-11-01T10:00:00Z',
          ),
        );
        await recoveryService.saveMarker(
          const DoseRecoveryMarker(
            userId: 1,
            clinicId: 20,
            idDosis: 103,
            idempotencyKey: 'key-user1-clinic20',
            timestamp: '2026-11-01T10:00:00Z',
          ),
        );

        final markersU1C10 = await recoveryService.getPendingMarkers(
          userId: 1,
          clinicId: 10,
        );
        expect(markersU1C10.length, equals(1));
        expect(markersU1C10.first.idempotencyKey, equals('key-user1-clinic10'));

        final markersU2C10 = await recoveryService.getPendingMarkers(
          userId: 2,
          clinicId: 10,
        );
        expect(markersU2C10.length, equals(1));
        expect(markersU2C10.first.idempotencyKey, equals('key-user2-clinic10'));

        final markersOther = await recoveryService.getPendingMarkers(
          userId: 99,
          clinicId: 99,
        );
        expect(markersOther, isEmpty);
      },
    );
  });

  group('Protocolo de registro en dos fases (Hallazgo A)', () {
    test(
      'flujo exitoso: intentos (Fase 1) seguido de registros (Fase 2)',
      () async {
        fakeApi.onPost = (url, {body, headers}) {
          if (url.endsWith('/intentos')) {
            expect(headers?['Idempotency-Key'], isNotEmpty);
            expect(body['request_hash'], isNotEmpty);
            return {
              'estado': 'EN_CURSO',
              'confirmado': false,
              'en_curso': true,
              'rechazado': false,
              'id_dosis': 100,
              'idempotency_key': headers?['Idempotency-Key'],
              'generacion': 1,
            };
          } else if (url.endsWith('/registros')) {
            expect(body['estado'], equals('INGERIDA'));
            expect(body['efectiva_en'], equals('2026-11-01T14:00:00Z'));
            expect(body['nota'], equals('Sin efectos secundarios'));
            return {
              'id_dosis': 100,
              'id_medicamento_plan': 31,
              'programada_en': '2026-11-01T14:00:00Z',
              'programada_hora_local': '10:00',
              'zona_horaria': 'America/La_Paz',
              'estado': 'INGERIDA',
              'vencida': false,
              'efectiva_en': '2026-11-01T14:00:00Z',
              'registrada_en': '2026-11-01T14:01:00Z',
              'puntual': true,
              'nota': 'Sin efectos secundarios',
            };
          }
          throw UnimplementedError();
        };

        final result = await recoveryService.registrarDosisEnDosFases(
          userId: 1,
          clinicId: 5,
          idDosis: 100,
          estado: 'INGERIDA',
          efectivaEnRaw: '2026-11-01T14:00:00.000Z', // Debe normalizarse a Z
          nota: 'Sin efectos secundarios',
        );

        expect(result.isConfirmed, isTrue);
        expect(result.estado, equals('CONFIRMADA'));

        // Verificación de llamadas en 2 fases
        expect(fakeApi.recordedCalls.length, equals(2));
        expect(fakeApi.recordedCalls[0]['url'], contains('/intentos'));
        expect(fakeApi.recordedCalls[1]['url'], contains('/registros'));

        // Tras el éxito: se limpia el marcador persistente, cuerpo en memoria y bloqueo
        final pendingMarkers = await recoveryService.getPendingMarkers(
          userId: 1,
          clinicId: 5,
        );
        expect(pendingMarkers, isEmpty);
        expect(recoveryService.hasPendingBody(result.idempotencyKey), isFalse);
        expect(recoveryService.isDoseLocked(100), isFalse);
      },
    );

    test(
      'fase 1 ya confirmada previamente devuelve resultado sin reenviar fase 2',
      () async {
        fakeApi.onPost = (url, {body, headers}) {
          if (url.endsWith('/intentos')) {
            return {
              'estado': 'CONFIRMADA',
              'confirmado': true,
              'en_curso': false,
              'rechazado': false,
              'id_dosis': 101,
              'idempotency_key': headers?['Idempotency-Key'],
              'generacion': 3,
              'dosis': {'id_dosis': 101, 'estado': 'INGERIDA'},
            };
          }
          throw StateError('Fase 2 no debe ser llamada si ya está confirmada');
        };

        final result = await recoveryService.registrarDosisEnDosFases(
          userId: 1,
          clinicId: 5,
          idDosis: 101,
          estado: 'INGERIDA',
        );

        expect(result.isConfirmed, isTrue);
        expect(fakeApi.recordedCalls.length, equals(1));
        expect(recoveryService.isDoseLocked(101), isFalse);
        final markers = await recoveryService.getPendingMarkers(
          userId: 1,
          clinicId: 5,
        );
        expect(markers, isEmpty);
      },
    );

    test(
      'Fase 1 RECHAZADA: NUNCA envía fase 2, limpia marcador y desbloquea',
      () async {
        fakeApi.onPost = (url, {body, headers}) {
          if (url.endsWith('/intentos')) {
            return {
              'estado': 'RECHAZADA',
              'confirmado': false,
              'en_curso': false,
              'rechazado': true,
              'id_dosis': 102,
              'idempotency_key': headers?['Idempotency-Key'],
            };
          }
          throw StateError(
            'Fase 2 NUNCA debe ejecutarse si la intención fue rechazada',
          );
        };

        final result = await recoveryService.registrarDosisEnDosFases(
          userId: 1,
          clinicId: 5,
          idDosis: 102,
          estado: 'INGERIDA',
        );

        expect(result.isRejected, isTrue);
        expect(fakeApi.recordedCalls.length, equals(1));
        expect(recoveryService.isDoseLocked(102), isFalse);
        final markers = await recoveryService.getPendingMarkers(
          userId: 1,
          clinicId: 5,
        );
        expect(markers, isEmpty);
      },
    );

    test(
      'Fase 1 NO_INICIADA: NUNCA envía fase 2, conserva marcador y bloquea dosis',
      () async {
        fakeApi.onPost = (url, {body, headers}) {
          if (url.endsWith('/intentos')) {
            return {
              'estado': 'NO_INICIADA',
              'confirmado': false,
              'en_curso': false,
              'rechazado': false,
              'id_dosis': 103,
              'idempotency_key': headers?['Idempotency-Key'],
            };
          }
          throw StateError('Fase 2 NUNCA debe ejecutarse con NO_INICIADA');
        };

        final result = await recoveryService.registrarDosisEnDosFases(
          userId: 1,
          clinicId: 5,
          idDosis: 103,
          estado: 'INGERIDA',
        );

        expect(result.isNotStarted, isTrue);
        expect(fakeApi.recordedCalls.length, equals(1));
        // Debe conservar marcador y mantener dosis bloqueada
        expect(recoveryService.isDoseLocked(103), isTrue);
        final markers = await recoveryService.getPendingMarkers(
          userId: 1,
          clinicId: 5,
        );
        expect(markers.length, equals(1));
      },
    );

    test(
      'Fase 1 con ValidationException (422): desbloquea dosis y limpia marcador',
      () async {
        fakeApi.onPost = (url, {body, headers}) {
          throw ValidationException('Campo inválido');
        };

        await expectLater(
          recoveryService.registrarDosisEnDosFases(
            userId: 1,
            clinicId: 5,
            idDosis: 104,
            estado: 'ESTADO_INVALIDO',
          ),
          throwsA(isA<ValidationException>()),
        );

        expect(recoveryService.isDoseLocked(104), isFalse);
        final markers = await recoveryService.getPendingMarkers(
          userId: 1,
          clinicId: 5,
        );
        expect(markers, isEmpty);
      },
    );

    test(
      'Fase 1 con ConflictException (409): bloquea dosis y retiene marcador',
      () async {
        fakeApi.onPost = (url, {body, headers}) {
          throw ConflictException('Conflicto concurrente en backend');
        };

        await expectLater(
          recoveryService.registrarDosisEnDosFases(
            userId: 1,
            clinicId: 5,
            idDosis: 105,
            estado: 'INGERIDA',
          ),
          throwsA(isA<ConflictException>()),
        );

        expect(recoveryService.isDoseLocked(105), isTrue);
        final markers = await recoveryService.getPendingMarkers(
          userId: 1,
          clinicId: 5,
        );
        expect(markers.length, equals(1));
      },
    );

    test(
      'Fase 1 con UnauthorizedException (401): bloquea dosis y retiene marcador',
      () async {
        fakeApi.onPost = (url, {body, headers}) {
          throw UnauthorizedException('Token expirado');
        };

        await expectLater(
          recoveryService.registrarDosisEnDosFases(
            userId: 1,
            clinicId: 5,
            idDosis: 106,
            estado: 'INGERIDA',
          ),
          throwsA(isA<UnauthorizedException>()),
        );

        expect(recoveryService.isDoseLocked(106), isTrue);
        final markers = await recoveryService.getPendingMarkers(
          userId: 1,
          clinicId: 5,
        );
        expect(markers.length, equals(1));
      },
    );

    test(
      'Fase 1 con ServerException (5xx): bloquea dosis y retiene marcador',
      () async {
        fakeApi.onPost = (url, {body, headers}) {
          throw ServerException('500 Internal Server Error');
        };

        await expectLater(
          recoveryService.registrarDosisEnDosFases(
            userId: 1,
            clinicId: 5,
            idDosis: 107,
            estado: 'INGERIDA',
          ),
          throwsA(isA<ServerException>()),
        );

        expect(recoveryService.isDoseLocked(107), isTrue);
        final markers = await recoveryService.getPendingMarkers(
          userId: 1,
          clinicId: 5,
        );
        expect(markers.length, equals(1));
      },
    );

    test(
      'Fase 2 con ValidationException (422): desbloquea dosis y limpia marcador',
      () async {
        fakeApi.onPost = (url, {body, headers}) {
          if (url.endsWith('/intentos')) {
            return {
              'estado': 'EN_CURSO',
              'confirmado': false,
              'en_curso': true,
              'id_dosis': 108,
              'idempotency_key': headers?['Idempotency-Key'],
            };
          } else if (url.endsWith('/registros')) {
            throw ValidationException('Error 422 en cuerpo clínico');
          }
          throw UnimplementedError();
        };

        await expectLater(
          recoveryService.registrarDosisEnDosFases(
            userId: 1,
            clinicId: 5,
            idDosis: 108,
            estado: 'INGERIDA',
          ),
          throwsA(isA<ValidationException>()),
        );

        expect(recoveryService.isDoseLocked(108), isFalse);
        final markers = await recoveryService.getPendingMarkers(
          userId: 1,
          clinicId: 5,
        );
        expect(markers, isEmpty);
      },
    );
  });

  group('Simulación de timeout y desconexión', () {
    test(
      'timeout en fase 2 bloquea la dosis, conserva marcador y cuerpo en memoria',
      () async {
        const customKey = 'test-timeout-key-1';
        fakeApi.onPost = (url, {body, headers}) {
          if (url.endsWith('/intentos')) {
            return {
              'estado': 'EN_CURSO',
              'confirmado': false,
              'en_curso': true,
              'id_dosis': 200,
              'idempotency_key': customKey,
            };
          } else if (url.endsWith('/registros')) {
            throw TimeoutException('Timeout de red simulado');
          }
          throw UnimplementedError();
        };

        await expectLater(
          recoveryService.registrarDosisEnDosFases(
            userId: 1,
            clinicId: 5,
            idDosis: 200,
            estado: 'INGERIDA',
            customIdempotencyKey: customKey,
          ),
          throwsA(isA<TimeoutException>()),
        );

        // Verificaciones post-timeout:
        // 1. La dosis queda bloqueada contra nuevos registros concurrentes
        expect(recoveryService.isDoseLocked(200), isTrue);

        // 2. El cuerpo clínico se conserva en la memoria de la sesión
        expect(recoveryService.hasPendingBody(customKey), isTrue);
        expect(
          recoveryService.getPendingBody(customKey)?['estado'],
          equals('INGERIDA'),
        );

        // 3. El marcador persistente opaco está guardado (sin datos clínicos)
        final markers = await recoveryService.getPendingMarkers(
          userId: 1,
          clinicId: 5,
        );
        expect(markers.length, equals(1));
        expect(markers.first.idDosis, equals(200));
        expect(markers.first.idempotencyKey, equals(customKey));

        // 4. Intento de nuevo registro sobre dosis bloqueada falla con conflicto
        await expectLater(
          recoveryService.registrarDosisEnDosFases(
            userId: 1,
            clinicId: 5,
            idDosis: 200,
            estado: 'OMITIDA',
          ),
          throwsA(isA<ConflictException>()),
        );
      },
    );

    test(
      'reintento con cuerpo preservado en memoria tiene éxito y desbloquea',
      () async {
        const key = 'test-retry-with-body';
        recoveryService.lockDose(300);
        await recoveryService.saveMarker(
          DoseRecoveryMarker(
            userId: 1,
            clinicId: 5,
            idDosis: 300,
            idempotencyKey: key,
            timestamp: DateTime.now().toUtc().toIso8601String(),
          ),
        );
        final clinicalMap = {
          'estado': 'INGERIDA',
          'efectiva_en': null,
          'nota': 'Reintento',
        };
        recoveryService.setPendingBodyForTesting(key, clinicalMap);

        fakeApi.onPost = (url, {body, headers}) {
          expect(url, contains('/registros'));
          expect(headers?['Idempotency-Key'], equals(key));
          expect(body['nota'], equals('Reintento'));
          return {
            'id_dosis': 300,
            'id_medicamento_plan': 31,
            'programada_en': '2026-11-01T14:00:00Z',
            'programada_hora_local': '10:00',
            'zona_horaria': 'America/La_Paz',
            'estado': 'INGERIDA',
            'vencida': false,
            'efectiva_en': '2026-11-01T14:00:00Z',
            'registrada_en': '2026-11-01T14:01:00Z',
            'puntual': true,
            'nota': 'Reintento',
          };
        };

        final retryResult = await recoveryService.reintentarOperacionConCuerpo(
          idDosis: 300,
          idempotencyKey: key,
        );

        expect(retryResult, isNotNull);
        expect(retryResult!.isConfirmed, isTrue);
        expect(retryResult.idDosis, equals(300));
        expect(retryResult.dosis?['estado'], equals('INGERIDA'));
        expect(retryResult.dosisModel?.esIngerida, isTrue);
        expect(recoveryService.isDoseLocked(300), isFalse);
        expect(recoveryService.hasPendingBody(key), isFalse);
        final markers = await recoveryService.getPendingMarkers(
          userId: 1,
          clinicId: 5,
        );
        expect(markers, isEmpty);
      },
    );
  });

  group('Resolución sin cuerpo clínico (Reinicio / Logout vía /resolver)', () {
    const abandonedKey = 'abandoned-key-resolver';

    setUp(() async {
      // Simula que la memoria de sesión se borró por reinicio de app
      recoveryService.clearPendingClinicalData();
      await recoveryService.saveMarker(
        DoseRecoveryMarker(
          userId: 1,
          clinicId: 5,
          idDosis: 400,
          idempotencyKey: abandonedKey,
          timestamp: DateTime.now().toUtc().toIso8601String(),
        ),
      );
    });

    test(
      'reintentarOperacionConCuerpo devuelve null si el cuerpo se perdió',
      () async {
        final res = await recoveryService.reintentarOperacionConCuerpo(
          idDosis: 400,
          idempotencyKey: abandonedKey,
        );
        expect(res, isNull);
      },
    );

    test(
      'resolver respuesta CONFIRMADA limpia marcador y devuelve resultado',
      () async {
        fakeApi.onPost = (url, {body, headers}) {
          expect(url, contains('/resolver'));
          return {
            'estado': 'CONFIRMADA',
            'confirmado': true,
            'en_curso': false,
            'rechazado': false,
            'id_dosis': 400,
            'idempotency_key': abandonedKey,
            'generacion': 5,
            'dosis': {'id_dosis': 400, 'estado': 'INGERIDA'},
          };
        };

        final res = await recoveryService.resolverOperacionAbandonada(
          userId: 1,
          clinicId: 5,
          idDosis: 400,
          idempotencyKey: abandonedKey,
        );

        expect(res.isConfirmed, isTrue);
        final markers = await recoveryService.getPendingMarkers(
          userId: 1,
          clinicId: 5,
        );
        expect(markers, isEmpty);
        expect(recoveryService.isDoseLocked(400), isFalse);
      },
    );

    test(
      'resolver respuesta RECHAZADA limpia marcador y devuelve resultado',
      () async {
        fakeApi.onPost = (url, {body, headers}) {
          expect(url, contains('/resolver'));
          return {
            'estado': 'RECHAZADA',
            'confirmado': false,
            'en_curso': false,
            'rechazado': true,
            'id_dosis': 400,
            'idempotency_key': abandonedKey,
            'generacion': 6,
          };
        };

        final res = await recoveryService.resolverOperacionAbandonada(
          userId: 1,
          clinicId: 5,
          idDosis: 400,
          idempotencyKey: abandonedKey,
        );

        expect(res.isRejected, isTrue);
        final markers = await recoveryService.getPendingMarkers(
          userId: 1,
          clinicId: 5,
        );
        expect(markers, isEmpty);
        expect(recoveryService.isDoseLocked(400), isFalse);
      },
    );

    test(
      'resolver respuesta EN_CURSO mantiene bloqueo hasta resolución del backend',
      () async {
        fakeApi.onPost = (url, {body, headers}) {
          return {
            'estado': 'EN_CURSO',
            'confirmado': false,
            'en_curso': true,
            'rechazado': false,
            'id_dosis': 400,
            'idempotency_key': abandonedKey,
          };
        };

        final res = await recoveryService.resolverOperacionAbandonada(
          userId: 1,
          clinicId: 5,
          idDosis: 400,
          idempotencyKey: abandonedKey,
        );

        expect(res.isInProgress, isTrue);
        final markers = await recoveryService.getPendingMarkers(
          userId: 1,
          clinicId: 5,
        );
        expect(markers.length, equals(1));
        expect(recoveryService.isDoseLocked(400), isTrue);
      },
    );

    test(
      'contrato NO_INICIADA: NO libera el marcador en cliente hasta que backend persiste RECHAZADA',
      () async {
        fakeApi.onPost = (url, {body, headers}) {
          return {
            'estado': 'NO_INICIADA',
            'confirmado': false,
            'en_curso': false,
            'rechazado': false,
            'id_dosis': 400,
            'idempotency_key': abandonedKey,
          };
        };

        final res = await recoveryService.resolverOperacionAbandonada(
          userId: 1,
          clinicId: 5,
          idDosis: 400,
          idempotencyKey: abandonedKey,
        );

        expect(res.isNotStarted, isTrue);
        // REGLA: NO liberes el marcador solo por ver NO_INICIADA.
        final markers = await recoveryService.getPendingMarkers(
          userId: 1,
          clinicId: 5,
        );
        expect(markers.length, equals(1));
        expect(recoveryService.isDoseLocked(400), isTrue);

        // Ahora cuando el backend resuelve persistiendo como RECHAZADA:
        fakeApi.onPost = (url, {body, headers}) {
          return {
            'estado': 'RECHAZADA',
            'confirmado': false,
            'en_curso': false,
            'rechazado': true,
            'id_dosis': 400,
            'idempotency_key': abandonedKey,
          };
        };

        final finalRes = await recoveryService.resolverOperacionAbandonada(
          userId: 1,
          clinicId: 5,
          idDosis: 400,
          idempotencyKey: abandonedKey,
        );

        expect(finalRes.isRejected, isTrue);
        final finalMarkers = await recoveryService.getPendingMarkers(
          userId: 1,
          clinicId: 5,
        );
        expect(finalMarkers, isEmpty);
        expect(recoveryService.isDoseLocked(400), isFalse);
      },
    );
  });

  group('RecordDoseUseCase integrando delegación y normalización', () {
    test(
      'RecordDoseUseCase normaliza fechas y delega registrarEnDosFases',
      () async {
        fakeApi.onPost = (url, {body, headers}) {
          if (url.endsWith('/intentos')) {
            return {
              'estado': 'EN_CURSO',
              'confirmado': false,
              'en_curso': true,
              'id_dosis': 500,
              'idempotency_key': headers?['Idempotency-Key'],
            };
          } else if (url.endsWith('/registros')) {
            expect(body['efectiva_en'], equals('2026-11-01T14:08:00Z'));
            return {
              'id_dosis': 500,
              'id_medicamento_plan': 31,
              'programada_en': '2026-11-01T14:00:00Z',
              'programada_hora_local': '10:00',
              'zona_horaria': 'America/La_Paz',
              'estado': 'INGERIDA',
              'vencida': false,
              'efectiva_en': '2026-11-01T14:08:00Z',
              'registrada_en': '2026-11-01T14:09:00Z',
              'puntual': true,
              'nota': null,
            };
          }
          throw UnimplementedError();
        };

        final useCase = RecordDoseUseCase(
          repository: FakeTreatmentRepository(),
          recoveryService: recoveryService,
        );

        final result = await useCase.registrarEnDosFases(
          userId: 1,
          clinicId: 5,
          idDosis: 500,
          estado: 'INGERIDA',
          efectivaEnRaw: '2026-11-01T14:08:00.000Z',
        );

        expect(result.isConfirmed, isTrue);
        expect(fakeApi.recordedCalls.length, equals(2));
      },
    );

    test(
      'RecordDoseUseCase call normaliza fecha antes de enviar al repositorio',
      () async {
        final fakeRepo = FakeTreatmentRepository();
        final useCase = RecordDoseUseCase(
          repository: fakeRepo,
          recoveryService: recoveryService,
        );

        final dosis = await useCase(
          idDosis: 600,
          idempotencyKey: 'key-call',
          estado: 'INGERIDA',
          efectivaEn: '2026-11-01T10:08:00.000Z',
          nota: 'Toma normal',
        );

        expect(dosis.idDosis, equals(600));
        expect(
          fakeRepo.lastBody?['efectiva_en'],
          equals('2026-11-01T10:08:00Z'),
        );
        expect(fakeRepo.lastBody?['estado'], equals('INGERIDA'));
        expect(fakeRepo.lastBody?['nota'], equals('Toma normal'));
      },
    );
  });

  group('Contrato backend estricto CU17: Dosis directa en /registros', () {
    test(
      '1. Respuesta directa de Dosis en /registros se procesa tipadamente y conserva atributos reales',
      () async {
        fakeApi.onPost = (url, {body, headers}) {
          if (url.endsWith('/intentos')) {
            return {
              'estado': 'EN_CURSO',
              'confirmado': false,
              'en_curso': true,
              'rechazado': false,
              'id_dosis': 701,
              'idempotency_key': headers?['Idempotency-Key'],
              'generacion': 1,
            };
          } else if (url.endsWith('/registros')) {
            return {
              'id_dosis': 701,
              'id_medicamento_plan': 31,
              'programada_en': '2026-11-01T14:00:00Z',
              'programada_hora_local': '10:00',
              'zona_horaria': 'America/La_Paz',
              'estado': 'INGERIDA',
              'vencida': false,
              'efectiva_en': '2026-11-01T14:00:00Z',
              'registrada_en': '2026-11-01T14:01:00Z',
              'puntual': true,
              'nota': 'Sin efectos secundarios',
            };
          }
          throw UnimplementedError();
        };

        final result = await recoveryService.registrarDosisEnDosFases(
          userId: 10,
          clinicId: 2,
          idDosis: 701,
          estado: 'INGERIDA',
          efectivaEnRaw: '2026-11-01T14:00:00Z',
          nota: 'Sin efectos secundarios',
        );

        expect(result.isConfirmed, isTrue);
        expect(result.confirmado, isTrue);
        expect(result.estado, equals('CONFIRMADA'));
        expect(result.idDosis, equals(701));
        expect(result.generacion, equals(1));
        expect(result.dosis?['estado'], equals('INGERIDA'));
        expect(result.dosis?['programada_hora_local'], equals('10:00'));
        expect(result.dosis?['puntual'], isTrue);
        expect(result.dosis?['nota'], equals('Sin efectos secundarios'));
        expect(result.dosisModel, isNotNull);
        expect(result.dosisModel!.idDosis, equals(701));
        expect(result.dosisModel!.esIngerida, isTrue);
        expect(result.dosisModel!.esPuntual, isTrue);

        expect(recoveryService.isDoseLocked(701), isFalse);
        expect(recoveryService.hasPendingBody(result.idempotencyKey), isFalse);
        final markers = await recoveryService.getPendingMarkers(
          userId: 10,
          clinicId: 2,
        );
        expect(markers, isEmpty);
      },
    );

    test(
      '2. Intención RECHAZADA: no se envía /registros y no hay confirmación',
      () async {
        fakeApi.onPost = (url, {body, headers}) {
          if (url.endsWith('/intentos')) {
            return {
              'estado': 'RECHAZADA',
              'confirmado': false,
              'en_curso': false,
              'rechazado': true,
              'id_dosis': 702,
              'idempotency_key': headers?['Idempotency-Key'],
            };
          } else if (url.endsWith('/registros')) {
            fail(
              'CRÍTICO: /registros jamás debe llamarse cuando la intención es RECHAZADA',
            );
          }
          throw UnimplementedError();
        };

        final result = await recoveryService.registrarDosisEnDosFases(
          userId: 10,
          clinicId: 2,
          idDosis: 702,
          estado: 'INGERIDA',
        );

        expect(result.isRejected, isTrue);
        expect(result.isConfirmed, isFalse);
        expect(result.estado, equals('RECHAZADA'));
        expect(fakeApi.recordedCalls.length, equals(1));
        expect(fakeApi.recordedCalls.first['url'], contains('/intentos'));
        expect(
          fakeApi.recordedCalls.any(
            (c) => (c['url'] as String).contains('/registros'),
          ),
          isFalse,
        );

        expect(recoveryService.isDoseLocked(702), isFalse);
        expect(recoveryService.hasPendingBody(result.idempotencyKey), isFalse);
        final markers = await recoveryService.getPendingMarkers(
          userId: 10,
          clinicId: 2,
        );
        expect(markers, isEmpty);
      },
    );

    test(
      '3. Intención NO_INICIADA o inválida: no se envía /registros y el bloqueo permanece',
      () async {
        fakeApi.onPost = (url, {body, headers}) {
          if (url.endsWith('/intentos')) {
            return {
              'estado': 'NO_INICIADA',
              'confirmado': false,
              'en_curso': false,
              'rechazado': false,
              'no_iniciada': true,
              'id_dosis': 703,
              'idempotency_key': headers?['Idempotency-Key'],
            };
          } else if (url.endsWith('/registros')) {
            fail(
              'CRÍTICO: /registros jamás debe llamarse cuando la intención es NO_INICIADA',
            );
          }
          throw UnimplementedError();
        };

        final result = await recoveryService.registrarDosisEnDosFases(
          userId: 10,
          clinicId: 2,
          idDosis: 703,
          estado: 'INGERIDA',
        );

        expect(result.isNotStarted, isTrue);
        expect(result.isConfirmed, isFalse);
        expect(fakeApi.recordedCalls.length, equals(1));
        expect(recoveryService.isDoseLocked(703), isTrue);
        final markers = await recoveryService.getPendingMarkers(
          userId: 10,
          clinicId: 2,
        );
        expect(markers.length, equals(1));
        expect(markers.first.idDosis, equals(703));
      },
    );

    test(
      '4. Reintento con cuerpo: /registros devuelve Dosis directa y se confirma',
      () async {
        const key = 'retry-direct-dose-key';
        recoveryService.lockDose(704);
        await recoveryService.saveMarker(
          const DoseRecoveryMarker(
            userId: 10,
            clinicId: 2,
            idDosis: 704,
            idempotencyKey: key,
            timestamp: '2026-11-01T10:00:00Z',
          ),
        );
        final clinicalMap = {
          'estado': 'OMITIDA',
          'efectiva_en': null,
          'nota': 'Omitida por prescripción médica',
        };
        recoveryService.setPendingBodyForTesting(key, clinicalMap);

        fakeApi.onPost = (url, {body, headers}) {
          expect(url, contains('/registros'));
          expect(headers?['Idempotency-Key'], equals(key));
          expect(body['estado'], equals('OMITIDA'));
          return {
            'id_dosis': 704,
            'id_medicamento_plan': 31,
            'programada_en': '2026-11-01T14:00:00Z',
            'programada_hora_local': '10:00',
            'zona_horaria': 'America/La_Paz',
            'estado': 'OMITIDA',
            'vencida': false,
            'efectiva_en': null,
            'registrada_en': '2026-11-01T14:02:00Z',
            'puntual': null,
            'nota': 'Omitida por prescripción médica',
          };
        };

        final retryResult = await recoveryService.reintentarOperacionConCuerpo(
          idDosis: 704,
          idempotencyKey: key,
        );

        expect(retryResult, isNotNull);
        expect(retryResult!.isConfirmed, isTrue);
        expect(retryResult.estado, equals('CONFIRMADA'));
        expect(retryResult.idDosis, equals(704));
        expect(retryResult.dosis?['estado'], equals('OMITIDA'));
        expect(retryResult.dosisModel?.esOmitida, isTrue);
        expect(recoveryService.isDoseLocked(704), isFalse);
        expect(recoveryService.hasPendingBody(key), isFalse);
        final markers = await recoveryService.getPendingMarkers(
          userId: 10,
          clinicId: 2,
        );
        expect(markers, isEmpty);
      },
    );

    test(
      '5. Timeout en Fase 2: marcador y bloqueo seguro permanecen',
      () async {
        const timeoutKey = 'timeout-fase2-key';
        fakeApi.onPost = (url, {body, headers}) {
          if (url.endsWith('/intentos')) {
            return {
              'estado': 'EN_CURSO',
              'confirmado': false,
              'en_curso': true,
              'id_dosis': 705,
              'idempotency_key': timeoutKey,
            };
          } else if (url.endsWith('/registros')) {
            throw TimeoutException('Simulated timeout during phase 2');
          }
          throw UnimplementedError();
        };

        await expectLater(
          recoveryService.registrarDosisEnDosFases(
            userId: 10,
            clinicId: 2,
            idDosis: 705,
            estado: 'INGERIDA',
            customIdempotencyKey: timeoutKey,
          ),
          throwsA(isA<TimeoutException>()),
        );

        expect(recoveryService.isDoseLocked(705), isTrue);
        expect(recoveryService.hasPendingBody(timeoutKey), isTrue);
        final markers = await recoveryService.getPendingMarkers(
          userId: 10,
          clinicId: 2,
        );
        expect(markers.length, equals(1));
        expect(markers.first.idDosis, equals(705));
        expect(markers.first.idempotencyKey, equals(timeoutKey));
      },
    );

    test(
      '6. DoseOperationResult.fromRegistroDosisResponse valida estrictamente DosisModel',
      () {
        final validJson = {
          'id_dosis': 706,
          'id_medicamento_plan': 31,
          'programada_en': '2026-11-01T14:00:00Z',
          'programada_hora_local': '10:00',
          'zona_horaria': 'America/La_Paz',
          'estado': 'INGERIDA',
          'vencida': false,
          'efectiva_en': '2026-11-01T14:00:00Z',
          'registrada_en': '2026-11-01T14:01:00Z',
          'puntual': true,
          'nota': 'Dosis tomada',
        };

        final result = DoseOperationResult.fromRegistroDosisResponse(
          validJson,
          idempotencyKey: 'key-706',
          generacion: 3,
        );

        expect(result.estado, equals('CONFIRMADA'));
        expect(result.confirmado, isTrue);
        expect(result.enCurso, isFalse);
        expect(result.rechazado, isFalse);
        expect(result.noIniciada, isFalse);
        expect(result.idDosis, equals(706));
        expect(result.idempotencyKey, equals('key-706'));
        expect(result.generacion, equals(3));
        expect(result.dosisModel?.esIngerida, isTrue);
        expect(result.dosisModel?.esPuntual, isTrue);

        // JSON con id_dosis no positivo lanza FormatException
        expect(
          () => DoseOperationResult.fromRegistroDosisResponse({
            'id_dosis': 0,
            'estado': 'INGERIDA',
          }, idempotencyKey: 'key-bad'),
          throwsA(isA<FormatException>()),
        );

        expect(
          () => DoseOperationResult.fromRegistroDosisResponse({
            'estado': 'INGERIDA',
          }, idempotencyKey: 'key-no-id'),
          throwsA(isA<FormatException>()),
        );
      },
    );
  });
}
