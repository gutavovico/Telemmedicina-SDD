import '../../data/repositories/clinical_document_repository_impl.dart';
import '../../domain/repositories/clinical_document_repository.dart';
import '../entities/clinical_document.dart';

/// Caso de uso: consultar el listado de documentos del paciente autenticado.
class GetMyDocumentsUseCase {
  final ClinicalDocumentRepository _repository;

  GetMyDocumentsUseCase({ClinicalDocumentRepository? repository})
      : _repository = repository ?? ClinicalDocumentRepositoryImpl();

  Future<DocumentoPaginado> call({
    int page = 1,
    int pageSize = 20,
    String? tipoDocumento,
    String? q,
  }) {
    return _repository.getMyDocuments(
      page: page,
      pageSize: pageSize,
      tipoDocumento: tipoDocumento,
      q: q,
    );
  }
}