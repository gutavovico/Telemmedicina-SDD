import '../entities/ficha_entity.dart';
import '../repositories/ficha_repository.dart';

class CreateFichaUseCase {
  final FichaRepository _repository;

  CreateFichaUseCase(this._repository);

  Future<FichaEntity> call(Map<String, dynamic> data) {
    return _repository.createFicha(data);
  }
}
