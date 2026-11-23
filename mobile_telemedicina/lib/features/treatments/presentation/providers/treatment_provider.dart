import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exceptions.dart';
import '../../data/models/dosis_model.dart';
import '../../data/services/dose_operation_recovery_service.dart';
import '../../domain/entities/treatment_entities.dart';
import '../../domain/usecases/get_adherencia_usecase.dart';
import '../../domain/usecases/get_avisos_usecase.dart';
import '../../domain/usecases/get_cronograma_usecase.dart';
import '../../domain/usecases/get_treatment_detail_usecase.dart';
import '../../domain/usecases/get_treatments_usecase.dart';
import '../../domain/usecases/mark_aviso_read_usecase.dart';
import '../../domain/usecases/record_dose_usecase.dart';

/// Estados explícitos y atómicos para el listado de tratamientos.
enum TreatmentListStatus { initial, loading, loaded, empty, error }

/// Estados explícitos para el detalle del plan médico.
enum TreatmentDetailStatus { initial, loading, loaded, error }

/// Estados explícitos para la vista del cronograma del día.
enum CronogramaStatus { initial, loading, loaded, error }

/// Estados explícitos para la consulta de adherencia.
enum AdherenciaStatus { initial, loading, loaded, error }

/// Estados explícitos para la acción de registro / corrección de toma.
enum RecordDoseStatus { idle, submitting, success, error }

/// Estados explícitos para la bandeja de avisos.
enum AvisosStatus { initial, loading, loaded, empty, error }

/// Callback desacoplado para invalidación de sesión (401).
typedef SessionExpiredCallback = Future<void> Function();

/// Provider de estado de presentación para CU17 «Gestionar y Monitorear Tratamiento Médico».
class TreatmentProvider extends ChangeNotifier {
  final GetTreatmentsUseCase _getTreatmentsUseCase;
  final GetTreatmentDetailUseCase _getDetailUseCase;
  final GetCronogramaUseCase _getCronogramaUseCase;
  final GetAdherenciaUseCase _getAdherenciaUseCase;
  final RecordDoseUseCase _recordDoseUseCase;
  final GetAvisosUseCase _getAvisosUseCase;
  final MarkAvisoReadUseCase _markAvisoReadUseCase;
  final DoseOperationRecoveryService _recoveryService;

  SessionExpiredCallback? onSessionExpired;

  TreatmentProvider({
    GetTreatmentsUseCase? getTreatmentsUseCase,
    GetTreatmentDetailUseCase? getDetailUseCase,
    GetCronogramaUseCase? getCronogramaUseCase,
    GetAdherenciaUseCase? getAdherenciaUseCase,
    RecordDoseUseCase? recordDoseUseCase,
    GetAvisosUseCase? getAvisosUseCase,
    MarkAvisoReadUseCase? markAvisoReadUseCase,
    DoseOperationRecoveryService? recoveryService,
    this.onSessionExpired,
  }) : _getTreatmentsUseCase = getTreatmentsUseCase ?? GetTreatmentsUseCase(),
       _getDetailUseCase = getDetailUseCase ?? GetTreatmentDetailUseCase(),
       _getCronogramaUseCase = getCronogramaUseCase ?? GetCronogramaUseCase(),
       _getAdherenciaUseCase = getAdherenciaUseCase ?? GetAdherenciaUseCase(),
       _recordDoseUseCase = recordDoseUseCase ?? RecordDoseUseCase(),
       _getAvisosUseCase = getAvisosUseCase ?? GetAvisosUseCase(),
       _markAvisoReadUseCase = markAvisoReadUseCase ?? MarkAvisoReadUseCase(),
       _recoveryService = recoveryService ?? DoseOperationRecoveryService();

  // --- Listado de tratamientos ---
  TreatmentListStatus _listStatus = TreatmentListStatus.initial;
  List<TreatmentPlan> _treatments = const [];
  int _totalTreatments = 0;
  String? _listError;
  String? _estadoFilter;

