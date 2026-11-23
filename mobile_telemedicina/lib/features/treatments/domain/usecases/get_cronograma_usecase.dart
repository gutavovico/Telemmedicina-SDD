import '../../data/repositories/treatment_repository_impl.dart';
import '../entities/treatment_entities.dart';
import '../repositories/treatment_repository.dart';

/// Caso de uso: Consultar cronograma diario de tomas para una fecha específica.
class GetCronogramaUseCase {
  final TreatmentRepository _repository;

  GetCronogramaUseCase({TreatmentRepository? repository})
      : _repository = repository ?? TreatmentRepositoryImpl();

  Future<CronogramaDia> call(int idTratamiento, String fecha) {
    return _repository.getCronograma(idTratamiento, fecha);
  }
}
