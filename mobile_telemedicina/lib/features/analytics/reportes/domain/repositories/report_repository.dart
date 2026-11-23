import '../../data/models/report_models.dart';
import 'report_voice_recorder.dart';

abstract class ReportRepository {
  Future<ReportCatalog> catalog();
  Future<ReportOptions> options();
  Future<ReportResult> query(ReportQuery definition);
  Future<ReportInterpretation> interpret(String texto, String fechaReferencia);
  Future<String> transcribe(ReportAudio audio);
}
