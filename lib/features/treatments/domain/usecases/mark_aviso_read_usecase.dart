import '../../data/repositories/treatment_repository_impl.dart';
import '../entities/treatment_entities.dart';
import '../repositories/treatment_repository.dart';

/// Caso de uso: Marcar un aviso de tratamiento como leído.
class MarkAvisoReadUseCase {
  final TreatmentRepository _repository;

  MarkAvisoReadUseCase({TreatmentRepository? repository})
      : _repository = repository ?? TreatmentRepositoryImpl();

  Future<Aviso> call(int idAviso) {
    return _repository.leerAviso(idAviso);
  }
}
