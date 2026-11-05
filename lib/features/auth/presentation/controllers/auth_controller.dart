import 'dart:async' show unawaited;
import 'package:flutter/foundation.dart';
import '../../../../core/network/api_exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/notifications/push_service.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/models/auth_models.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/services/inactivity_service.dart';

class AuthController extends ChangeNotifier {
  final AuthRemoteDataSource _remoteDataSource;
  final SecureStorageService _storageService;
  final InactivityService _inactivityService;

  AuthController({
    AuthRemoteDataSource? remoteDataSource,
    SecureStorageService? storageService,
    InactivityService? inactivityService,
  }) : _remoteDataSource = remoteDataSource ?? AuthRemoteDataSource(),
       _storageService = storageService ?? SecureStorageService(),
       _inactivityService = inactivityService ??
           InactivityService(
             remoteDataSource: remoteDataSource,
             storageService: storageService,
           );

  UserModel? _currentUser;
  bool _isLoading = false;
  bool _isCheckingAuth = true;
  bool _profileVerified = false;
  bool _reportsAuthorized = false;
  bool _isLoggingOut = false;
  int _sessionEpoch = 0;
  int _reportsCheckEpoch = 0;
  String? _errorMessage;
  String? _successMessage;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isCheckingAuth => _isCheckingAuth;
  bool get isProfileVerified => _profileVerified;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  bool get isAuthenticated => _currentUser != null;
  bool get isPatient => _currentUser?.isPatient ?? false;
  String? get userRole => _currentUser?.rolNombre?.toLowerCase();

  Future<void> _saveTenantFromProfile(UserModel user) async {
    final tenantId = user.tenantId;
    if (tenantId != null && tenantId.isNotEmpty) {
      await _storageService.saveTenantId(tenantId);
    } else {
      await _storageService.clearTenantId();
    }
  }

  bool get canAccessReports {
    return _profileVerified && _reportsAuthorized && eligibleForReports(_currentUser);
  }
  static bool eligibleForReports(UserEntity? user) {
    if (user == null || user.idClinica == null ||
        user.estado?.toLowerCase() != 'activo') return false;
    final role = (user.rolNombre ?? '').trim().toUpperCase()
        .replaceAll('Ó', 'O').replaceAll('Á', 'A');
    return const {'ADMIN', 'ADMINISTRADOR', 'ADMINISTRACION'}.contains(role);
  }
  String? get reportsAccountKey => canAccessReports
      ? '${_currentUser!.idUsuario}:${_currentUser!.idClinica}' : null;

  Future<void> verifyReportsAccess() async {
    final epoch = _sessionEpoch;
    final check = ++_reportsCheckEpoch;
    _reportsAuthorized = false;
    notifyListeners();
    if (!_profileVerified || !eligibleForReports(_currentUser)) {
      return;
    }
    try {
      await ApiClient().get(ApiConfig.reportCatalogUrl);
      if (epoch != _sessionEpoch || check != _reportsCheckEpoch) return;
      _reportsAuthorized = true;
    } on UnauthorizedException {
      if (epoch != _sessionEpoch || check != _reportsCheckEpoch) return;
      await handleReportsUnauthorized();
      return;
    } catch (_) {
      if (epoch != _sessionEpoch || check != _reportsCheckEpoch) return;
      _reportsAuthorized = false;
    }
    notifyListeners();
  }

  void denyReportsAccess() {
    ++_reportsCheckEpoch;
    _reportsAuthorized = false;
    notifyListeners();
  }

