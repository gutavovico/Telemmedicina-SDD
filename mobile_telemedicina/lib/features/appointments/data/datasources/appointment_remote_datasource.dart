import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../models/appointment_model.dart';

class AppointmentRemoteDataSource {
  final ApiClient _apiClient = ApiClient();

  Future<List<AppointmentModel>> getAppointments({
    String? q,
    String? fecha,
    String? estado,
  }) async {
    final queryParams = <String, String>{};
    if (q != null && q.isNotEmpty) queryParams['q'] = q;
    if (fecha != null && fecha.isNotEmpty) queryParams['fecha'] = fecha;
    if (estado != null && estado.isNotEmpty && estado != 'TODOS') {
      queryParams['estado'] = estado;
    }

    final uri = Uri.parse(
      ApiConfig.appointmentsUrl,
    ).replace(queryParameters: queryParams.isEmpty ? null : queryParams);
    final response = await _apiClient.get(uri.toString());

    if (response is Map<String, dynamic> && response.containsKey('items')) {
      final List items = response['items'] as List;
      return items
          .map(
            (json) => AppointmentModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } else if (response is List) {
      return response
          .map(
            (json) => AppointmentModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    }
    return [];
  }

  Future<AppointmentModel> createAppointment(Map<String, dynamic> data) async {
    final response = await _apiClient.post(
      ApiConfig.appointmentsUrl,
      body: data,
    );
    return AppointmentModel.fromJson(response as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> createPatient(Map<String, dynamic> data) async {
    final response = await _apiClient.post(ApiConfig.patientsUrl, body: data);
    return Map<String, dynamic>.from(response as Map);
  }

  Future<AppointmentModel> updateAppointment(
    int id,
    Map<String, dynamic> data,
  ) async {
    final response = await _apiClient.put(
      '${ApiConfig.appointmentsUrl}/$id',
      body: data,
    );
    return AppointmentModel.fromJson(response as Map<String, dynamic>);
  }

  Future<bool> deleteAppointment(int id) async {
    await _apiClient.delete('${ApiConfig.appointmentsUrl}/$id');
    return true;
  }

  Future<List<Map<String, dynamic>>> getDoctors() async {
    try {
      final response = await _apiClient.get(ApiConfig.doctorsUrl);
      if (response is Map<String, dynamic> && response.containsKey('items')) {
        return List<Map<String, dynamic>>.from(response['items'] as List);
      } else if (response is List) {
        return List<Map<String, dynamic>>.from(response);
      }
    } catch (_) {}
    return [];
  }
}
