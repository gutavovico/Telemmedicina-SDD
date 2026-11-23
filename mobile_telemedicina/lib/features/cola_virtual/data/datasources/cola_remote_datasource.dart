import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../models/cola_models.dart';

class ColaRemoteDataSource {
  final ApiClient _apiClient = ApiClient();

  Future<MiTurnoModel> getMiTurno() async {
    final response = await _apiClient.get(ApiConfig.miTurnoUrl);
    if (response is Map<String, dynamic>) {
      return MiTurnoModel.fromJson(response);
    }
    throw Exception('Formato de respuesta inválido al consultar el turno');
  }

  Future<ColaOperativaModel> getColaOperativa({int? idMedico, String? fecha}) async {
    final params = <String>[];
    if (idMedico != null) params.add('id_medico=$idMedico');
    if (fecha != null && fecha.isNotEmpty) params.add('fecha=$fecha');
    final url = params.isEmpty ? ApiConfig.liveQueueUrl : '${ApiConfig.liveQueueUrl}?${params.join('&')}';
    final response = await _apiClient.get(url);
    if (response is Map<String, dynamic>) {
      return ColaOperativaModel.fromJson(response);
    }
    throw Exception('Formato de respuesta inválido al cargar la fila virtual');
  }

  Future<ColaOperativaModel> avanzar(int idCita) async {
    final response = await _apiClient.post(ApiConfig.avanzarColaUrl(idCita), body: {});
    if (response is Map<String, dynamic>) {
      return ColaOperativaModel.fromJson(response);
    }
    throw Exception('Respuesta inesperada al avanzar la fila');
  }

  Future<ColaOperativaModel> marcarPerdida(int idCita) async {
    final response = await _apiClient.post(ApiConfig.perdidaColaUrl(idCita), body: {});
    if (response is Map<String, dynamic>) {
      return ColaOperativaModel.fromJson(response);
    }
    throw Exception('Respuesta inesperada al marcar el turno');
  }

  Future<void> registrarPausa({
    required int idMedico,
    required String fecha,
    required String horaInicio,
    required String horaFin,
    required String motivo,
  }) async {
    await _apiClient.post(ApiConfig.pausasColaUrl, body: {
      'id_medico': idMedico,
      'fecha': fecha,
      'hora_inicio': horaInicio,
      'hora_fin': horaFin,
      'motivo': motivo,
    });
  }
}
