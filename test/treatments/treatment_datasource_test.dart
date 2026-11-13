import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_telemedicina/core/network/api_client_interface.dart';
import 'package:mobile_telemedicina/core/network/api_exceptions.dart';
import 'package:mobile_telemedicina/features/treatments/data/datasources/treatment_remote_datasource.dart';

class MockApiClient implements ApiClientInterface {
  String? lastGetUrl;
  String? lastPostUrl;
  String? lastPatchUrl;
  String? lastDeleteUrl;
  dynamic lastPostBody;
  dynamic lastPatchBody;
  Map<String, String>? lastHeaders;

  dynamic getResponse;
  dynamic postResponse;
  dynamic patchResponse;
  dynamic deleteResponse;
  Exception? exceptionToThrow;

  @override
  Future<dynamic> get(
    String url, {
    bool includeAuth = true,
    String? authToken,
    Map<String, String>? headers,
  }) async {
    lastGetUrl = url;
    lastHeaders = headers;
    if (exceptionToThrow != null) throw exceptionToThrow!;
    return getResponse;
  }

  @override
  Future<dynamic> post(
    String url, {
    dynamic body,
    bool includeAuth = true,
    Map<String, String>? headers,
  }) async {
    lastPostUrl = url;
    lastPostBody = body;
    lastHeaders = headers;
    if (exceptionToThrow != null) throw exceptionToThrow!;
    return postResponse;
  }

  @override
  Future<dynamic> patch(
    String url, {
    dynamic body,
    bool includeAuth = true,
    Map<String, String>? headers,
  }) async {
    lastPatchUrl = url;
    lastPatchBody = body;
    lastHeaders = headers;
    if (exceptionToThrow != null) throw exceptionToThrow!;
    return patchResponse;
  }

  @override
  Future<dynamic> delete(
    String url, {
    bool includeAuth = true,
    Map<String, String>? headers,
  }) async {
    lastDeleteUrl = url;
    lastHeaders = headers;
    if (exceptionToThrow != null) throw exceptionToThrow!;
    return deleteResponse;
  }

  @override
  Future<Uint8List> downloadBytes(String url, {bool includeAuth = true}) async {
    return Uint8List(0);
  }
}

