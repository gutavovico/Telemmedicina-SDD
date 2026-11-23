import '../../data/repositories/treatment_repository_impl.dart';
import '../entities/treatment_entities.dart';
import '../repositories/treatment_repository.dart';

/// Caso de uso: Consultar detalle estructurado de un tratamiento médico.
class GetTreatmentDetailUseCase {
  final TreatmentRepository _repository;

  GetTreatmentDetailUseCase({TreatmentRepository? repository})
      : _repository = repository ?? TreatmentRepositoryImpl();

  Future<TreatmentPlan> call(int idTratamiento) {
    return _repository.getTreatmentDetail(idTratamiento);
  }
}
