import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_telemedicina/features/auth/data/models/auth_models.dart';
import 'package:mobile_telemedicina/features/auth/domain/services/inactivity_service.dart';

/// Pruebas del control de inactividad en movil (CU23).
///
/// Se usa `FakeAsync` para avanzar el reloj sin esperar de verdad, y se inyectan
/// los colaboradores por callback para no tocar red ni `FlutterSecureStorage`.
///
/// No se usa `flushTimers()` a proposito: tambien ejecuta los timers periodicos
/// hasta agotarlos, lo que cerraria la sesion en pruebas donde no debe. El
/// tiempo se avanza con `elapse`, que respeta el orden de los temporizadores.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const ventanaMin = 15; // minutos de ventana de inactividad
  const aviso = 60; // segundos de aviso

  late List<int> warnings;
  late bool expirado;
  late int limpiezas;
  late List<String> llamadas;

  setUp(() {
    warnings = <int>[];
    expirado = false;
    limpiezas = 0;
    llamadas = <String>[];
  });

  InactivityService build({int? statusRestantes, bool fallo = false}) {
    return InactivityService(
      fetchStatus: () async {
        llamadas.add('status');
        if (fallo) throw Exception('sin red');
        return SessionStatusResponse(
          segundosRestantes: statusRestantes ?? ventanaMin * 60,
          ventanaSegundos: ventanaMin * 60,
          avisoSegundos: aviso,
        );
      },
      renewSession: () async {
        llamadas.add('renew');
        return SessionStatusResponse(
          segundosRestantes: ventanaMin * 60,
          ventanaSegundos: ventanaMin * 60,
          avisoSegundos: aviso,
        );
      },
      clearSession: () async {
        llamadas.add('clear');
        limpiezas++;
      },
    );
  }

  test('el aviso aparece antes de expirar y agota la cuenta atras', () {
    FakeAsync().run((f) {
      final service = build();
      service.warningSeconds.listen(warnings.add);
      service.expired.listen((_) => expirado = true);

      service.start();
      // Con 13 min todavia no hay aviso: la ventana son 15 y el aviso 60 s.
      f.elapse(const Duration(minutes: 13));
      expect(warnings, isEmpty);

      // El aviso arranca a los 14 min exactos (15 min - 60 s) mostrando 60 s.
      f.elapse(const Duration(minutes: 1));
      expect(warnings.first, aviso);
      expect(expirado, isFalse);

      // La cuenta atras va bajando de a un segundo.
      f.elapse(const Duration(seconds: 59));
      expect(warnings, contains(1));
      expect(expirado, isFalse);

      // Agotada la cuenta, la sesion se cierra.
      f.elapse(const Duration(seconds: 1));
      expect(warnings.last, 0);
      expect(expirado, isTrue);
      service.dispose();
    });
  });

  test('expirar limpia las credenciales locales', () {
    FakeAsync().run((f) {
      final service = build();
      service.expired.listen((_) => expirado = true);

      service.start();
      f.elapse(const Duration(minutes: 15));
      f.flushMicrotasks();

      expect(limpiezas, 1);
      expect(llamadas, contains('clear'));
      service.dispose();
    });
  });

  test('continuar renueva en el servidor y retrasa el cierre', () {
    FakeAsync().run((f) {
      final service = build();
      service.expired.listen((_) => expirado = true);

      service.start();
      // 13 min dentro del aviso, todavia sin avisos.
      f.elapse(const Duration(minutes: 13));
      expect(warnings, isEmpty);

      service.continueSession();
      f.flushMicrotasks();

      // Renovacion real en el servidor, no solo un reinicio local.
      expect(llamadas, contains('renew'));

      f.elapse(const Duration(minutes: 13));
      f.flushMicrotasks();
      expect(expirado, isFalse);
      expect(limpiezas, 0);
      service.dispose();
    });
  });

  test('reconcilia el reloj con el servidor en lugar de confiar en el local', () {
    FakeAsync().run((f) {
      // El servidor dice que solo quedan 120 s: sin reconciliar, el aviso
      // tardaria 14 min en aparecer.
      final service = build(statusRestantes: 120);
      service.warningSeconds.listen(warnings.add);

      service.start();
      service.syncWithServer();
      f.flushMicrotasks();

      f.elapse(const Duration(seconds: 60));
      expect(llamadas, contains('status'));
      expect(warnings, isNotEmpty);
      expect(warnings.first, aviso);
      service.dispose();
    });
  });

  test('expira si el servidor reporta cero segundos', () {
    FakeAsync().run((f) {
      final service = build(statusRestantes: 0);
      service.expired.listen((_) => expirado = true);

      service.start();
      service.syncWithServer();
      f.flushMicrotasks();
      f.flushMicrotasks();

      expect(expirado, isTrue);
      expect(limpiezas, 1);
      service.dispose();
    });
  });

  test('un fallo de red no cierra una sesion valida', () {
    FakeAsync().run((f) {
      final service = build(fallo: true);
      service.expired.listen((_) => expirado = true);

      service.start();
      service.syncWithServer();
      f.flushMicrotasks();
      f.elapse(const Duration(minutes: 5));

      expect(expirado, isFalse);
      expect(limpiezas, 0);
      service.dispose();
    });
  });

  test('registrar actividad reinicia el reloj local', () {
    FakeAsync().run((f) {
      final service = build();
      service.expired.listen((_) => expirado = true);

      service.start();
      f.elapse(const Duration(minutes: 10));

      // Sin actividad, 10 min mas cerrarian la sesion (15 min en total).
      service.registerActivity();
      f.elapse(const Duration(minutes: 10));

      expect(expirado, isFalse);
      expect(limpiezas, 0);
      service.dispose();
    });
  });

  test('stop detiene el temporizador', () {
    FakeAsync().run((f) {
      final service = build();
      service.expired.listen((_) => expirado = true);

      service.start();
      service.stop();
      f.elapse(const Duration(minutes: 30));

      expect(expirado, isFalse);
      expect(limpiezas, 0);
      service.dispose();
    });
  });

  group('ForgotPasswordRequest', () {
    test('incluye el canal elegido', () {
      expect(
        ForgotPasswordRequest(correo: 'a@b.com').toJson(),
        containsPair('canal', 'email'),
      );
      expect(
        ForgotPasswordRequest(correo: 'a@b.com', canal: 'sms').toJson(),
        containsPair('canal', 'sms'),
      );
    });
  });
}
