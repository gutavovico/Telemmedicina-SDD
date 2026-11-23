import '../../domain/repositories/teleconsulta_repository.dart';
import '../datasources/teleconsulta_remote_datasource.dart';
import '../models/chat_message_model.dart';
import '../models/teleconsulta_model.dart';

class TeleconsultaRepositoryImpl implements TeleconsultaRepository {
  final TeleconsultaRemoteDataSource _remoteDataSource;

  TeleconsultaRepositoryImpl({TeleconsultaRemoteDataSource? remoteDataSource})
      : _remoteDataSource = remoteDataSource ?? TeleconsultaRemoteDataSource();

  @override
  Future<TeleconsultaViewModel> getTeleconsulta(int idCita) {
    return _remoteDataSource.getTeleconsulta(idCita);
  }

  @override
  Future<TeleconsultaViewModel> getMiTeleconsultaActiva() {
    return _remoteDataSource.getMiTeleconsultaActiva();
  }

  @override
  Future<ChatMessageModel> enviarMensaje({
    required int idCita,
    required String contenido,
    String? adjuntoNombre,
    String? adjuntoTamano,
    String? adjuntoUrl,
  }) {
    return _remoteDataSource.enviarMensaje(
      idCita: idCita,
      contenido: contenido,
      adjuntoNombre: adjuntoNombre,
      adjuntoTamano: adjuntoTamano,
      adjuntoUrl: adjuntoUrl,
    );
  }
}
