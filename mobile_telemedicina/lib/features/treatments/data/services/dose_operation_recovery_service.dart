import 'dart:async' as dart_async;
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_client_interface.dart';
import '../../../../core/network/api_exceptions.dart';
import '../models/dosis_model.dart';
import '../utils/canonical_json_hasher.dart';

export '../utils/canonical_json_hasher.dart';

/// Función auxiliar para calcular el SHA-256 del registro de dosis canónico compatible con Pydantic v2.
String hashCanonicalRegistroDosis({
  required String estado,
  DateTime? efectivaEn,
  String? efectivaEnRaw,
  String? nota,
}) {
  return CanonicalJsonHasher.hashDoseRegistration(
    estado: estado,
    efectivaEn: efectivaEnRaw,
    efectivaEnDateTime: efectivaEn,
    nota: nota,
  );
}

/// Marcador mínimo y opaco de recuperación.
///
/// REGLA ESTRICTA DE PRIVACIDAD CU17:
/// PROHIBIDO almacenar datos clínicos (diagnóstico, medicamento, notas clínicas,
/// estado clínico de ingesta, indicaciones) en el marcador persistente.
class DoseRecoveryMarker {
  final int userId;
  final int clinicId;
  final int idDosis;
  final String idempotencyKey;
  final String timestamp;

  const DoseRecoveryMarker({
    required this.userId,
    required this.clinicId,
    required this.idDosis,
    required this.idempotencyKey,
    required this.timestamp,
  });

