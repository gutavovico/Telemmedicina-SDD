import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/services/dose_operation_recovery_service.dart';
import '../providers/treatment_provider.dart';

/// Coordinador de ciclo de vida de sesión para CU17.
///
/// Responsabilidades:
/// 1. Coordina la sesión con [AuthController].
/// 2. Detecta cambio de usuario o cierre de sesión y llama a
///    [DoseOperationRecoveryService.clearPendingClinicalData()] para garantizar
///    que ningún dato clínico pendiente en memoria sobreviva al cambio de cuenta.
/// 3. Invalida mediante contadores de generación de sesión cualquier respuesta
///    asíncrona o tardía para evitar poblar la UI tras logout o switch de cuenta.
/// 4. Permite reconciliar al inicio de sesión los marcadores pendientes
///    aislados estrictamente para ese usuario y clínica.
class TreatmentSessionCoordinator extends ChangeNotifier {
  final DoseOperationRecoveryService _recoveryService;
  final AuthController? _authController;
  TreatmentProvider? _treatmentProvider;

  int? _currentUserId;
  int? _currentClinicId;
  int _sessionGeneration = 0;
  bool _isReconciling = false;
  List<DoseOperationResult> _lastReconciliationResults = [];

  TreatmentSessionCoordinator({
    required DoseOperationRecoveryService recoveryService,
    AuthController? authController,
    TreatmentProvider? treatmentProvider,
  })  : _recoveryService = recoveryService,
        _authController = authController,
        _treatmentProvider = treatmentProvider {
    final controller = _authController;
    if (controller != null) {
      controller.addListener(_onAuthChanged);
      final initialUser = controller.currentUser;
      if (initialUser != null) {
        _currentUserId = initialUser.idUsuario;
        _currentClinicId = initialUser.idClinica;
      }
    }
  }

  int? get currentUserId => _currentUserId;
  int? get currentClinicId => _currentClinicId;
  int get sessionGeneration => _sessionGeneration;
  bool get isReconciling => _isReconciling;
  TreatmentProvider? get treatmentProvider => _treatmentProvider;
  List<DoseOperationResult> get lastReconciliationResults =>
      List.unmodifiable(_lastReconciliationResults);

  /// Conecta o actualiza la referencia al [TreatmentProvider].
  void attachTreatmentProvider(TreatmentProvider provider) {
    _treatmentProvider = provider;
    if (_currentUserId != null) {
      provider.syncAuthSession(
        isAuthenticated: true,
        userId: _currentUserId,
        clinicId: _currentClinicId,
      );
    }
  }

  void _onAuthChanged() {
    final user = _authController?.currentUser;
    onSessionStateChanged(
      userId: user?.idUsuario,
      clinicId: user?.idClinica,
    );
  }

  /// Detecta cambio de usuario o de clínica y limpia datos clínicos en memoria.
  void onSessionStateChanged({int? userId, int? clinicId}) {
    final userChanged =
        userId != _currentUserId || clinicId != _currentClinicId;

    if (userChanged) {
      _sessionGeneration++;
      // Cambio de cuenta o cierre de sesión detectado:
      // Inmediatamente eliminamos los cuerpos clínicos en memoria
      _recoveryService.clearPendingClinicalData();
      if (userId == null) {
        _recoveryService.onSessionLogout();
      }
      _currentUserId = userId;
      _currentClinicId = clinicId;
      _lastReconciliationResults = [];

      // Sincronizar provider si está conectado
      _treatmentProvider?.syncAuthSession(
        isAuthenticated: userId != null,
        userId: userId,
        clinicId: clinicId,
      );

      notifyListeners();
    }
  }

  /// Invocado explícitamente en el flujo de logout.
  void onSessionLogout() {
    _sessionGeneration++;
    _recoveryService.onSessionLogout();
    _currentUserId = null;
    _currentClinicId = null;
    _lastReconciliationResults = [];
    _treatmentProvider?.syncAuthSession(
      isAuthenticated: false,
      userId: null,
      clinicId: null,
    );
    notifyListeners();
  }

  /// Reconcilia los marcadores pendientes del usuario y clínica actualmente autenticados.
  Future<List<DoseOperationResult>> reconcileSessionMarkers() async {
    final uid = _currentUserId;
    final cid = _currentClinicId;
    if (uid == null || cid == null) {
      return [];
    }
    return reconcileForUserAndClinic(userId: uid, clinicId: cid);
  }

  /// Reconcilia marcadores pendientes para un usuario y clínica específicos.
  Future<List<DoseOperationResult>> reconcileForUserAndClinic({
    required int userId,
    required int clinicId,
  }) async {
    final startGeneration = _sessionGeneration;
    _isReconciling = true;
    notifyListeners();

    try {
      final results = await _recoveryService.reconciliarMarcadoresPendientes(
        userId: userId,
        clinicId: clinicId,
      );
      // Si la sesión cambió durante la llamada asíncrona, descartar resultados tardíos
      if (startGeneration != _sessionGeneration) {
        return [];
      }
      _lastReconciliationResults = results;
      return results;
    } finally {
      if (startGeneration == _sessionGeneration) {
        _isReconciling = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _authController?.removeListener(_onAuthChanged);
    super.dispose();
  }
}
