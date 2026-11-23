import '../../domain/repositories/waitlist_repository.dart';
import '../datasources/waitlist_remote_datasource.dart';
import '../models/waitlist_models.dart';

class WaitlistRepositoryImpl implements WaitlistRepository {
  final WaitlistRemoteDataSource _remoteDataSource;

  WaitlistRepositoryImpl({WaitlistRemoteDataSource? remoteDataSource})
      : _remoteDataSource = remoteDataSource ?? WaitlistRemoteDataSource();

  @override
  Future<List<InscripcionEsperaModel>> getMisInscripciones() =>
      _remoteDataSource.getMisInscripciones();

  @override
  Future<InscripcionEsperaModel> inscribirse({
    int? idMedico,
    int? idEspecialidad,
    String? fechaDeseada,
    String? motivo,
  }) =>
      _remoteDataSource.inscribirse(
        idMedico: idMedico,
        idEspecialidad: idEspecialidad,
        fechaDeseada: fechaDeseada,
        motivo: motivo,
      );

  @override
  Future<InscripcionEsperaModel> salir(int id) => _remoteDataSource.salir(id);

  @override
  Future<InscripcionEsperaModel> confirmar(int id) => _remoteDataSource.confirmar(id);

  @override
  Future<InscripcionEsperaModel> rechazar(int id) => _remoteDataSource.rechazar(id);
}
