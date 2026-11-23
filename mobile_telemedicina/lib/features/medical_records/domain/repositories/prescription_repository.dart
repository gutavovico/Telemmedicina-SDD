import 'dart:typed_data';

import '../entities/prescription.dart';

/// Contrato del repositorio de recetas (CU16, solo lectura).
///
/// Por seguridad, ningún método acepta `idPaciente`, `idMedico`,
/// `idClinica` ni `tenantId`: el alcance lo resuelve el backend desde
/// la identidad autenticada (JWT + `X-Tenant-ID` inyectados por `ApiClient`).
abstract class PrescriptionRepository {
  /// Lista las recetas propias con filtros permitidos y paginación.
  Future<PrescriptionPage> getMyPrescriptions({
    String? estado,
    String? desde,
    String? hasta,
    int skip = 0,
    int limit = 20,
  });

  /// Consulta el detalle estructurado de una receta propia.
  Future<Prescription> getPrescriptionById(int idReceta);

  /// Descarga los bytes crudos del PDF original autenticado.
  Future<Uint8List> downloadPrescriptionPdf(int idReceta);
}
