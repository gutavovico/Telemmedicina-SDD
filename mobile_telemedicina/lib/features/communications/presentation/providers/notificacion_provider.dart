import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/utils/dispositivo_helper.dart';
import '../../data/datasources/notificacion_remote_datasource.dart';
import '../../data/models/notificacion_model.dart';
import '../../data/services/fcm_adapter.dart';
import '../../data/services/local_headsup_notification_service.dart';

/// Provider reactivo para CU20: Bandeja de Notificaciones, contador para la campana,
/// polling en tiempo real y alertas emergentes (tipo WhatsApp) nativas e in-app.
class NotificacionProvider extends ChangeNotifier {
  final NotificacionRemoteDataSource _dataSource;
  final FcmAdapter _fcmAdapter;
  final LocalHeadsUpNotificationService _localNotifications;
  final bool _habilitarPolling;
  final Duration _duracionBanner;

  NotificacionProvider({
    NotificacionRemoteDataSource? dataSource,
    FcmAdapter? fcmAdapter,
    LocalHeadsUpNotificationService? localNotifications,
    bool habilitarPolling = true,
    Duration duracionBanner = const Duration(seconds: 5),
  })  : _dataSource = dataSource ?? NotificacionRemoteDataSource(),
        _fcmAdapter = fcmAdapter ?? SafeFallbackFcmAdapter(),
        _localNotifications =
            localNotifications ?? LocalHeadsUpNotificationService.instance,
        _habilitarPolling = habilitarPolling,
        _duracionBanner = duracionBanner;

  List<NotificacionModel> _notificaciones = const [];
  int _conteoNoLeidas = 0;
  bool _cargando = false;
  String? _error;
  String _categoriaActiva = 'TODAS';
  bool _inicializado = false;
  bool _sesionAutenticada = false;
  bool _semillaInicialCargada = false;
  bool _consultandoPolling = false;
  final Set<int> _idsYaNotificados = <int>{};

  NotificacionMensajePush? _bannerActivo;
  Timer? _bannerAutoDismissTimer;
  Timer? _pollingTimer;
  StreamSubscription<String>? _subToken;
  StreamSubscription<NotificacionMensajePush>? _subForeground;
  StreamSubscription<NotificacionMensajePush>? _subOpened;

  List<NotificacionModel> get notificaciones => _notificaciones;
  int get conteoNoLeidas => _conteoNoLeidas;
  bool get cargando => _cargando;
  String? get error => _error;
  String get categoriaActiva => _categoriaActiva;
  NotificacionMensajePush? get bannerActivo => _bannerActivo;
  FcmAdapter get fcmAdapter => _fcmAdapter;

  List<NotificacionModel> get notificacionesFiltradas {
    if (_categoriaActiva == 'TODAS') return _notificaciones;
    return _notificaciones
        .where((n) => n.categoria.toUpperCase() == _categoriaActiva)
        .toList();
  }

  /// Sincroniza el ciclo de vida de notificaciones con AuthController.
  void sincronizarSesion({required bool isAuthenticated}) {
    if (_sesionAutenticada == isAuthenticated) return;
    _sesionAutenticada = isAuthenticated;
    if (isAuthenticated) {
      unawaited(inicializarPush());
      unawaited(refrescarConteoNoLeidas());
      if (_habilitarPolling) {
        _iniciarPollingTiempoReal();
      }
    } else {
      _detenerPollingTiempoReal();
      _bannerAutoDismissTimer?.cancel();
      _bannerAutoDismissTimer = null;
      _semillaInicialCargada = false;
      _idsYaNotificados.clear();
      unawaited(revocarDispositivoActual());
      _notificaciones = const [];
      _conteoNoLeidas = 0;
      _bannerActivo = null;
      _error = null;
      notifyListeners();
    }
  }