  // --- Detalle del plan seleccionado ---
  TreatmentDetailStatus _detailStatus = TreatmentDetailStatus.initial;
  TreatmentPlan? _selectedTreatment;
  int? _activeDetailId;
  String? _detailError;

  // --- Cronograma del día ---
  CronogramaStatus _cronogramaStatus = CronogramaStatus.initial;
  CronogramaDia? _cronograma;
  DateTime _selectedDate = DateTime.now();
  String? _cronogramaError;

  // --- Adherencia ---
  AdherenciaStatus _adherenciaStatus = AdherenciaStatus.initial;
  Adherencia? _adherencia;
  String? _adherenciaError;

  // --- Registro de dosis y bloqueos por estado incierto ---
  RecordDoseStatus _recordDoseStatus = RecordDoseStatus.idle;
  String? _recordDoseError;
  final Set<int> _lockedDoses = {};
  List<DoseRecoveryMarker> _pendingMarkers = const [];

  // --- Bandeja de avisos ---
  AvisosStatus _avisosStatus = AvisosStatus.initial;
  List<Aviso> _avisos = const [];
  int _totalAvisos = 0;
  int _unreadAvisosCount = 0;
  String? _avisosError;
  bool _soloNoLeidosFilter = false;

  // --- Sesión y Generaciones de Concurrencia ---
  int? _currentUserId;
  int? _currentClinicId;
  int _sessionGeneration = 0;
  bool _sessionExpiredNotified = false;
  bool _wasAuthenticated = false;
  int _listGen = 0;
  int _detailGen = 0;
  int _cronogramaGen = 0;
  int _avisosGen = 0;
  bool _disposed = false;

  // ================= GETTERS =================
  TreatmentListStatus get listStatus => _listStatus;
  List<TreatmentPlan> get treatments => List.unmodifiable(_treatments);
  int get totalTreatments => _totalTreatments;
  String? get listError => _listError;
  String? get estadoFilter => _estadoFilter;

  TreatmentDetailStatus get detailStatus => _detailStatus;
  TreatmentPlan? get selectedTreatment => _selectedTreatment;
  int? get activeDetailId => _activeDetailId;
  String? get detailError => _detailError;

  CronogramaStatus get cronogramaStatus => _cronogramaStatus;
  CronogramaDia? get cronograma => _cronograma;
  DateTime get selectedDate => _selectedDate;
  String? get cronogramaError => _cronogramaError;

  AdherenciaStatus get adherenciaStatus => _adherenciaStatus;
  Adherencia? get adherencia => _adherencia;
  String? get adherenciaError => _adherenciaError;

  RecordDoseStatus get recordDoseStatus => _recordDoseStatus;
  String? get recordDoseError => _recordDoseError;

  int? get currentUserId => _currentUserId;
  int? get currentClinicId => _currentClinicId;
  int get sessionGeneration => _sessionGeneration;
  DoseOperationRecoveryService get recoveryService => _recoveryService;
  RecordDoseUseCase get recordDoseUseCase => _recordDoseUseCase;
  List<DoseRecoveryMarker> get pendingMarkers =>
      List.unmodifiable(_pendingMarkers);
  bool get hasPendingMarkers => _pendingMarkers.isNotEmpty;

  /// Retorna todas las dosis bloqueadas localmente o por marcadores pendientes.
  Set<int> get lockedDoses {
    final set = Set<int>.from(_lockedDoses);
    for (final m in _pendingMarkers) {
      set.add(m.idDosis);
    }
    for (var i = 1; i <= 10000; i++) {
      if (_recoveryService.isDoseLocked(i)) {
        set.add(i);
      }
    }
    return Set.unmodifiable(set);
  }

  /// Retorna si la toma está bloqueada por operación en curso o resultado incierto.
  bool isDoseLocked(int idDosis) =>
      _lockedDoses.contains(idDosis) ||
      _recoveryService.isDoseLocked(idDosis) ||
      _pendingMarkers.any((m) => m.idDosis == idDosis);

  /// Retorna si una dosis específica tiene una operación incierta o pendiente.
  bool hasPendingOperationForDose(int idDosis) => isDoseLocked(idDosis);