  factory DoseRecoveryMarker.fromJson(Map<String, dynamic> json) {
    validateNoClinicalData(json);
    return DoseRecoveryMarker(
      userId: (json['userId'] as num).toInt(),
      clinicId: (json['clinicId'] as num).toInt(),
      idDosis: (json['idDosis'] as num).toInt(),
      idempotencyKey: json['idempotencyKey'] as String,
      timestamp: json['timestamp'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    final map = {
      'userId': userId,
      'clinicId': clinicId,
      'idDosis': idDosis,
      'idempotencyKey': idempotencyKey,
      'timestamp': timestamp,
    };
    validateNoClinicalData(map);
    return map;
  }

  /// Valida que ningún campo clínico esté presente en el mapa.
  static void validateNoClinicalData(Map<String, dynamic> map) {
    const forbidden = {
      'diagnostico',
      'medicamento',
      'nota',
      'notas',
      'farmaco',
      'receta',
      'efectiva_en',
      'estado',
      'sintomas',
      'indicaciones',
    };
    for (final key in map.keys) {
      if (forbidden.contains(key.toLowerCase())) {
        throw ArgumentError(
          'PROHIBIDO almacenar datos clínicos en el marcador persistente: $key',
        );
      }
    }
  }
}

/// Resultado de una operación de registro o consulta de idempotencia de dosis.
class DoseOperationResult {
  final String estado; // CONFIRMADA, EN_CURSO, RECHAZADA, NO_INICIADA
  final bool confirmado;
  final bool enCurso;
  final bool rechazado;
  final bool noIniciada;
  final int idDosis;
  final String idempotencyKey;
  final int? generacion;
  final Map<String, dynamic>? dosis;
  final String? mensaje;

  const DoseOperationResult({
    required this.estado,
    required this.confirmado,
    required this.enCurso,
    required this.rechazado,
    this.noIniciada = false,
    required this.idDosis,
    required this.idempotencyKey,
    this.generacion,
    this.dosis,
    this.mensaje,
  });

  factory DoseOperationResult.fromJson(Map<String, dynamic> json) {
    final estado = (json['estado'] as String?)?.toUpperCase() ?? 'DESCONOCIDO';
    return DoseOperationResult(
      estado: estado,
      confirmado: json['confirmado'] as bool? ?? (estado == 'CONFIRMADA'),
      enCurso: json['en_curso'] as bool? ?? (estado == 'EN_CURSO'),
      rechazado: json['rechazado'] as bool? ?? (estado == 'RECHAZADA'),
      noIniciada: json['no_iniciada'] as bool? ?? (estado == 'NO_INICIADA'),
      idDosis: (json['id_dosis'] as num?)?.toInt() ?? 0,
      idempotencyKey: json['idempotency_key'] as String? ?? '',
      generacion: (json['generacion'] as num?)?.toInt(),
      dosis: json['dosis'] as Map<String, dynamic>?,
      mensaje: json['mensaje'] as String? ?? json['detail'] as String?,
    );
  }

  /// Construye un [DoseOperationResult] a partir de la respuesta directa del endpoint
  /// `POST /api/v1/tratamientos/dosis/{id_dosis}/registros`, el cual devuelve directamente
  /// el objeto Dosis serializado (HTTP 200) y no el sobre de idempotencia.
  factory DoseOperationResult.fromRegistroDosisResponse(
    Map<String, dynamic> json, {
    required String idempotencyKey,
    int? generacion,
  }) {
    final Map<String, dynamic> doseMap = json['dosis'] is Map
        ? Map<String, dynamic>.from(json['dosis'] as Map)
        : json;
    final dosisModel = DosisModel.fromJson(doseMap);
    if (dosisModel.idDosis <= 0) {
      throw const FormatException(
        'Respuesta de registro de dosis inválida: id_dosis es requerido y debe ser positivo.',
      );
    }
    return DoseOperationResult(
      estado: 'CONFIRMADA',
      confirmado: true,
      enCurso: false,
      rechazado: false,
      noIniciada: false,
      idDosis: dosisModel.idDosis,
      idempotencyKey: idempotencyKey,
      generacion: generacion,
      dosis: doseMap,
    );
  }

  Map<String, dynamic> toJson() => {
    'estado': estado,
    'confirmado': confirmado,
    'en_curso': enCurso,
    'rechazado': rechazado,
    'no_iniciada': noIniciada,
    'id_dosis': idDosis,
    'idempotency_key': idempotencyKey,
    if (generacion != null) 'generacion': generacion,
    if (dosis != null) 'dosis': dosis,
    if (mensaje != null) 'mensaje': mensaje,
  };

  bool get isConfirmed => confirmado || estado == 'CONFIRMADA';
  bool get isInProgress => enCurso || estado == 'EN_CURSO';
  bool get isRejected => rechazado || estado == 'RECHAZADA';
  bool get isNotStarted => noIniciada || estado == 'NO_INICIADA';

  /// Modelo de dosis fuertemente tipado si la respuesta contiene los datos de la dosis.
  DosisModel? get dosisModel =>
      dosis != null ? DosisModel.fromJson(dosis!) : null;
}

/// Servicio encargado del protocolo en dos fases y recuperación de tomas (CU17).
class DoseOperationRecoveryService {
  static const String storageKeyMarkers = 'cu17_dose_recovery_markers';

  final ApiClientInterface _apiClient;
  SharedPreferences? _prefs;

  /// Almacenamiento ÚNICAMENTE en memoria de sesión para el cuerpo clínico pendiente.
  /// Se descarta inmediatamente ante logout o cierre de la app.
  final Map<String, Map<String, dynamic>> _pendingBodies = {};

  /// Conjunto de dosis bloqueadas localmente mientras una operación sea incierta o en curso.
  final Set<int> _lockedDoses = {};
  final Set<int> _uncertainDoses = {};
  final Set<int> _executingDoses = {};

  DoseOperationRecoveryService({
    ApiClientInterface? apiClient,
    SharedPreferences? prefs,
  }) : _apiClient = apiClient ?? ApiClient(),
       _prefs = prefs;

  Future<SharedPreferences?> _getPrefs() async {
    if (_prefs != null) return _prefs;
    try {
      return _prefs = await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  /// Genera un UUIDv4 criptográficamente seguro para `Idempotency-Key`.
  static String generateIdempotencyKey() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    // RFC 4122 v4
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  // --- Gestión de bloqueos locales de dosis ---

  /// Indica si una dosis está bloqueada por una operación en curso o resultado incierto.
  bool isDoseLocked(int idDosis) =>
      _lockedDoses.contains(idDosis) ||
      _uncertainDoses.contains(idDosis) ||
      _executingDoses.contains(idDosis);

  /// Bloquea temporalmente nuevos envíos sobre la dosis.
  void lockDose(int idDosis) => _lockedDoses.add(idDosis);

  /// Marca la dosis como bloqueada debido a resultado incierto (timeout, error de red o 5xx).
  void _markDoseUncertain(int idDosis) {
    _lockedDoses.add(idDosis);
    _uncertainDoses.add(idDosis);
  }

  /// Desbloquea la dosis tras confirmación o resolución definitiva.
  void unlockDose(int idDosis) {
    _lockedDoses.remove(idDosis);
    _uncertainDoses.remove(idDosis);
    _executingDoses.remove(idDosis);
  }

  // --- Gestión de cuerpos clínicos en memoria (Sesión) ---

  /// Indica si el cuerpo clínico se conserva en la memoria de la sesión actual.
  bool hasPendingBody(String idempotencyKey) =>
      _pendingBodies.containsKey(idempotencyKey);

  /// Obtiene el cuerpo clínico pendiente en memoria si existe.
  Map<String, dynamic>? getPendingBody(String idempotencyKey) =>
      _pendingBodies[idempotencyKey];

  /// Permite establecer un cuerpo clínico en memoria para pruebas.
  void setPendingBodyForTesting(
    String idempotencyKey,
    Map<String, dynamic> body,
  ) {
    _pendingBodies[idempotencyKey] = Map.unmodifiable(body);
  }

  /// Elimina de inmediato todos los cuerpos clínicos en memoria (al hacer logout o cambio de usuario).
  void clearPendingClinicalData() {
    _pendingBodies.clear();
  }

  /// Notificación de cierre de sesión: borra memoria clínica y limpia bloqueos.
  void onSessionLogout() {
    clearPendingClinicalData();
    _lockedDoses.clear();
    _uncertainDoses.clear();
    _executingDoses.clear();
  }

  // --- Gestión de marcadores opacos persistentes ---

  /// Obtiene todos los marcadores guardados en almacenamiento persistente.
  Future<List<DoseRecoveryMarker>> getAllMarkers() async {
    final prefs = await _getPrefs();
    if (prefs == null) return [];
    final raw = prefs.getString(storageKeyMarkers);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map(
            (item) => DoseRecoveryMarker.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Filtra marcadores aislando estrictamente por [userId] y [clinicId].
  /// Jamás devuelve ni procesa operaciones de otras cuentas o centros.
  Future<List<DoseRecoveryMarker>> getPendingMarkers({
    required int userId,
    required int clinicId,
  }) async {
    if (userId <= 0 || clinicId <= 0) return [];
    final all = await getAllMarkers();
    return all
        .where((m) => m.userId == userId && m.clinicId == clinicId)
        .toList();
  }

  /// Guarda de forma duradera el marcador mínimo de recuperación.
  Future<void> saveMarker(DoseRecoveryMarker marker) async {
    final prefs = await _getPrefs();
    if (prefs == null) {
      throw StateError(
        'No se pudo guardar el marcador de recuperación de la dosis.',
      );
    }
    final previousValue = prefs.getString(storageKeyMarkers);
    final all = await getAllMarkers();
    all.removeWhere((m) => m.idempotencyKey == marker.idempotencyKey);
    all.add(marker);
    final jsonList = all.map((m) => m.toJson()).toList();
    try {
      if (await prefs.setString(storageKeyMarkers, jsonEncode(jsonList))) {
        return;
      }
    } catch (_) {
      // SharedPreferences actualiza su caché antes de confirmar la escritura.
    }
    try {
      if (previousValue == null) {
        await prefs.remove(storageKeyMarkers);
      } else {
        await prefs.setString(storageKeyMarkers, previousValue);
      }
    } catch (_) {
      // La operación clínica no se enviará si no se confirmó el marcador.
    }
    throw StateError(
      'No se pudo guardar el marcador de recuperación de la dosis.',
    );
  }

  /// Elimina un marcador duradero cuando la operación concluye o se resuelve.
  Future<void> removeMarker(String idempotencyKey) async {
    final prefs = await _getPrefs();
    if (prefs == null) return;
    final all = await getAllMarkers();
    all.removeWhere((m) => m.idempotencyKey == idempotencyKey);
    final jsonList = all.map((m) => m.toJson()).toList();
    await prefs.setString(storageKeyMarkers, jsonEncode(jsonList));
  }

  // --- Protocolo en dos fases ---

  /// Registra una toma utilizando el protocolo estricto en dos fases:
  /// 1. Normaliza fecha y genera cuerpo clínico canónico compatible con Pydantic v2.
  /// 2. Guarda clave, cuerpo clínico en memoria de sesión y marcador mínimo opaco ANTES de la petición.
  /// 3. Fase 1: POST /dosis/{id}/intentos con `request_hash` y header `Idempotency-Key`.
  ///    - Si devuelve CONFIRMADA: recupera dosis sin repetir registro, limpia marcador/memoria, desbloquea dosis y retorna resultado.
  ///    - Si devuelve RECHAZADA, NO_INICIADA, respuesta inválida o error: NUNCA enviar fase 2.
  /// 4. Solo si la intención está confirmada como `EN_CURSO`:
  ///    Fase 2: POST /dosis/{id}/registros con exactamente la misma clave y el mismo cuerpo normalizado.
  /// 5. Ante fallo de red / timeout / 5xx en fase 1 o 2: bloquea la dosis, conserva clave y marcador.
  /// 6. Diferencia 422 (validación), 409 (conflicto), 401 (no autenticado), timeout y 5xx.
  Future<DoseOperationResult> registrarDosisEnDosFases({
    required int userId,
    required int clinicId,
    required int idDosis,
    required String estado,
    DateTime? efectivaEn,
    String? efectivaEnRaw,
    String? nota,
    String? customIdempotencyKey,
  }) async {
    if (_executingDoses.contains(idDosis) ||
        _uncertainDoses.contains(idDosis)) {
      throw ConflictException(
        'Existe una operación en curso o de resultado incierto para esta dosis.',
      );
    }
    _executingDoses.add(idDosis);
    _lockedDoses.add(idDosis);

    final idempotencyKey = customIdempotencyKey ?? generateIdempotencyKey();

    // Normalizar efectiva_en para garantizar compatibilidad idéntica con Pydantic v2
    final String? efectivaStr;
    if (efectivaEnRaw != null) {
      efectivaStr = CanonicalJsonHasher.normalizeIsoDateTime(efectivaEnRaw);
    } else if (efectivaEn != null) {
      efectivaStr = CanonicalJsonHasher.formatCanonicalDateTime(efectivaEn);
    } else {
      efectivaStr = null;
    }

    // 1. Cuerpo clínico normalizado
    final clinicalBody = <String, dynamic>{
      'efectiva_en': efectivaStr,
      'estado': estado,
      'nota': nota,
    };

    // 2. Hash canónico SHA-256
    final requestHash = CanonicalJsonHasher.hashDoseRegistration(
      estado: estado,
      efectivaEn: efectivaStr,
      nota: nota,
    );

    // 3. Almacenar clave y cuerpo clínico ÚNICAMENTE en memoria de sesión ANTES de la petición
    _pendingBodies[idempotencyKey] = Map.unmodifiable(clinicalBody);

    // 4. Marcador mínimo de recuperación (¡sin datos clínicos!) guardado ANTES de la petición
    final marker = DoseRecoveryMarker(
      userId: userId,
      clinicId: clinicId,
      idDosis: idDosis,
      idempotencyKey: idempotencyKey,
      timestamp: DateTime.now().toUtc().toIso8601String(),
    );
    try {
      await saveMarker(marker);
    } catch (_) {
      _pendingBodies.remove(idempotencyKey);
      unlockDose(idDosis);
      rethrow;
    }

    // 5. Fase 1: POST /dosis/{id}/intentos con request_hash e Idempotency-Key
    dynamic intentoResp;
    try {
      intentoResp = await _apiClient.post(
        ApiConfig.doseAttemptsUrl(idDosis),
        body: {'request_hash': requestHash},
        headers: {'Idempotency-Key': idempotencyKey},
      );
    } catch (e) {
      _executingDoses.remove(idDosis);
      if (e is ValidationException) {
        // 422: Datos de solicitud inválidos por el backend. Sin mutación.
        await removeMarker(idempotencyKey);
        _pendingBodies.remove(idempotencyKey);
        unlockDose(idDosis);
        rethrow;
      } else if (e is ConflictException) {
        // 409: Conflicto de concurrencia o estado.
        _markDoseUncertain(idDosis);
        rethrow;
      } else if (e is UnauthorizedException) {
        // 401: Token inválido/expirado. Mantener marcador para reconciliación post-login.
        _markDoseUncertain(idDosis);
        rethrow;
      } else if (e is TimeoutException ||
          e is dart_async.TimeoutException ||
          e is NetworkException ||
          e is ServerException) {
        // Timeout, error de red o 5xx en fase 1: resultado incierto
        _markDoseUncertain(idDosis);
        rethrow;
      } else {
        // Catch genérico: NO liberar el bloqueo
        _markDoseUncertain(idDosis);
        rethrow;
      }
    }

    final intentoResult = DoseOperationResult.fromJson(
      intentoResp is Map<String, dynamic> ? intentoResp : {},
    );

    // Si intención devuelve CONFIRMADA: recuperar dosis confirmada sin repetir registro,
    // limpiar marcador/memoria, desbloquear dosis y retornar resultado.
    if (intentoResult.isConfirmed) {
      await removeMarker(idempotencyKey);
      _pendingBodies.remove(idempotencyKey);
      unlockDose(idDosis);
      return intentoResult;
    }

    // Si Fase 1 devuelve RECHAZADA: NUNCA enviar fase 2.
    if (intentoResult.isRejected) {
      await removeMarker(idempotencyKey);
      _pendingBodies.remove(idempotencyKey);
      unlockDose(idDosis);
      return intentoResult;
    }

    // Si Fase 1 devuelve NO_INICIADA, respuesta inválida o error: NUNCA enviar fase 2.
    if (intentoResult.isNotStarted || !intentoResult.isInProgress) {
      _executingDoses.remove(idDosis);
      _markDoseUncertain(idDosis);
      return intentoResult;
    }

    // 6. Fase 2: Solo si la intención está confirmada como EN_CURSO:
    // POST /dosis/{id}/registros con exactamente la misma clave y el mismo cuerpo normalizado.
    try {
      final registroResp = await _apiClient.post(
        ApiConfig.doseRecordsUrl(idDosis),
        body: clinicalBody,
        headers: {'Idempotency-Key': idempotencyKey},
      );

      final registroMap = registroResp is Map<String, dynamic>
          ? registroResp
          : (registroResp is Map
                ? Map<String, dynamic>.from(registroResp)
                : <String, dynamic>{});

      final result = DoseOperationResult.fromRegistroDosisResponse(
        registroMap,
        idempotencyKey: idempotencyKey,
        generacion: intentoResult.generacion,
      );

      // Éxito: limpiar marcador persistente y memoria, desbloquear dosis y retornar el resultado confirmado.
      await removeMarker(idempotencyKey);
      _pendingBodies.remove(idempotencyKey);
      unlockDose(idDosis);
      return result;
    } catch (e) {
      _executingDoses.remove(idDosis);
      if (e is ValidationException) {
        // 422 en Fase 2: Rechazado por validación
        await removeMarker(idempotencyKey);
        _pendingBodies.remove(idempotencyKey);
        unlockDose(idDosis);
        rethrow;
      } else if (e is ConflictException) {
        // 409
        _markDoseUncertain(idDosis);
        rethrow;
      } else if (e is UnauthorizedException) {
        // 401
        _markDoseUncertain(idDosis);
        rethrow;
      } else if (e is TimeoutException ||
          e is dart_async.TimeoutException ||
          e is NetworkException ||
          e is ServerException) {
        // Timeout, error de red o 5xx en fase 2: conservar clave y marcador, BLOQUEAR dosis
        _markDoseUncertain(idDosis);
        rethrow;
      } else {
        // Catch genérico: NO liberar el bloqueo
        _markDoseUncertain(idDosis);
        rethrow;
      }
    }
  }

  // --- Recuperación e Idempotencia ---

  /// Consulta el estado de una operación mediante GET /dosis/{id}/registros/idempotencia/{key}.
  Future<DoseOperationResult> consultarIdempotencia({
    required int idDosis,
    required String idempotencyKey,
  }) async {
    final response = await _apiClient.get(
      ApiConfig.doseIdempotencyUrl(idDosis, idempotencyKey),
    );
    return DoseOperationResult.fromJson(
      response is Map<String, dynamic> ? response : {},
    );
  }

  /// Si el cuerpo clínico se conserva en memoria (misma sesión), permite un reintento exacto
  /// con la misma clave y el mismo cuerpo normalizado.
  Future<DoseOperationResult?> reintentarOperacionConCuerpo({
    required int idDosis,
    required String idempotencyKey,
  }) async {
    final body = getPendingBody(idempotencyKey);
    if (body == null) {
      // El cuerpo clínico ya no se conserva (ej. tras reinicio o logout)
      return null;
    }

    try {
      final response = await _apiClient.post(
        ApiConfig.doseRecordsUrl(idDosis),
        body: body,
        headers: {'Idempotency-Key': idempotencyKey},
      );

      final map = response is Map<String, dynamic>
          ? response
          : (response is Map
                ? Map<String, dynamic>.from(response)
                : <String, dynamic>{});

      final result = DoseOperationResult.fromRegistroDosisResponse(
        map,
        idempotencyKey: idempotencyKey,
      );

      await removeMarker(idempotencyKey);
      _pendingBodies.remove(idempotencyKey);
      unlockDose(idDosis);
      return result;
    } catch (e) {
      if (e is ValidationException) {
        await removeMarker(idempotencyKey);
        _pendingBodies.remove(idempotencyKey);
        unlockDose(idDosis);
        rethrow;
      }
      _markDoseUncertain(idDosis);
      rethrow;
    }
  }

  /// Resuelve deterministamente una operación abandonada vía POST /dosis/{id}/registros/idempotencia/{key}/resolver.
  ///
  /// Maneja los 4 estados del contrato:
  /// - `CONFIRMADA`: dosis actualizada exitosamente; limpia marcador, desbloquea dosis y retorna resultado.
  /// - `RECHAZADA`: operación descartada definitivamente; limpia marcador, desbloquea dosis y retorna resultado.
  /// - `EN_CURSO`: resolución o registro en curso; mantiene bloqueo y marcador.
  /// - `NO_INICIADA`: NO libera el marcador en el cliente. Mantiene bloqueo hasta que backend resuelva a RECHAZADA.
  Future<DoseOperationResult> resolverOperacionAbandonada({
    required int userId,
    required int clinicId,
    required int idDosis,
    required String idempotencyKey,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiConfig.doseResolveUrl(idDosis, idempotencyKey),
      );

      final result = DoseOperationResult.fromJson(
        response is Map<String, dynamic> ? response : {},
      );

      switch (result.estado) {
        case 'CONFIRMADA':
          await removeMarker(idempotencyKey);
          _pendingBodies.remove(idempotencyKey);
          unlockDose(idDosis);
          return result;

        case 'RECHAZADA':
          await removeMarker(idempotencyKey);
          _pendingBodies.remove(idempotencyKey);
          unlockDose(idDosis);
          return result;

        case 'EN_CURSO':
          _markDoseUncertain(idDosis);
          return result;

        case 'NO_INICIADA':
          // REGLA: Si devuelve NO_INICIADA, NO liberar marcador en el cliente.
          _markDoseUncertain(idDosis);
          return result;

        default:
          _markDoseUncertain(idDosis);
          return result;
      }
    } catch (e) {
      _markDoseUncertain(idDosis);
      rethrow;
    }
  }

  /// Reconcilia los marcadores pendientes al iniciar sesión aislando estrictamente por [userId] y [clinicId].
  Future<List<DoseOperationResult>> reconciliarMarcadoresPendientes({
    required int userId,
    required int clinicId,
  }) async {
    final markers = await getPendingMarkers(userId: userId, clinicId: clinicId);
    final results = <DoseOperationResult>[];

    for (final marker in markers) {
      final key = marker.idempotencyKey;
      final idDosis = marker.idDosis;

      // 1. Si el cuerpo clínico se conserva en memoria (misma sesión):
      if (hasPendingBody(key)) {
        try {
          final status = await consultarIdempotencia(
            idDosis: idDosis,
            idempotencyKey: key,
          );
          if (status.isConfirmed) {
            await removeMarker(key);
            _pendingBodies.remove(key);
            unlockDose(idDosis);
            results.add(status);
            continue;
          } else if (status.isRejected) {
            await removeMarker(key);
            _pendingBodies.remove(key);
            unlockDose(idDosis);
            results.add(status);
            continue;
          } else {
            // Reintentar con el cuerpo disponible
            final retryResult = await reintentarOperacionConCuerpo(
              idDosis: idDosis,
              idempotencyKey: key,
            );
            if (retryResult != null) {
              results.add(retryResult);
              continue;
            }
          }
        } catch (_) {
          lockDose(idDosis);
        }
      }

      // 2. Si el cuerpo clínico ya no se conserva (reinicio / nueva sesión):
      try {
        final resolveResult = await resolverOperacionAbandonada(
          userId: userId,
          clinicId: clinicId,
          idDosis: idDosis,
          idempotencyKey: key,
        );
        results.add(resolveResult);
      } catch (_) {
        lockDose(idDosis);
      }
    }

    return results;
  }
}
