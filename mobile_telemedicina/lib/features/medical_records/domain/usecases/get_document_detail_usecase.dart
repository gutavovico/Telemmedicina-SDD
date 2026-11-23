import '../../data/repositories/clinical_document_repository_impl.dart';
import '../../domain/repositories/clinical_document_repository.dart';
import '../entities/clinical_document.dart';

/// Caso de uso: consultar el detalle de un documento clínico por id.
class GetDocumentDetailUseCase {
  final ClinicalDocumentRepository _repository;

  GetDocumentDetailUseCase({ClinicalDocumentRepository? repository})
      : _repository = repository ?? ClinicalDocumentRepositoryImpl();

  Future<ClinicalDocument> call(int idDocumento) {
    return _repository.getDocumentById(idDocumento);
  }
}