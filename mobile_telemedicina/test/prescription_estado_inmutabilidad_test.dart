import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/entities/prescription.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/repositories/prescription_repository.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/usecases/download_prescription_pdf_usecase.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/usecases/get_my_prescriptions_usecase.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/usecases/get_prescription_detail_usecase.dart';
import 'package:mobile_telemedicina/features/medical_records/presentation/providers/prescription_provider.dart';
import 'dart:typed_data';

Prescription _receta({int id = 1}) {
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
      nombreCompleto: 'Dr',
      matriculaProfesional: 'MP-1',
    ),
    paciente: const PrescriptionPaciente(idPaciente: 10, nombreCompleto: 'P'),
    detalles: [
      PrescriptionDetalle(
        idRecetaDetalle: 1,
        medicamentoNombre: 'A',
        dosis: 'd',
        frecuencia: 'f',
        duracion: 'du',
        viaAdministracion: 'ORAL',
        cantidad: 1,
        posicion: 1,
      ),
    ],
  );
}

class FakeRepo implements PrescriptionRepository {
  @override
  Future<PrescriptionPage> getMyPrescriptions({
    String? estado,
    String? desde,
    String? hasta,
    int skip = 0,
    int limit = 20,
  }) async =>
      PrescriptionPage(items: [_receta()], total: 1, skip: skip, limit: limit);

  @override
  Future<Prescription> getPrescriptionById(int idReceta) async => _receta();

  @override
  Future<Uint8List> downloadPrescriptionPdf(int idReceta) async =>
      Uint8List.fromList([1]);
}

void main() {
  group('Estados desconocidos seguros', () {
    test('EMITIDA exacto', () {
      expect(estadoRecetaFromString('EMITIDA'), EstadoReceta.emitida);
    });

    test('ANULADA exacto', () {
      expect(estadoRecetaFromString('ANULADA'), EstadoReceta.anulada);
    });

    test('tolera minúsculas/mayúsculas y espacios', () {
      expect(estadoRecetaFromString('emitida'), EstadoReceta.emitida);
      expect(estadoRecetaFromString('anulada'), EstadoReceta.anulada);
      expect(estadoRecetaFromString(' Emitida '), EstadoReceta.emitida);
      expect(estadoRecetaFromString('emItIdA'), EstadoReceta.emitida);
    });

    test('valor desconocido mapea a desconocido, nunca a emitida', () {
      expect(estadoRecetaFromString('VENCIDA'), EstadoReceta.desconocido);
      expect(estadoRecetaFromString('PENDIENTE'), EstadoReceta.desconocido);
      expect(estadoRecetaFromString('XYZ'), EstadoReceta.desconocido);
      expect(
        estadoVisualDe(estado: EstadoReceta.desconocido, estaVencida: false),
        EstadoVisualReceta.desconocido,
      );
      // Sin semántica de vigencia aunque estaVencida=true.
      expect(
        estadoVisualDe(estado: EstadoReceta.desconocido, estaVencida: true),
        EstadoVisualReceta.desconocido,
      );
    });

    test('valor vacío mapea a desconocido', () {
      expect(estadoRecetaFromString(''), EstadoReceta.desconocido);
      expect(estadoRecetaFromString('   '), EstadoReceta.desconocido);
    });
  });

  group('Inmutabilidad defensiva', () {
    test('Prescription.detalles no modificable', () {
      final p = _receta();
      expect(() => p.detalles.add(p.detalles.first), throwsUnsupportedError);
      expect(() => p.detalles.clear(), throwsUnsupportedError);
      expect(p.detalles, hasLength(1));
    });

    test('PrescriptionPage.items no modificable', () {
      final page = PrescriptionPage(
        items: [_receta(id: 1)],
        total: 1,
        skip: 0,
        limit: 20,
      );
      expect(() => page.items.add(_receta(id: 2)), throwsUnsupportedError);
      expect(() => page.items.clear(), throwsUnsupportedError);
      expect(page.items, hasLength(1));
    });

    test('mutar lista original no afecta a la entidad (copia defensiva)', () {
      final mutable = [_receta(id: 1)];
      final page = PrescriptionPage(
        items: mutable,
        total: 1,
        skip: 0,
        limit: 20,
      );
      mutable.clear();
      // La entidad conserva su copia.
      expect(page.items, hasLength(1));
    });

    test('provider.items no permite mutación externa', () async {
      final provider = PrescriptionProvider(
        getMyPrescriptionsUseCase: GetMyPrescriptionsUseCase(
          repository: FakeRepo(),
        ),
        getDetailUseCase: GetPrescriptionDetailUseCase(repository: FakeRepo()),
        downloadUseCase: DownloadPrescriptionPdfUseCase(repository: FakeRepo()),
      );
      await provider.loadPrescriptions(refresh: true);
      expect(provider.items, hasLength(1));
      expect(() => provider.items.add(_receta(id: 99)), throwsUnsupportedError);
      expect(() => (provider.items as List).clear(), throwsUnsupportedError);
      // El estado interno sigue intacto.
      expect(provider.items, hasLength(1));
    });
  });
}
