import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

import '../../data/services/device_registration_service.dart';

abstract class PushTokenSource {
  Future<bool> requestPermission();
  Future<void> register();
  Future<void> unregister();
  Stream<String> get onRegistered;
}

class FirebaseAndroidPushTokenSource implements PushTokenSource {
  final FirebaseMessaging _messaging;

  FirebaseAndroidPushTokenSource({FirebaseMessaging? messaging})
    : _messaging = messaging ?? FirebaseMessaging.instance;

  @override
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<void> register() => _messaging.register();

  @override
  Future<void> unregister() => _messaging.unregister();

  @override
  Stream<String> get onRegistered => _messaging.onRegistered;
}

/// Vincula un token FCM únicamente a la sesión paciente verificada.
class AndroidPushSessionCoordinator {
  final PushTokenSource? _tokenSource;
  final DeviceRegistrationService _devices;
  String? _identity;
  String? _lastToken;
  int? _registeredDeviceId;
  int _generation = 0;
  Future<void> _transition = Future<void>.value();
  Future<void> _registration = Future<void>.value();
  StreamSubscription<String>? _tokenSubscription;
  bool _disposed = false;

  AndroidPushSessionCoordinator({
    PushTokenSource? tokenSource,
    DeviceRegistrationService? devices,
  }) : _tokenSource = tokenSource,
       _devices = devices ?? DeviceRegistrationService();

  void syncSession({
    required bool isPatient,
    required bool isProfileVerified,
    int? userId,
    int? clinicId,
  }) {
    final source = _tokenSource;
    if (_disposed || source == null) return;
    final next =
        isPatient && isProfileVerified && userId != null && clinicId != null
        ? '$userId:$clinicId'
        : null;
    if (_identity == next) return;

    final previous = _identity;
    _identity = next;
    final generation = ++_generation;
    _transition = _transition.catchError((Object _) {}).then((_) async {
      await _tokenSubscription?.cancel();
      _tokenSubscription = null;
      await _registration.catchError((Object _) {});

      if (previous != null) {
        final oldId = _registeredDeviceId;
        _registeredDeviceId = null;
        _lastToken = null;
        if (oldId != null) {
          await _devices.eliminarDispositivo(oldId);
        }
        try {
          await source.unregister();
        } catch (_) {
          // La revocación en el backend ya se intentó; no bloquear el logout.
        }
      }

      if (_disposed || next == null || generation != _generation) return;
      try {
        if (!await source.requestPermission()) return;
        if (_disposed || generation != _generation) return;
        _tokenSubscription = source.onRegistered.listen(
          (token) => _registerToken(token, generation),
        );
        await source.register();
      } catch (_) {
        // La bandeja de avisos y el registro de dosis siguen disponibles.
      }
    });
    unawaited(_transition.catchError((Object _) {}));
  }

  void _registerToken(String token, int generation) {
    if (token.trim().isEmpty) return;
    _registration = _registration.catchError((Object _) {}).then((_) async {
      if (_disposed || generation != _generation || _lastToken == token) return;
      final result = await _devices.registrarDispositivo(token);
      if (!result.success || result.idDispositivo == null) return;
      if (_disposed || generation != _generation) {
        await _devices.eliminarDispositivo(result.idDispositivo!);
        return;
      }
      final oldId = _registeredDeviceId;
      _registeredDeviceId = result.idDispositivo;
      _lastToken = token;
      if (oldId != null && oldId != _registeredDeviceId) {
        await _devices.eliminarDispositivo(oldId);
      }
    });
    unawaited(_registration.catchError((Object _) {}));
  }

  /// Se espera antes de borrar la credencial HTTP del usuario.
  Future<void> beforeLogout() async {
    syncSession(isPatient: false, isProfileVerified: false);
    await _transition;
  }

  void dispose() {
    _disposed = true;
    ++_generation;
    unawaited(_tokenSubscription?.cancel() ?? Future<void>.value());
  }
}
