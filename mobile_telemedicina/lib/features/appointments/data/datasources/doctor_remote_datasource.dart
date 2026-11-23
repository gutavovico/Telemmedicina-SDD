import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../models/doctor_model.dart';

class DoctorRemoteDataSource {
  final ApiClient _apiClient;

  DoctorRemoteDataSource({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Future<List<DoctorModel>> getDoctors({
    String? nombre,
    int? idEspecialidad,
    String? estado = 'activo',
  }) async {
    final queryParams = <String, String>{};
    if (nombre != null && nombre.trim().isNotEmpty) {
      queryParams['nombre'] = nombre.trim();
    }
    if (idEspecialidad != null && idEspecialidad > 0) {
      queryParams['id_especialidad'] = idEspecialidad.toString();
    }
    if (estado != null && estado.isNotEmpty) {
      queryParams['estado'] = estado;
    }

    final queryString = queryParams.isNotEmpty
        ? '?${Uri(queryParameters: queryParams).query}'
        : '';

    final response = await _apiClient.get('${ApiConfig.doctorsUrl}$queryString');

    if (response is Map<String, dynamic> && response.containsKey('items')) {
      final items = response['items'] as List<dynamic>;
      return items
          .map((item) => DoctorModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } else if (response is List<dynamic>) {
      return response
          .map((item) => DoctorModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<DoctorModel> getDoctorById(int idMedico) async {
    final response = await _apiClient.get('${ApiConfig.doctorsUrl}/$idMedico');
    return DoctorModel.fromJson(response as Map<String, dynamic>);
  }

  Future<List<SpecialtyModel>> getSpecialties({bool todos = false}) async {
    final url = todos
        ? '${ApiConfig.specialtiesUrl}?todos=true'
        : ApiConfig.specialtiesUrl;
    final response = await _apiClient.get(url);

    if (response is List<dynamic>) {
      return response
          .map((item) => SpecialtyModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }
}