  /// Obtiene el marcador persistente para la dosis si existe.
  DoseRecoveryMarker? getPendingMarkerForDose(int idDosis) {
    try {
      return _pendingMarkers.firstWhere((m) => m.idDosis == idDosis);
    } catch (_) {
      return null;
    }
  }

  /// Retorna si el cuerpo clínico de la dosis sigue disponible en la memoria de sesión.
  bool hasPendingBodyForDose(int idDosis) {
    final marker = getPendingMarkerForDose(idDosis);
    if (marker == null) return false;
    return _recoveryService.hasPendingBody(marker.idempotencyKey);
  }

  AvisosStatus get avisosStatus => _avisosStatus;
  List<Aviso> get avisos => List.unmodifiable(_avisos);
  int get totalAvisos => _totalAvisos;
  int get unreadAvisosCount => _unreadAvisosCount;
  String? get avisosError => _avisosError;
  bool get soloNoLeidosFilter => _soloNoLeidosFilter;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  // ================= SESIÓN =================
  void syncAuthSession({
    required bool isAuthenticated,
    int? userId,
    int? clinicId,
  }) {
    final sessionChanged =
        !isAuthenticated ||
        !_wasAuthenticated ||
        _currentUserId != userId ||
        _currentClinicId != clinicId;

    if (sessionChanged) {
      _sessionGeneration++;
      _listGen++;
      _detailGen++;
      _cronogramaGen++;
      _avisosGen++;
      _recoveryService.onSessionLogout();
      _treatments = const [];
      _totalTreatments = 0;
      _selectedTreatment = null;
      _activeDetailId = null;
      _cronograma = null;
      _adherencia = null;
      _avisos = const [];
      _totalAvisos = 0;
      _unreadAvisosCount = 0;
      _lockedDoses.clear();
      _pendingMarkers = const [];
      _listStatus = TreatmentListStatus.initial;
      _detailStatus = TreatmentDetailStatus.initial;
      _cronogramaStatus = CronogramaStatus.initial;
      _adherenciaStatus = AdherenciaStatus.initial;
      _avisosStatus = AvisosStatus.initial;
      _recordDoseStatus = RecordDoseStatus.idle;
      _listError = null;
      _detailError = null;
      _cronogramaError = null;
      _adherenciaError = null;
      _avisosError = null;
      _recordDoseError = null;
    }

    if (!_wasAuthenticated && isAuthenticated) {
      _sessionExpiredNotified = false;
    }

    _currentUserId = isAuthenticated ? userId : null;
    _currentClinicId = isAuthenticated ? clinicId : null;
    _wasAuthenticated = isAuthenticated;
    _safeNotify();
  }

  void _handleError(Object error) {
    if (error is UnauthorizedException) {
      if (!_sessionExpiredNotified) {
        _sessionExpiredNotified = true;
        onSessionExpired?.call();
      }
    }
  }

  // ================= RECUPERACIÓN Y RECONCILIACIÓN DE DOSIS =================

  /// Carga los marcadores persistentes para el usuario y clínica autenticados.
  Future<List<DoseRecoveryMarker>> loadPendingMarkers() async {
    final opGen = _sessionGeneration;
    final opUser = _currentUserId;
    final opClinic = _currentClinicId;

    if (opUser == null || opClinic == null) {
      _pendingMarkers = const [];
      _safeNotify();
      return [];
    }

    final markers = await _recoveryService.getPendingMarkers(
      userId: opUser,
      clinicId: opClinic,
    );

    if (opGen != _sessionGeneration ||
        _currentUserId != opUser ||
        _currentClinicId != opClinic ||
        _disposed) {
      return [];
    }

    _pendingMarkers = markers;
    final markerDoseIds = _pendingMarkers.map((m) => m.idDosis).toSet();
    for (final id in markerDoseIds) {
      _lockedDoses.add(id);
    }
    _lockedDoses.removeWhere(
      (id) => !markerDoseIds.contains(id) && !_recoveryService.isDoseLocked(id),
    );

    _safeNotify();
    return _pendingMarkers;
  }

