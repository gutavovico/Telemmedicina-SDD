import '../../data/repositories/treatment_repository_impl.dart';
import '../../data/services/dose_operation_recovery_service.dart';
import '../entities/treatment_entities.dart';
import '../repositories/treatment_repository.dart';

/// Caso de uso: Registrar consumo de dosis (INGERIDA, OMITIDA, POSPUESTA)
/// implementando garantías de idempotencia estricta, protocolo de dos fases
/// y trazabilidad clínica conforme a CU17.
class RecordDoseUseCase {
  final TreatmentRepository _repository;
  final DoseOperationRecoveryService? _recoveryService;

  RecordDoseUseCase({
    TreatmentRepository? repository,
    DoseOperationRecoveryService? recoveryService,
  })  : _repository = repository ?? TreatmentRepositoryImpl(),
        _recoveryService = recoveryService;

  DoseOperationRecoveryService get _service =>
      _recoveryService ?? DoseOperationRecoveryService();

  /// Registra directamente una dosis con su Idempotency-Key normalizando
  /// el payload canónico para garantizar consistencia con Pydantic v2.
  Future<Dosis> call({
    required int idDosis,
    required String idempotencyKey,
    required String estado,
    String? efectivaEn,
    DateTime? efectivaEnDateTime,
    String? nota,
  }) {
    final normalizedEfectivaEn = efectivaEnDateTime != null
        ? CanonicalJsonHasher.formatCanonicalDateTime(efectivaEnDateTime)
        : (efectivaEn != null
            ? CanonicalJsonHasher.normalizeIsoDateTime(efectivaEn)
            : null);

    final body = <String, dynamic>{
      'efectiva_en': normalizedEfectivaEn,
      'estado': estado,
      'nota': nota,
    };

    return _repository.registrarDosis(
      idDosis,
      idempotencyKey,
      body,
    );
  }

  /// Ejecuta el protocolo estricto en dos fases (Intento + Registro) delegando
  /// en [DoseOperationRecoveryService] con aislamiento y marcadores opacos.
  Future<DoseOperationResult> registrarEnDosFases({
    required int userId,
    required int clinicId,
    required int idDosis,
    required String estado,
    DateTime? efectivaEn,
    String? efectivaEnRaw,
    String? nota,
    String? customIdempotencyKey,
  }) {
    return _service.registrarDosisEnDosFases(
      userId: userId,
      clinicId: clinicId,
      idDosis: idDosis,
      estado: estado,
      efectivaEn: efectivaEn,
      efectivaEnRaw: efectivaEnRaw,
      nota: nota,
      customIdempotencyKey: customIdempotencyKey,
    );
  }

  /// Inicia un intento de registro asegurando exclusión concurrente en backend (Fase 1).
  Future<OperacionIdempotencia> startAttempt({
    required int idDosis,
    required String idempotencyKey,
    required String estado,
    String? efectivaEn,
    DateTime? efectivaEnDateTime,
    String? nota,
  }) {
    final requestHash = CanonicalJsonHasher.hashDoseRegistration(
      estado: estado,
      efectivaEn: efectivaEn,
      efectivaEnDateTime: efectivaEnDateTime,
      nota: nota,
    );

    return _repository.iniciarIntentoDosis(
      idDosis,
      idempotencyKey,
      requestHash,
    );
  }

  /// Consulta el estado de una clave de idempotencia sobre una toma.
  Future<OperacionIdempotencia> checkIdempotency({
    required int idDosis,
    required String idempotencyKey,
  }) {
    return _repository.consultarIdempotencia(idDosis, idempotencyKey);
  }

  /// Resuelve de forma definitiva una operación abandonada vía repositorio.
  Future<OperacionIdempotencia> resolveAbandoned({
    required int idDosis,
    required String idempotencyKey,
  }) {
    return _repository.resolverOperacionAbandonada(idDosis, idempotencyKey);
  }

  /// Reconcilia operaciones pendientes de un usuario y clínica vía el servicio de recuperación.
  Future<List<DoseOperationResult>> reconciliarPendientes({
    required int userId,
    required int clinicId,
  }) {
    return _service.reconciliarMarcadoresPendientes(
      userId: userId,
      clinicId: clinicId,
    );
  }
}
