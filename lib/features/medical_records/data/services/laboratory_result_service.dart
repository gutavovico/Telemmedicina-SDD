import 'dart:typed_data';

import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_client_interface.dart';
import '../models/laboratory_result_model.dart';

/// Cliente de datos de resultados de laboratorio (CU11, solo lectura).
///
/// Reutiliza el cliente HTTP existente: el Bearer y el `X-Tenant-ID` (guardados en
/// `FlutterSecureStorage`) los agrega `ApiClient`. Nunca se envía `id_clinica` ni `tenant_id`.
class LaboratoryResultService {
  final ApiClientInterface _apiClient;

  LaboratoryResultService({ApiClientInterface? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  /// `GET /api/v1/resultados-laboratorio/me`: resultados INCORPORADO del paciente autenticado.
  Future<LaboratoryResultPageModel> getMine({
    int page = 1,
    int pageSize = 10,
    String? codigoExamen,
    String? fechaDesde,
    String? fechaHasta,
  }) async {
    final query = <String, String>{'page': '$page', 'page_size': '$pageSize'};
    if (codigoExamen != null && codigoExamen.trim().isNotEmpty) {
      query['codigo_examen'] = codigoExamen.trim();
    }
    if (fechaDesde != null && fechaDesde.isNotEmpty) query['fecha_desde'] = fechaDesde;
    if (fechaHasta != null && fechaHasta.isNotEmpty) query['fecha_hasta'] = fechaHasta;
    final queryString = Uri(queryParameters: query).query;

    final response = await _apiClient.get('${ApiConfig.myLabResultsUrl}?$queryString');
    if (response is! Map<String, dynamic>) {
      return const LaboratoryResultPageModel(
        items: [],
        total: 0,
        page: 1,
        pageSize: 10,
        totalPages: 0,
      );
    }
    return LaboratoryResultPageModel.fromJson(response);
  }

  /// `GET /api/v1/resultados-laboratorio/{id}/archivo`: bytes del archivo (PDF, JPG o PNG).
  Future<Uint8List> downloadFile(int idResultado) {
    return _apiClient.downloadBytes(ApiConfig.labResultFileUrl(idResultado));
  }
}
