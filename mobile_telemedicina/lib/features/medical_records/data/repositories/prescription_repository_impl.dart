import 'dart:typed_data';

import '../../domain/entities/prescription.dart';
import '../../domain/repositories/prescription_repository.dart';
import '../datasources/prescription_remote_datasource.dart';
import '../models/prescription_model.dart';

/// Repositorio concreto CU16 con mapeos explícitos modelo → entidad.
///
/// Ordena los detalles ascendentemente por `posicion` aunque el backend
/// altere el orden, y rechaza PDFs vacíos por construcción.
class PrescriptionRepositoryImpl implements PrescriptionRepository {
  final PrescriptionRemoteDatasource _datasource;

  PrescriptionRepositoryImpl({PrescriptionRemoteDatasource? datasource})
    : _datasource = datasource ?? PrescriptionRemoteDatasource();

  @override
  Future<PrescriptionPage> getMyPrescriptions({
    String? estado,
    String? desde,
    String? hasta,
    int skip = 0,
    int limit = 20,
  }) async {
    final result = await _datasource.getMyPrescriptions(
      estado: estado,
      desde: desde,
      hasta: hasta,
      skip: skip,
      limit: limit,
    );
    final entities = result.items.map(mapEntity).toList();
    return PrescriptionPage(
      items: entities,
      total: result.total,
      skip: skip,
      limit: limit,
    );
  }

  @override
  Future<Prescription> getPrescriptionById(int idReceta) async {
    final model = await _datasource.getPrescriptionById(idReceta);
    return mapEntity(model);
  }

  @override
  Future<Uint8List> downloadPrescriptionPdf(int idReceta) async {
    final bytes = await _datasource.downloadPrescriptionPdf(idReceta);
    if (bytes.isEmpty) {
      throw StateError(
        'El servidor devolvió un documento vacío. Intenta nuevamente.',
      );
    }
    return bytes;
  }

  /// Mapeo explícito modelo → entidad (sin `dynamic` en dominio).
  static Prescription mapEntity(PrescriptionModel model) {
    final detalles = model.detalles.map(mapDetalle).toList()
      ..sort((a, b) => a.posicion.compareTo(b.posicion));
    return Prescription(
      idReceta: model.idReceta,
      idClinica: model.idClinica,
      idConsulta: model.idConsulta,
      idPaciente: model.idPaciente,
      idMedico: model.idMedico,
      idDocumento: model.idDocumento,
      idRecetaSustituta: model.idRecetaSustituta,
      folio: model.folio,
      pdfUrl: model.pdfUrl,
      indicacionesGenerales: model.indicacionesGenerales,
      algoritmoFirma: model.algoritmoFirma,
      keyId: model.keyId,
      versionPayload: model.versionPayload,
      hashPdf: model.hashPdf,
      fechaEmision: model.fechaEmision,
      fechaVencimiento: model.fechaVencimiento,
      estaVencida: model.estaVencida,
      estado: estadoRecetaFromString(model.estado),
      motivoAnulacion: model.motivoAnulacion,
      observacionesAnulacion: model.observacionesAnulacion,
      fechaAnulacion: model.fechaAnulacion,
      medico: PrescriptionMedico(
        idMedico: model.medico.idMedico,
        nombreCompleto: model.medico.nombreCompleto,
        matriculaProfesional: model.medico.matriculaProfesional,
        especialidad: model.medico.especialidad,
      ),
      paciente: PrescriptionPaciente(
        idPaciente: model.paciente.idPaciente,
        nombreCompleto: model.paciente.nombreCompleto,
      ),
      detalles: detalles,
    );
  }

  static PrescriptionDetalle mapDetalle(PrescriptionDetalleModel model) {
    return PrescriptionDetalle(
      idRecetaDetalle: model.idRecetaDetalle,
      idMedicamento: model.idMedicamento,
      nombreMedicamentoManual: model.nombreMedicamentoManual,
      medicamentoNombre: model.medicamentoNombre,
      principioActivo: model.principioActivo,
      concentracion: model.concentracion,
      formaFarmaceutica: model.formaFarmaceutica,
      dosis: model.dosis,
      frecuencia: model.frecuencia,
      duracion: model.duracion,
      viaAdministracion: model.viaAdministracion,
      cantidad: model.cantidad,
      indicaciones: model.indicaciones,
      posicion: model.posicion,
    );
  }
}
