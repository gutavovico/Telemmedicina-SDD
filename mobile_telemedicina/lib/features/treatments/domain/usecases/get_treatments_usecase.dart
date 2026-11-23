import '../../data/repositories/treatment_repository_impl.dart';
import '../entities/treatment_entities.dart';
import '../repositories/treatment_repository.dart';

/// Caso de uso: Consultar lista de tratamientos médicos del paciente.
class GetTreatmentsUseCase {
  final TreatmentRepository _repository;

  GetTreatmentsUseCase({TreatmentRepository? repository})
      : _repository = repository ?? TreatmentRepositoryImpl();

  Future<TreatmentPage> call({
    String? estado,
    int skip = 0,
    int limit = 20,
  }) {
    return _repository.getTreatments(
      estado: estado,
      skip: skip,
      limit: limit,
    );
  }
}
