import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_telemedicina/core/network/api_exceptions.dart';
import 'package:mobile_telemedicina/features/analytics/exportacion/data/services/report_export_service.dart';
import 'package:mobile_telemedicina/features/analytics/reportes/data/models/report_models.dart';
import 'package:mobile_telemedicina/features/analytics/reportes/domain/repositories/report_repository.dart';
import 'package:mobile_telemedicina/features/analytics/reportes/domain/repositories/report_voice_recorder.dart';
import 'package:mobile_telemedicina/features/analytics/reportes/presentation/controllers/reports_controller.dart';
import 'package:mobile_telemedicina/features/analytics/reportes/presentation/screens/reports_screen.dart';
import 'package:mobile_telemedicina/features/auth/data/models/auth_models.dart';
import 'package:mobile_telemedicina/features/auth/presentation/controllers/auth_controller.dart';

final _catalog = ReportCatalog({
  'reportes': [{
    'id': 'citas', 'titulo': 'Actividad de citas', 'metrica_principal': 'citas',
    'semantica': 'Una cita programada no demuestra atención efectiva.',
    'dimensiones': ['fecha', 'id_medico', 'estado', 'modalidad'],
    'columnas': ['fecha', 'id_medico', 'estado', 'modalidad', 'citas', 'cancelaciones'],
    'ordenables': ['fecha', 'id_medico', 'estado', 'modalidad', 'citas', 'cancelaciones'],
    'metricas': ['citas', 'cancelaciones'],
    'filtros': [{'campo': 'id_medico', 'operadores': ['eq']},
      {'campo': 'estado', 'operadores': ['eq']}],
  }],
  'formatos': ['pdf', 'xlsx', 'csv', 'html'],
  'modalidades': ['PRESENCIAL', 'TELEMEDICINA', 'CONFLICTO', 'DESCONOCIDA', 'OTRA'],
  'limites': {'periodo_dias': 366, 'filtros': 8, 'agrupaciones': 2,
    'columnas': 6, 'tamano_pagina': 100, 'filas_exportacion': 5000},
  'metricas_no_disponibles': {'ausentismo': {
    'disponible': false, 'valor': null, 'causa': 'SIN_ESTADO_AUSENCIA'}},
  'categorias_nulas': {'id_especialidad': 'Sin especialidad registrada'},
});
final _options = ReportOptions({'medicos': [{'id_medico': 20, 'nombre': 'Médica'}],
  'especialidades': <Map<String, dynamic>>[]});

ReportResult _result(ReportQuery definition, {int total = 14}) => ReportResult({
  'definicion': definition.toJson(), 'semantica': 'Citas programadas',
  'metricas': {'citas': {'disponible': true, 'valor': total, 'causa': null},
    'ausentismo': {'disponible': false, 'valor': null, 'causa': 'SIN_ESTADO_AUSENCIA'}},
  'total': total, 'filas': total == 0 ? <Map<String, dynamic>>[] : [
    {'fecha': '2026-09-01', 'citas': 1}],
  'advertencias': <String>[], 'generado_en': '2026-10-03T12:00:00Z',
});

class _Repository implements ReportRepository {
  final requests = <ReportQuery>[];
  final interpretedTexts = <String>[];
  final referenceDates = <String>[];
  final audioRequests = <ReportAudio>[];
  Completer<ReportResult>? deferred;
  Completer<ReportInterpretation>? deferredInterpret;
  Completer<String>? deferredTranscript;
  bool fail = false;
  Object? failure;
  Object? interpretFailure;
  Object? transcriptionFailure;
  ReportInterpretation? interpretResponse;
  int total = 14;
  @override
  Future<ReportCatalog> catalog() async => _catalog;
  @override
  Future<ReportOptions> options() async => _options;
  @override
  Future<ReportResult> query(ReportQuery definition) async {
    requests.add(definition);
    if (failure != null) throw failure!;
    if (fail) throw ApiException(message: 'Error sintético', statusCode: 500);
    if (deferred != null) { final waiting = deferred!; deferred = null; return waiting.future; }
    return _result(definition, total: total);
  }
  @override
  Future<ReportInterpretation> interpret(String texto, String fechaReferencia) async {
    interpretedTexts.add(texto); referenceDates.add(fechaReferencia);
    if (interpretFailure != null) throw interpretFailure!;
    if (deferredInterpret != null) return deferredInterpret!.future;
    return interpretResponse ?? _interpretation('valida', definition: const ReportQuery(
      reporte: 'citas', desde: '2026-09-01', hasta: '2026-09-30',
      columnas: ['citas']));
  }
  @override
  Future<String> transcribe(ReportAudio audio) async {
    audioRequests.add(audio);
    if (transcriptionFailure != null) throw transcriptionFailure!;
    if (deferredTranscript != null) return deferredTranscript!.future;
    return 'Citas de septiembre de 2026';
  }
}

