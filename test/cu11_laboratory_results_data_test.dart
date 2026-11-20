import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_telemedicina/core/config/api_config.dart';
import 'package:mobile_telemedicina/core/network/api_client_interface.dart';
import 'package:mobile_telemedicina/core/network/api_exceptions.dart';
import 'package:mobile_telemedicina/features/medical_records/data/models/laboratory_result_model.dart';
import 'package:mobile_telemedicina/features/medical_records/data/repositories/laboratory_result_repository_impl.dart';
import 'package:mobile_telemedicina/features/medical_records/data/services/lab_result_error_mapper.dart';
import 'package:mobile_telemedicina/features/medical_records/data/services/laboratory_result_service.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/entities/laboratory_result.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/failures/lab_result_failure.dart';

/// Cliente HTTP simulado: registra llamadas y devuelve/lanza lo configurado.
class _FakeApiClient implements ApiClientInterface {
  final List<String> getCalls = [];
  final List<String> downloadCalls = [];
  final List<Map<String, String>?> getHeaders = [];
  dynamic getResponse;
  Object? getError;
  Uint8List downloadResponse = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D]);
  Object? downloadError;

  @override
  Future<dynamic> get(
    String url, {
    bool includeAuth = true,
    String? authToken,
    Map<String, String>? headers,
  }) async {
    getCalls.add(url);
    getHeaders.add(headers);
    final error = getError;
    if (error != null) throw error;
    return getResponse;
  }

  @override
  Future<Uint8List> downloadBytes(String url, {bool includeAuth = true}) async {
    downloadCalls.add(url);
    final error = downloadError;
    if (error != null) throw error;
    return downloadResponse;
  }

  @override
  Future<dynamic> post(String url,
          {dynamic body, bool includeAuth = true, Map<String, String>? headers}) async =>
      throw StateError('CU11 móvil es solo lectura: no debe llamar POST');

  @override
  Future<dynamic> patch(String url,
          {dynamic body, bool includeAuth = true, Map<String, String>? headers}) async =>
      throw StateError('CU11 móvil es solo lectura: no debe llamar PATCH');

  @override
  Future<dynamic> delete(String url,
          {bool includeAuth = true, Map<String, String>? headers}) async =>
      throw StateError('CU11 móvil es solo lectura: no debe llamar DELETE');
}

Map<String, dynamic> _fullItem() => {
      'id_resultado': 7,
      'id_clinica': 1,
      'estado': 'INCORPORADO',
      'origen': 'MANUAL',
      'id_paciente': 3,
      'paciente_nombre': 'Carlos Pérez',
      'id_orden': 12,
      'id_examen': 4,
      'codigo_examen': 'HEM-01',
      'nombre_examen': 'Hemograma completo',
      'laboratorio_origen': 'Laboratorio Central',
      'fecha_realizacion': '2026-05-10',
      'observaciones': 'Valores normales',
      'nombre_archivo': 'hemograma.pdf',
      'content_type': 'application/pdf',
      'tamano_bytes': 2048,
      'hash_archivo': 'abc123',
      'id_documento': 55,
      'id_fuente': null,
      'fuente_codigo': null,
      'id_externo': null,
      'id_sincronizacion': null,
      'motivo_pendiente': null,
      'datos_correspondencia': null,
      'registrado_por': 9,
      'registrado_por_nombre': 'Ana Lab',
      'proceso': null,
      'registrado_en': '2026-05-10T12:00:00',
      'resuelto_por': null,
      'resuelto_en': null,
      'motivo_resolucion': null,
    };

Map<String, dynamic> _pageJson(List<Map<String, dynamic>> items,
        {int page = 1, int totalPages = 1}) =>
    {
      'items': items,
      'total': items.length,
      'page': page,
      'page_size': 10,
      'total_pages': totalPages,
    };

LaboratoryResultRepositoryImpl _repo(_FakeApiClient client) =>
    LaboratoryResultRepositoryImpl(service: LaboratoryResultService(apiClient: client));

Future<LabResultFailure> _failureOf(Future<dynamic> Function() action) async {
  try {
    await action();
  } on LabResultFailure catch (e) {
    return e;
  }
  fail('Se esperaba LabResultFailure');
}

