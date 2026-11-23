import '../entities/patient_entity.dart';

abstract class PatientRepository {
  Future<PatientEntity> getMyPatientProfile();
  Future<PatientEntity> updateMyPatientProfile(Map<String, dynamic> patchData);
}
