import '../../../../../core/config/api_config.dart';
import '../../../../../core/network/api_client.dart';
import '../../domain/repositories/report_repository.dart';
import '../../domain/repositories/report_voice_recorder.dart';
import '../models/report_models.dart';

class ReportRepositoryImpl implements ReportRepository {
  final ApiClient _client;
  ReportRepositoryImpl({ApiClient? client}) : _client = client ?? ApiClient();

  @override
  Future<ReportCatalog> catalog() async => ReportCatalog(
    await _client.get(ApiConfig.reportCatalogUrl) as Map<String, dynamic>);

  @override
  Future<ReportOptions> options() async => ReportOptions(
    await _client.get(ApiConfig.reportOptionsUrl) as Map<String, dynamic>);

  @override
  Future<ReportResult> query(ReportQuery definition) async => ReportResult(
    await _client.post(ApiConfig.reportQueryUrl, body: definition.toJson())
      as Map<String, dynamic>);

  @override
  Future<ReportInterpretation> interpret(String texto, String fechaReferencia) async =>
      ReportInterpretation(await _client.post(ApiConfig.reportInterpretUrl,
        body: {'texto': texto, 'fecha_referencia': fechaReferencia})
          as Map<String, dynamic>);

  @override
  Future<String> transcribe(ReportAudio audio) async {
    final response = await _client.postAudio(ApiConfig.reportTranscribeUrl,
      audio.bytes, filename: audio.filename, mimeType: audio.mimeType)
        as Map<String, dynamic>;
    return response['texto'] as String;
  }
}
