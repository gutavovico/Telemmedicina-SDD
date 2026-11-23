import 'dart:typed_data';

import '../../data/repositories/prescription_repository_impl.dart';
import '../repositories/prescription_repository.dart';

/// Caso de uso: descargar el PDF original de una receta propia.
///
/// Rechaza respuestas exitosas con bytes vacíos para evitar
/// persistir o compartir archivos corruptos.
class DownloadPrescriptionPdfUseCase {
  final PrescriptionRepository _repository;

  DownloadPrescriptionPdfUseCase({PrescriptionRepository? repository})
    : _repository = repository ?? PrescriptionRepositoryImpl();

  Future<Uint8List> call(int idReceta) async {
    final bytes = await _repository.downloadPrescriptionPdf(idReceta);
    if (bytes.isEmpty) {
      throw StateError(
        'El servidor devolvió un documento vacío. Intenta nuevamente.',
      );
    }
    return bytes;
  }
}
