import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_telemedicina/core/config/api_config.dart';
import 'package:mobile_telemedicina/core/network/api_client_interface.dart';
import 'package:mobile_telemedicina/core/network/api_exceptions.dart';
import 'package:mobile_telemedicina/features/medical_records/data/models/clinical_document_model.dart';
import 'package:mobile_telemedicina/features/medical_records/data/repositories/clinical_document_repository_impl.dart';
import 'package:mobile_telemedicina/features/medical_records/data/services/clinical_document_service.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/entities/clinical_document.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/repositories/clinical_document_repository.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/usecases/download_document_usecase.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/usecases/get_document_detail_usecase.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/usecases/get_my_documents_usecase.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/usecases/get_tenant_documents_usecase.dart';
import 'package:mobile_telemedicina/features/medical_records/presentation/providers/clinical_documents_provider.dart';

class FakeApiClient implements ApiClientInterface {
  final Map<String, dynamic> getResponses = {};
  final Map<String, dynamic> postResponses = {};
  final List<String> getCalls = [];
  Uint8List downloadResponse = Uint8List.fromList([1, 2, 3]);
  Uint8List Function()? downloadBuilder;
  ApiException? downloadFailure;
  final List<bool> downloadAuth = [];
  int getCallsCount = 0;

  @override
  Future<dynamic> get(String url, {bool includeAuth = true, String? authToken, Map<String, String>? headers}) async {
    getCalls.add(url);
    getCallsCount++;
    return getResponses[url.split('?').first];
  }

  @override
  Future<dynamic> post(
    String url, {
    dynamic body,
    bool includeAuth = true,
    Map<String, String>? headers,
  }) async {
    getCalls.add('P:$url');
    return postResponses[url];
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
    getCalls.add('D:$url');
    downloadAuth.add(includeAuth);
    if (downloadFailure != null) {
      final error = downloadFailure!;
      downloadFailure = null;
      throw error;
    }
    return downloadBuilder?.call() ?? downloadResponse;
  }
}

class FakeRepository implements ClinicalDocumentRepository {
  final DocumentoPaginado? paginado;
  final ClinicalDocument? documento;
  final DocumentoDescargable? descargable;
  final Uint8List bytes;
  final bool failDownload;

  FakeRepository({
    this.paginado,
    this.documento,
    this.descargable,
    Uint8List? bytes,
    this.failDownload = false,
  }) : bytes = bytes ?? Uint8List(0);

  @override
  Future<Uint8List> downloadDocumentBytes(int idDocumento) async {
    if (failDownload) throw ApiException(message: 'Acceso denegado al documento.', statusCode: 403);
    return bytes;
  }

  @override
  Future<ClinicalDocument> getDocumentById(int idDocumento) async {
    if (documento == null) throw Exception('not found');
    return documento!;
  }

  @override
  Future<DocumentoPaginado> getMyDocuments({
    int page = 1,
    int pageSize = 20,
    String? tipoDocumento,
    String? q,
  }) async {
    if (paginado == null) throw Exception('empty');
    return paginado!;
  }

  @override
  Future<DocumentoPaginado> getTenantDocuments({
    int page = 1,
    int pageSize = 20,
    String? tipoDocumento,
    String? q,
    int? idPaciente,
    String? fechaDesde,
    String? fechaHasta,
  }) async {
    if (paginado == null) throw Exception('empty');
    return paginado!;
  }

  @override
  Future<DocumentoPaginado> getPatientDocuments({
    required int patientId,
    int page = 1,
    int pageSize = 20,
    String? tipoDocumento,
    String? q,
    String? fechaDesde,
    String? fechaHasta,
  }) async {
    if (paginado == null) throw Exception('empty');
    return paginado!;
  }

  @override
  Future<DocumentoDescargable> requestDownloadUrl(int idDocumento) async {
    if (descargable == null) throw Exception('empty');
    return descargable!;
  }
}

