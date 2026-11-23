import '../entities/ficha_entity.dart';
import '../repositories/ficha_repository.dart';

class GetPatientFichasUseCase {
  final FichaRepository _repository;

  GetPatientFichasUseCase(this._repository);

  Future<List<FichaEntity>> call({int? idPaciente, String? fecha, String? estado}) {
    return _repository.getFichas(idPaciente: idPaciente, fecha: fecha, estado: estado);
  }
}