void main() {
  late MockApiClient mockClient;
  late TreatmentRemoteDatasource datasource;

  setUp(() {
    mockClient = MockApiClient();
    datasource = TreatmentRemoteDatasource(apiClient: mockClient);
  });

  group('TreatmentRemoteDatasource', () {
    test('getTreatments envía parámetros skip, limit y estado', () async {
      mockClient.getResponse = {
        'items': [
          {
            'id_tratamiento': 1,
            'id_clinica': 1,
            'id_consulta': 10,
            'id_receta': 20,
            'id_diagnostico': 30,
            'id_paciente': 5,
            'id_medico': 7,
            'fecha_inicio': '2026-11-01',
            'fecha_fin': '2026-11-15',
            'zona_horaria': 'America/La_Paz',
            'estado': 'ACTIVO',
            'medicamentos': [],
          }
        ],
        'total': 1,
      };

      final result = await datasource.getTreatments(
        estado: 'ACTIVO',
        skip: 0,
        limit: 10,
      );

      expect(
        mockClient.lastGetUrl,
        contains('/api/v1/tratamientos?skip=0&limit=10&estado=ACTIVO'),
      );
      expect(result['total'], equals(1));
      expect(result['items'].length, equals(1));
    });

    test('getTreatmentDetail consulta la ruta exacta del id', () async {
      mockClient.getResponse = {
        'id_tratamiento': 42,
        'id_clinica': 1,
        'id_consulta': 10,
        'id_paciente': 5,
        'id_medico': 7,
        'fecha_inicio': '2026-11-01',
        'fecha_fin': '2026-11-15',
        'zona_horaria': 'America/La_Paz',
        'estado': 'ACTIVO',
        'medicamentos': [],
      };

      final plan = await datasource.getTreatmentDetail(42);

      expect(mockClient.lastGetUrl, endsWith('/api/v1/tratamientos/42'));
      expect(plan.idTratamiento, equals(42));
    });

    test('getCronograma envía fecha como query parameter', () async {
      mockClient.getResponse = {
        'id_tratamiento': 42,
        'fecha': '2026-11-02',
        'zona_horaria': 'America/La_Paz',
        'dosis': [],
        'adherencia': null,
      };

      final cronograma = await datasource.getCronograma(42, '2026-11-02');

      expect(
        mockClient.lastGetUrl,
        endsWith('/api/v1/tratamientos/42/cronograma?fecha=2026-11-02'),
      );
      expect(cronograma.fecha, equals('2026-11-02'));
    });

    test('getAdherencia consulta el endpoint de adherencia', () async {
      mockClient.getResponse = {
        'numerador_puntual': 5,
        'denominador_programado': 6,
        'porcentaje': 83.3,
        'nivel': 'OPTIMA',
        'calculado_en': '2026-11-02T12:00:00Z',
      };

      final adherencia = await datasource.getAdherencia(42);

      expect(
        mockClient.lastGetUrl,
        endsWith('/api/v1/tratamientos/42/adherencia'),
      );
      expect(adherencia.nivel, equals('OPTIMA'));
      expect(adherencia.porcentaje, equals(83.3));
    });

    test('iniciarIntentoDosis envía POST con request_hash e Idempotency-Key',
        () async {
      mockClient.postResponse = {
        'id_dosis': 501,
        'idempotency_key': 'key-abc',
        'estado': 'EN_CURSO',
        'confirmado': false,
        'en_curso': true,
        'rechazado': false,
        'dosis': null,
        'mensaje': 'Operación en curso',
        'generacion': 1,
      };

      final op = await datasource.iniciarIntentoDosis(
        501,
        'key-abc',
        'hash-123456',
      );

      expect(
        mockClient.lastPostUrl,
        endsWith('/api/v1/tratamientos/dosis/501/intentos'),
      );
      expect(mockClient.lastPostBody, equals({'request_hash': 'hash-123456'}));
      expect(mockClient.lastHeaders?['Idempotency-Key'], equals('key-abc'));
      expect(op.enCurso, isTrue);
    });

    test('registrarDosis envía POST con body completo e Idempotency-Key',
        () async {
      mockClient.postResponse = {
        'id_dosis': 501,
        'id_medicamento_plan': 12,
        'programada_en': '2026-11-01T12:00:00Z',
        'programada_hora_local': '08:00',
        'zona_horaria': 'America/La_Paz',
        'estado': 'INGERIDA',
        'vencida': false,
        'efectiva_en': '2026-11-01T12:05:00Z',
        'registrada_en': '2026-11-01T12:06:00Z',
        'puntual': true,
        'nota': 'Con comida',
      };

      final body = {
        'estado': 'INGERIDA',
        'efectiva_en': '2026-11-01T12:05:00Z',
        'nota': 'Con comida',
      };

      final dosis = await datasource.registrarDosis(501, 'key-reg-1', body);

      expect(
        mockClient.lastPostUrl,
        endsWith('/api/v1/tratamientos/dosis/501/registros'),
      );
      expect(mockClient.lastPostBody, equals(body));
      expect(mockClient.lastHeaders?['Idempotency-Key'], equals('key-reg-1'));
      expect(dosis.estado, equals('INGERIDA'));
      expect(dosis.puntual, isTrue);
    });

    test('consultarIdempotencia consulta el endpoint de idempotencia', () async {
      mockClient.getResponse = {
        'id_dosis': 501,
        'idempotency_key': 'key-check',
        'estado': 'CONFIRMADA',
        'confirmado': true,
        'en_curso': false,
        'rechazado': false,
        'dosis': {
          'id_dosis': 501,
          'id_medicamento_plan': 12,
          'programada_en': '2026-11-01T12:00:00Z',
          'programada_hora_local': '08:00',
          'zona_horaria': 'America/La_Paz',
          'estado': 'INGERIDA',
          'vencida': false,
          'efectiva_en': '2026-11-01T12:05:00Z',
          'registrada_en': '2026-11-01T12:06:00Z',
          'puntual': true,
          'nota': null,
        },
        'mensaje': null,
        'generacion': 1,
      };

      final op = await datasource.consultarIdempotencia(501, 'key-check');

      expect(
        mockClient.lastGetUrl,
        endsWith('/api/v1/tratamientos/dosis/501/registros/idempotencia/key-check'),
      );
      expect(op.confirmado, isTrue);
      expect(op.dosis?.estado, equals('INGERIDA'));
    });

    test('resolverOperacionAbandonada llama al resolver endpoint', () async {
      mockClient.postResponse = {
        'id_dosis': 501,
        'idempotency_key': 'key-lost',
        'estado': 'RECHAZADA',
        'confirmado': false,
        'en_curso': false,
        'rechazado': true,
        'dosis': null,
        'mensaje': 'Operación resuelta como rechazada tras abandono',
        'generacion': 1,
      };

      final op = await datasource.resolverOperacionAbandonada(501, 'key-lost');

      expect(
        mockClient.lastPostUrl,
        endsWith(
            '/api/v1/tratamientos/dosis/501/registros/idempotencia/key-lost/resolver'),
      );
      expect(op.rechazado, isTrue);
    });

    test('getAvisos y leerAviso con PATCH', () async {
      mockClient.getResponse = {
        'items': [
          {
            'id_aviso': 99,
            'id_tratamiento': 42,
            'id_dosis': 501,
            'tipo': 'RECORDATORIO_PREVIO',
            'canal': 'WEB',
            'titulo': 'Toma próxima',
            'mensaje': 'Recuerde tomar su medicamento',
            'estado': 'PENDIENTE',
            'programada_en': '2026-11-01T11:30:00Z',
            'enviada_en': null,
            'leida_en': null,
          }
        ],
        'total': 1,
      };

      final avisosResult = await datasource.getAvisos(noLeidos: true);
      expect(
        mockClient.lastGetUrl,
        contains('/api/v1/tratamientos/avisos?skip=0&limit=20&no_leidos=true'),
      );
      expect(avisosResult['total'], equals(1));

      mockClient.patchResponse = {
        'id_aviso': 99,
        'id_tratamiento': 42,
        'id_dosis': 501,
        'tipo': 'RECORDATORIO_PREVIO',
        'canal': 'WEB',
        'titulo': 'Toma próxima',
        'mensaje': 'Recuerde tomar su medicamento',
        'estado': 'ENVIADO',
        'programada_en': '2026-11-01T11:30:00Z',
        'enviada_en': '2026-11-01T11:35:00Z',
        'leida_en': '2026-11-01T11:35:00Z',
      };

      final avisoLeido = await datasource.leerAviso(99);
      expect(
        mockClient.lastPatchUrl,
        endsWith('/api/v1/tratamientos/avisos/99/leer'),
      );
      expect(avisoLeido.leidaEn, isNotNull);
    });

    test('registrarDispositivo y eliminarDispositivo', () async {
      mockClient.postResponse = {
        'id_dispositivo': 15,
        'plataforma': 'ANDROID',
      };

      final reg = await datasource.registrarDispositivo('fcm-token-xyz', 'ANDROID');
      expect(
        mockClient.lastPostUrl,
        endsWith('/api/v1/tratamientos/dispositivos'),
      );
      expect(reg['id_dispositivo'], equals(15));

      mockClient.deleteResponse = null;
      await datasource.eliminarDispositivo(15);
      expect(
        mockClient.lastDeleteUrl,
        endsWith('/api/v1/tratamientos/dispositivos/15'),
      );
    });

    test('Manejo de códigos de error de tratamiento (TREATMENT_*)', () async {
      mockClient.exceptionToThrow = ConflictException(
        'Clave de idempotencia reutilizada con otros datos',
      );

      expect(
        () => datasource.registrarDosis(501, 'key-bad', {'estado': 'OMITIDA'}),
        throwsA(isA<ConflictException>()),
      );

      mockClient.exceptionToThrow = NotFoundException('Dosis no encontrada');
      expect(
        () => datasource.getTreatmentDetail(99999),
        throwsA(isA<NotFoundException>()),
      );

      mockClient.exceptionToThrow = ForbiddenException('Acceso restringido');
      expect(
        () => datasource.registrarDosis(501, 'key-bad', {'estado': 'OMITIDA'}),
        throwsA(isA<ForbiddenException>()),
      );
    });
  });
}
