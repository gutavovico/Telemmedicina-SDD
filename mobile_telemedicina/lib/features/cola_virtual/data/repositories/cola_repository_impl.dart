import '../../domain/repositories/cola_repository.dart';
import '../datasources/cola_remote_datasource.dart';
import '../models/cola_models.dart';

class ColaRepositoryImpl implements ColaRepository {
  final ColaRemoteDataSource _remoteDataSource;

  ColaRepositoryImpl({ColaRemoteDataSource? remoteDataSource})
      : _remoteDataSource = remoteDataSource ?? ColaRemoteDataSource();

  @override
  Future<MiTurnoModel> getMiTurno() => _remoteDataSource.getMiTurno();

  @override
  Future<ColaOperativaModel> getColaOperativa({int? idMedico, String? fecha}) =>
      _remoteDataSource.getColaOperativa(idMedico: idMedico, fecha: fecha);

  @override
  Future<ColaOperativaModel> avanzar(int idCita) => _remoteDataSource.avanzar(idCita);

  @override
  Future<ColaOperativaModel> marcarPerdida(int idCita) => _remoteDataSource.marcarPerdida(idCita);

  @override
  Future<void> registrarPausa({
    required int idMedico,
    required String fecha,
    required String horaInicio,
    required String horaFin,
    required String motivo,
  }) =>
      _remoteDataSource.registrarPausa(
        idMedico: idMedico,
        fecha: fecha,
        horaInicio: horaInicio,
        horaFin: horaFin,
        motivo: motivo,
      );
}
