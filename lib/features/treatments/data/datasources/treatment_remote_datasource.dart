import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_client_interface.dart';
import '../models/adherencia_model.dart';
import '../models/aviso_model.dart';
import '../models/cronograma_dia_model.dart';
import '../models/dosis_model.dart';
import '../models/operacion_idempotencia_model.dart';
import '../models/treatment_plan_model.dart';

/// Datasource remoto para CU17 «Gestionar y Monitorear Tratamiento Médico».
class TreatmentRemoteDatasource {
  final ApiClientInterface _apiClient;

  TreatmentRemoteDatasource({ApiClientInterface? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  /// Consulta planes terapéuticos propios con filtro opcional de estado y paginación.
  Future<Map<String, dynamic>> getTreatments({
    String? estado,
    int skip = 0,
    int limit = 20,
  }) async {
    final params = <String>[
      'skip=$skip',
      'limit=$limit',
      if (estado != null && estado.trim().isNotEmpty)
        'estado=${Uri.encodeQueryComponent(estado.trim())}',
    ];
    final url = '${ApiConfig.treatmentsUrl}?${params.join('&')}';
    final response = await _apiClient.get(url);
    final map = Map<String, dynamic>.from(response as Map);
    final rawItems = (map['items'] as List<dynamic>?) ?? [];
    final items = rawItems
        .whereType<Map>()
        .map((e) => TreatmentPlanModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final total = (map['total'] as num?)?.toInt() ?? items.length;
    return {
      'items': items,
      'total': total,
    };
  }

  /// Consulta el detalle completo de un plan de tratamiento.
  Future<TreatmentPlanModel> getTreatmentDetail(int idTratamiento) async {
    final url = ApiConfig.treatmentDetailUrl(idTratamiento);
    final response = await _apiClient.get(url);
    return TreatmentPlanModel.fromJson(Map<String, dynamic>.from(response as Map));
  }

  /// Consulta el cronograma diario de tomas para una fecha específica (YYYY-MM-DD).
  Future<CronogramaDiaModel> getCronograma(
    int idTratamiento,
    String fecha,
  ) async {
    final url = ApiConfig.cronogramaUrl(idTratamiento, fecha);
    final response = await _apiClient.get(url);
    return CronogramaDiaModel.fromJson(Map<String, dynamic>.from(response as Map));
  }

  /// Consulta las métricas de adherencia acumuladas del plan terapéutico.
  Future<AdherenciaModel> getAdherencia(int idTratamiento) async {
    final url = ApiConfig.adherenciaUrl(idTratamiento);
    final response = await _apiClient.get(url);
    return AdherenciaModel.fromJson(Map<String, dynamic>.from(response as Map));
  }

  /// Inicia o verifica un intento de registro de dosis mediante protocolo transaccional.
  Future<OperacionIdempotenciaModel> iniciarIntentoDosis(
    int idDosis,
    String idempotencyKey,
    String requestHash,
  ) async {
    final url = ApiConfig.dosisIntentosUrl(idDosis);
    final response = await _apiClient.post(
      url,
      body: {'request_hash': requestHash},
      headers: {'Idempotency-Key': idempotencyKey},
    );
    return OperacionIdempotenciaModel.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  /// Registra una dosis (INGERIDA, OMITIDA, POSPUESTA) con clave de idempotencia.
  Future<DosisModel> registrarDosis(
    int idDosis,
    String idempotencyKey,
    Map<String, dynamic> body,
  ) async {
    final url = ApiConfig.dosisRegistrosUrl(idDosis);
    final response = await _apiClient.post(
      url,
      body: body,
      headers: {'Idempotency-Key': idempotencyKey},
    );
    final map = Map<String, dynamic>.from(response as Map);
    final doseMap = map['dosis'] is Map
        ? Map<String, dynamic>.from(map['dosis'] as Map)
        : map;
    return DosisModel.fromJson(doseMap);
  }

  /// Consulta el estado de una operación de idempotencia sobre una toma.
  Future<OperacionIdempotenciaModel> consultarIdempotencia(
    int idDosis,
    String idempotencyKey,
  ) async {
    final url = ApiConfig.dosisIdempotenciaUrl(idDosis, idempotencyKey);
    final response = await _apiClient.get(url);
    return OperacionIdempotenciaModel.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  /// Resuelve de forma concluyente una operación abandonada tras caída o cierre.
  Future<OperacionIdempotenciaModel> resolverOperacionAbandonada(
    int idDosis,
    String idempotencyKey,
  ) async {
    final url = ApiConfig.dosisResolverUrl(idDosis, idempotencyKey);
    final response = await _apiClient.post(url);
    return OperacionIdempotenciaModel.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  /// Lista los avisos/recordatorios de la bandeja web y móvil del paciente.
  Future<Map<String, dynamic>> getAvisos({
    int skip = 0,
    int limit = 20,
    bool noLeidos = false,
  }) async {
    final url = ApiConfig.avisosUrl(
      skip: skip,
      limit: limit,
      noLeidos: noLeidos,
    );
    final response = await _apiClient.get(url);
    final map = Map<String, dynamic>.from(response as Map);
    final rawItems = (map['items'] as List<dynamic>?) ?? [];
    final items = rawItems
        .whereType<Map>()
        .map((e) => AvisoModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final total = (map['total'] as num?)?.toInt() ?? items.length;
    return {
      'items': items,
      'total': total,
    };
  }

  /// Marca un aviso como leído en el servidor.
  Future<AvisoModel> leerAviso(int idAviso) async {
    final url = ApiConfig.leerAvisoUrl(idAviso);
    final response = await _apiClient.patch(url);
    return AvisoModel.fromJson(Map<String, dynamic>.from(response as Map));
  }

  /// Registra el token push FCM del dispositivo en el backend.
  Future<Map<String, dynamic>> registrarDispositivo(
    String token,
    String plataforma,
  ) async {
    final url = ApiConfig.dispositivosUrl;
    final response = await _apiClient.post(
      url,
      body: {
        'token': token,
        'plataforma': plataforma,
      },
    );
    return Map<String, dynamic>.from(response as Map);
  }

  /// Revoca el dispositivo registrado en el backend.
  Future<void> eliminarDispositivo(int idDispositivo) async {
    final url = ApiConfig.dispositivoDetailUrl(idDispositivo);
    await _apiClient.delete(url);
  }
}
