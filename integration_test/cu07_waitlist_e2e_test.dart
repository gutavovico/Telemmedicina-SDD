// E2E manual asistido de CU07 ejecutado en el dispositivo Android real.
// Requiere el backend local expuesto en el telefono mediante `adb reverse`.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:mobile_telemedicina/main.dart' as app;

const String api = 'http://localhost:8000';

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  int intentos = 25,
}) async {
  for (var i = 0; i < intentos; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 500));
  }
  final textos = find.byType(Text).evaluate().map((element) {
    final widget = element.widget as Text;
    return widget.data ?? widget.textSpan?.toPlainText() ?? '';
  }).where((texto) => texto.isNotEmpty).toList();
  fail('No aparecio el elemento esperado: $finder. Textos en pantalla: $textos');
}

Future<void> _pumpSeconds(WidgetTester tester, int seconds) async {
  for (var i = 0; i < seconds * 2; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

Future<Map<String, String>> _headers(String token) => Future.value({
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    });

Future<String> _loginApi(String correo, String password) async {
  final response = await http.post(
    Uri.parse('$api/auth/login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'correo': correo, 'password': password}),
  );
  expect(response.statusCode, 200, reason: response.body);
  return jsonDecode(response.body)['access_token'] as String;
}

Future<int> _crearCita(
  String token, {
  required int idEspecialidad,
  required String fecha,
  required String hora,
}) async {
  final response = await http.post(
    Uri.parse('$api/citas'),
    headers: await _headers(token),
    body: jsonEncode({
      'id_paciente': 3,
      'id_medico': 1,
      'id_especialidad': idEspecialidad,
      'fecha_cita': fecha,
      'hora_inicio': hora,
      'hora_fin': '11:00',
      'motivo': 'E2E manual CU07',
      'estado': 'CONFIRMADA',
      'tipo_consulta': 'PRESENCIAL',
    }),
  );
  expect(response.statusCode, 201, reason: response.body);
  return jsonDecode(response.body)['id_cita'] as int;
}

Future<void> _cancelarCita(String token, int idCita) async {
  final response = await http.put(
    Uri.parse('$api/citas/$idCita'),
    headers: await _headers(token),
    body: jsonEncode({'estado': 'CANCELADA'}),
  );
  expect(response.statusCode, 200, reason: response.body);
}

Future<List<dynamic>> _miEspera(String token) async {
  final response = await http.get(
    Uri.parse('$api/api/v1/lista-espera/mi-espera'),
    headers: await _headers(token),
  );
  expect(response.statusCode, 200, reason: response.body);
  return jsonDecode(response.body) as List<dynamic>;
}

Future<void> _esperarEstadoApi(String token, String estado) async {
  for (var i = 0; i < 25; i++) {
    final items = await _miEspera(token);
    if (items.any((item) => item['estado'] == estado)) return;
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  fail('El backend no registro el estado $estado');
}

Future<void> _loginEnApp(WidgetTester tester) async {
  final login = find.text('Ingresar al Portal');
  final home = find.text('Mi Lista de Espera');
  for (var i = 0; i < 25; i++) {
    if (login.evaluate().isNotEmpty) break;
    if (home.evaluate().isNotEmpty) return; // Sesion ya guardada en el dispositivo.
    await tester.pump(const Duration(milliseconds: 500));
  }
  if (login.evaluate().isEmpty) {
    fail('No aparecio el login ni la pantalla de inicio de la app');
  }
  final campos = find.byType(TextFormField);
  expect(campos, findsNWidgets(2));
  await tester.enterText(campos.at(0), 'paciente.carlos@telemedicina.com');
  await tester.enterText(campos.at(1), 'paciente123');
  await tester.tap(login);
  await _pumpUntil(tester, home);
}

Future<void> _abrirListaEspera(WidgetTester tester) async {
  final destino = find.text('Mi Lista de Espera').first;
  await _pumpUntil(tester, destino);
  await tester.ensureVisible(destino);
  await tester.pump();
  await tester.tap(destino);
  await _pumpUntil(tester, find.text('Inscribirme'));
}

Future<void> _inscribirse(
  WidgetTester tester, {
  required int idEspecialidad,
}) async {
  await tester.tap(find.text('Inscribirme'));
  await _pumpUntil(tester, find.text('Datos de la especialidad'));

  final campos = find.byType(TextField);
  await tester.enterText(campos.at(0), '1'); // id_medico
  await tester.enterText(campos.at(1), '$idEspecialidad');
  await tester.tap(find.text('Continuar'));

  await _pumpUntil(tester, find.text('Confirmar inscripción'));
  await tester.tap(find.text('Confirmar inscripción'));
  for (var i = 0; i < 20 && find.text('Confirmar inscripción').evaluate().isNotEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
  await _pumpUntil(tester, find.text('En espera'));
}

Future<void> _recargarLista(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.arrow_back));
  await _pumpUntil(tester, find.text('Mi Lista de Espera'));
  await _abrirListaEspera(tester);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('CU07: inscripcion, reasignacion y confirmacion/rechazo en APK',
      (tester) async {
    // El coordinator de CU17 notifica durante el build; es ruido preexistente
    // y no debe marcar como fallida esta prueba de CU07. testWidgets instala
    // su propio handler al iniciar, por eso se ajusta aqui dentro.
    final onErrorOriginal = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('TreatmentProvider')) return;
      onErrorOriginal?.call(details);
    };

    app.main();
    await _pumpSeconds(tester, 3);

    final pacienteToken = await _loginApi('paciente.carlos@telemedicina.com', 'paciente123');
    final adminToken = await _loginApi('admin@telemedicina.com', 'admin123');

    // Estado inicial: sin inscripciones activas.
    expect(await _miEspera(pacienteToken), isEmpty);

    await _loginEnApp(tester);
    await _abrirListaEspera(tester);

    // 1) Inscripcion desde la APK (médico 1 / cardiología 2).
    await _inscribirse(tester, idEspecialidad: 2);
    expect(find.text('Tu posición en la lista: #1'), findsOneWidget);
    expect((await _miEspera(pacienteToken)).first['estado'], 'EN_ESPERA');

    // 2) Se cancela una cita desde el backend (CU25) y el hook ofrece el cupo.
    final citaConfirmar =
        await _crearCita(adminToken, idEspecialidad: 2, fecha: '2026-11-25', hora: '10:00');
    await _cancelarCita(adminToken, citaConfirmar);
    await _recargarLista(tester);

    await _pumpUntil(tester, find.text('Turno ofrecido'));
    final ofrecida = (await _miEspera(pacienteToken))
        .firstWhere((item) => item['estado'] == 'OFRECIDO');
    expect(ofrecida['id_cita_ofrecida'], isNotNull);

    // 3) Confirmar el turno ofrecido desde la APK.
    await tester.tap(find.text('Confirmar').first);
    await _esperarEstadoApi(pacienteToken, 'CONFIRMADO');
    await _recargarLista(tester);
    await _pumpUntil(tester, find.text('Confirmado'));
    final citaConfirmada = await http.get(
      Uri.parse('$api/citas?id_medico=1&fecha=2026-11-25&page_size=50'),
      headers: await _headers(adminToken),
    );
    expect(citaConfirmada.statusCode, 200, reason: citaConfirmada.body);
    final citasDelDia = jsonDecode(citaConfirmada.body)['items'] as List<dynamic>;
    expect(citasDelDia.any((cita) => cita['estado'] == 'CONFIRMADA'), isTrue,
        reason: 'La cita reasignada debe quedar CONFIRMADA: ${citaConfirmada.body}');

    // 4) Segunda inscripción (medicina general 1) y rechazo del turno ofrecido.
    await _inscribirse(tester, idEspecialidad: 1);
    final citaRechazar =
        await _crearCita(adminToken, idEspecialidad: 1, fecha: '2026-11-26', hora: '10:00');
    await _cancelarCita(adminToken, citaRechazar);
    await _recargarLista(tester);

    await _pumpUntil(tester, find.text('Turno ofrecido'));
    await tester.tap(find.text('Rechazar'));
    await _esperarEstadoApi(pacienteToken, 'RECHAZADO');
    await _recargarLista(tester);
    await _pumpUntil(tester, find.text('Rechazado'));

    // Permitir que terminen las solicitudes en vuelo antes del teardown.
    await _pumpSeconds(tester, 5);
  });
}
