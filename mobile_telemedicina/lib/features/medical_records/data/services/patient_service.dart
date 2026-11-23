import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../models/patient_model.dart';

class PatientService {
  final ApiClient _apiClient = ApiClient();

  /// Obtiene el expediente y perfil del paciente autenticado desde `/api/v1/pacientes/me`
  Future<PatientModel> getMyPatientProfile() async {
    final response = await _apiClient.get(ApiConfig.myPatientProfileUrl);
    return PatientModel.fromJson(response as Map<String, dynamic>);
  }

  /// Actualiza los datos de contacto y emergencia del paciente autenticado desde `/api/v1/pacientes/me`
  Future<PatientModel> updateMyPatientProfile(Map<String, dynamic> patchData) async {
    final response = await _apiClient.patch(
      ApiConfig.myPatientProfileUrl,
      body: patchData,
    );
    return PatientModel.fromJson(response as Map<String, dynamic>);
  }
}
