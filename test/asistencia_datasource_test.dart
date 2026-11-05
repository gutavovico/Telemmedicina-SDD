import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_telemedicina/core/config/api_config.dart';
import 'package:mobile_telemedicina/core/network/api_client_interface.dart';
import 'package:mobile_telemedicina/features/ai_assistant/data/datasources/asistencia_remote_datasource.dart';

/// Fake que registra llamadas a URLs, bodies y parámetros para aserciones de red.
class FakeApiClient implements ApiClientInterface {
  String? lastGetUrl;
  String? lastPostUrl;
  dynamic lastPostBody;
  dynamic getResponse;
  dynamic postResponse;

  @override
  Future<dynamic> get(
    String url, {
    bool includeAuth = true,
    String? authToken,
  }) async {
    lastGetUrl = url;
    return getResponse;
  }

  @override
  Future<dynamic> post(
    String url, {
    dynamic body,
    bool includeAuth = true,
  }) async {
    lastPostUrl = url;
    lastPostBody = body;
    return postResponse;
  }

  @override
  Future<Uint8List> downloadBytes(String url, {bool includeAuth = true}) async {
    return Uint8List(0);
  }
}

Map<String, dynamic> evaluacionJsonMock() => {
      'id_evaluacion': 105,
      'id_paciente': 32,
      'fecha_evaluacion': '2026-11-04T08:30:00Z',
      'estado_evaluacion': 'COMPLETADA',
      'nivel_riesgo_global': 'ALTO',
      'total_medicamentos_analizados': 2,
      'total_alertas_detectadas': 1,
      'resumen_ejecutivo': 'Se detectó 1 interacción farmacológica.',
      'aviso_legal': 'Aviso RF-25',
      'medicamentos_analizados': [],
      'alertas': [],
      'recomendaciones': [],
    };

Map<String, dynamic> historialJsonMock() => {
      'items': [
        {
          'id_evaluacion': 105,
          'id_paciente': 32,
          'fecha_evaluacion': '2026-11-04T08:30:00Z',
          'estado_evaluacion': 'COMPLETADA',
          'nivel_riesgo_global': 'ALTO',
          'total_medicamentos_analizados': 2,
          'total_alertas_detectadas': 1,
          'resumen_ejecutivo': 'Resumen',
        }
      ],
      'total': 1,
      'page': 1,
      'limit': 10,
      'total_paginas': 1,
    };

void main() {
  group('AsistenciaRemoteDatasource - Pruebas Unitarias de Red y Parámetros', () {
    late FakeApiClient fakeApi;
    late AsistenciaRemoteDatasource datasource;

    setUp(() {
      fakeApi = FakeApiClient();
      datasource = AsistenciaRemoteDatasource(apiClient: fakeApi);
    });

    test('buildHistorialQueryParams genera exactamente page y limit sin campos prohibidos', () {
      final params = AsistenciaRemoteDatasource.buildHistorialQueryParams(
        page: 2,
        limit: 15,
      );

      expect(params['page'], equals('2'));
      expect(params['limit'], equals('15'));
      expect(params.containsKey('id_paciente'), isFalse);
      expect(params.containsKey('id_clinica'), isFalse);
      expect(params.containsKey('tenant_id'), isFalse);
    });

    test('evaluarTratamiento envía POST a la ruta correcta con forzar_recalculo', () async {
      fakeApi.postResponse = evaluacionJsonMock();

      final res = await datasource.evaluarTratamiento(forzarRecalculo: true);

      expect(fakeApi.lastPostUrl, equals(ApiConfig.assistanceEvaluateUrl));
      expect(fakeApi.lastPostBody, equals({'forzar_recalculo': true}));
      expect(res.idEvaluacion, equals(105));
    });

    test('getHistorial envía GET con query params exactos a la ruta de historial', () async {
      fakeApi.getResponse = historialJsonMock();

      final res = await datasource.getHistorial(page: 1, limit: 10);

      expect(
        fakeApi.lastGetUrl,
        equals('${ApiConfig.assistanceHistoryUrl}?page=1&limit=10'),
      );
      expect(res.items.length, equals(1));
      expect(res.total, equals(1));
    });

    test('getEvaluacionById envía GET con el id en la ruta exacta', () async {
      fakeApi.getResponse = evaluacionJsonMock();

      final res = await datasource.getEvaluacionById(105);

      expect(
        fakeApi.lastGetUrl,
        equals(ApiConfig.assistanceDetailUrl(105)),
      );
      expect(res.idEvaluacion, equals(105));
    });
  });
}

