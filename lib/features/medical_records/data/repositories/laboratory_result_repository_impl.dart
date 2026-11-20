import 'dart:typed_data';

import '../../domain/entities/laboratory_result.dart';
import '../../domain/failures/lab_result_failure.dart';
import '../../domain/repositories/laboratory_result_repository.dart';
import '../services/lab_result_error_mapper.dart';
import '../services/laboratory_result_service.dart';

class LaboratoryResultRepositoryImpl implements LaboratoryResultRepository {
  final LaboratoryResultService _service;

  LaboratoryResultRepositoryImpl({LaboratoryResultService? service})
      : _service = service ?? LaboratoryResultService();

  @override
  Future<LaboratoryResultPage> getMyResults({
    int page = 1,
    int pageSize = 10,
    String? codigoExamen,
    String? fechaDesde,
    String? fechaHasta,
  }) async {
    try {
      final model = await _service.getMine(
        page: page,
        pageSize: pageSize,
        codigoExamen: codigoExamen,
        fechaDesde: fechaDesde,
        fechaHasta: fechaHasta,
      );
      return model.toEntity();
    } catch (error) {
      throw LabResultErrorMapper.fromError(error, operation: LabResultOperation.list);
    }
  }

  @override
  Future<Uint8List> downloadFile(int idResultado) async {
    try {
      final bytes = await _service.downloadFile(idResultado);
      if (bytes.isEmpty) {
        throw const LabResultFailure(
          kind: LabResultFailureKind.emptyFile,
          message: 'El servidor devolvió un archivo vacío. Intenta nuevamente.',
        );
      }
      return bytes;
    } catch (error) {
      throw LabResultErrorMapper.fromError(error, operation: LabResultOperation.file);
    }
  }
}
