import '../../../../../core/config/api_config.dart';
import '../../../../../core/network/api_client.dart';
import '../../../../../core/network/api_client_interface.dart';
import '../models/specialist_search_models.dart';

class SpecialistSearchRemoteDataSource {
  final ApiClientInterface _apiClient;

  SpecialistSearchRemoteDataSource({ApiClientInterface? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<List<SpecialistSpecialtyOptionModel>> getSpecialties() async {
    final response = await _apiClient.get(ApiConfig.specialtiesUrl);
    if (response is List<dynamic>) {
      return response
          .map(
            (item) => SpecialistSpecialtyOptionModel.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList();
    }
    return const [];
  }

  Future<SpecialistSearchResponseModel> searchSpecialists(
    SpecialistSearchFilterParams filters,
  ) async {
    final queryParams = filters.toQueryParams();
    final queryString = Uri(queryParameters: queryParams).query;
    final url = '${ApiConfig.specialistsUrl}/buscar?$queryString';

    final response = await _apiClient.get(url);
    if (response is Map<String, dynamic>) {
      return SpecialistSearchResponseModel.fromJson(response);
    }
    return const SpecialistSearchResponseModel(
      total: 0,
      page: 1,
      perPage: 20,
      items: [],
    );
  }

  Future<SpecialistItemModel> getSpecialistAvailability(
    int idMedico,
    String fechaInicio,
    String fechaFin, {
    int? idServicio,
  }) async {
    final queryParams = <String, String>{
      'fecha_inicio': fechaInicio,
      'fecha_fin': fechaFin,
    };
    if (idServicio != null) {
      queryParams['id_servicio'] = idServicio.toString();
    }
    final queryString = Uri(queryParameters: queryParams).query;
    final url =
        '${ApiConfig.specialistsUrl}/$idMedico/disponibilidad?$queryString';

    final response = await _apiClient.get(url);
    return SpecialistItemModel.fromJson(response as Map<String, dynamic>);
  }
}
