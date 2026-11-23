import '../../data/repositories/treatment_repository_impl.dart';
import '../entities/treatment_entities.dart';
import '../repositories/treatment_repository.dart';

/// Caso de uso: Consultar índice y nivel de adherencia del tratamiento.
class GetAdherenciaUseCase {
  final TreatmentRepository _repository;

  GetAdherenciaUseCase({TreatmentRepository? repository})
      : _repository = repository ?? TreatmentRepositoryImpl();

  Future<Adherencia> call(int idTratamiento) {
    return _repository.getAdherencia(idTratamiento);
  }
}
