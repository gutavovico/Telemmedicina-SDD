import '../../domain/entities/patient_entity.dart';
import '../../domain/repositories/patient_repository.dart';
import '../datasources/patient_remote_datasource.dart';

class PatientRepositoryImpl implements PatientRepository {
  final PatientRemoteDataSource _remoteDataSource;

  PatientRepositoryImpl({PatientRemoteDataSource? remoteDataSource})
      : _remoteDataSource = remoteDataSource ?? PatientRemoteDataSource();

  @override
  Future<PatientEntity> getMyPatientProfile() {
    return _remoteDataSource.getMyPatientProfile();
  }

  @override
  Future<PatientEntity> updateMyPatientProfile(Map<String, dynamic> patchData) {
    return _remoteDataSource.updateMyPatientProfile(patchData);
  }
}
