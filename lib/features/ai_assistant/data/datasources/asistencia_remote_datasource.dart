import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_client_interface.dart';
import '../models/asistencia_tratamiento_model.dart';

/// Datasource remoto para el Asistente Inteligente de Tratamiento (CU18).
///
/// Solo lectura/evaluación con alcance de paciente autenticado.
/// Nunca envía `id_paciente`, `id_clinica` ni `tenant_id`: el backend resuelve
/// la identidad y el inquilino a partir del token JWT.
class AsistenciaRemoteDatasource {
  final ApiClientInterface _apiClient;

  AsistenciaRemoteDatasource({ApiClientInterface? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  /// Construye los query parameters canónicos para el historial.
  /// Expuesto como método estático para pruebas unitarias de construcción exacta.
  static Map<String, String> buildHistorialQueryParams({
    int page = 1,
    int limit = 10,
  }) {
    return {
      'page': '$page',
      'limit': '$limit',
    };
  }

  /// `POST /api/v1/asistencia-tratamiento/evaluar`
  /// Solicita la evaluación bajo demanda del tratamiento activo.
  Future<EvaluacionTratamientoModel> evaluarTratamiento({
    bool forzarRecalculo = false,
  }) async {
    final response = await _apiClient.post(
      ApiConfig.assistanceEvaluateUrl,
      body: {'forzar_recalculo': forzarRecalculo},
    );
    return EvaluacionTratamientoModel.fromJson(response as Map<String, dynamic>);
  }

  /// `GET /api/v1/asistencia-tratamiento/historial`
  /// Consulta el historial paginado de evaluaciones del paciente autenticado.
  Future<HistorialEvaluacionModel> getHistorial({
    int page = 1,
    int limit = 10,
  }) async {
    final query = buildHistorialQueryParams(page: page, limit: limit);
    final queryString = Uri(queryParameters: query).query;
    final response = await _apiClient.get(
      '${ApiConfig.assistanceHistoryUrl}?$queryString',
    );
    return HistorialEvaluacionModel.fromJson(response as Map<String, dynamic>);
  }

  /// `GET /api/v1/asistencia-tratamiento/evaluaciones/{id}`
  /// Consulta el detalle completo de una evaluación específica.
  Future<EvaluacionTratamientoModel> getEvaluacionById(int idEvaluacion) async {
    final response = await _apiClient.get(
      ApiConfig.assistanceDetailUrl(idEvaluacion),
    );
    return EvaluacionTratamientoModel.fromJson(response as Map<String, dynamic>);
  }
}

