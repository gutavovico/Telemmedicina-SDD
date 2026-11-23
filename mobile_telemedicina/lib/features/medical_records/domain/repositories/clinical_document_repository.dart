import 'dart:typed_data';
import '../entities/clinical_document.dart';

/// Contrato del repositorio de documentos clínicos (CU12).
/// La capa de datos implementa esta interfaz.
abstract class ClinicalDocumentRepository {
  Future<DocumentoPaginado> getMyDocuments({
    int page = 1,
    int pageSize = 20,
    String? tipoDocumento,
    String? q,
  });

  /// Documentos del tenant (ADMIN/MEDICO/RECEPCION)
  Future<DocumentoPaginado> getTenantDocuments({
    int page = 1,
    int pageSize = 20,
    String? tipoDocumento,
    String? q,
    int? idPaciente,
    String? fechaDesde,
    String? fechaHasta,
  });

  /// Documentos de un paciente específico (ADMIN/MEDICO/RECEPCION)
  Future<DocumentoPaginado> getPatientDocuments({
    required int patientId,
    int page = 1,
    int pageSize = 20,
    String? tipoDocumento,
    String? q,
    String? fechaDesde,
    String? fechaHasta,
  });

  Future<ClinicalDocument> getDocumentById(int idDocumento);

  Future<DocumentoDescargable> requestDownloadUrl(int idDocumento);

  Future<Uint8List> downloadDocumentBytes(int idDocumento);
}