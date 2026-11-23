import '../../data/repositories/clinical_document_repository_impl.dart';
import '../../domain/repositories/clinical_document_repository.dart';
import '../entities/clinical_document.dart';

/// Caso de uso: consultar el listado de documentos del tenant (ADMIN/MEDICO/RECEPCION).
class GetTenantDocumentsUseCase {
  final ClinicalDocumentRepository _repository;

  GetTenantDocumentsUseCase({ClinicalDocumentRepository? repository})
      : _repository = repository ?? ClinicalDocumentRepositoryImpl();

  Future<DocumentoPaginado> call({
    int page = 1,
    int pageSize = 20,
    String? tipoDocumento,
    String? q,
    int? idPaciente,
    String? fechaDesde,
    String? fechaHasta,
  }) {
    return _repository.getTenantDocuments(
      page: page,
      pageSize: pageSize,
      tipoDocumento: tipoDocumento,
      q: q,
      idPaciente: idPaciente,
      fechaDesde: fechaDesde,
      fechaHasta: fechaHasta,
    );
  }
}