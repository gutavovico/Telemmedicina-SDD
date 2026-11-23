import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../../../../../core/config/api_config.dart';
import '../../../../../core/network/api_client.dart';
import '../../../../../core/network/api_exceptions.dart';
import '../../../reportes/data/models/report_models.dart';

typedef BinaryTransport = Future<http.Response> Function(Map<String, dynamic> body);
typedef SaveReport = Future<void> Function(String name, String extension,
    String mime, Uint8List bytes);

class ReportExportService {
  static const mimes = <String, String>{
    'pdf': 'application/pdf',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'csv': 'text/csv',
    'html': 'text/html',
  };
  final BinaryTransport _transport;
  final SaveReport _save;

  ReportExportService({BinaryTransport? transport, SaveReport? save})
      : _transport = transport ?? ((body) => ApiClient().postBinary(
          ApiConfig.reportExportUrl, body: body)),
        _save = save ?? _saveWithDialog;

  static Future<void> _saveWithDialog(String name, String extension,
      String mime, Uint8List bytes) async {
    final saved = kIsWeb
      ? await FileSaver.instance.saveFile(name: name, bytes: bytes,
          fileExtension: extension, mimeType: MimeType.custom,
          customMimeType: mime)
      : await FileSaver.instance.saveAs(name: name, bytes: bytes,
          fileExtension: extension, mimeType: MimeType.custom,
          customMimeType: mime);
    if (saved == null) {
      throw ApiException(message: 'No se guardó el archivo.');
    }
  }

  Future<String> export(ReportQuery definition, String format,
      {bool Function()? isCurrent}) async {
    final expectedMime = mimes[format];
    if (expectedMime == null) throw ApiException(message: 'Formato no disponible.');
    final body = {...definition.toJson(), 'formato': format};
    final response = await _transport(body);
    // Fakes and alternate transports must obey the same error rule as ApiClient.
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = response.body;
      throw ApiException(message: response.statusCode == 413
          ? 'El reporte supera 5.000 grupos. Reduce el período o acota con filtros.'
          : 'No se pudo exportar: $detail', statusCode: response.statusCode);
    }
    final mime = (response.headers['content-type'] ?? '').split(';').first.trim().toLowerCase();
    if (mime != expectedMime || response.bodyBytes.isEmpty) {
      throw ApiException(message: 'El servidor no devolvió un archivo $format válido.');
    }
    final name = safeFilename(response.headers['content-disposition'],
      definition.reporte, format);
    if (isCurrent != null && !isCurrent()) {
      throw ApiException(message: 'La definición cambió durante la descarga.');
    }
    final stem = name.substring(0, name.length - format.length - 1);
    await _save(stem, format, mime, response.bodyBytes);
    return name;
  }

  static String safeFilename(String? disposition, String report, String format) {
    final match = RegExp(r'filename="?([^";]+)"?', caseSensitive: false)
        .firstMatch(disposition ?? '');
    final candidate = match?.group(1) ?? '';
    if (RegExp(r'^reporte_[a-z_]+_[0-9]{8}_[0-9]{6}\.(pdf|xlsx|csv|html)$')
        .hasMatch(candidate) && candidate.startsWith('reporte_${report}_') &&
        candidate.endsWith('.$format')) {
      return candidate;
    }
    final stamp = DateTime.now().toUtc().toIso8601String()
        .replaceAll(RegExp(r'[^0-9]'), '').padRight(14, '0').substring(0, 14);
    return 'reporte_${report}_$stamp.$format';
  }
}
