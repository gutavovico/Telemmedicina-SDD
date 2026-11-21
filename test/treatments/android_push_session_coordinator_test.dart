import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_telemedicina/features/treatments/data/services/device_registration_service.dart';
import 'package:mobile_telemedicina/features/treatments/presentation/session/android_push_session_coordinator.dart';

class FakePushTokenSource implements PushTokenSource {
  final events = StreamController<String>.broadcast(sync: true);
  final registered = Completer<void>();
  int registerCalls = 0;
  int unregisterCalls = 0;
  bool permission = true;
  String? installationId;

  @override
  Stream<String> get onRegistered => events.stream;

  @override
  Future<bool> requestPermission() async => permission;

  @override
  Future<void> register() async {
    registerCalls++;
    if (installationId != null) events.add(installationId!);
    if (!registered.isCompleted) registered.complete();
  }

  @override
  Future<void> unregister() async {
    unregisterCalls++;
  }

  void rotate(String id) => events.add(id);

  Future<void> dispose() => events.close();
}

class FakePushDevices extends DeviceRegistrationService {
  final ids = <String>[];
  final revoked = <int>[];
  final firstRegistration = Completer<void>();
  final secondRegistration = Completer<void>();

  @override
  Future<DeviceRegistrationResult> registrarDispositivo(
    String token, {
    String plataforma = 'ANDROID',
  }) async {
    ids.add(token);
    if (!firstRegistration.isCompleted) firstRegistration.complete();
    if (ids.length == 2 && !secondRegistration.isCompleted) {
      secondRegistration.complete();
    }
    return DeviceRegistrationResult.success(
      idDispositivo: ids.length,
      plataforma: plataforma,
    );
  }

  @override
  Future<bool> eliminarDispositivo(int idDispositivo) async {
    revoked.add(idDispositivo);
    return true;
  }
}

void main() {
  test(
    'registra FID solo para paciente verificado y lo revoca al salir',
    () async {
      final source = FakePushTokenSource()..installationId = 'fid-paciente';
      final devices = FakePushDevices();
      final coordinator = AndroidPushSessionCoordinator(
        tokenSource: source,
        devices: devices,
      );

      coordinator.syncSession(
        isPatient: true,
        isProfileVerified: false,
        userId: 5,
        clinicId: 2,
      );
      expect(source.registerCalls, 0);

      coordinator.syncSession(
        isPatient: true,
        isProfileVerified: true,
        userId: 5,
        clinicId: 2,
      );
      await devices.firstRegistration.future;
      await coordinator.beforeLogout();

      expect(devices.ids, ['fid-paciente']);
      expect(devices.revoked, [1]);
      expect(source.unregisterCalls, 1);
      coordinator.dispose();
      await source.dispose();
    },
  );

  test(
    'no solicita push cuando la preferencia del paciente está apagada',
    () async {
      final source = FakePushTokenSource()..installationId = 'fid-inactivo';
      final devices = FakePushDevices();
      final coordinator = AndroidPushSessionCoordinator(
        tokenSource: source,
        devices: devices,
      );

      coordinator.syncSession(
        isPatient: false,
        isProfileVerified: true,
        userId: 5,
        clinicId: 2,
      );
      await coordinator.beforeLogout();

      expect(source.registerCalls, 0);
      expect(devices.ids, isEmpty);
      coordinator.dispose();
      await source.dispose();
    },
  );

  test('la rotación registra el FID nuevo y revoca el anterior', () async {
    final source = FakePushTokenSource()..installationId = 'fid-inicial';
    final devices = FakePushDevices();
    final coordinator = AndroidPushSessionCoordinator(
      tokenSource: source,
      devices: devices,
    );

    coordinator.syncSession(
      isPatient: true,
      isProfileVerified: true,
      userId: 5,
      clinicId: 2,
    );
    await devices.firstRegistration.future;
    source.rotate('fid-rotado');
    await devices.secondRegistration.future;
    await Future<void>.delayed(Duration.zero);
    await coordinator.beforeLogout();

    expect(devices.ids, ['fid-inicial', 'fid-rotado']);
    expect(devices.revoked, [1, 2]);
    coordinator.dispose();
    await source.dispose();
  });

  test('al cambiar de cuenta revoca la instalación anterior', () async {
    final source = FakePushTokenSource()..installationId = 'fid-cuenta-a';
    final devices = FakePushDevices();
    final coordinator = AndroidPushSessionCoordinator(
      tokenSource: source,
      devices: devices,
    );

    coordinator.syncSession(
      isPatient: true,
      isProfileVerified: true,
      userId: 5,
      clinicId: 2,
    );
    await devices.firstRegistration.future;
    source.installationId = 'fid-cuenta-b';
    coordinator.syncSession(
      isPatient: true,
      isProfileVerified: true,
      userId: 8,
      clinicId: 3,
    );
    await devices.secondRegistration.future;
    await coordinator.beforeLogout();

    expect(devices.ids, ['fid-cuenta-a', 'fid-cuenta-b']);
    expect(devices.revoked, [1, 2]);
    expect(source.unregisterCalls, 2);
    coordinator.dispose();
    await source.dispose();
  });
}
