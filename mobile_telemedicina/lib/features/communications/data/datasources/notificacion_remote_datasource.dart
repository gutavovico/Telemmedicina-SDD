import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../models/notificacion_model.dart';

class NotificacionRemoteDataSource {
  final ApiClient _apiClient;

  NotificacionRemoteDataSource({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Future<List<NotificacionModel>> obtenerBandeja({
    String? categoria,
    bool soloNoLeidas = false,
    int limite = 50,
  }) async {
    final query = <String, String>{'limite': '$limite'};
    if (categoria != null && categoria.isNotEmpty && categoria.toUpperCase() != 'TODAS') {
      query['categoria'] = categoria.toUpperCase();
    }
    if (soloNoLeidas) {
      query['solo_no_leidas'] = 'true';
    }

    final uri = Uri.parse(ApiConfig.notificacionesBandejaUrl).replace(queryParameters: query);
    final response = await _apiClient.get(uri.toString());
    if (response is List) {
      return response
          .whereType<Map<String, dynamic>>()
          .map(NotificacionModel.fromJson)
          .toList();
    }
    return const [];
  }

  Future<int> obtenerConteoNoLeidas() async {
    final response = await _apiClient.get(ApiConfig.notificacionesResumenUrl);
    if (response is Map<String, dynamic>) {
      return (response['no_leidas'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  Future<NotificacionModel?> marcarLeida(int idNotificacion) async {
    final response = await _apiClient.patch(
      ApiConfig.notificacionLeerUrl(idNotificacion),
      body: const {},
    );
    if (response is Map<String, dynamic>) {
      return NotificacionModel.fromJson(response);
    }
    return null;
  }

  Future<int> marcarTodasLeidas() async {
    final response = await _apiClient.post(
      ApiConfig.notificacionesMarcarTodasUrl,
      body: const {},
    );
    if (response is Map<String, dynamic>) {
      return (response['actualizadas'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  Future<void> registrarDispositivo({
    required String dispositivoId,
    required String pushToken,
  }) async {
    await _apiClient.post(
      ApiConfig.notificacionesDispositivosUrl,
      body: {
        'dispositivo_id': dispositivoId,
        'canal': 'FLUTTER',
        'push_token': pushToken,
      },
    );
  }

  Future<void> revocarDispositivo(String dispositivoId) async {
    try {
      await _apiClient.delete(ApiConfig.notificacionRevocarDispositivoUrl(dispositivoId));
    } catch (_) {
      // Silencioso en cierre de sesión para no bloquear logout
    }
  }
}