  Future<void> inicializarPush() async {
    if (_inicializado) return;
    _inicializado = true;
    try {
      await _localNotifications.inicializar();
      await _fcmAdapter.requestPermission();
      final token = await _fcmAdapter.obtenerToken();
      if (token != null && token.isNotEmpty) {
        final dispId = await DispositivoHelper.obtenerDispositivoId();
        await _dataSource.registrarDispositivo(
          dispositivoId: dispId,
          pushToken: token,
        );
      }

      _subToken = _fcmAdapter.onTokenRefresh.listen((nuevoToken) async {
        if (nuevoToken.trim().isEmpty) return;
        final dispId = await DispositivoHelper.obtenerDispositivoId();
        try {
          await _dataSource.registrarDispositivo(
            dispositivoId: dispId,
            pushToken: nuevoToken.trim(),
          );
        } catch (_) {}
      });

      _subForeground = _fcmAdapter.onMessage.listen((msg) {
        mostrarBannerInApp(msg);
        unawaited(refrescarConteoNoLeidas());
      });

      _subOpened = _fcmAdapter.onMessageOpenedApp.listen((msg) {
        mostrarBannerInApp(msg);
      });
    } catch (_) {
      // Operación resiliente: nunca bloquea ni requiere instalaciones externas
    }
  }

