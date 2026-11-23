import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_telemedicina/core/network/api_exceptions.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/entities/prescription.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/repositories/prescription_repository.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/usecases/download_prescription_pdf_usecase.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/usecases/get_my_prescriptions_usecase.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/usecases/get_prescription_detail_usecase.dart';
import 'package:mobile_telemedicina/features/medical_records/presentation/providers/prescription_provider.dart';

Prescription _receta({
  int id = 1,
  String folio = 'REC-2026-000001',
  EstadoReceta estado = EstadoReceta.emitida,
  bool vencida = false,
}) {
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
    estaVencida: vencida,
    estado: estado,
    medico: const PrescriptionMedico(
      idMedico: 3,
      nombreCompleto: 'Dr. Test',
      matriculaProfesional: 'MP-1',
      especialidad: 'Clínica',
    ),
    paciente: const PrescriptionPaciente(
      idPaciente: 10,
      nombreCompleto: 'Pac Test',
    ),
    detalles: const [],
  );
}

class FakeRepo implements PrescriptionRepository {
  Future<PrescriptionPage> Function({
    String? estado,
    String? desde,
    String? hasta,
    int skip,
    int limit,
  })?
  listHandler;
  Future<Prescription> Function(int id)? detailHandler;
  Future<Uint8List> Function(int id)? downloadHandler;
  int downloadCalls = 0;

  @override
  Future<PrescriptionPage> getMyPrescriptions({
    String? estado,
    String? desde,
    String? hasta,
    int skip = 0,
    int limit = 20,
  }) {
    return listHandler!(
      estado: estado,
      desde: desde,
      hasta: hasta,
      skip: skip,
      limit: limit,
    );
  }

  @override
  Future<Prescription> getPrescriptionById(int idReceta) =>
      detailHandler!(idReceta);

  @override
  Future<Uint8List> downloadPrescriptionPdf(int idReceta) {
    downloadCalls++;
    return downloadHandler!(idReceta);
  }
}

PrescriptionProvider _provider(FakeRepo repo) => PrescriptionProvider(
  getMyPrescriptionsUseCase: GetMyPrescriptionsUseCase(repository: repo),
  getDetailUseCase: GetPrescriptionDetailUseCase(repository: repo),
  downloadUseCase: DownloadPrescriptionPdfUseCase(repository: repo),
);