  /// Carga los marcadores pendientes, consulta idempotencia y reintenta con cuerpo si está disponible.
  Future<List<DoseOperationResult>> checkPendingMarkersAndReconcile() async {
    final opGen = _sessionGeneration;
    final opUser = _currentUserId;
    final opClinic = _currentClinicId;

    if (opUser == null || opClinic == null) {
      throw UnauthorizedException(
        'Usuario no autenticado o clínica no seleccionada',
      );
    }

    final results = await _recoveryService.reconciliarMarcadoresPendientes(
      userId: opUser,
      clinicId: opClinic,
    );

    if (opGen != _sessionGeneration ||
        _currentUserId != opUser ||
        _currentClinicId != opClinic ||
        _disposed) {
      return [];
    }

    await loadPendingMarkers();

    if (opGen != _sessionGeneration ||
        _currentUserId != opUser ||
        _currentClinicId != opClinic ||
        _disposed) {
      return [];
    }

    for (final res in results) {
      if (res.isConfirmed && res.dosis != null && _cronograma != null) {
        final updatedDosis = DosisModel.fromJson(res.dosis!).toEntity();
        final currentDoses = List<Dosis>.from(_cronograma!.dosis);
        final index = currentDoses.indexWhere((d) => d.idDosis == res.idDosis);
        if (index != -1) {
          currentDoses[index] = updatedDosis;
          _cronograma = CronogramaDia(
            idTratamiento: _cronograma!.idTratamiento,
            fecha: _cronograma!.fecha,
            zonaHoraria: _cronograma!.zonaHoraria,
            dosis: currentDoses,
            adherencia: _cronograma!.adherencia,
          );
        }
      }
    }

    final hadChanges = results.any((r) => r.isConfirmed || r.isRejected);
    if (hadChanges) {
      final treatmentId =
          _selectedTreatment?.idTratamiento ?? _cronograma?.idTratamiento;
      if (treatmentId != null) {
        unawaited(loadCronograma(treatmentId, _selectedDate));
        unawaited(loadAdherencia(treatmentId));
      }
    }

    _safeNotify();
    return results;
  }

  /// Reintenta una toma cuyo cuerpo clínico aún existe en memoria de sesión.
  Future<DoseOperationResult?> retryDoseWithPendingBody({
    required int idDosis,
    required String idempotencyKey,
  }) async {
    final opGen = _sessionGeneration;
    final opUser = _currentUserId;
    final opClinic = _currentClinicId;

    if (opUser == null || opClinic == null) {
      throw UnauthorizedException(
        'Usuario no autenticado o clínica no seleccionada',
      );
    }

    _recordDoseStatus = RecordDoseStatus.submitting;
    _recordDoseError = null;
    _safeNotify();

    try {
      final result = await _recoveryService.reintentarOperacionConCuerpo(
        idDosis: idDosis,
        idempotencyKey: idempotencyKey,
      );

      if (opGen != _sessionGeneration ||
          _currentUserId != opUser ||
          _currentClinicId != opClinic ||
          _disposed) {
        return result;
      }

      if (result != null && result.isConfirmed) {
        _lockedDoses.remove(idDosis);
        _recoveryService.unlockDose(idDosis);
        await loadPendingMarkers();

        if (opGen != _sessionGeneration ||
            _currentUserId != opUser ||
            _currentClinicId != opClinic ||
            _disposed) {
          return result;
        }

        if (result.dosis != null && _cronograma != null) {
          final updatedDosis = DosisModel.fromJson(result.dosis!).toEntity();
          final currentDoses = List<Dosis>.from(_cronograma!.dosis);
          final index = currentDoses.indexWhere((d) => d.idDosis == idDosis);
          if (index != -1) {
            currentDoses[index] = updatedDosis;
            _cronograma = CronogramaDia(
              idTratamiento: _cronograma!.idTratamiento,
              fecha: _cronograma!.fecha,
              zonaHoraria: _cronograma!.zonaHoraria,
              dosis: currentDoses,
              adherencia: _cronograma!.adherencia,
            );
          }
        }

        final treatmentId =
            _selectedTreatment?.idTratamiento ?? _cronograma?.idTratamiento;
        if (treatmentId != null) {
          unawaited(loadCronograma(treatmentId, _selectedDate));
          unawaited(loadAdherencia(treatmentId));
        }
        _recordDoseStatus = RecordDoseStatus.success;
      }
      _safeNotify();
      return result;
    } catch (e) {
      if (opGen != _sessionGeneration ||
          _currentUserId != opUser ||
          _currentClinicId != opClinic ||
          _disposed) {
        rethrow;
      }
      _lockedDoses.add(idDosis);
      _recordDoseStatus = RecordDoseStatus.error;
      _recordDoseError = e.toString().replaceFirst('Exception: ', '');
      _handleError(e);
      _safeNotify();
      rethrow;
    }
  }

