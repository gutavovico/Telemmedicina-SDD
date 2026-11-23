import 'dart:typed_data';

import '../entities/laboratory_result.dart';

/// Contrato del repositorio de resultados de laboratorio (CU11, solo lectura).
/// La capa de datos implementa esta interfaz y lanza `LabResultFailure` ante errores.
abstract class LaboratoryResultRepository {
  /// Resultados incorporados del paciente autenticado (`GET .../me`).
  Future<LaboratoryResultPage> getMyResults({
    int page = 1,
    int pageSize = 10,
    String? codigoExamen,
    String? fechaDesde,
    String? fechaHasta,
  });

  /// Bytes del archivo de un resultado (`GET .../{id}/archivo`).
  Future<Uint8List> downloadFile(int idResultado);
}
