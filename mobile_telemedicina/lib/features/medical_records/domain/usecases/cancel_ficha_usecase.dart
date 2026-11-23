import '../entities/ficha_entity.dart';
import '../repositories/ficha_repository.dart';

class CancelFichaUseCase {
  final FichaRepository _repository;

  CancelFichaUseCase(this._repository);

  Future<FichaEntity> call(String idFicha, String motivo) {
    return _repository.cancelFicha(idFicha, motivo);
  }
}