  /// Resuelve de forma definitiva una operación abandonada vía POST /resolver.
  Future<DoseOperationResult> resolveAbandonedDose({
    required int idDosis,
    required String idempotencyKey,
  }) async {
    final opGen = _sessionGeneration;
    final opUser = _currentUserId;
    final opClinic = _currentClinicId;

    if (opUser == null || opClinic == null) {
      throw UnauthorizedException(
        'Usuario no autenticado o clínica no seleccionada',
      );
    }

    _recordDoseStatus = RecordDoseStatus.submitting;
    _recordDoseError = null;
    _safeNotify();

    try {
      final result = await _recoveryService.resolverOperacionAbandonada(
        userId: opUser,
        clinicId: opClinic,
        idDosis: idDosis,
        idempotencyKey: idempotencyKey,
      );

      if (opGen != _sessionGeneration ||
          _currentUserId != opUser ||
          _currentClinicId != opClinic ||
          _disposed) {
        return result;
      }

      if (result.isRejected || result.isConfirmed) {
        _lockedDoses.remove(idDosis);
        _recoveryService.unlockDose(idDosis);
        await loadPendingMarkers();

        if (opGen != _sessionGeneration ||
            _currentUserId != opUser ||
            _currentClinicId != opClinic ||
            _disposed) {
          return result;
        }

        final treatmentId =
            _selectedTreatment?.idTratamiento ?? _cronograma?.idTratamiento;
        if (treatmentId != null) {
          unawaited(loadCronograma(treatmentId, _selectedDate));
          unawaited(loadAdherencia(treatmentId));
        }
        _recordDoseStatus = RecordDoseStatus.success;
      } else {
        _lockedDoses.add(idDosis);
      }

      _safeNotify();
      return result;
    } catch (e) {
      if (opGen != _sessionGeneration ||
          _currentUserId != opUser ||
          _currentClinicId != opClinic ||
          _disposed) {
        rethrow;
      }
      _lockedDoses.add(idDosis);
      _recordDoseStatus = RecordDoseStatus.error;
      _recordDoseError = e.toString().replaceFirst('Exception: ', '');
      _handleError(e);
      _safeNotify();
      rethrow;
    }
  }

  // ================= 1. LISTA DE TRATAMIENTOS =================
  Future<void> loadTreatments({bool refresh = false, String? estado}) async {
    final opGen = _sessionGeneration;
    final opUser = _currentUserId;
    final opClinic = _currentClinicId;
    final gen = ++_listGen;

    if (!refresh) {
      _listStatus = TreatmentListStatus.loading;
      _listError = null;
      _safeNotify();
    }

    _estadoFilter = estado;

    try {
      final page = await _getTreatmentsUseCase(
        estado: estado,
        skip: 0,
        limit: 50,
      );

      if (opGen != _sessionGeneration ||
          _currentUserId != opUser ||
          _currentClinicId != opClinic ||
          gen != _listGen ||
          _disposed) {
        return;
      }

      _treatments = page.items;
      _totalTreatments = page.total;
      _listStatus = _treatments.isEmpty
          ? TreatmentListStatus.empty
          : TreatmentListStatus.loaded;
      _listError = null;
      _safeNotify();
    } catch (e) {
      if (opGen != _sessionGeneration ||
          _currentUserId != opUser ||
          _currentClinicId != opClinic ||
          gen != _listGen ||
          _disposed) {
        return;
      }
      _handleError(e);
      _listStatus = TreatmentListStatus.error;
      _listError = e.toString().replaceFirst('Exception: ', '');
      _safeNotify();
    }
  }

