import 'dart:typed_data';

import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_client_interface.dart';
import '../models/prescription_model.dart';

/// Datasource remoto CU16 (solo lectura, alcance de paciente).
///
/// Únicos query parameters permitidos: `estado`, `desde`, `hasta`,
/// `skip` y `limit`. Nunca envía `id_paciente`, `id_medico`,
/// `id_clinica` ni `tenant_id`: la autenticación y el tenant viajan
/// en headers mediante el `ApiClient` central.
class PrescriptionRemoteDatasource {
  final ApiClientInterface _apiClient;

  PrescriptionRemoteDatasource({ApiClientInterface? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// Construye los query parameters exactos del contrato §5.1.
  /// Expuesto como estático para pruebas de construcción exacta.
  static Map<String, String> buildListQueryParams({
    String? estado,
    String? desde,
    String? hasta,
    int skip = 0,
    int limit = 20,
  }) {
    final query = <String, String>{'skip': '$skip', 'limit': '$limit'};
    if (estado != null && estado.trim().isNotEmpty) {
      query['estado'] = estado.trim();
    }
    if (desde != null && desde.trim().isNotEmpty) {
      query['desde'] = desde.trim();
    }
    if (hasta != null && hasta.trim().isNotEmpty) {
      query['hasta'] = hasta.trim();
    }
    return query;
  }

  /// `GET /api/v1/recetas` — solo recetas del paciente autenticado.
  Future<PrescriptionListModel> getMyPrescriptions({
    String? estado,
    String? desde,
    String? hasta,
    int skip = 0,
    int limit = 20,
  }) async {
    final query = buildListQueryParams(
      estado: estado,
      desde: desde,
      hasta: hasta,
      skip: skip,
      limit: limit,
    );
    final queryString = Uri(queryParameters: query).query;
    final response = await _apiClient.get(
      '${ApiConfig.prescriptionsUrl}?$queryString',
    );
    return PrescriptionListModel.fromJson(response as Map<String, dynamic>);
  }

  /// `GET /api/v1/recetas/{id_receta}`.
  Future<PrescriptionModel> getPrescriptionById(int idReceta) async {
    final response = await _apiClient.get(
      ApiConfig.prescriptionDetailUrl(idReceta),
    );
    return PrescriptionModel.fromJson(response as Map<String, dynamic>);
  }

  /// `GET /api/v1/recetas/{id_receta}/pdf` — bytes crudos autenticados.
  /// No usa URL pública: la autenticación viaja en headers del cliente central.
  Future<Uint8List> downloadPrescriptionPdf(int idReceta) {
    return _apiClient.downloadBytes(ApiConfig.prescriptionPdfUrl(idReceta));
  }
}
