import '../../data/repositories/clinical_document_repository_impl.dart';
import '../../domain/repositories/clinical_document_repository.dart';
import '../entities/clinical_document.dart';

/// Caso de uso: consultar el listado de documentos de un paciente específico (ADMIN/MEDICO/RECEPCION).
class GetPatientDocumentsUseCase {
  final ClinicalDocumentRepository _repository;

  GetPatientDocumentsUseCase({ClinicalDocumentRepository? repository})
      : _repository = repository ?? ClinicalDocumentRepositoryImpl();

  Future<DocumentoPaginado> call({
    required int patientId,
    int page = 1,
    int pageSize = 20,
    String? tipoDocumento,
    String? q,
    String? fechaDesde,
    String? fechaHasta,
  }) {
    return _repository.getPatientDocuments(
      patientId: patientId,
      page: page,
      pageSize: pageSize,
      tipoDocumento: tipoDocumento,
      q: q,
      fechaDesde: fechaDesde,
      fechaHasta: fechaHasta,
    );
  }
}