  // ================= 2. DETALLE DE TRATAMIENTO =================
  Future<void> loadTreatmentDetail(int idTratamiento) async {
    final opGen = _sessionGeneration;
    final opUser = _currentUserId;
    final opClinic = _currentClinicId;
    final gen = ++_detailGen;

    _activeDetailId = idTratamiento;
    _detailStatus = TreatmentDetailStatus.loading;
    _detailError = null;
    _safeNotify();

    try {
      final detail = await _getDetailUseCase(idTratamiento);

      if (opGen != _sessionGeneration ||
          _currentUserId != opUser ||
          _currentClinicId != opClinic ||
          gen != _detailGen ||
          _disposed) {
        return;
      }

      _selectedTreatment = detail;
      if (detail.adherencia != null) {
        _adherencia = detail.adherencia;
        _adherenciaStatus = AdherenciaStatus.loaded;
      }
      _detailStatus = TreatmentDetailStatus.loaded;
      _detailError = null;
      _safeNotify();
    } catch (e) {
      if (opGen != _sessionGeneration ||
          _currentUserId != opUser ||
          _currentClinicId != opClinic ||
          gen != _detailGen ||
          _disposed) {
        return;
      }
      _handleError(e);
      _detailStatus = TreatmentDetailStatus.error;
      _detailError = e.toString().replaceFirst('Exception: ', '');
      _safeNotify();
    }
  }

  // ================= 3. CRONOGRAMA =================
  Future<void> loadCronograma(int idTratamiento, [DateTime? fecha]) async {
    final opGen = _sessionGeneration;
    final opUser = _currentUserId;
    final opClinic = _currentClinicId;
    final gen = ++_cronogramaGen;

    if (fecha != null) {
      _selectedDate = fecha;
    }
    _cronogramaStatus = CronogramaStatus.loading;
    _cronogramaError = null;
    _safeNotify();

    final dateStr = _formatIsoDate(_selectedDate);

    try {
      final dia = await _getCronogramaUseCase(idTratamiento, dateStr);

      if (opGen != _sessionGeneration ||
          _currentUserId != opUser ||
          _currentClinicId != opClinic ||
          gen != _cronogramaGen ||
          _disposed) {
        return;
      }

      _cronograma = dia;
      if (dia.adherencia != null) {
        _adherencia = dia.adherencia;
        _adherenciaStatus = AdherenciaStatus.loaded;
      }
      _cronogramaStatus = CronogramaStatus.loaded;
      _cronogramaError = null;

      // Verificar y sincronizar operaciones pendientes de la sesión
      await loadPendingMarkers();

      if (opGen != _sessionGeneration ||
          _currentUserId != opUser ||
          _currentClinicId != opClinic ||
          gen != _cronogramaGen ||
          _disposed) {
        return;
      }

      _safeNotify();
    } catch (e) {
      if (opGen != _sessionGeneration ||
          _currentUserId != opUser ||
          _currentClinicId != opClinic ||
          gen != _cronogramaGen ||
          _disposed) {
        return;
      }
      _handleError(e);
      _cronogramaStatus = CronogramaStatus.error;
      _cronogramaError = e.toString().replaceFirst('Exception: ', '');
      _safeNotify();
    }
  }

  Future<void> changeCronogramaDate(DateTime newDate) async {
    _selectedDate = newDate;
    if (_selectedTreatment != null) {
      await loadCronograma(_selectedTreatment!.idTratamiento, newDate);
    } else if (_cronograma != null) {
      await loadCronograma(_cronograma!.idTratamiento, newDate);
    } else {
      _safeNotify();
    }
  }

