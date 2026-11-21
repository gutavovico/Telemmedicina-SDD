import '../entities/asistencia_tratamiento.dart';

/// Interfaz abstracta del repositorio de Asistencia Inteligente de Tratamiento (CU18).
///
/// La capa de dominio define esta interfaz y la capa de datos la implementa.
abstract class AsistenciaRepository {
  /// Solicita una evaluación bajo demanda del tratamiento vigente del paciente.
  /// Si [forzarRecalculo] es true, ignora la caché de 10 minutos.
  Future<EvaluacionTratamiento> evaluarTratamiento({bool forzarRecalculo = false});

  /// Obtiene el historial paginado de evaluaciones del paciente autenticado.
  Future<HistorialEvaluacion> getHistorial({int page = 1, int limit = 10});

  /// Obtiene el detalle completo de una evaluación histórica por su identificador.
  Future<EvaluacionTratamiento> getEvaluacionById(int idEvaluacion);
}

