import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../models/ficha_model.dart';

abstract class FichaRemoteDataSource {
  Future<List<FichaModel>> getFichas({int? idPaciente, String? fecha, String? estado});
  Future<FichaModel> getFichaById(String idFicha);
  Future<FichaModel> createFicha(Map<String, dynamic> data);
  Future<FichaModel> cancelFicha(String idFicha, String motivo);
}

class FichaRemoteDataSourceImpl implements FichaRemoteDataSource {
  final ApiClient _apiClient;

  FichaRemoteDataSourceImpl({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  @override
  Future<List<FichaModel>> getFichas({int? idPaciente, String? fecha, String? estado}) async {
    final queryParams = <String>[];
    if (idPaciente != null) queryParams.add('id_paciente=$idPaciente');
    if (fecha != null && fecha.isNotEmpty) queryParams.add('fecha=$fecha');
    if (estado != null && estado.isNotEmpty) queryParams.add('estado=$estado');

    final queryString = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
    final url = '${ApiConfig.fichasUrl}$queryString';

    final response = await _apiClient.get(url);
    if (response is Map<String, dynamic> && response.containsKey('items')) {
      final items = response['items'] as List<dynamic>;
      return items.map((e) => FichaModel.fromJson(e as Map<String, dynamic>)).toList();
    } else if (response is List<dynamic>) {
      return response.map((e) => FichaModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  @override
  Future<FichaModel> getFichaById(String idFicha) async {
    final response = await _apiClient.get('${ApiConfig.fichasUrl}/$idFicha');
    return FichaModel.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<FichaModel> createFicha(Map<String, dynamic> data) async {
    final response = await _apiClient.post(ApiConfig.fichasUrl, body: data);
    return FichaModel.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<FichaModel> cancelFicha(String idFicha, String motivo) async {
    final response = await _apiClient.post(
      '${ApiConfig.fichasUrl}/$idFicha/cancelar',
      body: {'motivo_cancelacion': motivo},
    );
    return FichaModel.fromJson(response as Map<String, dynamic>);
  }
}