  // A 401 from analytics alone does not establish that the whole session ended.
  Future<void> handleReportsUnauthorized() async {
    final epoch = _sessionEpoch;
    denyReportsAccess();
    try {
      final user = await _remoteDataSource.getMe();
      if (epoch != _sessionEpoch) return;
      _currentUser = user;
      _profileVerified = true;
      notifyListeners();
    } on UnauthorizedException {
      if (epoch == _sessionEpoch) await logout();
    } catch (_) {
      // Keep the established session; reports remain unavailable until retried.
    }
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  void setSuccessMessage(String msg) {
    _successMessage = msg;
    _errorMessage = null;
    notifyListeners();
  }

  void setErrorMessage(String msg) {
    _errorMessage = msg;
    _successMessage = null;
    notifyListeners();
  }

  // Check saved session on app launch
  Future<bool> checkAuthStatus() async {
    if (_isLoggingOut) return false;
    final epoch = ++_sessionEpoch;
    ++_reportsCheckEpoch;
    _profileVerified = false;
    _reportsAuthorized = false;
    _isCheckingAuth = true;
    notifyListeners();

    try {
      final hasSessionToken = ApiClient().hasSessionAccessToken;
      final token = hasSessionToken ? null : await _storageService.getAccessToken();
      if (epoch != _sessionEpoch) return false;
      if (!hasSessionToken && (token == null || token.isEmpty)) {
        await _storageService.clearSession();
        if (epoch != _sessionEpoch) return false;
        ApiClient().setSessionAccessToken(null);
        _currentUser = null;
        _isCheckingAuth = false;
        notifyListeners();
        return false;
      }
      if (token != null && token.isNotEmpty) {
        ApiClient().setSessionAccessToken(token);
      }

      // Try reading locally cached user first for faster load
      final cachedUser = hasSessionToken ? null : await _storageService.getUser();
      if (epoch != _sessionEpoch) return false;
      if (cachedUser != null) {
        _currentUser = UserModel.fromJson(cachedUser);
        notifyListeners();
      }

      // Verify token with backend
      try {
        final user = await _remoteDataSource.getMe();
        if (epoch != _sessionEpoch) return false;
        _currentUser = user;
        _profileVerified = true;
        await _saveTenantFromProfile(user);
        if (!hasSessionToken && await _storageService.getRememberMe()) {
          if (epoch != _sessionEpoch) return false;
          await _storageService.saveUser(user.toJson());
        }
        if (epoch != _sessionEpoch) return false;
        unawaited(verifyReportsAccess());
      } catch (e) {
        if (epoch != _sessionEpoch) return false;
        // If 401, session is invalid
        if (e is UnauthorizedException) {
          await _storageService.clearSession();
          if (epoch != _sessionEpoch) return false;
          ApiClient().setSessionAccessToken(null);
          _currentUser = null;
          _profileVerified = false;
          _reportsAuthorized = false;
          _isCheckingAuth = false;
          notifyListeners();
          return false;
        }
      }

      _isCheckingAuth = false;
      notifyListeners();
      return _currentUser != null;
    } catch (_) {
      ApiClient().clearSessionAccessToken();
      if (epoch != _sessionEpoch) return false;
      _currentUser = null;
      _profileVerified = false;
      _reportsAuthorized = false;
      _isCheckingAuth = false;
      notifyListeners();
      return false;
    }
  }

  // Login
  Future<bool> login(String correo, String password, {bool rememberMe = true}) async {
    if (_isLoggingOut) return false;
    final epoch = ++_sessionEpoch;
    ++_reportsCheckEpoch;
    _currentUser = null;
    _profileVerified = false;
    _reportsAuthorized = false;
    _isLoading = true;
    _isCheckingAuth = false;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      ApiClient().setSessionAccessToken(null);
      await _storageService.clearSession();
      if (epoch != _sessionEpoch) return false;
      final request = LoginRequest(correo: correo, password: password);
      final tokenResponse = await _remoteDataSource.login(request);
      if (tokenResponse.accessToken.isEmpty) {
        throw const FormatException(
          'El backend no devolvió un token de acceso',
        );
      }
      if (epoch != _sessionEpoch) return false;
      ApiClient().setSessionAccessToken(tokenResponse.accessToken);

      // Guardar tokens siempre para mantener la sesión HTTP activa
      await _storageService.saveTokens(
        accessToken: tokenResponse.accessToken,
        refreshToken: tokenResponse.refreshToken,
      );
      if (epoch != _sessionEpoch) return false;
      await _storageService.setRememberMe(rememberMe);
      if (epoch != _sessionEpoch) return false;

      if (tokenResponse.tenantId != null && tokenResponse.tenantId!.isNotEmpty) {
        await _storageService.saveTenantId(tokenResponse.tenantId!);
        if (epoch != _sessionEpoch) return false;
      }

      // Obtener datos del usuario en sesión
      final user = await _remoteDataSource.getMe();
      if (epoch != _sessionEpoch) return false;
      _currentUser = user;
      _profileVerified = true;
      await _saveTenantFromProfile(user);

      // Si el login no trajo tenant_id, derivarlo de id_clinica o tenant_id de /auth/me
      final currentTenant = await _storageService.getTenantId();
      if (user.idClinica != null) {
        await _storageService.saveTenantId(user.idClinica.toString());
      } else if (currentTenant == null || currentTenant.isEmpty) {
        await _storageService.saveTenantId('1');
      }
      if (epoch != _sessionEpoch) return false;
      if (rememberMe) {
        await _storageService.saveUser(user.toJson());
      }
      if (epoch != _sessionEpoch) return false;
      unawaited(verifyReportsAccess());
      // CU19: registra el token FCM del móvil tras iniciar sesión.
      unawaited(PushService.instance.registerCurrentToken());

      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      if (epoch != _sessionEpoch) return false;
      ApiClient().setSessionAccessToken(null);
      await _storageService.clearSession();
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      if (epoch != _sessionEpoch) return false;
      ApiClient().setSessionAccessToken(null);
      await _storageService.clearSession();
      _errorMessage = 'Ocurrió un error inesperado al iniciar sesión.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Register
  Future<bool> register({
    required String nombres,
    required String apellidos,
    required String correo,
    required String password,
    String? telefono,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final request = RegisterRequest(
        nombres: nombres,
        apellidos: apellidos,
        correo: correo,
        password: password,
        telefono: telefono,
      );

      await _remoteDataSource.register(request);

      _isLoading = false;
      _successMessage =
          '¡Cuenta creada con éxito! Por favor inicia sesión para continuar.';
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      print(e);
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Forgot Password
  Future<bool> forgotPassword(String correo, {String canal = 'email'}) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final request = ForgotPasswordRequest(correo: correo, canal: canal);
      final response = await _remoteDataSource.forgotPassword(request);

      _isLoading = false;
      final detail = response.detail;
      if (response.debugCode != null) {
        _successMessage = '$detail (Código dev: ${response.debugCode})';
      } else {
        _successMessage = detail;
      }
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      print(e);
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Reset Password
  Future<bool> resetPassword(
    String correo,
    String codigo,
    String nuevaPassword,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final request = ResetPasswordRequest(
        correo: correo,
        codigo: codigo,
        nuevaPassword: nuevaPassword,
      );
      await _remoteDataSource.resetPassword(request);

      _isLoading = false;
      _successMessage =
          'Contraseña restablecida exitosamente. Por favor inicia sesión.';
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage =
          'Ocurrió un error inesperado al restablecer la contraseña.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    if (_isLoggingOut) return;
    _isLoggingOut = true;
    _inactivityService.stop();
    ++_sessionEpoch;
    ++_reportsCheckEpoch;
    _currentUser = null;
    _profileVerified = false;
    _reportsAuthorized = false;
    _isLoading = false;
    _isCheckingAuth = false;
    notifyListeners();
    try {
      // CU19: desactiva el dispositivo antes de invalidar la sesión.
      try {
        await PushService.instance.unregisterDevice();
      } catch (_) {
        // El cierre de sesión debe continuar aunque falle la revocación push.
      }
      final refreshToken = await _storageService.getRefreshToken();
      await _remoteDataSource.logout(refreshToken);
    } catch (_) {
      // Best-effort remote token invalidation
    } finally {
      ApiClient().setSessionAccessToken(null);
      try {
        await _storageService.clearSession();
      } catch (_) {
        // Still finish local logout if storage is unavailable.
      }
      _currentUser = null;
      _errorMessage = null;
      _successMessage = null;
      _isLoggingOut = false;
      notifyListeners();
    }
  }

  /// Inicia el control de inactividad tras un login correcto (CU23).
  void startInactivityControl() => _inactivityService.start();

  /// Reconcilia el reloj de inactividad contra el servidor (CU23).
  Future<void> syncInactivityWithServer() =>
      _inactivityService.syncWithServer();

  /// Renueva la sesion en el servidor desde el aviso de inactividad (CU23).
  Future<void> continueSession() => _inactivityService.continueSession();

  /// Cuenta regresiva del aviso, en segundos. `null` si no hay aviso activo.
  Stream<int> get inactivityWarning => _inactivityService.warningSeconds;

  /// Emite cuando la sesion se cierra por inactividad (CU23).
  Stream<void> get sessionExpired => _inactivityService.expired;

  @override
  void dispose() {
    _inactivityService.dispose();
    super.dispose();
  }
}
