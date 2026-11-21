import '../../data/repositories/laboratory_result_repository_impl.dart';
import '../entities/laboratory_result.dart';
import '../repositories/laboratory_result_repository.dart';

/// Caso de uso: consultar los resultados de laboratorio incorporados del paciente autenticado (CU11).
class GetMyLabResultsUseCase {
  final LaboratoryResultRepository _repository;

  GetMyLabResultsUseCase({LaboratoryResultRepository? repository})
      : _repository = repository ?? LaboratoryResultRepositoryImpl();

  Future<LaboratoryResultPage> call({
    int page = 1,
    int pageSize = 10,
    String? codigoExamen,
    String? fechaDesde,
    String? fechaHasta,
  }) {
    return _repository.getMyResults(
      page: page,
      pageSize: pageSize,
      codigoExamen: codigoExamen,
      fechaDesde: fechaDesde,
      fechaHasta: fechaHasta,
    );
  }
}
