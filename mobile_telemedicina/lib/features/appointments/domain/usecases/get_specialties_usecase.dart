import '../entities/specialty_entity.dart';
import '../repositories/doctor_repository.dart';

class GetSpecialtiesUseCase {
  final DoctorRepository _repository;

  GetSpecialtiesUseCase(this._repository);

  Future<List<SpecialtyEntity>> call({bool todos = false}) {
    return _repository.getSpecialties(todos: todos);
  }
}