ReportInterpretation _interpretation(String state, {ReportQuery? definition}) =>
    ReportInterpretation({'estado': state,
      'definicion': definition?.toJson(), 'resumen': 'Solicitud sintética',
      'campos_aclaracion': state == 'aclaracion' ? ['periodo'] : <String>[],
      'advertencias': <String>[]});

class _VoiceRecorder implements ReportVoiceRecorder {
  int starts = 0, stops = 0, cancels = 0, disposals = 0;
  Object? startFailure;
  Completer<void>? delayedStart;
  ReportAudio? nextAudio;
  Completer<ReportAudio>? delayedStop;
  void Function(Object)? onFailure;
  @override
  Future<void> start({required void Function(Object error) onFailure}) async {
    starts++;
    this.onFailure = onFailure;
    if (startFailure != null) throw startFailure!;
    if (delayedStart != null) await delayedStart!.future;
  }
  @override
  Future<ReportAudio> stop() async {
    stops++;
    return delayedStop?.future ?? nextAudio ?? ReportAudio(Uint8List.fromList([82, 73, 70, 70]));
  }
  @override
  Future<void> cancel() async { cancels++; }
  @override
  Future<void> dispose() async { disposals++; }
}

class _ScreenAuth extends AuthController {
  final bool allowed;
  _ScreenAuth(this.allowed);
  @override
  bool get isCheckingAuth => false;
  @override
  bool get canAccessReports => allowed;
  @override
  bool get isAuthenticated => true;
  @override
  String? get reportsAccountKey => allowed ? '1:1' : null;
}

Future<ReportsController> _ready(_Repository repository,
    {ReportExportService? exporter, _VoiceRecorder? recorder}) async {
  final controller = ReportsController(repository: repository, exporter: exporter,
    recorder: recorder ?? _VoiceRecorder());
  controller.bindAccount('1:1');
  await controller.loadCatalog();
  return controller;
}

