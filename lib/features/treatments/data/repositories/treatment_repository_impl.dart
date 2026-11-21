import '../../domain/entities/treatment_entities.dart';
import '../../domain/repositories/treatment_repository.dart';
import '../datasources/treatment_remote_datasource.dart';
import '../models/aviso_model.dart';
import '../models/treatment_plan_model.dart';

/// Implementación concreta del repositorio de tratamientos médicos (CU17).
class TreatmentRepositoryImpl implements TreatmentRepository {
  final TreatmentRemoteDatasource _datasource;

  TreatmentRepositoryImpl({TreatmentRemoteDatasource? datasource})
      : _datasource = datasource ?? TreatmentRemoteDatasource();

  @override
  Future<TreatmentPage> getTreatments({
    String? estado,
    int skip = 0,
    int limit = 20,
  }) async {
    final result = await _datasource.getTreatments(
      estado: estado,
      skip: skip,
      limit: limit,
    );
    final models = (result['items'] as List<dynamic>?)
            ?.whereType<TreatmentPlanModel>()
            .toList() ??
        <TreatmentPlanModel>[];
    final total = (result['total'] as int?) ?? models.length;

    return TreatmentPage(
      items: models.map((m) => m.toEntity()).toList(),
      total: total,
      skip: skip,
      limit: limit,
    );
  }

  @override
  Future<TreatmentPlan> getTreatmentDetail(int idTratamiento) async {
    final model = await _datasource.getTreatmentDetail(idTratamiento);
    return model.toEntity();
  }

  @override
  Future<CronogramaDia> getCronograma(int idTratamiento, String fecha) async {
    final model = await _datasource.getCronograma(idTratamiento, fecha);
    return model.toEntity();
  }

  @override
  Future<Adherencia> getAdherencia(int idTratamiento) async {
    final model = await _datasource.getAdherencia(idTratamiento);
    return model.toEntity();
  }

  @override
  Future<OperacionIdempotencia> iniciarIntentoDosis(
    int idDosis,
    String idempotencyKey,
    String requestHash,
  ) async {
    final model = await _datasource.iniciarIntentoDosis(
      idDosis,
      idempotencyKey,
      requestHash,
    );
    return model.toEntity();
  }

  @override
  Future<Dosis> registrarDosis(
    int idDosis,
    String idempotencyKey,
    Map<String, dynamic> body,
  ) async {
    final model = await _datasource.registrarDosis(
      idDosis,
      idempotencyKey,
      body,
    );
    return model.toEntity();
  }

  @override
  Future<OperacionIdempotencia> consultarIdempotencia(
    int idDosis,
    String idempotencyKey,
  ) async {
    final model = await _datasource.consultarIdempotencia(
      idDosis,
      idempotencyKey,
    );
    return model.toEntity();
  }

  @override
  Future<OperacionIdempotencia> resolverOperacionAbandonada(
    int idDosis,
    String idempotencyKey,
  ) async {
    final model = await _datasource.resolverOperacionAbandonada(
      idDosis,
      idempotencyKey,
    );
    return model.toEntity();
  }

  @override
  Future<AvisoPage> getAvisos({
    int skip = 0,
    int limit = 20,
    bool noLeidos = false,
  }) async {
    final result = await _datasource.getAvisos(
      skip: skip,
      limit: limit,
      noLeidos: noLeidos,
    );
    final models = (result['items'] as List<dynamic>?)
            ?.whereType<AvisoModel>()
            .toList() ??
        <AvisoModel>[];
    final total = (result['total'] as int?) ?? models.length;

    return AvisoPage(
      items: models.map((a) => a.toEntity()).toList(),
      total: total,
      skip: skip,
      limit: limit,
    );
  }

  @override
  Future<Aviso> leerAviso(int idAviso) async {
    final model = await _datasource.leerAviso(idAviso);
    return model.toEntity();
  }

  @override
  Future<Map<String, dynamic>> registrarDispositivo(
    String token,
    String plataforma,
  ) {
    return _datasource.registrarDispositivo(token, plataforma);
  }

  @override
  Future<void> eliminarDispositivo(int idDispositivo) {
    return _datasource.eliminarDispositivo(idDispositivo);
  }
}
