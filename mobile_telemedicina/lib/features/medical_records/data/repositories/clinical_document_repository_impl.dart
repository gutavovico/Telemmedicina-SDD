import 'dart:typed_data';

import '../../domain/entities/clinical_document.dart';
import '../../domain/repositories/clinical_document_repository.dart';
import '../models/clinical_document_model.dart';
import '../services/clinical_document_service.dart';

class ClinicalDocumentRepositoryImpl implements ClinicalDocumentRepository {
  final ClinicalDocumentService _service;

  ClinicalDocumentRepositoryImpl({ClinicalDocumentService? service})
      : _service = service ?? ClinicalDocumentService();

  @override
  Future<DocumentoPaginado> getMyDocuments({
    int page = 1,
    int pageSize = 20,
    String? tipoDocumento,
    String? q,
  }) async {
    final result = await _service.getMyDocuments(
      page: page,
      pageSize: pageSize,
      tipoDocumento: tipoDocumento,
      q: q,
    );
    return _mapPaginado(result);
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
    final result = await _service.getTenantDocuments(
      page: page,
      pageSize: pageSize,
      tipoDocumento: tipoDocumento,
      q: q,
      idPaciente: idPaciente,
      fechaDesde: fechaDesde,
      fechaHasta: fechaHasta,
    );
    return _mapPaginado(result);
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
    final result = await _service.getPatientDocuments(
      patientId: patientId,
      page: page,
      pageSize: pageSize,
      tipoDocumento: tipoDocumento,
      q: q,
      fechaDesde: fechaDesde,
      fechaHasta: fechaHasta,
    );
    return _mapPaginado(result);
  }

  @override
  Future<ClinicalDocument> getDocumentById(int idDocumento) async {
    final model = await _service.getDocumentById(idDocumento);
    return _mapEntity(model);
  }

  @override
  Future<DocumentoDescargable> requestDownloadUrl(int idDocumento) async {
    final model = await _service.requestDownloadUrl(idDocumento);
    return DocumentoDescargable(
      idDocumento: model.idDocumento,
      urlFirmada: model.urlFirmada,
      expiraEn: model.expiraEn,
      nombreArchivo: model.nombreArchivo,
      contentType: model.contentType,
    );
  }

  @override
  Future<Uint8List> downloadDocumentBytes(int idDocumento) {
    return _service.downloadDocumentBytes(idDocumento);
  }

  DocumentoPaginado _mapPaginado(DocumentoPaginadoModel model) {
    return DocumentoPaginado(
      items: model.items.map(_mapEntity).toList(),
      total: model.total,
      page: model.page,
      pageSize: model.pageSize,
      totalPages: model.totalPages,
    );
  }

  ClinicalDocument _mapEntity(ClinicalDocumentModel model) {
    return ClinicalDocument(
      idDocumento: model.idDocumento,
      idPaciente: model.idPaciente,
      tipoDocumento: model.tipoDocumento,
      titulo: model.titulo,
      descripcion: model.descripcion,
      fechaDocumento: model.fechaDocumento,
      estado: model.estado,
      pacienteNombre: model.pacienteNombre,
      firmanteNombre: model.firmanteNombre,
    );
  }
}