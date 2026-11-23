import '../../data/models/chat_message_model.dart';
import '../../data/models/teleconsulta_model.dart';

abstract class TeleconsultaRepository {
  Future<TeleconsultaViewModel> getTeleconsulta(int idCita);
  Future<TeleconsultaViewModel> getMiTeleconsultaActiva();
  Future<ChatMessageModel> enviarMensaje({
    required int idCita,
    required String contenido,
    String? adjuntoNombre,
    String? adjuntoTamano,
    String? adjuntoUrl,
  });
}
