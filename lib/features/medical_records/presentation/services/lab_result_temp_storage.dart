import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Almacenamiento temporal del archivo descargado de un resultado (CU11).
/// Abstracción para poder simularla en pruebas.
abstract class LabResultTempStorage {
  /// Escribe los bytes en un archivo temporal y devuelve su ruta.
  Future<String> write(Uint8List bytes, String extension);

  /// Elimina el archivo temporal. Nunca lanza.
  Future<void> delete(String path);
}

/// Implementación con `path_provider` (directorio temporal de la app).
class DeviceLabResultTempStorage implements LabResultTempStorage {
  const DeviceLabResultTempStorage();

  @override
  Future<String> write(Uint8List bytes, String extension) async {
    final dir = await getTemporaryDirectory();
    final name = 'lab_result_${DateTime.now().microsecondsSinceEpoch}.$extension';
    final file = File('${dir.path}${Platform.pathSeparator}$name');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  @override
  Future<void> delete(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Limpieza best-effort: no debe romper la salida del visor.
    }
  }
}
