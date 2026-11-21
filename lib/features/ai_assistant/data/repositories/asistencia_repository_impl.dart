import '../../domain/entities/asistencia_tratamiento.dart';
import '../../domain/repositories/asistencia_repository.dart';
import '../datasources/asistencia_remote_datasource.dart';

/// Implementación del repositorio de Asistencia Inteligente de Tratamiento (CU18).
class AsistenciaRepositoryImpl implements AsistenciaRepository {
  final AsistenciaRemoteDatasource _remoteDatasource;

  AsistenciaRepositoryImpl({AsistenciaRemoteDatasource? remoteDatasource})
      : _remoteDatasource = remoteDatasource ?? AsistenciaRemoteDatasource();

  @override
  Future<EvaluacionTratamiento> evaluarTratamiento({bool forzarRecalculo = false}) {
    return _remoteDatasource.evaluarTratamiento(forzarRecalculo: forzarRecalculo);
  }

  @override
  Future<HistorialEvaluacion> getHistorial({int page = 1, int limit = 10}) {
    return _remoteDatasource.getHistorial(page: page, limit: limit);
  }

  @override
  Future<EvaluacionTratamiento> getEvaluacionById(int idEvaluacion) {
    return _remoteDatasource.getEvaluacionById(idEvaluacion);
  }
}