  // ================= 4. ADHERENCIA =================
  Future<void> loadAdherencia(int idTratamiento) async {
    final opGen = _sessionGeneration;
    final opUser = _currentUserId;
    final opClinic = _currentClinicId;

    _adherenciaStatus = AdherenciaStatus.loading;
    _adherenciaError = null;
    _safeNotify();

    try {
      final metric = await _getAdherenciaUseCase(idTratamiento);

      if (opGen != _sessionGeneration ||
          _currentUserId != opUser ||
          _currentClinicId != opClinic ||
          _disposed) {
        return;
      }

      _adherencia = metric;
      _adherenciaStatus = AdherenciaStatus.loaded;
      _adherenciaError = null;
      _safeNotify();
    } catch (e) {
      if (opGen != _sessionGeneration ||
          _currentUserId != opUser ||
          _currentClinicId != opClinic ||
          _disposed) {
        return;
      }
      _handleError(e);
      _adherenciaStatus = AdherenciaStatus.error;
      _adherenciaError = e.toString().replaceFirst('Exception: ', '');
      _safeNotify();
    }
  }

  // ================= 5. REGISTRAR / CORREGIR TOMA (PROTOCOLO EN DOS FASES) =================
  Future<Dosis> recordDose({
    required int idDosis,
    required String estado,
    DateTime? efectivaEn,
    String? nota,
    bool isCorrection = false,
    String? customIdempotencyKey,
  }) async {
    final opGen = _sessionGeneration;
    final opUser = _currentUserId;
    final opClinic = _currentClinicId;

    if (opUser == null || opClinic == null) {
      throw UnauthorizedException(
        'Usuario no autenticado o clínica no seleccionada',
      );
    }

    // Si la toma está bloqueada, arrojamos ConflictException estricta
    if (isDoseLocked(idDosis)) {
      throw ConflictException(
        'Existe una operación en curso o de resultado incierto para esta dosis.',
      );
    }

    _lockedDoses.add(idDosis);
    _recordDoseStatus = RecordDoseStatus.submitting;
    _recordDoseError = null;
    _safeNotify();

    // Corrección legítima: una corrección de dosis ya registrada debe generar una NUEVA clave
    final String key;
    if (isCorrection) {
      key = DoseOperationRecoveryService.generateIdempotencyKey();
    } else {
      key =
          customIdempotencyKey ??
          DoseOperationRecoveryService.generateIdempotencyKey();
    }

    final efectivaIso = efectivaEn?.toUtc().toIso8601String();

    try {
      final result = await _recoveryService.registrarDosisEnDosFases(
        userId: opUser,
        clinicId: opClinic,
        idDosis: idDosis,
        estado: estado,
        efectivaEn: efectivaEn,
        efectivaEnRaw: efectivaIso,
        nota: nota,
        customIdempotencyKey: key,
      );

      // Si la sesión cambió durante la llamada asíncrona, descartar respuesta tardía
      if (opGen != _sessionGeneration ||
          _currentUserId != opUser ||
          _currentClinicId != opClinic ||
          _disposed) {
        throw ConflictException('Sesión invalidada durante la operación');
      }

      if (!result.isConfirmed || result.dosis == null) {
        _recordDoseStatus = RecordDoseStatus.error;
        if (result.isRejected) {
          _lockedDoses.remove(idDosis);
          await loadPendingMarkers();
          final msg = result.mensaje ?? 'Operación rechazada';
          _recordDoseError = msg;
          _safeNotify();
          throw ConflictException(msg);
        } else {
          _lockedDoses.add(idDosis);
          await loadPendingMarkers();
          const msg = 'Operación no confirmada o de resultado incierto';
          _recordDoseError = msg;
          _safeNotify();
          throw ConflictException(msg);
        }
      }

      _lockedDoses.remove(idDosis);
      await loadPendingMarkers();

      if (opGen != _sessionGeneration ||
          _currentUserId != opUser ||
          _currentClinicId != opClinic ||
          _disposed) {
        throw ConflictException('Sesión invalidada durante la operación');
      }

      final updatedDosis = DosisModel.fromJson(result.dosis!).toEntity();

      if (_cronograma != null) {
        final currentDoses = List<Dosis>.from(_cronograma!.dosis);
        final index = currentDoses.indexWhere((d) => d.idDosis == idDosis);
        if (index != -1) {
          currentDoses[index] = updatedDosis;
          _cronograma = CronogramaDia(
            idTratamiento: _cronograma!.idTratamiento,
            fecha: _cronograma!.fecha,
            zonaHoraria: _cronograma!.zonaHoraria,
            dosis: currentDoses,
            adherencia: _cronograma!.adherencia,
          );
        }
      }

      _recordDoseStatus = RecordDoseStatus.success;

      // Refrescar adherencia acumulada en segundo plano
      final treatmentId =
          _selectedTreatment?.idTratamiento ?? _cronograma?.idTratamiento;
      if (treatmentId != null) {
        unawaited(loadAdherencia(treatmentId));
      }

      _safeNotify();
      return updatedDosis;
    } catch (e) {
      if (opGen != _sessionGeneration ||
          _currentUserId != opUser ||
          _currentClinicId != opClinic ||
          _disposed) {
        rethrow;
      }
      if (_recoveryService.isDoseLocked(idDosis)) {
        _lockedDoses.add(idDosis);
      }
      await loadPendingMarkers();
      if (opGen != _sessionGeneration ||
          _currentUserId != opUser ||
          _currentClinicId != opClinic ||
          _disposed) {
        rethrow;
      }
      _recordDoseStatus = RecordDoseStatus.error;
      _recordDoseError = e.toString().replaceFirst('Exception: ', '');
      _handleError(e);
      _safeNotify();
      rethrow;
    }
  }

