import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../medical_records/domain/entities/clinical_document.dart';
import '../../../medical_records/domain/usecases/download_document_usecase.dart';
import '../../../medical_records/domain/usecases/get_document_detail_usecase.dart';
import '../../../medical_records/domain/usecases/get_my_documents_usecase.dart';
import '../../../medical_records/domain/usecases/get_tenant_documents_usecase.dart';
import '../../../../core/network/api_exceptions.dart';

class ClinicalDocumentsProvider extends ChangeNotifier {
  final GetMyDocumentsUseCase _getMyDocumentsUseCase;
  final GetTenantDocumentsUseCase _getTenantDocumentsUseCase;
  final GetDocumentDetailUseCase _getDocumentDetailUseCase;
  final DownloadDocumentUseCase _downloadDocumentUseCase;

  ClinicalDocumentsProvider({
    GetMyDocumentsUseCase? getMyDocumentsUseCase,
    GetTenantDocumentsUseCase? getTenantDocumentsUseCase,
    GetDocumentDetailUseCase? getDocumentDetailUseCase,
    DownloadDocumentUseCase? downloadDocumentUseCase,
  })  : _getMyDocumentsUseCase = getMyDocumentsUseCase ?? GetMyDocumentsUseCase(),
        _getTenantDocumentsUseCase = getTenantDocumentsUseCase ?? GetTenantDocumentsUseCase(),
        _getDocumentDetailUseCase = getDocumentDetailUseCase ?? GetDocumentDetailUseCase(),
        _downloadDocumentUseCase = downloadDocumentUseCase ?? DownloadDocumentUseCase();

  List<ClinicalDocument>? _documents;
  ClinicalDocument? _selectedDocument;
  bool _isLoading = false;
  bool _isViewerLoading = false;
  String? _errorMessage;
  int _page = 1;
  int _totalPages = 1;
  bool _hasMore = false;
  String? _activeTipoDocumento;

  List<ClinicalDocument>? get documents => _documents;
  ClinicalDocument? get selectedDocument => _selectedDocument;
  bool get isLoading => _isLoading;
  bool get isViewerLoading => _isViewerLoading;
  String? get errorMessage => _errorMessage;
  int get page => _page;
  int get totalPages => _totalPages;
  bool get hasMore => _hasMore;
  String? get activeTipoDocumento => _activeTipoDocumento;

  void clearMessages() {
    _errorMessage = null;
    notifyListeners();
  }

  void setTipoDocumento(String? tipo) {
    if (_activeTipoDocumento == tipo) return;
    _activeTipoDocumento = tipo;
    _page = 1;
    notifyListeners();
    loadDocuments();
  }

  /// Carga documentos según el rol del usuario autenticado
  /// - PACIENTE: usa /api/v1/documentos/me (sus propios documentos)
  /// - MEDICO/ADMIN/RECEPCION: usa /api/v1/documentos (documentos del tenant)
  Future<void> loadDocuments({bool reset = true, AuthController? authController}) async {
    if (reset) {
      _page = 1;
      _totalPages = 1;
      _hasMore = false;
      _documents = null;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      DocumentoPaginado result;
      final userRole = authController?.userRole ?? 'PACIENTE';

      if (userRole == 'paciente') {
        // Paciente: solo sus documentos
        result = await _getMyDocumentsUseCase(
          page: _page,
          pageSize: 20,
          tipoDocumento: _activeTipoDocumento,
        );
      } else {
        // Médico/Admin/Recepción: documentos del tenant con filtros
        result = await _getTenantDocumentsUseCase(
          page: _page,
          pageSize: 20,
          tipoDocumento: _activeTipoDocumento,
          q: null,
          idPaciente: null,
          fechaDesde: null,
          fechaHasta: null,
        );
      }

      _documents = reset ? result.items : [...?_documents, ...result.items];
      _totalPages = result.totalPages;
      _hasMore = _page < result.totalPages;
      _page++;
    } on ApiException catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      notifyListeners();
      return;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Error inesperado al cargar documentos clínicos.';
      notifyListeners();
      return;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (_isLoading || !_hasMore) return;
    await loadDocuments(reset: false);
  }

  Future<void> loadDetail(int idDocumento) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _selectedDocument = await _getDocumentDetailUseCase(idDocumento);
    } on ApiException catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      notifyListeners();
      return;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Error inesperado al consultar el documento.';
      notifyListeners();
      return;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<Uint8List?> downloadDocument(int idDocumento) async {
    _isViewerLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final bytes = await _downloadDocumentUseCase(idDocumento);
      _isViewerLoading = false;
      notifyListeners();
      return bytes;
    } on ApiException catch (e) {
      _isViewerLoading = false;
      _errorMessage = e.message;
      notifyListeners();
      return null;
    } catch (e) {
      _isViewerLoading = false;
      _errorMessage = 'Error al descargar el documento.';
      notifyListeners();
      return null;
    }
  }
}
