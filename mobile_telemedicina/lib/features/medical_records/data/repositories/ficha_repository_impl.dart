import '../../domain/entities/ficha_entity.dart';
import '../../domain/repositories/ficha_repository.dart';
import '../datasources/ficha_remote_datasource.dart';

class FichaRepositoryImpl implements FichaRepository {
  final FichaRemoteDataSource _remoteDataSource;

  FichaRepositoryImpl({FichaRemoteDataSource? remoteDataSource})
      : _remoteDataSource = remoteDataSource ?? FichaRemoteDataSourceImpl();

  @override
  Future<List<FichaEntity>> getFichas({int? idPaciente, String? fecha, String? estado}) {
    return _remoteDataSource.getFichas(idPaciente: idPaciente, fecha: fecha, estado: estado);
  }

  @override
  Future<FichaEntity> getFichaById(String idFicha) {
    return _remoteDataSource.getFichaById(idFicha);
  }

  @override
  Future<FichaEntity> createFicha(Map<String, dynamic> data) {
    return _remoteDataSource.createFicha(data);
  }

  @override
  Future<FichaEntity> cancelFicha(String idFicha, String motivo) {
    return _remoteDataSource.cancelFicha(idFicha, motivo);
  }
}
