import '../entities/treatment_entities.dart';

/// Contrato del repositorio de tratamientos médicos (CU17).
abstract class TreatmentRepository {
  /// Lista los planes de tratamiento propios del usuario autenticado.
  Future<TreatmentPage> getTreatments({
    String? estado,
    int skip = 0,
    int limit = 20,
  });

  /// Obtiene el detalle estructurado de un plan de tratamiento.
  Future<TreatmentPlan> getTreatmentDetail(int idTratamiento);

  /// Obtiene el cronograma de tomas programadas para una fecha local específica.
  Future<CronogramaDia> getCronograma(int idTratamiento, String fecha);

  /// Obtiene las métricas de adherencia acumuladas del tratamiento.
  Future<Adherencia> getAdherencia(int idTratamiento);

  /// Inicia o valida un intento de registro de toma con clave de idempotencia y hash del cuerpo.
  Future<OperacionIdempotencia> iniciarIntentoDosis(
    int idDosis,
    String idempotencyKey,
    String requestHash,
  );

  /// Registra el consumo efectivo de una toma (INGERIDA, OMITIDA, POSPUESTA).
  Future<Dosis> registrarDosis(
    int idDosis,
    String idempotencyKey,
    Map<String, dynamic> body,
  );

  /// Consulta el estado de una clave de idempotencia sobre una toma.
  Future<OperacionIdempotencia> consultarIdempotencia(
    int idDosis,
    String idempotencyKey,
  );

  /// Resuelve de forma definitiva una operación abandonada tras fallo de red.
  Future<OperacionIdempotencia> resolverOperacionAbandonada(
    int idDosis,
    String idempotencyKey,
  );

  /// Lista los avisos y alertas preventivas de tratamientos.
  Future<AvisoPage> getAvisos({
    int skip = 0,
    int limit = 20,
    bool noLeidos = false,
  });

  /// Marca un aviso como leído.
  Future<Aviso> leerAviso(int idAviso);

  /// Registra el token del dispositivo para recordatorios push.
  Future<Map<String, dynamic>> registrarDispositivo(
    String token,
    String plataforma,
  );

  /// Elimina el registro del dispositivo para notificaciones push.
  Future<void> eliminarDispositivo(int idDispositivo);
}
