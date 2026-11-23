import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../models/waitlist_models.dart';

class WaitlistRemoteDataSource {
  final ApiClient _apiClient = ApiClient();

  Future<List<InscripcionEsperaModel>> getMisInscripciones() async {
    final response = await _apiClient.get(ApiConfig.myWaitlistUrl);
    if (response is List) {
      return response
          .whereType<Map<String, dynamic>>()
          .map(InscripcionEsperaModel.fromJson)
          .toList();
    }
    throw Exception('Formato de respuesta inválido al consultar la lista de espera');
  }

  Future<InscripcionEsperaModel> inscribirse({
    int? idMedico,
    int? idEspecialidad,
    String? fechaDeseada,
    String? motivo,
  }) async {
    final response = await _apiClient.post(ApiConfig.waitlistUrl, body: {
      'id_medico': idMedico,
      'id_especialidad': idEspecialidad,
      'fecha_deseada': fechaDeseada,
      'motivo': motivo,
    });
    if (response is Map<String, dynamic>) {
      return InscripcionEsperaModel.fromJson(response);
    }
    throw Exception('Respuesta inesperada al inscribirse en la lista de espera');
  }

  Future<InscripcionEsperaModel> salir(int id) async {
    final response = await _apiClient.delete(ApiConfig.waitlistItemUrl(id));
    if (response is Map<String, dynamic>) {
      return InscripcionEsperaModel.fromJson(response);
    }
    return InscripcionEsperaModel(
      idListaEspera: id,
      idPaciente: 0,
      pacienteNombre: '',
      estado: 'CANCELADO',
      prioridad: 0,
      posicion: 0,
    );
  }

  Future<InscripcionEsperaModel> confirmar(int id) async {
    final response = await _apiClient.post(ApiConfig.waitlistConfirmUrl(id), body: {});
    if (response is Map<String, dynamic>) {
      return InscripcionEsperaModel.fromJson(response);
    }
    throw Exception('Respuesta inesperada al confirmar el turno');
  }

  Future<InscripcionEsperaModel> rechazar(int id) async {
    final response = await _apiClient.post(ApiConfig.waitlistRejectUrl(id), body: {});
    if (response is Map<String, dynamic>) {
      return InscripcionEsperaModel.fromJson(response);
    }
    throw Exception('Respuesta inesperada al rechazar el turno');
  }
}
