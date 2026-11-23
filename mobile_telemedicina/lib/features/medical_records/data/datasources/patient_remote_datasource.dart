import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../models/patient_model.dart';

class PatientRemoteDataSource {
  final ApiClient _apiClient;

  PatientRemoteDataSource({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Future<PatientModel> getMyPatientProfile() async {
    final response = await _apiClient.get(ApiConfig.myPatientProfileUrl);
    return PatientModel.fromJson(response as Map<String, dynamic>);
  }

  Future<PatientModel> updateMyPatientProfile(Map<String, dynamic> patchData) async {
    final response = await _apiClient.patch(
      ApiConfig.myPatientProfileUrl,
      body: patchData,
    );
    return PatientModel.fromJson(response as Map<String, dynamic>);
  }
}
