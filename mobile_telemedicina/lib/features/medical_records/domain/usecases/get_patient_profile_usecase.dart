import '../entities/patient_entity.dart';
import '../repositories/patient_repository.dart';

class GetPatientProfileUseCase {
  final PatientRepository _repository;

  GetPatientProfileUseCase(this._repository);

  Future<PatientEntity> call() {
    return _repository.getMyPatientProfile();
  }
}
