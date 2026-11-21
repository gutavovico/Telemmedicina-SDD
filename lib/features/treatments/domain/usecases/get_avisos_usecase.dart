import '../../data/repositories/treatment_repository_impl.dart';
import '../entities/treatment_entities.dart';
import '../repositories/treatment_repository.dart';

/// Caso de uso: Listar avisos y alertas preventivas de tratamientos.
class GetAvisosUseCase {
  final TreatmentRepository _repository;

  GetAvisosUseCase({TreatmentRepository? repository})
      : _repository = repository ?? TreatmentRepositoryImpl();

  Future<AvisoPage> call({
    int skip = 0,
    int limit = 20,
    bool noLeidos = false,
  }) {
    return _repository.getAvisos(
      skip: skip,
      limit: limit,
      noLeidos: noLeidos,
    );
  }
}
