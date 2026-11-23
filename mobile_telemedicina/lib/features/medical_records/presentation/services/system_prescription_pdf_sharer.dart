import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'prescription_pdf_sharer.dart';

/// Implementación con APIs del SO: escribe el PDF en el directorio temporal
/// y lo comparte con `share_plus`. Elimina el temporal tras compartir.
///
/// Elección de dependencias (mínimas):
/// - `path_provider`: ubicación temporal segura del SO sin rutas hardcodeadas.
/// - `share_plus`: hoja de compartición/guardado nativa (archivos, Drive,
///   WhatsApp, etc.) sin gestionar permisos de almacenamiento manualmente.
///
/// Seguridad y concurrencia:
/// - El nombre siempre se sanea dentro del servicio, aunque el llamador
///   envíe un nombre inseguro (p. ej. `../../etc/passwd` o con `/`).
/// - Los bytes vacíos se rechazan antes de escribir.
/// - Cada descarga usa un archivo temporal único (sufijo temporal) para no
///   sobrescribir otra descarga concurrente.
/// - Limpieza best-effort por archivo propio; nunca se registran rutas,
///   tokens o contenido clínico.
class SystemPrescriptionPdfSharer implements PrescriptionPdfSharer {
  final List<File> _tempFiles = [];
  int _fileCounter = 0;

  /// Proveedores inyectables para pruebas (sin plugins nativos).
  final Future<Directory> Function()? directoryProvider;
  final Future<void> Function(XFile file, String shareText)? shareFunction;

  SystemPrescriptionPdfSharer({this.directoryProvider, this.shareFunction});

  /// Sanea un nombre de archivo dentro del servicio.
  ///
  /// - Extrae el basename (elimina directorios `/` y `\` y `..`).
  /// - Sustituye caracteres fuera de `[A-Za-z0-9\-_.]` por `_`.
  /// - Colapsa `_+`, garantiza extensión `.pdf` y un base no vacío.
  /// Nunca devuelve rutas ni separadores.
  static String sanitizeFilename(String filename) {
    var base = filename.trim();
    if (base.isEmpty) return 'receta.pdf';
    // Basename: elimina cualquier componente de ruta.
    base = base.split('/').last.split('\\').last.trim();
    base = base.replaceAll('..', '_');
    if (base.isEmpty) return 'receta.pdf';
    final hasPdfExt = base.toLowerCase().endsWith('.pdf');
    final withoutExt = hasPdfExt ? base.substring(0, base.length - 4) : base;
    var sanitized = withoutExt.replaceAll(RegExp(r'[^A-Za-z0-9\-_.]+'), '_');
    sanitized = sanitized.replaceAll(RegExp(r'_+'), '_');
    sanitized = sanitized.replaceAll(RegExp(r'^[_.]+|[_.]+$'), '');
    if (sanitized.isEmpty) sanitized = 'receta';
    // Limita longitud para filesystems (conserva legibilidad del folio).
    if (sanitized.length > 80) sanitized = sanitized.substring(0, 80);
    return '$sanitized.pdf';
  }

  @override
  Future<void> sharePdf({
    required Uint8List bytes,
    required String filename,
  }) async {
    // Rechazo temprano: no se escribe ningún archivo vacío.
    if (bytes.isEmpty) {
      throw StateError(
        'El servidor devolvió un documento vacío. Intenta nuevamente.',
      );
    }
    final safeName = sanitizeFilename(filename);
    final dir = await (directoryProvider?.call() ?? getTemporaryDirectory());
    // Archivo único por descarga para no sobrescribir concurrencia.
    final uniqueSuffix =
        '${DateTime.now().microsecondsSinceEpoch}_${_fileCounter++}';
    final dot = safeName.lastIndexOf('.');
    final stem = dot > 0 ? safeName.substring(0, dot) : safeName;
    final uniqueName = '${stem}_$uniqueSuffix.pdf';
    final file = File('${dir.path}/$uniqueName');
    await file.writeAsBytes(bytes, flush: true);
    _tempFiles.add(file);
    try {
      final xfile = XFile(
        file.path,
        mimeType: 'application/pdf',
        name: safeName,
      );
      final shareText = 'Receta médica digital: $safeName';
      if (shareFunction != null) {
        await shareFunction!(xfile, shareText);
      } else {
        await SharePlus.instance.share(
          ShareParams(files: [xfile], text: shareText),
        );
      }
    } finally {
      // Limpieza best-effort solo del archivo propio: no se borran archivos
      // de otras descargas concurrentes todavía en uso.
      // No se loguean rutas, tokens ni contenido clínico.
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {
        // Best-effort: nunca rompe la UX.
      }
      _tempFiles.remove(file);
    }
  }

  @override
  Future<void> cleanupTempFiles() async {
    for (final file in List<File>.from(_tempFiles)) {
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {
        // Limpieza best-effort: nunca debe romper la UX ni loguear rutas.
      }
      _tempFiles.remove(file);
    }
  }
}
