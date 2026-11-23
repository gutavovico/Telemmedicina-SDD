import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:mobile_telemedicina/features/medical_records/presentation/services/prescription_pdf_sharer.dart';
import 'package:mobile_telemedicina/features/medical_records/presentation/services/system_prescription_pdf_sharer.dart';

void main() {
  group('SystemPrescriptionPdfSharer saneamiento', () {
    test('nombre inseguro se sanea sin separadores ni traversal', () {
      expect(
        SystemPrescriptionPdfSharer.sanitizeFilename('../../etc/passwd'),
        isNot(contains('/')),
      );
      expect(
        SystemPrescriptionPdfSharer.sanitizeFilename('../../etc/passwd'),
        isNot(contains('..')),
      );
      expect(
        SystemPrescriptionPdfSharer.sanitizeFilename('a/b\\c.pdf'),
        isNot(contains('/')),
      );
      expect(
        SystemPrescriptionPdfSharer.sanitizeFilename('a/b\\c.pdf'),
        isNot(contains('\\')),
      );
      expect(
        SystemPrescriptionPdfSharer.sanitizeFilename('REC/2026:000058'),
        isNot(contains('/')),
      );
      expect(
        SystemPrescriptionPdfSharer.sanitizeFilename('REC/2026:000058'),
        isNot(contains(':')),
      );
      expect(SystemPrescriptionPdfSharer.sanitizeFilename(''), 'receta.pdf');
      expect(SystemPrescriptionPdfSharer.sanitizeFilename('   '), 'receta.pdf');
      final safe = SystemPrescriptionPdfSharer.sanitizeFilename(
        'receta_REC-2026-000058.pdf',
      );
      expect(safe, 'receta_REC-2026-000058.pdf');
    });

    test('bytes vacíos se rechazan antes de escribir', () async {
      final dir = await Directory.systemTemp.createTemp('cu16_sharer_');
      addTearDown(() async {
        try {
          await dir.delete(recursive: true);
        } catch (_) {}
      });
      var shareCalls = 0;
      final sharer = SystemPrescriptionPdfSharer(
        directoryProvider: () async => dir,
        shareFunction: (file, text) async => shareCalls++,
      );
      expect(
        () => sharer.sharePdf(bytes: Uint8List(0), filename: 'receta.pdf'),
        throwsStateError,
      );
      expect(shareCalls, 0);
      // No se escribió ningún archivo.
      final entries = await dir.list().toList();
      expect(entries, isEmpty);
    });

    test('descargas concurrentes no se sobrescriben y limpian', () async {
      final dir = await Directory.systemTemp.createTemp('cu16_concurrent_');
      addTearDown(() async {
        try {
          await dir.delete(recursive: true);
        } catch (_) {}
      });
      final seenPaths = <String>[];
      final sharer = SystemPrescriptionPdfSharer(
        directoryProvider: () async => dir,
        shareFunction: (XFile file, String text) async {
          seenPaths.add(file.path);
          // Simula hoja de compartir lenta.
          await Future.delayed(const Duration(milliseconds: 20));
        },
      );
      final bytes = Uint8List.fromList([37, 80, 68, 70]);
      await Future.wait([
        sharer.sharePdf(bytes: bytes, filename: 'receta_REC-1.pdf'),
        sharer.sharePdf(bytes: bytes, filename: 'receta_REC-1.pdf'),
      ]);
      // Rutas únicas (no sobrescritura).
      expect(seenPaths, hasLength(2));
      expect(seenPaths[0] == seenPaths[1], false);
      // Limpieza best-effort: el temporal ya no existe.
      final remaining = await dir.list().toList();
      expect(remaining, isEmpty);
    });

    test('abstracción InMemory registra bytes y nombre para widgets', () async {
      final fake = InMemoryPrescriptionPdfSharer();
      final bytes = Uint8List.fromList([1, 2, 3]);
      await fake.sharePdf(bytes: bytes, filename: 'receta_X.pdf');
      expect(fake.shareCalls, 1);
      expect(fake.lastBytes, bytes);
      expect(fake.lastFilename, 'receta_X.pdf');
      await fake.cleanupTempFiles();
      expect(fake.cleanupCalls, 1);
    });
  });
}
