import '../entities/patient_entity.dart';
import '../repositories/patient_repository.dart';

class UpdatePatientProfileUseCase {
  final PatientRepository _repository;

  UpdatePatientProfileUseCase(this._repository);

  Future<PatientEntity> call(Map<String, dynamic> patchData) {
    return _repository.updateMyPatientProfile(patchData);
  }
}
