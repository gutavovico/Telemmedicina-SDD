import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/models/auth_models.dart';

/// Consulta el estado de inactividad al servidor.
typedef SessionStatusFetcher = Future<SessionStatusResponse> Function();

/// Renueva la sesion en el servidor ("Seguir conectado").
typedef SessionRenewer = Future<SessionStatusResponse> Function();

/// Borra las credenciales locales al cerrar la sesion.
typedef SessionCleaner = Future<void> Function();

/// Control de inactividad con aviso y cierre automatico de sesion (CU23).
///
/// El temporizador local es una aproximacion: cuando la app pasa a background
/// el sistema puede congelar los temporizadores, asi que al volver se reconcilia
/// el reloj contra el servidor en lugar de confiar solo en el contador propio.
/// El servidor sigue siendo la fuente de verdad.
///
/// Los tres colaboradores (consultar, renovar, limpiar) se pueden inyectar por
/// callback para poder probar la logica de temporizadores sin red ni
/// almacenamiento real.
class InactivityService with WidgetsBindingObserver {
  final AuthRemoteDataSource _remoteDataSource;
  final SecureStorageService _storageService;
  final SessionStatusFetcher? _fetchStatus;
  final SessionRenewer? _renewSession;
  final SessionCleaner? _clearSession;

  final StreamController<int> _warningController =
      StreamController<int>.broadcast();
  final StreamController<void> _expiredController =
      StreamController<void>.broadcast();

  Timer? _timer;
  Timer? _countdown;
  bool _started = false;
  bool _disposed = false;

  late int _windowMs = ApiConfig.inactivityTimeoutMinutes * 60 * 1000;
  int _warningMs = ApiConfig.inactivityWarningSeconds * 1000;
  int _remaining = 0;

  InactivityService({
    AuthRemoteDataSource? remoteDataSource,
    SecureStorageService? storageService,
    SessionStatusFetcher? fetchStatus,
    SessionRenewer? renewSession,
    SessionCleaner? clearSession,
  })  : _remoteDataSource = remoteDataSource ?? AuthRemoteDataSource(),
        _storageService = storageService ?? SecureStorageService(),
        _fetchStatus = fetchStatus,
        _renewSession = renewSession,
        _clearSession = clearSession;

  Future<SessionStatusResponse> _getStatus() =>
      _fetchStatus?.call() ?? _remoteDataSource.getSessionStatus();

  Future<SessionStatusResponse> _renew() =>
      _renewSession?.call() ?? _remoteDataSource.continueSession();

  Future<void> _clear() =>
      _clearSession?.call() ?? _storageService.clearSession();

  /// Segundos restantes; solo emite mientras hay aviso visible.
  Stream<int> get warningSeconds => _warningController.stream;

  /// Emite cuando la sesion se cierra por inactividad.
  Stream<void> get expired => _expiredController.stream;

  bool get isRunning => _started;

  void start() {
    if (_started || _disposed) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _schedule(_windowMs);
  }

  void stop() {
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    _clearTimer();
    _clearCountdown();
    _remaining = 0;
  }

  /// El usuario elige seguir conectado: renueva en el servidor y reinicia el
  /// reloj local. Si la red falla se conserva el contador local, porque la
  /// siguiente peticion autenticada vuelve a validar la inactividad igual.
  Future<void> continueSession() async {
    if (!_started) return;
    _restartLocalCountdown();
    try {
      final status = await _renew();
      if (!_started) return;
      if (status.segundosRestantes <= 0) {
        await _expire();
        return;
      }
      _windowMs = status.segundosRestantes * 1000;
      _warningMs = status.avisoSegundos * 1000;
      _schedule(_windowMs);
    } catch (_) {
      // Sin red: se mantiene el contador local.
    }
  }

  /// Reconcilia el reloj local con el del servidor (CU23).
  ///
  /// Consultar el estado NO renueva la sesion; por eso solo se llama al volver
  /// del background o recuperar el foco, no de forma periodica.
  Future<void> syncWithServer() async {
    if (!_started) return;
    try {
      final status = await _getStatus();
      if (!_started) return;
      if (status.segundosRestantes <= 0) {
        await _expire();
        return;
      }
      _windowMs = status.segundosRestantes * 1000;
      _warningMs = status.avisoSegundos * 1000;
      _schedule(_windowMs);
    } catch (_) {
      // Fallo de red: no se cierra una sesion valida por un error de conexion.
    }
  }

  /// Registra actividad del usuario y reinicia el reloj local.
  void registerActivity() {
    if (!_started) return;
    _restartLocalCountdown();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_started) return;
    if (state == AppLifecycleState.resumed) {
      // Al volver del background el temporizador local puede estar desfasado.
      syncWithServer();
    }
  }

  void _schedule(int ms) {
    _clearTimer();
    _timer = Timer(
      Duration(milliseconds: (ms - _warningMs).clamp(0, ms)),
      () => _beginWarning(ms),
    );
  }

  void _beginWarning(int ms) {
    _clearTimer();
    if (_disposed) return;

    // Si al reconciliar ya estabamos dentro de la ventana de aviso, el aviso
    // aparece de inmediato; si no, cuenta desde el margen configurado.
    var restante = (ms < _warningMs ? ms : _warningMs) ~/ 1000;
    _remaining = restante;
    if (!_warningController.isClosed) _warningController.add(restante);

    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed) return;
      restante -= 1;
      _remaining = restante > 0 ? restante : 0;
      if (!_warningController.isClosed) _warningController.add(_remaining);
      if (restante <= 0) {
        _expire();
      }
    });
  }

  Future<void> _expire() async {
    if (!_started) return;
    stop();
    // El cierre por inactividad es local: el backend ya habra revocado el `jti`
    // cuando expire su ventana, asi que no se le notica (enviar un logout
    // global incrementaria `token_version` y cerraria las demas sesiones del
    // usuario, que es justo lo que NO se quiere aqui).
    await _clear();
    if (!_expiredController.isClosed) _expiredController.add(null);
  }

  void _restartLocalCountdown() {
    _clearCountdown();
    _schedule(_windowMs);
  }

  void _clearTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _clearCountdown() {
    _countdown?.cancel();
    _countdown = null;
  }

  void dispose() {
    _disposed = true;
    stop();
    _warningController.close();
    _expiredController.close();
  }
}
