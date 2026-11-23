import 'dart:typed_data';

import '../../data/repositories/laboratory_result_repository_impl.dart';
import '../repositories/laboratory_result_repository.dart';

/// Caso de uso: descarga segura (bytes) del archivo de un resultado de laboratorio (CU11).
class DownloadLabResultUseCase {
  final LaboratoryResultRepository _repository;

  DownloadLabResultUseCase({LaboratoryResultRepository? repository})
      : _repository = repository ?? LaboratoryResultRepositoryImpl();

  Future<Uint8List> call(int idResultado) => _repository.downloadFile(idResultado);
}