void main() {
  testWidgets('navegación directa rechaza otros roles y ADMIN ve el constructor', (tester) async {
    final denied = _ScreenAuth(false);
    final deniedReports = ReportsController(repository: _Repository(), recorder: _VoiceRecorder());
    await tester.pumpWidget(ChangeNotifierProvider<AuthController>.value(
      value: denied, child: MaterialApp(home: ReportsScreen(controller: deniedReports))));
    await tester.pump();
    expect(find.textContaining('solo para ADMIN'), findsOneWidget);
    expect(find.text('Generar reporte'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    deniedReports.dispose();
    denied.dispose();

    final allowed = _ScreenAuth(true);
    final reports = await _ready(_Repository());
    await tester.pumpWidget(ChangeNotifierProvider<AuthController>.value(
      value: allowed, child: MaterialApp(home: ReportsScreen(controller: reports))));
    await tester.pumpAndSettle();
    expect(find.text('Generar reporte'), findsOneWidget);
    expect(find.text('Enviar al terminar'), findsOneWidget);
    expect(reports.sendWhenStopped, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    reports.dispose();
    allowed.dispose();
  });

  test('perfil textual ADMIN activo con clínica permite acceso; otros roles no', () {
    UserModel user(String role, {String state = 'activo', int? clinic = 1}) =>
      UserModel.fromJson({'id_usuario': 1, 'id_clinica': clinic, 'nombres': 'A',
        'apellidos': 'B', 'correo': 'a@example.com', 'rol': role, 'estado': state});
    expect(AuthController.eligibleForReports(user('ADMIN')), isTrue);
    expect(AuthController.eligibleForReports(user('Administración')), isTrue);
    for (final role in ['MEDICO', 'RECEPCION', 'PACIENTE']) {
      expect(AuthController.eligibleForReports(user(role)), isFalse);
    }
    expect(AuthController.eligibleForReports(user('ADMIN', state: 'inactivo')), isFalse);
    expect(AuthController.eligibleForReports(user('ADMIN', clinic: null)), isFalse);
  });

  test('solicitud completa, página y ausentismo no disponible', () async {
    final repository = _Repository();
    final c = await _ready(repository);
    c.edit(ReportQuery(reporte: 'citas', desde: '2026-09-01', hasta: '2026-09-30',
      filtros: const [ReportFilter('id_medico', 20)],
      agrupacion: const ['fecha'], columnas: const ['fecha', 'citas', 'cancelaciones'],
      orden: const [ReportSort('fecha', 'desc')], tamanoPagina: 10));
    await c.generate();
    expect(repository.requests.single.toJson().containsKey('id_clinica'), isFalse);
    expect(repository.requests.single.toJson()['filtros'], [{
      'campo': 'id_medico', 'operador': 'eq', 'valor': 20}]);
    expect(c.result!.metricas['ausentismo']!.display, 'No disponible');
    expect(c.canExport, isTrue);
    await c.page(2);
    expect(repository.requests.last.pagina, 2);
    expect(repository.requests.last.columnas, ['fecha', 'citas', 'cancelaciones']);
    expect(repository.requests.last.orden.single.direccion, 'desc');
    final requestCount = repository.requests.length;
    c.edit(c.draft!.copyWith(hasta: c.draft!.hasta));
    expect(c.result!.definicion.pagina, 2);
    expect(c.dirty, isFalse);
    expect(c.canExport, isTrue);
    await c.page(3);
    expect(repository.requests.length, requestCount);
    c.dispose();
  });

  test('validaciones, vacío y error de consulta', () async {
    final repository = _Repository()..total = 0;
    final c = await _ready(repository);
    c.edit(ReportQuery(reporte: 'citas', desde: '2026-10-02', hasta: '2026-09-01',
      columnas: const ['citas']));
    await c.generate();
    expect(repository.requests, isEmpty);
    expect(c.error, isNotNull);
    c.edit(c.draft!.copyWith(desde: '2026-09-01'));
    await c.generate();
    expect(c.result!.total, 0);
    expect(c.result!.filas, isEmpty);
    expect(c.result!.metricas['citas']!.display, '0');
    expect(c.result!.metricas['ausentismo']!.display, 'No disponible');
    repository.fail = true;
    await c.generate();
    expect(c.error, 'Error sintético');
    c.dispose();
  });

  test('edición bloquea exportación; respuesta atrasada y cambio de cuenta se descartan', () async {
    final repository = _Repository();
    final c = await _ready(repository);
    c.edit(const ReportQuery(reporte: 'citas', desde: '2026-09-01',
      hasta: '2026-09-15', columnas: ['citas'], tamanoPagina: 10));
    await c.generate();
    expect(c.canExport, isTrue);
    c.edit(c.draft!.copyWith(hasta: '2026-09-30'));
    expect(c.dirty, isTrue);
    expect(c.canExport, isFalse);
    await c.generate();
    final delayed = Completer<ReportResult>();
    repository.deferred = delayed;
    final pending = c.page(2);
    c.bindAccount('2:2');
    delayed.complete(_result(repository.requests.last));
    await pending;
    await Future<void>.delayed(Duration.zero);
    expect(c.result, isNull);
    c.bindAccount(null);
    expect(c.catalog, isNull);
    c.dispose();
  });

  test('una respuesta anterior no reemplaza una definición editada', () async {
    final repository = _Repository();
    final c = await _ready(repository);
    c.edit(const ReportQuery(reporte: 'citas', desde: '2026-09-01',
      hasta: '2026-09-15', columnas: ['citas']));
    final delayed = Completer<ReportResult>();
    repository.deferred = delayed;
    final first = c.generate();
    final oldRequest = repository.requests.last;
    c.edit(c.draft!.copyWith(hasta: '2026-09-30'));
    await c.generate();
    delayed.complete(_result(oldRequest));
    await first;
    expect(c.result!.definicion.hasta, '2026-09-30');
    expect(c.canExport, isTrue);
    c.dispose();
  });

  test('al cerrar pantalla se descarta una consulta pendiente', () async {
    final repository = _Repository();
    final c = await _ready(repository);
    final delayed = Completer<ReportResult>();
    repository.deferred = delayed;
    final pending = c.generate();
    final request = repository.requests.last;
    c.dispose();
    delayed.complete(_result(request));
    await pending;
    expect(c.result, isNull);
  });

  test('403 retira acceso a reportes y 401 solicita comprobar la sesión', () async {
    final repository = _Repository();
    var sessionChecks = 0, forbiddenCalls = 0;
    final c = ReportsController(repository: repository, recorder: _VoiceRecorder(),
      onUnauthorized: () async { sessionChecks++; },
      onForbidden: () { forbiddenCalls++; });
    c.bindAccount('1:1');
    await Future<void>.delayed(Duration.zero);
    await c.generate();
    expect(c.result, isNotNull);
    repository.failure = ForbiddenException();
    await c.generate();
    expect(c.account, isNull);
    expect(c.result, isNull);
    expect(forbiddenCalls, 1);
    expect(sessionChecks, 0);
    repository.failure = null;
    c.bindAccount('1:1');
    await Future<void>.delayed(Duration.zero);
    repository.failure = UnauthorizedException();
    await c.generate();
    expect(c.account, isNull);
    expect(c.result, isNull);
    expect(sessionChecks, 1);
    c.dispose();
  });

  test('binarios MIME y nombre; JSON 413 y MIME incorrecto no se guardan', () async {
    final saved = <String>[];
    final requests = <Map<String, dynamic>>[];
    http.Response response(String mime, {int status = 200}) => http.Response.bytes(
      status == 200 ? Uint8List.fromList([37, 80, 68, 70])
          : Uint8List.fromList(utf8.encode('{"detail":"límite"}')),
      status, headers: {'content-type': mime,
        'content-disposition': 'attachment; filename="reporte_citas_20261003_120000.pdf"'});
    var current = response('application/pdf');
    final service = ReportExportService(
      transport: (body) async { requests.add(body); return current; },
      save: (name, extension, mime, bytes) async {
        saved.add('$name.$extension:$mime:${bytes.length}');
      });
    const query = ReportQuery(reporte: 'citas', desde: '2026-09-01',
      hasta: '2026-09-30', columnas: ['citas'], pagina: 2);
    expect(await service.export(query, 'pdf'), 'reporte_citas_20261003_120000.pdf');
    expect(requests.single['formato'], 'pdf');
    expect(requests.single.containsKey('id_clinica'), isFalse);
    expect(requests.single['pagina'], 2); // El backend ignora página al exportar.
    expect(saved.single, 'reporte_citas_20261003_120000.pdf:application/pdf:4');
    current = response('application/json', status: 413);
    await expectLater(service.export(query, 'pdf'), throwsA(
      isA<ApiException>().having((e) => e.statusCode, 'statusCode', 413)));
    current = response('application/json');
    await expectLater(service.export(query, 'pdf'), throwsA(isA<ApiException>()));
    expect(saved.length, 1);
    expect(ReportExportService.safeFilename(
      'attachment; filename="../../datos.pdf"', 'citas', 'pdf'),
      startsWith('reporte_citas_'));
    current = response('application/pdf');
    await expectLater(service.export(query, 'pdf', isCurrent: () => false),
      throwsA(isA<ApiException>()));
    expect(saved.length, 1);
  });

  test('los cuatro formatos conservan bytes y MIME', () async {
    final saved = <String>[];
    for (final entry in ReportExportService.mimes.entries) {
      final service = ReportExportService(
        transport: (_) async => http.Response.bytes(Uint8List.fromList([1, 2, 3]), 200,
          headers: {'content-type': entry.value}),
        save: (name, extension, mime, bytes) async {
          saved.add('$extension:$mime:${bytes.length}');
        });
      const query = ReportQuery(reporte: 'citas', desde: '2026-09-01',
        hasta: '2026-09-30', columnas: ['citas']);
      await service.export(query, entry.key);
    }
    expect(saved.length, 4);
    for (final entry in ReportExportService.mimes.entries) {
      expect(saved, contains('${entry.key}:${entry.value}:3'));
    }
  });

  test('Aplicar filtros reemplaza todo sin consultar; Enviar consulta con fecha local', () async {
    final repository = _Repository();
    final c = await _ready(repository);
    c.edit(c.draft!.copyWith(filtros: const [ReportFilter('id_medico', 20)],
      agrupacion: const ['fecha'], columnas: const ['fecha', 'citas']));
    c.setRequestText('Citas de septiembre de 2026');
    await c.interpretText(generateAfter: false, now: DateTime(2026, 10, 3));
    expect(repository.interpretedTexts, ['Citas de septiembre de 2026']);
    expect(repository.referenceDates, ['2026-10-03']);
    expect(repository.requests, isEmpty);
    expect(c.draft!.filtros, isEmpty);
    expect(c.draft!.agrupacion, isEmpty);
    expect(c.draft!.columnas, ['citas']);
    await c.interpretText(generateAfter: true, now: DateTime(2026, 10, 3));
    expect(repository.interpretedTexts.length, 2);
    expect(repository.requests.length, 1);
    expect(repository.requests.single.toJson().containsKey('id_clinica'), isFalse);
    expect(c.result!.definicion.columnas, ['citas']);
    c.dispose();
  });

  test('aclaración, rechazo, error y definición incompatible no aplican parcialmente', () async {
    final repository = _Repository();
    final c = await _ready(repository);
    final original = c.draft!;
    c.setRequestText('Septiembre');
    for (final state in ['aclaracion', 'no_admitida']) {
      repository.interpretResponse = _interpretation(state);
      await c.interpretText(generateAfter: true);
      expect(c.draft, same(original));
      expect(c.interpretation!.estado, state);
      expect(repository.requests, isEmpty);
    }
    repository.interpretResponse = null;
    repository.interpretFailure = ApiException(message: 'Temporal', statusCode: 503);
    await c.interpretText(generateAfter: true);
    expect(c.interpretError, 'Temporal');
    expect(c.draft, same(original));
    repository.interpretFailure = null;
    repository.interpretResponse = _interpretation('valida', definition:
      const ReportQuery(reporte: 'citas', desde: '2026-09-01', hasta: '2026-09-30',
        filtros: [ReportFilter('id_medico', 999)], columnas: ['citas']));
    await c.interpretText(generateAfter: true);
    expect(c.interpretError, isNotNull);
    expect(c.draft, same(original));
    expect(repository.requests, isEmpty);
    c.dispose();
  });

  test('403 de interpretación retira solo reportes; 401 de transcripción comprueba sesión', () async {
    final repository = _Repository(), recorder = _VoiceRecorder();
    var forbiddenCalls = 0, sessionChecks = 0;
    final c = ReportsController(repository: repository, recorder: recorder,
      onForbidden: () { forbiddenCalls++; },
      onUnauthorized: () async { sessionChecks++; });
    c.bindAccount('1:1');
    await c.loadCatalog();
    c.setRequestText('Citas de septiembre de 2026');
    repository.interpretFailure = ForbiddenException();
    await c.interpretText(generateAfter: true);
    expect(c.account, isNull);
    expect(repository.requests, isEmpty);
    expect(forbiddenCalls, 1);
    expect(sessionChecks, 0);

    repository.interpretFailure = null;
    c.bindAccount('1:1');
    await c.loadCatalog();
    repository.transcriptionFailure = UnauthorizedException();
    await c.toggleRecording();
    await c.toggleRecording();
    expect(c.account, isNull);
    expect(repository.interpretedTexts.length, 1);
    expect(repository.requests, isEmpty);
    expect(sessionChecks, 1);
    c.dispose();
  });

  test('Limpiar texto conserva definición, página, resultado y exportación', () async {
    final c = await _ready(_Repository());
    c.edit(c.draft!.copyWith(tamanoPagina: 10));
    await c.generate();
    await c.page(2);
    final draft = c.draft, result = c.result, canExport = c.canExport;
    c.setRequestText('Texto a limpiar');
    c.clearText();
    expect(c.requestText, isEmpty);
    expect(c.interpretation, isNull);
    expect(c.draft, same(draft));
    expect(c.result, same(result));
    expect(c.result!.definicion.pagina, 2);
    expect(c.canExport, canExport);
    c.dispose();
  });

  test('respuesta atrasada de interpretación no aplica tras edición o cuenta nueva', () async {
    final repository = _Repository();
    final c = await _ready(repository);
    c.setRequestText('Citas de septiembre de 2026');
    repository.deferredInterpret = Completer<ReportInterpretation>();
    final first = c.interpretText(generateAfter: true);
    c.setRequestText('Texto editado');
    repository.deferredInterpret!.complete(_interpretation('valida', definition:
      const ReportQuery(reporte: 'citas', desde: '2026-09-01',
        hasta: '2026-09-30', columnas: ['citas'])));
    await first;
    expect(repository.requests, isEmpty);
    expect(c.interpretation, isNull);
    repository.deferredInterpret = Completer<ReportInterpretation>();
    final second = c.interpretText(generateAfter: true);
    c.bindAccount('2:2');
    repository.deferredInterpret!.complete(_interpretation('valida', definition:
      const ReportQuery(reporte: 'citas', desde: '2026-09-01',
        hasta: '2026-09-30', columnas: ['citas'])));
    await second;
    expect(c.requestText, isEmpty);
    expect(c.result, isNull);
    expect(repository.requests, isEmpty);
    c.dispose();
  });

  test('Generar manualmente invalida una interpretación pendiente', () async {
    final repository = _Repository();
    final c = await _ready(repository);
    final original = c.draft!;
    c.setRequestText('Citas de septiembre de 2026');
    repository.deferredInterpret = Completer<ReportInterpretation>();
    final pending = c.interpretText(generateAfter: true);
    await c.generate();
    repository.deferredInterpret!.complete(_interpretation('valida', definition:
      const ReportQuery(reporte: 'citas', desde: '2026-09-01',
        hasta: '2026-09-30', columnas: ['citas'])));
    await pending;
    expect(c.draft!.sameDefinition(original), isTrue);
    expect(repository.requests.length, 1);
    expect(c.interpretation, isNull);
    c.dispose();
  });

  test('dictado normal conserva texto y el automático usa Enviar una sola vez', () async {
    final repository = _Repository(), recorder = _VoiceRecorder();
    final c = await _ready(repository, recorder: recorder);
    c.setRequestText('Reporte de');
    await c.toggleRecording();
    await c.toggleRecording();
    expect(c.requestText, 'Reporte de Citas de septiembre de 2026');
    expect(repository.interpretedTexts, isEmpty);
    expect(repository.requests, isEmpty);
    c.clearText();
    c.setSendWhenStopped(true);
    await c.toggleRecording();
    final stop = c.toggleRecording();
    await c.toggleRecording(); // Transcribiendo: no inicia otra cadena.
    await stop;
    expect(recorder.stops, 2);
    expect(repository.audioRequests.length, 2);
    expect(repository.audioRequests.last.filename, 'dictado.wav');
    expect(repository.audioRequests.last.mimeType, 'audio/wav');
    expect(repository.interpretedTexts.length, 1);
    expect(repository.requests.length, 1);
    c.dispose();
  });

  test('autoenvío se detiene ante aclaración sin consultar ni aplicar controles', () async {
    final repository = _Repository()..interpretResponse = _interpretation('aclaracion');
    final c = await _ready(repository);
    final original = c.draft;
    c.setSendWhenStopped(true);
    await c.toggleRecording();
    await c.toggleRecording();
    expect(repository.interpretedTexts.length, 1);
    expect(repository.requests, isEmpty);
    expect(c.draft, same(original));
    expect(c.interpretation!.estado, 'aclaracion');
    c.dispose();
  });

  test('cambio de filtros durante captura conserva texto sin autoenvío', () async {
    final repository = _Repository();
    final c = await _ready(repository);
    c.setSendWhenStopped(true);
    await c.toggleRecording();
    c.edit(c.draft!.copyWith(hasta: '2026-09-30'));
    await c.toggleRecording();
    expect(c.requestText, 'Citas de septiembre de 2026');
    expect(c.voiceNotice, contains('manualmente'));
    expect(repository.interpretedTexts, isEmpty);
    c.dispose();
  });

  test('edición, permiso y segundo plano impiden autoenvío; incorporar no envía', () async {
    final repository = _Repository(), recorder = _VoiceRecorder();
    final c = await _ready(repository, recorder: recorder);
    c.setSendWhenStopped(true);
    recorder.startFailure = StateError('Permiso denegado');
    await c.toggleRecording();
    expect(c.voiceError, contains('Permiso'));
    expect(repository.audioRequests, isEmpty);
    recorder.startFailure = null;
    c.setRequestText('Previo');
    await c.toggleRecording();
    c.setRequestText('Editado');
    c.setRequestText('Previo');
    await c.toggleRecording();
    expect(c.pendingTranscript, isNotNull);
    expect(repository.interpretedTexts, isEmpty);
    c.incorporatePendingTranscript();
    expect(c.pendingTranscript, isNull);
    expect(repository.interpretedTexts, isEmpty);
    await c.toggleRecording();
    c.cancelVoiceForLifecycle();
    expect(recorder.cancels, greaterThan(0));
    expect(repository.interpretedTexts, isEmpty);
    c.dispose();
  });

  test('permiso pendiente cancelado no interfiere con la siguiente grabación', () async {
    final recorder = _VoiceRecorder()..delayedStart = Completer<void>();
    final c = await _ready(_Repository(), recorder: recorder);
    final first = c.toggleRecording();
    expect(c.voiceState, 'requesting');
    c.cancelVoiceForLifecycle();
    await c.toggleRecording();
    expect(recorder.starts, 1);
    recorder.delayedStart!.complete();
    await first;
    expect(c.voiceState, 'idle');
    expect(recorder.cancels, greaterThan(0));
    recorder.delayedStart = null;
    await c.toggleRecording();
    expect(recorder.starts, 2);
    expect(c.voiceState, 'recording');
    c.dispose();
  });

  test('edición durante transcripción deja dictado pendiente sin autoenvío', () async {
    final repository = _Repository();
    final c = await _ready(repository);
    c.setSendWhenStopped(true);
    repository.deferredTranscript = Completer<String>();
    await c.toggleRecording();
    final stop = c.toggleRecording();
    await Future<void>.delayed(Duration.zero);
    c.setRequestText('Texto propio');
    repository.deferredTranscript!.complete('Citas de septiembre de 2026');
    await stop;
    expect(c.requestText, 'Texto propio');
    expect(c.pendingTranscript, 'Citas de septiembre de 2026');
    expect(repository.interpretedTexts, isEmpty);
    c.dispose();
  });

  test('error de transcripción no inicia interpretación ni consulta', () async {
    final repository = _Repository()
      ..transcriptionFailure = ApiException(message: 'Audio inválido', statusCode: 422);
    final c = await _ready(repository);
    c.setSendWhenStopped(true);
    await c.toggleRecording();
    await c.toggleRecording();
    expect(c.voiceError, 'Audio inválido');
    expect(repository.interpretedTexts, isEmpty);
    expect(repository.requests, isEmpty);
    c.dispose();
  });

  test('audio demasiado grande o MIME/nombre discordante no se envía', () async {
    final repository = _Repository(), recorder = _VoiceRecorder();
    final c = await _ready(repository, recorder: recorder);
    recorder.nextAudio = ReportAudio(Uint8List(5 * 1024 * 1024 + 1));
    await c.toggleRecording();
    await c.toggleRecording();
    expect(repository.audioRequests, isEmpty);
    recorder.nextAudio = ReportAudio(Uint8List.fromList([82, 73, 70, 70]),
      filename: 'dictado.webm', mimeType: 'audio/wav');
    await c.toggleRecording();
    await c.toggleRecording();
    expect(repository.audioRequests, isEmpty);
    c.dispose();
  });

  test('transcripción atrasada tras cambio de cuenta o salida se descarta', () async {
    final repository = _Repository(), recorder = _VoiceRecorder();
    final c = await _ready(repository, recorder: recorder);
    c.setSendWhenStopped(true);
    repository.deferredTranscript = Completer<String>();
    await c.toggleRecording();
    final stop = c.toggleRecording();
    await Future<void>.delayed(Duration.zero);
    c.bindAccount('2:2');
    repository.deferredTranscript!.complete('Citas de septiembre de 2026');
    await stop;
    expect(c.requestText, isEmpty);
    expect(repository.interpretedTexts, isEmpty);
    expect(repository.requests, isEmpty);
    c.dispose();
    expect(recorder.cancels, greaterThan(0));
  });

  test('salida descarta una transcripción atrasada y libera grabador', () async {
    final repository = _Repository(), recorder = _VoiceRecorder();
    final c = await _ready(repository, recorder: recorder);
    c.setSendWhenStopped(true);
    repository.deferredTranscript = Completer<String>();
    await c.toggleRecording();
    final stop = c.toggleRecording();
    await Future<void>.delayed(Duration.zero);
    c.dispose();
    repository.deferredTranscript!.complete('Citas de septiembre de 2026');
    await stop;
    expect(repository.interpretedTexts, isEmpty);
    expect(repository.requests, isEmpty);
    expect(recorder.cancels, greaterThan(0));
  });

  test('salida durante stop espera su final antes de cancelar el grabador', () async {
    final recorder = _VoiceRecorder()..delayedStop = Completer<ReportAudio>();
    final repository = _Repository();
    final c = await _ready(repository, recorder: recorder);
    await c.toggleRecording();
    final stopping = c.toggleRecording();
    c.cancelVoiceForLifecycle();
    expect(recorder.cancels, 0);
    recorder.delayedStop!.complete(ReportAudio(
      Uint8List.fromList([82, 73, 70, 70])));
    await stopping;
    await Future<void>.delayed(Duration.zero);
    expect(recorder.cancels, greaterThan(0));
    expect(repository.audioRequests, isEmpty);
    c.dispose();
  });

  test('segundo plano descarta interpretación automática aún pendiente', () async {
    final repository = _Repository();
    final c = await _ready(repository);
    c.setSendWhenStopped(true);
    repository.deferredInterpret = Completer<ReportInterpretation>();
    await c.toggleRecording();
    final stop = c.toggleRecording();
    await Future<void>.delayed(Duration.zero);
    expect(c.interpreting, isTrue);
    c.cancelVoiceForLifecycle();
    repository.deferredInterpret!.complete(_interpretation('valida', definition:
      const ReportQuery(reporte: 'citas', desde: '2026-09-01',
        hasta: '2026-09-30', columnas: ['citas'])));
    await stop;
    expect(repository.requests, isEmpty);
    expect(c.interpretation, isNull);
    c.dispose();
  });

  testWidgets('Enter envía y Shift+Enter conserva la edición', (tester) async {
    final repository = _Repository();
    final c = await _ready(repository);
    final auth = _ScreenAuth(true);
    await tester.pumpWidget(ChangeNotifierProvider<AuthController>.value(
      value: auth, child: MaterialApp(home: ReportsScreen(controller: c))));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Citas de septiembre de 2026');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(repository.interpretedTexts, isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(repository.interpretedTexts.length, 1);
    expect(repository.requests.length, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    c.dispose(); auth.dispose();
  });

  testWidgets('límite de duración transcribe sin autoenvío', (tester) async {
    final repository = _Repository(), recorder = _VoiceRecorder();
    final c = ReportsController(repository: repository, recorder: recorder);
    c.bindAccount('1:1');
    await tester.pump();
    c.setSendWhenStopped(true);
    await c.toggleRecording();
    await tester.pump(const Duration(seconds: 60));
    await tester.pump();
    expect(recorder.stops, 1);
    expect(c.requestText, 'Citas de septiembre de 2026');
    expect(repository.interpretedTexts, isEmpty);
    c.dispose();
  });
}