void main() {
  group('PrescriptionProvider listado', () {
    test('cargando -> con datos', () async {
      final repo = FakeRepo()
        ..listHandler = ({estado, desde, hasta, skip = 0, limit = 20}) async =>
            PrescriptionPage(
              items: [_receta()],
              total: 1,
              skip: skip,
              limit: limit,
            );
      final p = _provider(repo);

      final future = p.loadPrescriptions(refresh: true);
      expect(p.listStatus, PrescriptionListStatus.loading);
      await future;

      expect(p.listStatus, PrescriptionListStatus.loaded);
      expect(p.items, hasLength(1));
      expect(p.hasMore, false);
      expect(p.listError, isNull);
    });

    test('vacío cuando items=[] y total=0', () async {
      final repo = FakeRepo()
        ..listHandler = ({estado, desde, hasta, skip = 0, limit = 20}) async =>
            PrescriptionPage(
              items: const [],
              total: 0,
              skip: skip,
              limit: limit,
            );
      final p = _provider(repo);
      await p.loadPrescriptions(refresh: true);
      expect(p.listStatus, PrescriptionListStatus.empty);
      expect(p.items, isEmpty);
    });

    test('error recuperable con mensaje', () async {
      final repo = FakeRepo()
        ..listHandler = ({estado, desde, hasta, skip = 0, limit = 20}) async {
          throw NetworkException();
        };
      final p = _provider(repo);
      await p.loadPrescriptions(refresh: true);
      expect(p.listStatus, PrescriptionListStatus.error);
      expect(p.listError, isNotNull);
    });

    test('paginación incremental acumula y calcula hasMore', () async {
      final repo = FakeRepo()
        ..listHandler = ({estado, desde, hasta, skip = 0, limit = 20}) async {
          if (skip == 0) {
            return PrescriptionPage(
              items: List.generate(
                20,
                (i) => _receta(id: i + 1, folio: 'REC-$i'),
              ),
              total: 25,
              skip: 0,
              limit: 20,
            );
          }
          return PrescriptionPage(
            items: List.generate(5, (i) => _receta(id: 100 + i)),
            total: 25,
            skip: 20,
            limit: 20,
          );
        };
      final p = _provider(repo);
      await p.loadPrescriptions(refresh: true);
      expect(p.hasMore, true);
      await p.loadMore();
      expect(p.items, hasLength(25));
      expect(p.hasMore, false);
    });
  });

  group('PrescriptionProvider errores semánticos', () {
    test('401 en detalle => sesión expirada', () async {
      final repo = FakeRepo()
        ..detailHandler = (_) async {
          throw UnauthorizedException();
        };
      final p = _provider(repo);
      await p.loadDetail(99);
      expect(p.detailStatus, PrescriptionDetailStatus.error);
      expect(p.detailError, contains('sesión'));
    });

    test('403 en detalle => acceso restringido', () async {
      final repo = FakeRepo()
        ..detailHandler = (_) async {
          throw ForbiddenException();
        };
      final p = _provider(repo);
      await p.loadDetail(99);
      expect(p.detailError, contains('restringido'));
    });

    test('404 en detalle => mensaje genérico uniforme', () async {
      final repo = FakeRepo()
        ..detailHandler = (_) async {
          throw NotFoundException('cualquier mensaje interno');
        };
      final p = _provider(repo);
      await p.loadDetail(999);
      expect(p.detailStatus, PrescriptionDetailStatus.error);
      expect(p.detailError, 'La receta solicitada no fue encontrada.');
    });

    test('timeout en detalle => mensaje de espera', () async {
      final repo = FakeRepo()
        ..detailHandler = (_) async {
          throw TimeoutException();
        };
      final p = _provider(repo);
      await p.loadDetail(1);
      expect(p.detailError, contains('espera'));
    });
  });

  group('PrescriptionProvider descarga', () {
    test('descarga exitosa expone bytes y nombre seguro', () async {
      final repo = FakeRepo();
      repo.detailHandler = (id) async {
        return _receta(id: 58, folio: 'REC-2026-000058');
      };
      repo.downloadHandler = (_) async {
        return Uint8List.fromList([37, 80, 68, 70]);
      };
      final p = _provider(repo);
      await p.loadDetail(58);
      final bytes = await p.downloadPdf(58);
      expect(bytes, isNotNull);
      expect(bytes!.isNotEmpty, true);
      expect(p.downloadStatus, PrescriptionDownloadStatus.success);
      expect(p.lastDownloadedFilename, 'receta_REC-2026-000058.pdf');
      // El detalle sigue visible.
      expect(p.detailStatus, PrescriptionDetailStatus.loaded);
      expect(p.selected, isNotNull);
    });

    test('bytes vacíos => error sin borrar detalle', () async {
      final repo = FakeRepo();
      repo.detailHandler = (id) async {
        return _receta(id: 1);
      };
      repo.downloadHandler = (_) async {
        return Uint8List(0);
      };
      final p = _provider(repo);
      await p.loadDetail(1);
      final bytes = await p.downloadPdf(1);
      expect(bytes, isNull);
      expect(p.downloadStatus, PrescriptionDownloadStatus.error);
      expect(p.downloadError, contains('vacío'));
      expect(p.selected, isNotNull);
      expect(p.detailStatus, PrescriptionDetailStatus.loaded);
    });

    test('previene descargas simultáneas', () async {
      final completer = Completer<Uint8List>();
      final repo = FakeRepo()..downloadHandler = (_) => completer.future;
      final p = _provider(repo);

      final first = p.downloadPdf(1);
      expect(p.downloadStatus, PrescriptionDownloadStatus.downloading);
      final second = await p.downloadPdf(1);
      expect(second, isNull);
      expect(repo.downloadCalls, 1);

      completer.complete(Uint8List.fromList([1, 2, 3]));
      final firstResult = await first;
      expect(firstResult, isNotNull);
    });

    test('fallo de descarga conserva el detalle visible', () async {
      final repo = FakeRepo();
      repo.detailHandler = (id) async {
        return _receta(id: 5);
      };
      repo.downloadHandler = (_) async {
        throw NetworkException();
      };
      final p = _provider(repo);
      await p.loadDetail(5);
      await p.downloadPdf(5);
      expect(p.downloadStatus, PrescriptionDownloadStatus.error);
      expect(p.selected?.idReceta, 5);
      expect(p.detailStatus, PrescriptionDetailStatus.loaded);
    });
  });
}
