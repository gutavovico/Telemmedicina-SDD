import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/entities/prescription.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/repositories/prescription_repository.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/usecases/download_prescription_pdf_usecase.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/usecases/get_my_prescriptions_usecase.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/usecases/get_prescription_detail_usecase.dart';
import 'package:mobile_telemedicina/features/medical_records/presentation/providers/prescription_provider.dart';
import 'package:mobile_telemedicina/features/medical_records/presentation/utils/prescription_dates.dart';
import 'dart:typed_data';

class FakeRepo implements PrescriptionRepository {
  String? lastEstado;
  String? lastDesde;
  String? lastHasta;
  int calls = 0;

  @override
  Future<PrescriptionPage> getMyPrescriptions({
    String? estado,
    String? desde,
    String? hasta,
    int skip = 0,
    int limit = 20,
  }) async {
    calls++;
    lastEstado = estado;
    lastDesde = desde;
    lastHasta = hasta;
    return PrescriptionPage(items: [], total: 0, skip: skip, limit: limit);
  }

  @override
  Future<Prescription> getPrescriptionById(int idReceta) =>
      throw UnimplementedError();

  @override
  Future<Uint8List> downloadPrescriptionPdf(int idReceta) =>
      throw UnimplementedError();
}

void main() {
  group('Filtros de fecha CU16', () {
    test('rango válido se acepta', () {
      expect(isValidDateRange('2026-09-01', '2026-09-30'), true);
      expect(isValidDateRange('2026-09-01', '2026-09-01'), true);
      expect(isValidDateRange(null, '2026-09-30'), true);
      expect(isValidDateRange('2026-09-01', null), true);
      expect(isValidDateRange(null, null), true);
    });

    test('hasta anterior a desde es inválido', () {
      expect(isValidDateRange('2026-09-30', '2026-09-01'), false);
      expect(isValidDateRange('2026-10-01', '2026-09-30'), false);
    });

    test('provider aplica rango válido', () async {
      final repo = FakeRepo();
      final p = PrescriptionProvider(
        getMyPrescriptionsUseCase: GetMyPrescriptionsUseCase(repository: repo),
        getDetailUseCase: GetPrescriptionDetailUseCase(repository: repo),
        downloadUseCase: DownloadPrescriptionPdfUseCase(repository: repo),
      );
      await p.setFilters(
        estado: 'EMITIDA',
        desde: '2026-09-01',
        hasta: '2026-09-30',
      );
      expect(repo.lastEstado, 'EMITIDA');
      expect(repo.lastDesde, '2026-09-01');
      expect(repo.lastHasta, '2026-09-30');
      expect(p.desdeFilter, '2026-09-01');
      expect(p.hastaFilter, '2026-09-30');
    });

    test('limpieza de fechas envía nulos', () async {
      final repo = FakeRepo();
      final p = PrescriptionProvider(
        getMyPrescriptionsUseCase: GetMyPrescriptionsUseCase(repository: repo),
        getDetailUseCase: GetPrescriptionDetailUseCase(repository: repo),
        downloadUseCase: DownloadPrescriptionPdfUseCase(repository: repo),
      );
      await p.setFilters(desde: '2026-09-01', hasta: '2026-09-30');
      expect(repo.lastDesde, '2026-09-01');
      await p.setFilters(desde: null, hasta: null);
      expect(repo.lastDesde, isNull);
      expect(repo.lastHasta, isNull);
      expect(p.desdeFilter, isNull);
      expect(p.hastaFilter, isNull);
    });

    test('preservación del filtro de estado al modificar fechas', () async {
      final repo = FakeRepo();
      final p = PrescriptionProvider(
        getMyPrescriptionsUseCase: GetMyPrescriptionsUseCase(repository: repo),
        getDetailUseCase: GetPrescriptionDetailUseCase(repository: repo),
        downloadUseCase: DownloadPrescriptionPdfUseCase(repository: repo),
      );
      await p.setFilters(estado: 'ANULADA', desde: '2026-09-01');
      expect(repo.lastEstado, 'ANULADA');
      // Modifica solo fechas: el estado debe preservarse.
      await p.setFilters(
        estado: p.estadoFilter,
        desde: '2026-09-05',
        hasta: null,
      );
      expect(repo.lastEstado, 'ANULADA');
      expect(repo.lastDesde, '2026-09-05');
      expect(p.estadoFilter, 'ANULADA');
    });

    test('formato visible dd/MM/yyyy', () {
      expect(formatVisibleDate('2026-09-22T22:30:00Z'), '22/09/2026');
      expect(formatVisibleDate('2026-10-22'), '22/10/2026');
      expect(formatVisibleDate(''), '—');
    });
  });
}
