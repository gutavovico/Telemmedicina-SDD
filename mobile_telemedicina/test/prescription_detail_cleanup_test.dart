import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mobile_telemedicina/core/theme/app_theme.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/entities/prescription.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/repositories/prescription_repository.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/usecases/download_prescription_pdf_usecase.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/usecases/get_my_prescriptions_usecase.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/usecases/get_prescription_detail_usecase.dart';
import 'package:mobile_telemedicina/features/medical_records/presentation/providers/prescription_provider.dart';
import 'package:mobile_telemedicina/features/medical_records/presentation/screens/receta_detail_screen.dart';
import 'package:mobile_telemedicina/features/medical_records/presentation/services/prescription_pdf_sharer.dart';

Prescription recetaCon(int id, String folio) {
  return Prescription(
    idReceta: id,
    idClinica: 1,
    idConsulta: 1,
    idPaciente: 10,
    idMedico: 3,
    folio: folio,
    pdfUrl: '/api/v1/recetas/$id/pdf',
    algoritmoFirma: 'ED25519',
    keyId: 'k1',
    versionPayload: 1,
    hashPdf: 'h',
    fechaEmision: '2026-09-22T22:30:00Z',
    fechaVencimiento: '2026-10-22',
    estaVencida: false,
    estado: EstadoReceta.emitida,
    medico: const PrescriptionMedico(
      idMedico: 3,
      nombreCompleto: 'Dr. Test',
      matriculaProfesional: 'MP-1',
      especialidad: 'Clinica',
    ),
    paciente: const PrescriptionPaciente(idPaciente: 10, nombreCompleto: 'Pac'),
    detalles: const [],
  );
}

class FakeRepo implements PrescriptionRepository {
  Future<Prescription> Function(int id)? detailHandler;
  Future<Uint8List> Function(int id)? downloadHandler;

  @override
  Future<PrescriptionPage> getMyPrescriptions({
    String? estado,
    String? desde,
    String? hasta,
    int skip = 0,
    int limit = 20,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Prescription> getPrescriptionById(int idReceta) {
    return detailHandler!(idReceta);
  }

  @override
  Future<Uint8List> downloadPrescriptionPdf(int idReceta) {
    return downloadHandler!(idReceta);
  }
}

PrescriptionProvider providerFor(FakeRepo repo) {
  return PrescriptionProvider(
    getMyPrescriptionsUseCase: GetMyPrescriptionsUseCase(repository: repo),
    getDetailUseCase: GetPrescriptionDetailUseCase(repository: repo),
    downloadUseCase: DownloadPrescriptionPdfUseCase(repository: repo),
  );
}

class FailingSharer implements PrescriptionPdfSharer {
  @override
  Future<void> sharePdf({
    required Uint8List bytes,
    required String filename,
  }) async {
    throw Exception('share nativo fallo');
  }

  @override
  Future<void> cleanupTempFiles() async {}
}

Widget wrapWith(Widget child, PrescriptionProvider provider) {
  return ChangeNotifierProvider<PrescriptionProvider>.value(
    value: provider,
    child: MaterialApp(theme: AppTheme.lightTheme, home: child),
  );
}

void main() {
  group('Limpieza de estado entre detalles', () {
    test('abrir B limpia error/descarga/bytes de A', () async {
      final repo = FakeRepo();
      repo.detailHandler = (id) async => recetaCon(id, 'REC-$id');
      repo.downloadHandler = (id) async => Uint8List.fromList([1, 2, 3]);
      final p = providerFor(repo);

      await p.loadDetail(1);
      await p.downloadPdf(1);
      expect(p.downloadStatus, PrescriptionDownloadStatus.success);
      expect(p.lastDownloadedBytes, isNotNull);

      await p.loadDetail(2);
      expect(p.downloadStatus, PrescriptionDownloadStatus.idle);
      expect(p.downloadError, isNull);
      expect(p.lastDownloadedBytes, isNull);
      expect(p.lastDownloadedFilename, isNull);
      expect(p.selected?.idReceta, 2);
      expect(p.detailError, isNull);
    });

    test('descarga de A no actualiza UI de B', () async {
      final downloadA = Completer<Uint8List>();
      final repo = FakeRepo();
      repo.detailHandler = (id) async => recetaCon(id, 'REC-$id');
      repo.downloadHandler = (id) {
        if (id == 1) return downloadA.future;
        return Future.value(Uint8List.fromList([9, 9]));
      };
      final p = providerFor(repo);

      await p.loadDetail(1);
      final pendingA = p.downloadPdf(1);
      await p.loadDetail(2);
      downloadA.complete(Uint8List.fromList([1, 2, 3]));
      final resultA = await pendingA;
      expect(resultA, isNull);
      expect(p.selected?.idReceta, 2);
      expect(p.downloadStatus, PrescriptionDownloadStatus.idle);
      expect(p.lastDownloadedBytes, isNull);
    });
  });

  group('Compartir sin perder detalle', () {
    testWidgets('error al compartir conserva el detalle visible', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repo = FakeRepo();
      repo.detailHandler = (id) async => recetaCon(58, 'REC-2026-000058');
      repo.downloadHandler = (id) async => Uint8List.fromList([37, 80, 68, 70]);
      final provider = providerFor(repo);

      await tester.pumpWidget(
        wrapWith(
          RecetaDetailScreen(idReceta: 58, sharer: FailingSharer()),
          provider,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('REC-2026-000058'), findsOneWidget);

      await tester.tap(find.text('Descargar PDF'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('REC-2026-000058'), findsOneWidget);
      expect(find.textContaining('compartir'), findsOneWidget);
      expect(provider.detailStatus, PrescriptionDetailStatus.loaded);
      expect(provider.selected, isNotNull);
    });
  });
}
