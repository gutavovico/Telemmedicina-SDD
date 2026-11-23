import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/entities/prescription.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/repositories/prescription_repository.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/usecases/download_prescription_pdf_usecase.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/usecases/get_my_prescriptions_usecase.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/usecases/get_prescription_detail_usecase.dart';
import 'package:mobile_telemedicina/features/medical_records/presentation/providers/prescription_provider.dart';

Prescription _receta(int id) {
  return Prescription(
    idReceta: id,
    idClinica: 1,
    idConsulta: 1,
    idPaciente: 10,
    idMedico: 3,
    folio: 'REC-$id',
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
  Future<PrescriptionPage> Function({required int skip, required int limit})?
  listHandler;
  final List<int> requestedSkips = [];
  int listCalls = 0;

  @override
  Future<PrescriptionPage> getMyPrescriptions({
    String? estado,
    String? desde,
    String? hasta,
    int skip = 0,
    int limit = 20,
  }) {
    listCalls++;
    requestedSkips.add(skip);
    return listHandler!(skip: skip, limit: limit);
  }

  @override
  Future<Prescription> getPrescriptionById(int idReceta) =>
      throw UnimplementedError();

  @override
  Future<Uint8List> downloadPrescriptionPdf(int idReceta) =>
      throw UnimplementedError();
}

PrescriptionProvider _provider(FakeRepo repo) => PrescriptionProvider(
  getMyPrescriptionsUseCase: GetMyPrescriptionsUseCase(repository: repo),
  getDetailUseCase: GetPrescriptionDetailUseCase(repository: repo),
  downloadUseCase: DownloadPrescriptionPdfUseCase(repository: repo),
);

void main() {
  group('Paginación CU16 corregida', () {
    test('tres páginas sin saltos con secuencia skip 0, 20, 40', () async {
      final repo = FakeRepo()
        ..listHandler = ({required int skip, required int limit}) async {
          if (skip == 0) {
            return PrescriptionPage(
              items: List.generate(20, (i) => _receta(i + 1)),
              total: 55,
              skip: 0,
              limit: 20,
            );
          }
          if (skip == 20) {
            return PrescriptionPage(
              items: List.generate(20, (i) => _receta(21 + i)),
              total: 55,
              skip: 20,
              limit: 20,
            );
          }
          if (skip == 40) {
            return PrescriptionPage(
              items: List.generate(15, (i) => _receta(41 + i)),
              total: 55,
              skip: 40,
              limit: 20,
            );
          }
          fail('skip inesperado: $skip');
        };
      final p = _provider(repo);

      await p.loadPrescriptions(refresh: true, limit: 20);
      expect(
        p.items.map((e) => e.idReceta).toList(),
        List.generate(20, (i) => i + 1),
      );
      expect(p.hasMore, true);

      await p.loadMore();
      expect(repo.requestedSkips, [0, 20]);
      expect(p.items, hasLength(40));
      expect(p.items.map((e) => e.idReceta).toSet(), hasLength(40));
      expect(p.hasMore, true);

      await p.loadMore();
      // Secuencia exacta exigida: 0, 20, 40 (nunca 60).
      expect(repo.requestedSkips, [0, 20, 40]);
      expect(p.items, hasLength(55));
      expect(
        p.items.map((e) => e.idReceta).toList(),
        List.generate(55, (i) => i + 1),
      );
      expect(p.hasMore, false);
      // Sin duplicados ni saltos.
      final ids = p.items.map((e) => e.idReceta).toList();
      expect(ids.toSet(), hasLength(55));
      for (var i = 0; i < 55; i++) {
        expect(ids[i], i + 1);
      }
    });

    test('última página parcial mantiene hasMore coherente', () async {
      final repo = FakeRepo()
        ..listHandler = ({required int skip, required int limit}) async {
          if (skip == 0) {
            return PrescriptionPage(
              items: List.generate(20, (i) => _receta(i + 1)),
              total: 25,
              skip: 0,
              limit: 20,
            );
          }
          return PrescriptionPage(
            items: List.generate(5, (i) => _receta(21 + i)),
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
      expect(p.total, 25);
    });

    test('página inesperadamente vacía detiene paginación', () async {
      final repo = FakeRepo()
        ..listHandler = ({required int skip, required int limit}) async {
          if (skip == 0) {
            return PrescriptionPage(
              items: List.generate(20, (i) => _receta(i + 1)),
              total: 60,
              skip: 0,
              limit: 20,
            );
          }
          // Backend inconsistente: vacío antes de alcanzar total.
          return PrescriptionPage(items: [], total: 60, skip: 20, limit: 20);
        };
      final p = _provider(repo);
      await p.loadPrescriptions(refresh: true);
      expect(p.hasMore, true);
      await p.loadMore();
      // No debe quedar hasMore=true (evita solicitudes infinitas).
      expect(p.hasMore, false);
      expect(p.items, hasLength(20));
      // Un loadMore adicional no debe llamar al repositorio.
      final calls = repo.listCalls;
      await p.loadMore();
      expect(repo.listCalls, calls);
    });

    test('prevención de llamadas simultáneas a loadMore', () async {
      final c1 = Completer<PrescriptionPage>();
      final repo = FakeRepo()
        ..listHandler = ({required int skip, required int limit}) {
          if (skip == 0) {
            return Future.value(
              PrescriptionPage(
                items: List.generate(20, (i) => _receta(i + 1)),
                total: 60,
                skip: 0,
                limit: 20,
              ),
            );
          }
          return c1.future;
        };
      final p = _provider(repo);
      await p.loadPrescriptions(refresh: true);
      expect(p.hasMore, true);

      final first = p.loadMore();
      // Segunda llamada simultánea debe ignorarse.
      await p.loadMore();
      expect(repo.listCalls, 2); // 1 inicial + 1 loadMore (no 2 loadMore)
      c1.complete(
        PrescriptionPage(
          items: List.generate(20, (i) => _receta(21 + i)),
          total: 60,
          skip: 20,
          limit: 20,
        ),
      );
      await first;
      expect(p.items, hasLength(40));
    });

    test('no duplica elementos si el backend solapa', () async {
      final repo = FakeRepo()
        ..listHandler = ({required int skip, required int limit}) async {
          if (skip == 0) {
            return PrescriptionPage(
              items: List.generate(20, (i) => _receta(i + 1)),
              total: 40,
              skip: 0,
              limit: 20,
            );
          }
          // Solapa id 20 y añade 21..39 (19 nuevos + 1 duplicado).
          return PrescriptionPage(
            items: List.generate(20, (i) => _receta(20 + i)),
            total: 40,
            skip: 20,
            limit: 20,
          );
        };
      final p = _provider(repo);
      await p.loadPrescriptions(refresh: true);
      await p.loadMore();
      final ids = p.items.map((e) => e.idReceta).toList();
      expect(ids.toSet(), hasLength(ids.length));
      expect(p.items, hasLength(39));
    });
  });
}
