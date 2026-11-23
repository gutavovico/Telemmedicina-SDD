import 'dart:typed_data';

/// Abstracción testeable para guardar/compartir el PDF de una receta.
///
/// La implementación concreta delega la ubicación final a APIs seguras
/// del sistema operativo y elimina archivos temporales cuando ya no
/// son necesarios. Los widgets y el provider dependen de esta interfaz,
/// nunca de plugins directamente.
abstract class PrescriptionPdfSharer {
  /// Guarda o comparte [bytes] con el nombre seguro [filename].
  Future<void> sharePdf({required Uint8List bytes, required String filename});

  /// Elimina archivos temporales pendientes, si los hubiera.
  Future<void> cleanupTempFiles();
}

/// Implementación en memoria para pruebas de widgets.
class InMemoryPrescriptionPdfSharer implements PrescriptionPdfSharer {
  Uint8List? lastBytes;
  String? lastFilename;
  int shareCalls = 0;
  int cleanupCalls = 0;

  @override
  Future<void> sharePdf({
    required Uint8List bytes,
    required String filename,
  }) async {
    shareCalls++;
    lastBytes = bytes;
    lastFilename = filename;
  }

  @override
  Future<void> cleanupTempFiles() async {
    cleanupCalls++;
  }
}