  void _iniciarPollingTiempoReal() {
    _detenerPollingTiempoReal();
    unawaited(verificarNuevasNotificaciones());
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      unawaited(verificarNuevasNotificaciones());
    });
  }

  void _detenerPollingTiempoReal() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// Consulta nuevas notificaciones no leídas y dispara alertas emergentes tipo WhatsApp.
  Future<void> verificarNuevasNotificaciones() async {
    if (!_sesionAutenticada || _consultandoPolling) return;
    _consultandoPolling = true;
    try {
      final noLeidas = await _dataSource.obtenerBandeja(
        soloNoLeidas: true,
        limite: 20,
      );
      if (!_sesionAutenticada) return;

      // Primera carga: registrar las existentes sin inundar de alertas viejas
      if (!_semillaInicialCargada) {
        for (final n in noLeidas) {
          _idsYaNotificados.add(n.id);
        }
        _semillaInicialCargada = true;
        if (_conteoNoLeidas != noLeidas.length) {
          _conteoNoLeidas = noLeidas.length;
          notifyListeners();
        }
        return;
      }

      final nuevas = noLeidas
          .where((n) => !_idsYaNotificados.contains(n.id))
          .toList();

      if (nuevas.isNotEmpty) {
        for (final n in nuevas) {
          _idsYaNotificados.add(n.id);
        }

        // Incorporar nuevas al tope de la bandeja local si ya había sido cargada
        if (_notificaciones.isNotEmpty) {
          final existentesIds = _notificaciones.map((e) => e.id).toSet();
          final porAgregar =
              nuevas.where((n) => !existentesIds.contains(n.id)).toList();
          if (porAgregar.isNotEmpty) {
            _notificaciones = [...porAgregar, ..._notificaciones];
          }
        }

        _conteoNoLeidas = noLeidas.length;

        // Disparar alerta emergente nativa Android (heads-up tipo WhatsApp) + banner in-app auto-desaparecible
        for (final nueva in nuevas.reversed) {
          unawaited(_localNotifications.mostrarNotificacionEmergente(nueva));
          mostrarBannerInApp(
            NotificacionMensajePush(
              id: '${nueva.id}',
              titulo: nueva.titulo,
              cuerpo: nueva.mensaje,
              tipo: nueva.tipo,
              recursoTipo: nueva.recursoTipo,
              recursoId: nueva.recursoId,
              canalBadge: nueva.canalBadge,
              recibidaEn: nueva.creadaEn,
            ),
          );
        }
      } else if (_conteoNoLeidas != noLeidas.length) {
        _conteoNoLeidas = noLeidas.length;
        notifyListeners();
      }
    } catch (_) {
      // Silencioso en polling en segundo plano
    } finally {
      _consultandoPolling = false;
    }
  }

  /// Muestra un banner emergente superior estilo WhatsApp que desaparece automáticamente.
  void mostrarBannerInApp(NotificacionMensajePush mensaje) {
    _bannerAutoDismissTimer?.cancel();
    _bannerActivo = mensaje;
    notifyListeners();

    if (_duracionBanner > Duration.zero) {
      _bannerAutoDismissTimer = Timer(_duracionBanner, () {
        if (_bannerActivo?.id == mensaje.id) {
          descartarBannerInApp();
        }
      });
    }
  }

  void descartarBannerInApp() {
    _bannerAutoDismissTimer?.cancel();
    _bannerAutoDismissTimer = null;
    if (_bannerActivo == null) return;
    _bannerActivo = null;
    notifyListeners();
  }

  /// Permite cargar una lista local directamente (útil en tests o previsualización).
  void establecerNotificacionesLocales(List<NotificacionModel> lista) {
    _notificaciones = List<NotificacionModel>.from(lista);
    _conteoNoLeidas = _notificaciones.where((n) => !n.estaLeida).length;
    for (final n in _notificaciones) {
      _idsYaNotificados.add(n.id);
    }
    notifyListeners();
  }

  void cambiarCategoria(String categoria) {
    final norm = categoria.toUpperCase();
    if (_categoriaActiva == norm) return;
    _categoriaActiva = norm;
    notifyListeners();
  }

  Future<void> cargarBandeja({String? categoria}) async {
    if (categoria != null) {
      _categoriaActiva = categoria.toUpperCase();
    }
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final items = await _dataSource.obtenerBandeja(limite: 60);
      _notificaciones = items;
      _conteoNoLeidas = items.where((n) => !n.estaLeida).length;
      for (final n in items) {
        _idsYaNotificados.add(n.id);
      }
      _semillaInicialCargada = true;
    } catch (e) {
      _error = 'No se pudieron cargar las notificaciones.';
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<void> refrescarConteoNoLeidas() async {
    try {
      _conteoNoLeidas = await _dataSource.obtenerConteoNoLeidas();
      notifyListeners();
    } catch (_) {
      // Silencioso en refresco de badge
    }
  }

  Future<void> marcarLeida(int idNotificacion) async {
    final idx = _notificaciones.indexWhere((n) => n.id == idNotificacion);
    if (idx != -1 && !_notificaciones[idx].estaLeida) {
      final updated = List<NotificacionModel>.from(_notificaciones);
      updated[idx] = updated[idx].copyWith(
        leidaEn: DateTime.now(),
        estado: 'LEIDA',
      );
      _notificaciones = updated;
      _conteoNoLeidas = (_conteoNoLeidas - 1).clamp(0, 9999);
      notifyListeners();
    }

    try {
      await _dataSource.marcarLeida(idNotificacion);
    } catch (_) {
      // Se mantiene estado optimista si falla momentáneamente
    }
  }

  Future<void> marcarTodasLeidas() async {
    final ahora = DateTime.now();
    _notificaciones = _notificaciones
        .map((n) => n.estaLeida ? n : n.copyWith(leidaEn: ahora, estado: 'LEIDA'))
        .toList();
    _conteoNoLeidas = 0;
    notifyListeners();

    try {
      await _dataSource.marcarTodasLeidas();
    } catch (_) {}
  }

  Future<void> revocarDispositivoActual() async {
    try {
      final dispId = await DispositivoHelper.obtenerDispositivoId();
      await _dataSource.revocarDispositivo(dispId);
    } catch (_) {}
  }

  @override
  void dispose() {
    _detenerPollingTiempoReal();
    _bannerAutoDismissTimer?.cancel();
    _subToken?.cancel();
    _subForeground?.cancel();
    _subOpened?.cancel();
    unawaited(_fcmAdapter.dispose());
    super.dispose();
  }
}
