import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_telemedicina/core/network/api_client_interface.dart';
import 'package:mobile_telemedicina/features/medical_records/data/datasources/prescription_remote_datasource.dart';

/// Fake que registra URLs y devuelve respuestas programadas.
class FakeApiClient implements ApiClientInterface {
  String? lastGetUrl;
  String? lastDownloadUrl;
  dynamic getResponse;
  Uint8List downloadResponse = Uint8List(0);

  @override
  Future<dynamic> get(
    String url, {
    bool includeAuth = true,
    String? authToken,
    Map<String, String>? headers,
  }) async {
    lastGetUrl = url;
    return getResponse;
  }

  @override
  Future<dynamic> post(
    String url, {
    dynamic body,
    bool includeAuth = true,
    Map<String, String>? headers,
  }) async {
    return null;
  }

  @override
  Future<dynamic> patch(
    String url, {
    dynamic body,
    bool includeAuth = true,
    Map<String, String>? headers,
  }) async => null;

  @override
  Future<dynamic> delete(
    String url, {
    bool includeAuth = true,
    Map<String, String>? headers,
  }) async => null;

  @override
  Future<Uint8List> downloadBytes(String url, {bool includeAuth = true}) async {
    lastDownloadUrl = url;
    return downloadResponse;
  }
}

Map<String, dynamic> recetaJson() => {
  'id_receta': 58,
  'id_clinica': 1,
  'id_consulta': 45,
  'id_paciente': 10,
  'id_medico': 3,
  'id_documento': 210,
  'id_receta_sustituta': null,
  'folio': 'REC-2026-000058',
  'pdf_url': '/api/v1/recetas/58/pdf',
  'indicaciones_generales': null,
  'algoritmo_firma': 'ED25519',
  'key_id': 'prescriptions-2026-01',
  'version_payload': 1,
  'hash_pdf': 'abc',
  'fecha_emision': '2026-09-22T22:30:00Z',
  'fecha_vencimiento': '2026-10-22',
  'esta_vencida': false,
  'estado': 'EMITIDA',
  'motivo_anulacion': null,
  'observaciones_anulacion': null,
  'fecha_anulacion': null,
  'medico': {
    'id_medico': 3,
    'nombre_completo': 'Dr. Test',
    'matricula_profesional': 'MP-1',
    'especialidad': null,
  },
  'paciente': {'id_paciente': 10, 'nombre_completo': 'Paciente Test'},
  'detalles': [],
};

void main() {
  group('PrescriptionRemoteDatasource query params', () {
    test('construye query exacta con estado/desde/hasta/skip/limit', () async {
      final fake = FakeApiClient()
        ..getResponse = {
          'items': [recetaJson()],
          'total': 1,
        };
      final ds = PrescriptionRemoteDatasource(apiClient: fake);

      await ds.getMyPrescriptions(
        estado: 'EMITIDA',
        desde: '2026-09-01',
        hasta: '2026-09-30',
        skip: 20,
        limit: 20,
      );

      final uri = Uri.parse(fake.lastGetUrl!);
      expect(uri.queryParameters['estado'], 'EMITIDA');
      expect(uri.queryParameters['desde'], '2026-09-01');
      expect(uri.queryParameters['hasta'], '2026-09-30');
      expect(uri.queryParameters['skip'], '20');
      expect(uri.queryParameters['limit'], '20');
      expect(uri.path, '/api/v1/recetas');
    });

    test('omite filtros vacíos pero siempre envía skip/limit', () async {
      final fake = FakeApiClient()..getResponse = {'items': [], 'total': 0};
      final ds = PrescriptionRemoteDatasource(apiClient: fake);

      await ds.getMyPrescriptions();

      final uri = Uri.parse(fake.lastGetUrl!);
      expect(uri.queryParameters.containsKey('estado'), false);
      expect(uri.queryParameters.containsKey('desde'), false);
      expect(uri.queryParameters.containsKey('hasta'), false);
      expect(uri.queryParameters['skip'], '0');
      expect(uri.queryParameters['limit'], '20');
    });

    test('nunca envía id_paciente/id_medico/id_clinica/tenant_id', () async {
      final fake = FakeApiClient()..getResponse = {'items': [], 'total': 0};
      final ds = PrescriptionRemoteDatasource(apiClient: fake);

      await ds.getMyPrescriptions(
        estado: 'ANULADA',
        desde: '2026-01-01',
        hasta: '2026-12-31',
        skip: 0,
        limit: 20,
      );

      final url = fake.lastGetUrl!;
      expect(url, isNot(contains('id_paciente')));
      expect(url, isNot(contains('id_medico')));
      expect(url, isNot(contains('id_clinica')));
      expect(url, isNot(contains('tenant_id')));
      expect(url, isNot(contains('tenantId')));

      final params = PrescriptionRemoteDatasource.buildListQueryParams(
        estado: 'EMITIDA',
        skip: 0,
        limit: 20,
      );
      expect(params.containsKey('id_paciente'), false);
      expect(params.containsKey('id_medico'), false);
      expect(params.containsKey('id_clinica'), false);
      expect(params.containsKey('tenant_id'), false);
    });

    test('detalle usa ruta exacta /api/v1/recetas/{id}', () async {
      final fake = FakeApiClient()..getResponse = recetaJson();
      final ds = PrescriptionRemoteDatasource(apiClient: fake);

      await ds.getPrescriptionById(58);

      expect(fake.lastGetUrl, endsWith('/api/v1/recetas/58'));
    });

    test('pdf usa endpoint autenticado /api/v1/recetas/{id}/pdf', () async {
      final fake = FakeApiClient()
        ..downloadResponse = Uint8List.fromList([1, 2, 3]);
      final ds = PrescriptionRemoteDatasource(apiClient: fake);

      await ds.downloadPrescriptionPdf(58);

      expect(fake.lastDownloadUrl, endsWith('/api/v1/recetas/58/pdf'));
    });
  });
}