void main() {
  group('LaboratoryResultModel (parseo según contrato)', () {
    test('parsea todos los campos del contrato', () {
      final model = LaboratoryResultModel.fromJson(_fullItem());
      expect(model.idResultado, 7);
      expect(model.estado, 'INCORPORADO');
      expect(model.codigoExamen, 'HEM-01');
      expect(model.observaciones, 'Valores normales');
      expect(model.hashArchivo, 'abc123');
      expect(model.tamanoBytes, 2048);
      expect(model.contentType, 'application/pdf');
      expect(model.toEntity().estado, LabResultStatus.incorporado);
      expect(model.toEntity().estudio, 'Hemograma completo');
    });

    test('tolera campos ocultos/ausentes (observaciones, hash_archivo)', () {
      final json = _fullItem()
        ..remove('observaciones')
        ..remove('hash_archivo')
        ..remove('datos_correspondencia');
      final model = LaboratoryResultModel.fromJson(json);
      expect(model.observaciones, isNull);
      expect(model.hashArchivo, isNull);
      expect(model.toEntity().observaciones, isNull);
    });

    test('tolera valores null y json mínimo sin lanzar', () {
      final model = LaboratoryResultModel.fromJson({
        'id_resultado': 1,
        'estado': 'INCORPORADO',
        'observaciones': null,
        'hash_archivo': null,
        'nombre_examen': null,
        'codigo_examen': 'GLU-01',
      });
      expect(model.idResultado, 1);
      expect(model.toEntity().estudio, 'GLU-01'); // sin nombre usa el código
      expect(model.tamanoBytes, 0);
    });

    test('toJson conserva las claves del contrato (round-trip)', () {
      final original = _fullItem();
      final back = LaboratoryResultModel.fromJson(original).toJson();
      for (final key in original.keys) {
        expect(back.containsKey(key), isTrue, reason: 'falta $key');
        expect(back[key], original[key], reason: 'distinto $key');
      }
    });

    test('toJson no incluye tenant_id (la clínica viene solo de la sesión)', () {
      expect(LaboratoryResultModel.fromJson(_fullItem()).toJson().containsKey('tenant_id'), isFalse);
    });

    test('estado desconocido no rompe', () {
      expect(labResultStatusFromString('OTRO'), LabResultStatus.desconocido);
      expect(labResultStatusFromString(null), LabResultStatus.desconocido);
      expect(labResultStatusFromString('PENDIENTE_REVISION'), LabResultStatus.pendienteRevision);
      expect(labResultStatusFromString('ANULADO'), LabResultStatus.anulado);
    });

    test('página: parsea paginación y hasMore', () {
      final page = LaboratoryResultPageModel.fromJson(
        _pageJson([_fullItem()], page: 1, totalPages: 3),
      ).toEntity();
      expect(page.items, hasLength(1));
      expect(page.hasMore, isTrue);
      expect(page.totalPages, 3);
    });

    test('página vacía o sin claves no rompe', () {
      final page = LaboratoryResultPageModel.fromJson(const {}).toEntity();
      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
    });
  });

  group('LabResultErrorMapper (3 formas de detail + estados)', () {
    LabResultFailure map(ApiException e, [LabResultOperation op = LabResultOperation.list]) =>
        LabResultErrorMapper.fromApiException(e, operation: op);

    test('detail objeto {codigo, mensaje}: RESULTADO_NO_ENCONTRADO', () {
      final f = map(
        ApiException(
          message: 'x',
          statusCode: 404,
          details: {
            'detail': {'codigo': 'RESULTADO_NO_ENCONTRADO', 'mensaje': 'no existe'},
          },
        ),
        LabResultOperation.file,
      );
      expect(f.kind, LabResultFailureKind.notFound);
    });

    test('detail objeto: ARCHIVO_NO_ENCONTRADO', () {
      final f = map(
        ApiException(
          message: 'x',
          statusCode: 404,
          details: {
            'detail': {'codigo': 'ARCHIVO_NO_ENCONTRADO', 'mensaje': 'sin archivo'},
          },
        ),
        LabResultOperation.file,
      );
      expect(f.kind, LabResultFailureKind.fileNotFound);
    });

    test('detail objeto: PACIENTE_NO_ENCONTRADO en /me', () {
      final f = map(
        ApiException(
          message: 'x',
          statusCode: 404,
          details: {
            'detail': {'codigo': 'PACIENTE_NO_ENCONTRADO', 'mensaje': 'sin perfil'},
          },
        ),
      );
      expect(f.kind, LabResultFailureKind.noPatientProfile);
    });

    test('detail lista de validación FastAPI (422) usa el primer msg', () {
      final f = map(
        ApiException(
          message: 'Error de validación',
          statusCode: 422,
          details: {
            'detail': [
              {'loc': ['query', 'page'], 'msg': 'Input should be greater than or equal to 1'},
            ],
          },
        ),
      );
      expect(f.kind, LabResultFailureKind.unknown);
      expect(f.message, contains('greater than or equal to 1'));
    });

    test('detail texto plano en 403 con documents:read:lab_results -> downloadForbidden', () {
      final f = map(
        ForbiddenException('Permiso requerido: documents:read:lab_results'),
        LabResultOperation.file,
      );
      expect(f.kind, LabResultFailureKind.downloadForbidden);
      expect(f.message, contains('permiso'));
    });

    test('detail texto en details (String) también se interpreta', () {
      final f = map(
        ApiException(
          message: 'x',
          statusCode: 403,
          details: 'Permiso requerido: documents:read:lab_results',
        ),
        LabResultOperation.file,
      );
      expect(f.kind, LabResultFailureKind.downloadForbidden);
    });

    test('403 genérico -> forbidden; 403 de clínica -> noClinic', () {
      expect(map(ForbiddenException('Prohibido')).kind, LabResultFailureKind.forbidden);
      expect(
        map(ForbiddenException('El usuario no tiene clínica asociada')).kind,
        LabResultFailureKind.noClinic,
      );
    });

    test('401 -> sessionExpired', () {
      final f = map(UnauthorizedException());
      expect(f.kind, LabResultFailureKind.sessionExpired);
      expect(f.message, contains('sesión'));
    });

    test('404 sin código: /me = sin perfil de paciente; /archivo = no disponible', () {
      expect(map(NotFoundException()).kind, LabResultFailureKind.noPatientProfile);
      expect(map(NotFoundException(), LabResultOperation.file).kind, LabResultFailureKind.notFound);
    });

    test('red y timeout', () {
      expect(map(NetworkException()).kind, LabResultFailureKind.network);
      final t = map(TimeoutException(), LabResultOperation.file);
      expect(t.kind, LabResultFailureKind.timeout);
      expect(t.message, contains('descarga'));
    });

    test('5xx -> server', () {
      expect(map(ServerException()).kind, LabResultFailureKind.server);
    });

    test('error no HTTP -> unknown con mensaje genérico', () {
      final f = LabResultErrorMapper.fromError(StateError('boom'), operation: LabResultOperation.list);
      expect(f.kind, LabResultFailureKind.unknown);
      expect(f.message, isNot(contains('boom'))); // no filtra detalles internos
    });
  });

  group('LaboratoryResultRepositoryImpl (respuestas simuladas)', () {
    test('éxito: GET /me con page/page_size y sin id_clinica/tenant_id', () async {
      final client = _FakeApiClient()..getResponse = _pageJson([_fullItem()]);
      final page = await _repo(client).getMyResults(page: 2, pageSize: 5);

      expect(page.items.single.idResultado, 7);
      final url = client.getCalls.single;
      expect(url, startsWith(ApiConfig.myLabResultsUrl));
      expect(url, contains('page=2'));
      expect(url, contains('page_size=5'));
      expect(url, isNot(contains('tenant')));
      expect(url, isNot(contains('id_clinica')));
    });

    test('éxito: filtros opcionales se envían solo si existen', () async {
      final client = _FakeApiClient()..getResponse = _pageJson([]);
      await _repo(client).getMyResults(codigoExamen: ' HEM-01 ', fechaDesde: '2026-01-01');
      final url = client.getCalls.single;
      expect(url, contains('codigo_examen=HEM-01'));
      expect(url, contains('fecha_desde=2026-01-01'));
      expect(url, isNot(contains('fecha_hasta')));
    });

    test('éxito: descarga bytes de /{id}/archivo', () async {
      final client = _FakeApiClient();
      final bytes = await _repo(client).downloadFile(7);
      expect(bytes, isNotEmpty);
      expect(client.downloadCalls.single, ApiConfig.labResultFileUrl(7));
      expect(client.downloadCalls.single, endsWith('/api/v1/resultados-laboratorio/7/archivo'));
    });

    test('401 -> sessionExpired', () async {
      final client = _FakeApiClient()..getError = UnauthorizedException();
      final f = await _failureOf(() => _repo(client).getMyResults());
      expect(f.kind, LabResultFailureKind.sessionExpired);
    });

    test('403 en descarga sin documents:read:lab_results -> downloadForbidden', () async {
      final client = _FakeApiClient()
        ..downloadError = ForbiddenException('Permiso requerido: documents:read:lab_results');
      final f = await _failureOf(() => _repo(client).downloadFile(7));
      expect(f.kind, LabResultFailureKind.downloadForbidden);
    });

    test('404 en /me -> noPatientProfile; 404 en archivo -> notFound', () async {
      final client = _FakeApiClient()
        ..getError = NotFoundException()
        ..downloadError = NotFoundException();
      final list = await _failureOf(() => _repo(client).getMyResults());
      final file = await _failureOf(() => _repo(client).downloadFile(99));
      expect(list.kind, LabResultFailureKind.noPatientProfile);
      expect(file.kind, LabResultFailureKind.notFound);
    });

    test('fallo de red en listado y en descarga', () async {
      final client = _FakeApiClient()
        ..getError = NetworkException()
        ..downloadError = NetworkException();
      expect((await _failureOf(() => _repo(client).getMyResults())).kind, LabResultFailureKind.network);
      expect((await _failureOf(() => _repo(client).downloadFile(7))).kind, LabResultFailureKind.network);
    });

    test('descarga interrumpida (timeout) -> timeout', () async {
      final client = _FakeApiClient()..downloadError = TimeoutException();
      expect((await _failureOf(() => _repo(client).downloadFile(7))).kind, LabResultFailureKind.timeout);
    });

    test('archivo vacío -> emptyFile', () async {
      final client = _FakeApiClient()..downloadResponse = Uint8List(0);
      expect((await _failureOf(() => _repo(client).downloadFile(7))).kind, LabResultFailureKind.emptyFile);
    });

    test('respuesta inesperada del listado -> página vacía sin romper', () async {
      final client = _FakeApiClient()..getResponse = <dynamic>[];
      final page = await _repo(client).getMyResults();
      expect(page.items, isEmpty);
    });
  });
}
