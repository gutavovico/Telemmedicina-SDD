import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/entities/prescription.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/repositories/prescription_repository.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/usecases/download_prescription_pdf_usecase.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/usecases/get_my_prescriptions_usecase.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/usecases/get_prescription_detail_usecase.dart';
import 'package:mobile_telemedicina/features/medical_records/presentation/providers/prescription_provider.dart';

Prescription _receta(int id, {String folio = ''}) {
  return Prescription(
    idReceta: id,
    idClinica: 1,
    idConsulta: 1,
    idPaciente: 10,
    idMedico: 3,
    folio: folio.isEmpty ? 'REC-$id' : folio,
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
    ),
    paciente: const PrescriptionPaciente(idPaciente: 10, nombreCompleto: 'Pac'),
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

  @override
  Future<PrescriptionPage> getMyPrescriptions({
    String? estado,
    String? desde,
    String? hasta,
    int skip = 0,
    int limit = 20,
  }) => listHandler!(
    estado: estado,
    desde: desde,
    hasta: hasta,
    skip: skip,
    limit: limit,
  );

  @override
  Future<Prescription> getPrescriptionById(int idReceta) =>
      detailHandler!(idReceta);

  @override
  Future<Uint8List> downloadPrescriptionPdf(int idReceta) =>
      downloadHandler!(idReceta);
}

PrescriptionProvider _provider(FakeRepo repo) => PrescriptionProvider(
  getMyPrescriptionsUseCase: GetMyPrescriptionsUseCase(repository: repo),
  getDetailUseCase: GetPrescriptionDetailUseCase(repository: repo),
  downloadUseCase: DownloadPrescriptionPdfUseCase(repository: repo),
);

void main() {
  group('Respuestas asíncronas obsoletas (generaciones)', () {
    test('filtro anterior lento no sobrescribe filtro actual', () async {
      final slow = Completer<PrescriptionPage>();
      final fast = Completer<PrescriptionPage>();
      var call = 0;
      final repo = FakeRepo()
        ..listHandler = ({estado, desde, hasta, skip = 0, limit = 20}) {
          call++;
          if (call == 1) return slow.future; // EMITIDA lenta
          return fast.future; // ANULADA rápida
        };
      final p = _provider(repo);

      final f1 = p.setFilters(estado: 'EMITIDA');
      // Espera a que la primera llamada quede pendiente.
      await Future.delayed(const Duration(milliseconds: 10));
      final f2 = p.setFilters(estado: 'ANULADA');
      fast.complete(
        PrescriptionPage(
          items: [_receta(99, folio: 'ANULADA-1')],
          total: 1,
          skip: 0,
          limit: 20,
        ),
      );
      await f2;
      expect(p.estadoFilter, 'ANULADA');
      expect(p.items.map((e) => e.folio), ['ANULADA-1']);

      // La lenta responde después: debe descartarse.
      slow.complete(
        PrescriptionPage(
          items: [_receta(1, folio: 'EMITIDA-1')],
          total: 1,
          skip: 0,
          limit: 20,
        ),
      );
      await f1;
      expect(p.estadoFilter, 'ANULADA');
      expect(p.items.map((e) => e.folio), ['ANULADA-1']);
    });

    test('refresh mientras loadMore pendiente descarta el loadMore', () async {
      final loadMoreCompleter = Completer<PrescriptionPage>();
      var listCalls = 0;
      final repo = FakeRepo()
        ..listHandler = ({estado, desde, hasta, skip = 0, limit = 20}) {
          listCalls++;
          if (listCalls == 1) {
            return Future.value(
              PrescriptionPage(
                items: List.generate(20, (i) => _receta(i + 1)),
                total: 60,
                skip: 0,
                limit: 20,
              ),
            );
          }
          if (listCalls == 2) return loadMoreCompleter.future;
          // Refresh posterior.
          return Future.value(
            PrescriptionPage(
              items: List.generate(20, (i) => _receta(100 + i)),
              total: 60,
              skip: 0,
              limit: 20,
            ),
          );
        };
      final p = _provider(repo);
      await p.loadPrescriptions(refresh: true);
      expect(p.items.first.idReceta, 1);

      final pending = p.loadMore();
      await Future.delayed(const Duration(milliseconds: 10));
      await p.loadPrescriptions(refresh: true);
      expect(p.items.first.idReceta, 100);

      // El loadMore anterior responde tarde con datos viejos.
      loadMoreCompleter.complete(
        PrescriptionPage(
          items: List.generate(20, (i) => _receta(21 + i)),
          total: 60,
          skip: 20,
          limit: 20,
        ),
      );
      await pending;
      // No debe añadir elementos obsoletos tras el refresh.
      expect(p.items, hasLength(20));
      expect(p.items.first.idReceta, 100);
    });

    test('detalles A y B fuera de orden: A no reemplaza a B', () async {
      final completerA = Completer<Prescription>();
      final completerB = Completer<Prescription>();
      final repo = FakeRepo()
        ..detailHandler = (id) {
          if (id == 1) return completerA.future;
          return completerB.future;
        };
      final p = _provider(repo);

      final fA = p.loadDetail(1);
      await Future.delayed(const Duration(milliseconds: 10));
      final fB = p.loadDetail(2);
      completerB.complete(_receta(2, folio: 'REC-B'));
      await fB;
      expect(p.selected?.idReceta, 2);
      expect(p.selected?.folio, 'REC-B');

      completerA.complete(_receta(1, folio: 'REC-A'));
      await fA;
      // A es obsoleta: no reemplaza a B.
      expect(p.selected?.idReceta, 2);
      expect(p.selected?.folio, 'REC-B');
      expect(p.detailStatus, PrescriptionDetailStatus.loaded);
    });

    test('estados de carga corresponden solo a solicitud vigente', () async {
      final slow = Completer<PrescriptionPage>();
      final repo = FakeRepo()
        ..listHandler = ({estado, desde, hasta, skip = 0, limit = 20}) {
          if (estado == 'EMITIDA') return slow.future;
          return Future.value(
            PrescriptionPage(items: [_receta(7)], total: 1, skip: 0, limit: 20),
          );
        };
      final p = _provider(repo);
      final f1 = p.setFilters(estado: 'EMITIDA');
      expect(p.listStatus, PrescriptionListStatus.loading);
      await p.setFilters(estado: 'ANULADA');
      expect(p.listStatus, PrescriptionListStatus.loaded);
      slow.complete(
        PrescriptionPage(items: [_receta(1)], total: 1, skip: 0, limit: 20),
      );
      await f1;
      // El error/éxito obsoleto no cambia el estado vigente.
      expect(p.listStatus, PrescriptionListStatus.loaded);
      expect(p.items.first.idReceta, 7);
    });

    test('no notifica después de dispose', () async {
      final completer = Completer<PrescriptionPage>();
      final repo = FakeRepo()
        ..listHandler = ({estado, desde, hasta, skip = 0, limit = 20}) =>
            completer.future;
      final p = _provider(repo);
      final future = p.loadPrescriptions(refresh: true);
      p.dispose();
      completer.complete(
        PrescriptionPage(items: [_receta(1)], total: 1, skip: 0, limit: 20),
      );
      // No debe lanzar por notifyListeners tras dispose.
      await future;
    });
  });
}
