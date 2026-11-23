import '../entities/doctor_entity.dart';
import '../entities/specialty_entity.dart';

abstract class DoctorRepository {
  Future<List<DoctorEntity>> getDoctors({
    String? nombre,
    int? idEspecialidad,
    String? estado,
  });

  Future<DoctorEntity> getDoctorById(int idMedico);

  Future<List<SpecialtyEntity>> getSpecialties({bool todos = false});
}