  // ================= 6. BANDEJA DE AVISOS =================
  Future<void> loadAvisos({bool noLeidos = false}) async {
    final opGen = _sessionGeneration;
    final opUser = _currentUserId;
    final opClinic = _currentClinicId;
    final gen = ++_avisosGen;

    _soloNoLeidosFilter = noLeidos;
    _avisosStatus = AvisosStatus.loading;
    _avisosError = null;
    _safeNotify();

    try {
      final page = await _getAvisosUseCase(
        skip: 0,
        limit: 50,
        noLeidos: noLeidos,
      );

      if (opGen != _sessionGeneration ||
          _currentUserId != opUser ||
          _currentClinicId != opClinic ||
          gen != _avisosGen ||
          _disposed) {
        return;
      }

      _avisos = page.items;
      _totalAvisos = page.total;
      _unreadAvisosCount = _avisos.where((a) => !a.estaLeido).length;
      _avisosStatus = _avisos.isEmpty
          ? AvisosStatus.empty
          : AvisosStatus.loaded;
      _avisosError = null;
      _safeNotify();
    } catch (e) {
      if (opGen != _sessionGeneration ||
          _currentUserId != opUser ||
          _currentClinicId != opClinic ||
          gen != _avisosGen ||
          _disposed) {
        return;
      }
      _handleError(e);
      _avisosStatus = AvisosStatus.error;
      _avisosError = e.toString().replaceFirst('Exception: ', '');
      _safeNotify();
    }
  }

  Future<void> markAvisoAsRead(int idAviso) async {
    final opGen = _sessionGeneration;
    final opUser = _currentUserId;
    final opClinic = _currentClinicId;

    try {
      final updated = await _markAvisoReadUseCase(idAviso);

      if (opGen != _sessionGeneration ||
          _currentUserId != opUser ||
          _currentClinicId != opClinic ||
          _disposed) {
        return;
      }

      final current = List<Aviso>.from(_avisos);
      final idx = current.indexWhere((a) => a.idAviso == idAviso);
      if (idx != -1) {
        current[idx] = updated;
        _avisos = current;
        _unreadAvisosCount = _avisos.where((a) => !a.estaLeido).length;
        _safeNotify();
      }
    } catch (e) {
      if (opGen != _sessionGeneration ||
          _currentUserId != opUser ||
          _currentClinicId != opClinic ||
          _disposed) {
        return;
      }
      _handleError(e);
    }
  }

  static String _formatIsoDate(DateTime dt) {
    final year = dt.year.toString().padLeft(4, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
