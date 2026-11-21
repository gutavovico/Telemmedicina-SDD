import 'dart:typed_data';
import '../../data/repositories/clinical_document_repository_impl.dart';
import '../../domain/repositories/clinical_document_repository.dart';
import '../entities/clinical_document.dart';

/// Caso de uso: descarga segura (bytes) del archivo de un documento clínico.
class DownloadDocumentUseCase {
  final ClinicalDocumentRepository _repository;

  DownloadDocumentUseCase({ClinicalDocumentRepository? repository})
      : _repository = repository ?? ClinicalDocumentRepositoryImpl();

  Future<Uint8List> call(int idDocumento) async {
    final bytes = await _repository.downloadDocumentBytes(idDocumento);
    if (bytes.isEmpty) {
      throw StateError('El servidor devolvió un documento vacío. Intenta nuevamente.');
    }
    return bytes;
  }
}

/// Caso de uso: generar la URL firmada temporal del documento (auditada por el backend).
class RequestDocumentDownloadUrlUseCase {
  final ClinicalDocumentRepository _repository;

  RequestDocumentDownloadUrlUseCase({ClinicalDocumentRepository? repository})
      : _repository = repository ?? ClinicalDocumentRepositoryImpl();

  Future<DocumentoDescargable> call(int idDocumento) {
    return _repository.requestDownloadUrl(idDocumento);
  }
}
