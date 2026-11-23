import '../../domain/entities/doctor_entity.dart';
import '../../domain/entities/specialty_entity.dart';
import '../../domain/repositories/doctor_repository.dart';
import '../datasources/doctor_remote_datasource.dart';

class DoctorRepositoryImpl implements DoctorRepository {
  final DoctorRemoteDataSource _remoteDataSource;

  DoctorRepositoryImpl({DoctorRemoteDataSource? remoteDataSource})
      : _remoteDataSource = remoteDataSource ?? DoctorRemoteDataSource();

  @override
  Future<List<DoctorEntity>> getDoctors({
    String? nombre,
    int? idEspecialidad,
    String? estado,
  }) {
    return _remoteDataSource.getDoctors(
      nombre: nombre,
      idEspecialidad: idEspecialidad,
      estado: estado,
    );
  }

  @override
  Future<DoctorEntity> getDoctorById(int idMedico) {
    return _remoteDataSource.getDoctorById(idMedico);
  }

  @override
  Future<List<SpecialtyEntity>> getSpecialties({bool todos = false}) {
    return _remoteDataSource.getSpecialties(todos: todos);
  }
}
