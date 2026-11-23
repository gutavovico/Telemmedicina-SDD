import '../entities/doctor_entity.dart';
import '../repositories/doctor_repository.dart';

class GetDoctorsUseCase {
  final DoctorRepository _repository;

  GetDoctorsUseCase(this._repository);

  Future<List<DoctorEntity>> call({
    String? nombre,
    int? idEspecialidad,
    String? estado = 'activo',
  }) {
    return _repository.getDoctors(
      nombre: nombre,
      idEspecialidad: idEspecialidad,
      estado: estado,
    );
  }
}