Map<String, dynamic> _docJson({int id = 1, bool incluyePaciente = true}) => {
      'id_documento': id,
      'id_clinica': 1,
      'id_paciente': 12,
      'id_cita': 99,
      'tipo_documento': 'RESULTADO_LAB',
      'titulo': 'Hemograma completo',
      'descripcion': 'Resultados de laboratorio',
      'archivo_url': '/archivos/resultado.pdf',
      'hash_archivo': 'sha256:abc123',
      'firmado_por': 3,
      'fecha_documento': '2026-08-24',
      'metadatos': {'laboratorio': 'Laboratorio Central'},
      'estado': 'ACTIVO',
      'created_at': '2026-08-24T12:00:00Z',
      'updated_at': '2026-08-24T13:00:00Z',
      'paciente_nombre': incluyePaciente ? 'Carlos Mamani' : null,
      'firmante_nombre': 'Dra. Ana Gutiérrez',
    };

void main() {
  group('ClinicalDocumentModel (CU12)', () {
    test('fromJson cumple con el contrato de DocumentoClinicoResponse', () {
      final doc = ClinicalDocumentModel.fromJson(_docJson());
      expect(doc.idDocumento, 1);
      expect(doc.idClinica, 1);
      expect(doc.idPaciente, 12);
      expect(doc.tipoDocumento, 'RESULTADO_LAB');
      expect(doc.titulo, 'Hemograma completo');
      expect(doc.hashArchivo, 'sha256:abc123');
      expect(doc.pacienteNombre, 'Carlos Mamani');
      expect(doc.metadatos, {'laboratorio': 'Laboratorio Central'});
    });

    test('fromJson tolera campos nulos y ausentes', () {
      final doc = ClinicalDocumentModel.fromJson({'id_documento': 2, 'id_clinica': 1, 'id_paciente': 1});
      expect(doc.tipoDocumento, '');
      expect(doc.titulo, '');
      expect(doc.estado, 'ACTIVO');
      expect(doc.idCita, isNull);
      expect(doc.firmadoPor, isNull);
      expect(doc.pacienteNombre, isNull);
    });

    test('toJson redondea todos los campos', () {
      final doc = ClinicalDocumentModel.fromJson(_docJson());
      final json = doc.toJson();
      expect(json['id_documento'], 1);
      expect(json['tipo_documento'], 'RESULTADO_LAB');
      expect(json['archivo_url'], '/archivos/resultado.pdf');
      expect(json['estado'], 'ACTIVO');
    });

    test('DocumentoPaginadoModel.fromJson parsea items y defaults', () {
      final pag = DocumentoPaginadoModel.fromJson({
        'items': [_docJson(), _docJson(id: 2)],
        'total': 12,
        'page': 2,
        'page_size': 20,
        'total_pages': 3,
      });
      expect(pag.items, hasLength(2));
      expect(pag.total, 12);
      expect(pag.page, 2);
      expect(pag.pageSize, 20);
      expect(pag.totalPages, 3);
    });

    test('DocumentoPaginadoModel.fromJson usa defaults cuando faltan campos', () {
      final pag = DocumentoPaginadoModel.fromJson({'items': []});
      expect(pag.items, isEmpty);
      expect(pag.total, 0);
      expect(pag.page, 1);
      expect(pag.pageSize, 10);
      expect(pag.totalPages, 0);
    });

    test('DocumentoDownloadModel.fromJson completa campos', () {
      final dl = DocumentoDownloadModel.fromJson({
        'id_documento': 5,
        'url_firmada': 'http://storage/signed?token=x',
        'expira_en': 60,
        'nombre_archivo': 'resultado.pdf',
        'content_type': 'application/pdf',
      });
      expect(dl.idDocumento, 5);
      expect(dl.urlFirmada, contains('token=x'));
      expect(dl.nombreArchivo, 'resultado.pdf');
      expect(dl.contentType, 'application/pdf');
    });
  });

  group('ApiConfig URLs (CU12)', () {
    test('construye los endpoints de documentos', () {
      expect(ApiConfig.documentsUrl, endsWith('/api/v1/documentos'));
      expect(ApiConfig.myDocumentsUrl, endsWith('/api/v1/documentos/me'));
      expect(ApiConfig.patientDocumentsUrl(7), endsWith('/api/v1/pacientes/7/documentos'));
      expect(ApiConfig.documentDetailUrl(4), endsWith('/api/v1/documentos/4'));
      expect(ApiConfig.documentDownloadUrl(4), endsWith('/api/v1/documentos/4/download'));
      expect(ApiConfig.documentFileUrl(4), endsWith('/api/v1/documentos/4/file'));
      expect(ApiConfig.downloadTimeoutDuration, const Duration(seconds: 60));
    });
  });

  group('ClinicalDocumentService (CU12)', () {
    late FakeApiClient fakeClient;

    setUp(() {
      fakeClient = FakeApiClient();
    });

    test('getMyDocuments arma query y mapea paginación', () async {
      fakeClient.getResponses[ApiConfig.myDocumentsUrl] = {
        'items': [_docJson()],
        'total': 1,
        'page': 1,
        'page_size': 20,
        'total_pages': 1,
      };
      final service = ClinicalDocumentService(apiClient: fakeClient);
      final result = await service.getMyDocuments(tipoDocumento: 'RECETA', q: '  hemograma  ');
      expect(fakeClient.getCalls.first, contains('/documentos/me'));
      expect(fakeClient.getCalls.first, contains('tipo_documento=RECETA'));
      expect(fakeClient.getCalls.first, contains('q=hemograma'));
      expect(result.items, hasLength(1));
      expect(result.items.first.titulo, 'Hemograma completo');
    });

    test('getMyDocuments omite filtros vacíos', () async {
      fakeClient.getResponses[ApiConfig.myDocumentsUrl] = {
        'items': <dynamic>[],
        'total': 0,
        'page': 1,
        'page_size': 20,
        'total_pages': 0,
      };
      final service = ClinicalDocumentService(apiClient: fakeClient);
      await service.getMyDocuments();
      expect(fakeClient.getCalls.first, isNot(contains('tipo_documento')));
      expect(fakeClient.getCalls.first, isNot(contains('q=')));
      expect(fakeClient.getCalls.first, contains('page=1'));
    });

    test('getDocumentById consulta el detalle y mapea', () async {
      final url = ApiConfig.documentDetailUrl(4);
      fakeClient.getResponses[url] = _docJson(id: 4);
      final service = ClinicalDocumentService(apiClient: fakeClient);
      final doc = await service.getDocumentById(4);
      expect(fakeClient.getCalls.first, url);
      expect(doc.idDocumento, 4);
      expect(doc.estado, 'ACTIVO');
    });

    test('requestDownloadUrl genera URL firmada', () async {
      final url = ApiConfig.documentDownloadUrl(4);
      fakeClient.getResponses[url] = {
        'id_documento': 4,
        'url_firmada': 'http://storage/x',
        'expira_en': 60,
        'nombre_archivo': 'x.pdf',
        'content_type': 'application/pdf',
      };
      final service = ClinicalDocumentService(apiClient: fakeClient);
      final dl = await service.requestDownloadUrl(4);
      expect(fakeClient.getCalls.first, url);
      expect(dl.urlFirmada, 'http://storage/x');
    });

    test('downloadDocumentBytes lanza StateError si no hay URL firmada', () async {
      final url = ApiConfig.documentDownloadUrl(4);
      fakeClient.getResponses[url] = {
        'id_documento': 4,
        'url_firmada': '',
        'expira_en': 0,
        'nombre_archivo': 'x.pdf',
        'content_type': 'application/pdf',
      };
      final service = ClinicalDocumentService(apiClient: fakeClient);
      expect(
        () => service.downloadDocumentBytes(4),
        throwsA(isA<StateError>()),
      );
    });

    test('downloadDocumentBytes descarga bytes con la URL firmada', () async {
      final url = ApiConfig.documentDownloadUrl(4);
      fakeClient.getResponses[url] = {
        'id_documento': 4,
        'url_firmada': 'http://storage/signed',
        'expira_en': 60,
        'nombre_archivo': 'x.pdf',
        'content_type': 'application/pdf',
      };
      final service = ClinicalDocumentService(apiClient: fakeClient);
      final bytes = await service.downloadDocumentBytes(4);
      expect(bytes, [1, 2, 3]);
      expect(fakeClient.getCalls, contains('D:http://storage/signed'));
      expect(fakeClient.downloadAuth, [false]);
    });

    test('URL local usa ruta autenticada por ID en el host configurado', () async {
      fakeClient.getResponses[ApiConfig.documentDownloadUrl(4)] = {
        'id_documento': 4,
        'url_firmada': 'http://localhost:8000/api/v1/documentos/file/documentos/a.pdf',
        'expira_en': 60,
        'nombre_archivo': 'a.pdf',
        'content_type': 'application/pdf',
      };
      await ClinicalDocumentService(apiClient: fakeClient).downloadDocumentBytes(4);
      expect(fakeClient.getCalls, contains('D:${ApiConfig.documentFileUrl(4)}'));
      expect(fakeClient.downloadAuth, [true]);
    });

    test('si falla R2 reintenta por backend con ID autorizado', () async {
      fakeClient.getResponses[ApiConfig.documentDownloadUrl(4)] = {
        'id_documento': 4,
        'url_firmada': 'https://storage.example/documentos/a.pdf?token=x',
        'expira_en': 60,
        'nombre_archivo': 'a.pdf',
        'content_type': 'application/pdf',
      };
      fakeClient.downloadFailure = NetworkException();
      await ClinicalDocumentService(apiClient: fakeClient).downloadDocumentBytes(4);
      expect(fakeClient.getCalls, contains('D:${ApiConfig.documentFileUrl(4)}'));
      expect(fakeClient.downloadAuth, [false, true]);
    });
  });

  group('ClinicalDocumentRepositoryImpl (CU12)', () {
    test('mapea servicio → dominio en todas las operaciones', () async {
      final fakeClient = FakeApiClient();
      fakeClient.getResponses[ApiConfig.myDocumentsUrl] = {
        'items': [_docJson()],
        'total': 1,
        'page': 1,
        'page_size': 20,
        'total_pages': 1,
      };
      fakeClient.getResponses[ApiConfig.documentDetailUrl(1)] = _docJson();
      const dl = 'http://storage/x';
      fakeClient.getResponses[ApiConfig.documentDownloadUrl(1)] = {
        'id_documento': 1,
        'url_firmada': dl,
        'expira_en': 60,
        'nombre_archivo': 'x.pdf',
        'content_type': 'application/pdf',
      };
      final repo = ClinicalDocumentRepositoryImpl(
        service: ClinicalDocumentService(apiClient: fakeClient),
      );

      final pag = await repo.getMyDocuments();
      expect(pag, isA<DocumentoPaginado>());
      expect(pag.items.first.titulo, 'Hemograma completo');

      final doc = await repo.getDocumentById(1);
      expect(doc.idDocumento, 1);
      expect(doc.estaActivo, isTrue);
      expect(doc.estado, 'ACTIVO');

      final desc = await repo.requestDownloadUrl(1);
      expect(desc.urlFirmada, dl);
      expect(desc.idDocumento, 1);

      final bytes = await repo.downloadDocumentBytes(1);
      expect(bytes, [1, 2, 3]);
    });
  });

  group('Use Cases (CU12)', () {
    final pag = const DocumentoPaginado(items: [], total: 0, page: 1, pageSize: 20, totalPages: 1);
    final doc = const ClinicalDocument(
      idDocumento: 1,
      idPaciente: 12,
      tipoDocumento: 'RECETA',
      titulo: 'Receta',
      fechaDocumento: '2026-01-01',
      estado: 'ACTIVO',
    );
    const desc = DocumentoDescargable(
      idDocumento: 1,
      urlFirmada: 'http://url',
      expiraEn: 60,
      nombreArchivo: 'a.pdf',
      contentType: 'application/pdf',
    );

    test('GetMyDocumentsUseCase delega y propaga filtros por defecto', () async {
      final repo = FakeRepository(paginado: pag);
      final uc = GetMyDocumentsUseCase(repository: repo);
      final result = await uc();
      expect(result.totalPages, 1);
    });

    test('GetDocumentDetailUseCase devuelve la entidad', () async {
      final repo = FakeRepository(documento: doc);
      final uc = GetDocumentDetailUseCase(repository: repo);
      expect((await uc(1)).titulo, 'Receta');
    });

    test('DownloadDocumentUseCase retorna los bytes', () async {
      final repo = FakeRepository(bytes: Uint8List.fromList([9]));
      final uc = DownloadDocumentUseCase(repository: repo);
      expect(await uc(1), [9]);
    });

    test('DownloadDocumentUseCase rechaza archivo vacío', () async {
      final uc = DownloadDocumentUseCase(repository: FakeRepository(bytes: Uint8List(0)));
      await expectLater(uc(1), throwsA(isA<StateError>()));
    });

    test('RequestDocumentDownloadUrlUseCase devuelve la URL firmada', () async {
      final repo = FakeRepository(descargable: desc);
      final uc = RequestDocumentDownloadUrlUseCase(repository: repo);
      expect((await uc(1)).urlFirmada, 'http://url');
    });
  });

  group('ClinicalDocumentsProvider (CU12)', () {
    ClinicalDocumentsProvider buildProvider({
      DocumentoPaginado? paginado,
      ClinicalDocument? documento,
      DocumentoDescargable? descargable,
      Uint8List? bytes,
      bool failDownload = false,
    }) {
      final repo = FakeRepository(
        paginado: paginado,
        documento: documento,
        descargable: descargable,
        bytes: bytes,
        failDownload: failDownload,
      );
      return ClinicalDocumentsProvider(
        getMyDocumentsUseCase: GetMyDocumentsUseCase(repository: repo),
        getTenantDocumentsUseCase: GetTenantDocumentsUseCase(repository: repo),
        getDocumentDetailUseCase: GetDocumentDetailUseCase(repository: repo),
        downloadDocumentUseCase: DownloadDocumentUseCase(repository: repo),
      );
    }

    DocumentoPaginado paginado({int page = 1, int totalPages = 1}) => DocumentoPaginado(
          items: const [
            ClinicalDocument(
              idDocumento: 1,
              idPaciente: 12,
              tipoDocumento: 'RECETA',
              titulo: 'Receta',
              fechaDocumento: '2026-01-01',
              estado: 'ACTIVO',
            ),
          ],
          total: 1,
          page: page,
          pageSize: 20,
          totalPages: totalPages,
        );

    final cli = ClinicalDocument(
      idDocumento: 1,
      idPaciente: 12,
      tipoDocumento: 'RESULTADO_LAB',
      titulo: 'Resultados',
      fechaDocumento: '2026-01-01',
      estado: 'ACTIVO',
    );

    test('loadDocuments carga documentos y resetea paginación', () async {
      final provider = buildProvider(paginado: paginado(totalPages: 3));
      await provider.loadDocuments();
      expect(provider.isLoading, isFalse);
      expect(provider.documents, hasLength(1));
      expect(provider.totalPages, 3);
      expect(provider.hasMore, isTrue);
    });

    test('loadDocuments en error de API guarda el mensaje', () async {
      final provider = buildProvider();
      await provider.loadDocuments();
      expect(provider.isLoading, isFalse);
      expect(provider.errorMessage, isNotEmpty);
      expect(provider.documents, isNull);
    });

    test('loadMore respeta hasMore y appende', () async {
      final provider = buildProvider(paginado: paginado(page: 1, totalPages: 2));
      await provider.loadDocuments();
      provider.clearMessages();
      await provider.loadMore();
      expect(provider.documents, hasLength(2));
    });

    test('loadMore no consulta de nuevo si ya no hay paginas', () async {
      final provider = buildProvider(paginado: paginado(page: 1, totalPages: 1));
      await provider.loadDocuments();
      final before = provider.page;
      await provider.loadMore();
      expect(provider.page, before);
    });

    test('loadDetail carga el documento seleccionado', () async {
      final provider = buildProvider(documento: cli);
      await provider.loadDetail(1);
      expect(provider.selectedDocument?.titulo, 'Resultados');
      expect(provider.isLoading, isFalse);
    });

    test('downloadDocument retorna bytes y termina viewer loading', () async {
      final provider = buildProvider(bytes: Uint8List.fromList([7, 8]));
      final bytes = await provider.downloadDocument(1);
      expect(bytes, [7, 8]);
      expect(provider.isViewerLoading, isFalse);
    });

    test('downloadDocument con error retorna null y guarda mensaje', () async {
      final provider = buildProvider(failDownload: true);
      final bytes = await provider.downloadDocument(1);
      expect(bytes, isNull);
      expect(provider.errorMessage, isNotEmpty);
    });

    test('setTipoDocumento ignora el mismo tipo y cambia pagina', () async {
      final provider = buildProvider(paginado: paginado());
      provider.setTipoDocumento('RECETA');
      expect(provider.activeTipoDocumento, 'RECETA');
      await Future<void>.delayed(Duration.zero);
      expect(provider.page, greaterThan(1));
      provider.setTipoDocumento('RECETA');
      expect(provider.page, greaterThan(1));
    });
  });
}
