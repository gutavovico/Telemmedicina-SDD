import 'package:flutter/foundation.dart';

import '../../domain/failures/lab_result_failure.dart';
import '../../domain/usecases/download_lab_result_usecase.dart';
import '../services/lab_result_temp_storage.dart';

enum LabResultFileStatus { initial, loading, ready, error }

enum LabResultFileKind { pdf, image, unsupported }

/// Detecta el tipo real del archivo por sus primeros bytes (el cliente HTTP solo
/// devuelve bytes, sin cabeceras). Si no es reconocible se usa el `content_type`
/// declarado en el listado como respaldo.
LabResultFileKind detectLabResultFileKind(Uint8List bytes, {String? declaredContentType}) {
  if (bytes.length >= 5 &&
      bytes[0] == 0x25 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x44 &&
      bytes[3] == 0x46 &&
      bytes[4] == 0x2D) {
    return LabResultFileKind.pdf;
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return LabResultFileKind.image;
  }
  if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
    return LabResultFileKind.image;
  }
  switch ((declaredContentType ?? '').toLowerCase()) {
    case 'application/pdf':
      return LabResultFileKind.pdf;
    case 'image/png':
    case 'image/jpeg':
    case 'image/jpg':
      return LabResultFileKind.image;
  }
  return LabResultFileKind.unsupported;
}

/// Controla la descarga y el ciclo de vida del archivo temporal de un resultado (CU11).
/// Al hacer `dispose` (salir del visor) borra el archivo temporal y descarta respuestas tardías.
class LabResultFileController extends ChangeNotifier {
  final int idResultado;
  final String? declaredContentType;
  final DownloadLabResultUseCase _download;
  final LabResultTempStorage _storage;

  LabResultFileController({
    required this.idResultado,
    this.declaredContentType,
    DownloadLabResultUseCase? download,
    LabResultTempStorage? storage,
  })  : _download = download ?? DownloadLabResultUseCase(),
        _storage = storage ?? const DeviceLabResultTempStorage();

  LabResultFileStatus _status = LabResultFileStatus.initial;
  LabResultFileKind? _kind;
  Uint8List? _bytes;
  String? _filePath;
  String? _errorMessage;
  LabResultFailureKind? _errorKind;
  bool _disposed = false;
  int _token = 0;

  LabResultFileStatus get status => _status;
  LabResultFileKind? get kind => _kind;
  Uint8List? get bytes => _bytes;
  String? get filePath => _filePath;
  String? get errorMessage => _errorMessage;
  LabResultFailureKind? get errorKind => _errorKind;

  Future<void> load() async {
    final token = ++_token;
    await _cleanup();
    _status = LabResultFileStatus.loading;
    _errorMessage = null;
    _errorKind = null;
    _kind = null;
    _notify();

    try {
      final data = await _download(idResultado);
      if (_disposed || token != _token) return;

      final kind = detectLabResultFileKind(data, declaredContentType: declaredContentType);
      if (kind == LabResultFileKind.unsupported) {
        _errorKind = LabResultFailureKind.unknown;
        _errorMessage = 'El formato del archivo no se puede mostrar en la aplicación.';
        _status = LabResultFileStatus.error;
        _notify();
        return;
      }

      String? path;
      try {
        path = await _storage.write(data, kind == LabResultFileKind.pdf ? 'pdf' : _imageExt(data));
      } catch (_) {
        path = null; // sin disco: se muestra desde memoria
      }
      if (_disposed || token != _token) {
        if (path != null) await _storage.delete(path);
        return;
      }

      _bytes = data;
      _filePath = path;
      _kind = kind;
      _status = LabResultFileStatus.ready;
    } catch (error) {
      if (_disposed || token != _token) return;
      if (error is LabResultFailure) {
        _errorMessage = error.message;
        _errorKind = error.kind;
      } else {
        _errorMessage = 'No se pudo descargar el archivo. Intenta nuevamente.';
        _errorKind = LabResultFailureKind.unknown;
      }
      _status = LabResultFileStatus.error;
    }
    _notify();
  }

  String _imageExt(Uint8List data) =>
      (data.length >= 4 && data[0] == 0x89 && data[1] == 0x50) ? 'png' : 'jpg';

  Future<void> _cleanup() async {
    final path = _filePath;
    _filePath = null;
    _bytes = null;
    if (path != null) {
      await _storage.delete(path);
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    final path = _filePath;
    _filePath = null;
    _bytes = null;
    if (path != null) {
      // Borrado sin esperar: el visor ya se cerró.
      _storage.delete(path);
    }
    super.dispose();
  }
}
