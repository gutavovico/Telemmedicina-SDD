import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../../core/network/api_exceptions.dart';
import '../../../exportacion/data/services/report_export_service.dart';
import '../../data/models/report_models.dart';
import '../../data/repositories/report_repository_impl.dart';
import '../../data/services/report_voice_recorder_impl.dart';
import '../../domain/repositories/report_repository.dart';
import '../../domain/repositories/report_voice_recorder.dart';

class ReportsController extends ChangeNotifier {
  final ReportRepository repository;
  final ReportExportService exporter;
  final ReportVoiceRecorder recorder;
  final Future<void> Function()? onUnauthorized;
  final void Function()? onForbidden;
  ReportsController({ReportRepository? repository, ReportExportService? exporter,
      ReportVoiceRecorder? recorder,
      this.onUnauthorized, this.onForbidden})
      : repository = repository ?? ReportRepositoryImpl(),
        exporter = exporter ?? ReportExportService(),
        recorder = recorder ?? ReportVoiceRecorderImpl();

  String? _account;
  int _generation = 0;
  int _interpretTicket = 0, _voiceTicket = 0, _textRevision = 0;
  int _voiceContextVersion = 0, _voiceTextAtStart = 0, _voiceContextAtStart = 0;
  String? _voiceAccountAtStart;
  bool _voiceAutoAtStart = false;
  bool _autoChainActive = false;
  Timer? _voiceTimer;
  Completer<void>? _voiceStartFinished;
  Future<ReportAudio>? _stoppingVoice;
  Future<void>? _voiceCleanup;
  bool _disposed = false;
  bool loadingCatalog = false, loadingReport = false, exporting = false;
  bool interpreting = false, sendWhenStopped = false;
  String requestText = '', voiceState = 'idle';
  int voiceSeconds = 0;
  String? pendingTranscript, voiceError, voiceNotice, interpretError;
  ReportInterpretation? interpretation;
  String? error, exportError, savedFile;
  ReportCatalog? catalog;
  ReportOptions? options;
  ReportQuery? draft;
  ReportResult? result;
  bool dirty = false;
  String? get account => _account;
  bool get canExport => _account != null && result != null && !dirty &&
      !loadingReport && !exporting && !interpreting;
  bool get canClearText => requestText.isNotEmpty && voiceState == 'idle' &&
      !interpreting && !loadingReport && pendingTranscript == null;
  bool get canToggleAutoSend => voiceState == 'idle' && !interpreting &&
      !loadingReport && !loadingCatalog && _voiceStartFinished == null &&
      _voiceCleanup == null;
  bool get canToggleVoice => voiceState == 'recording' ||
      (voiceState == 'idle' && !interpreting && !loadingReport &&
        pendingTranscript == null && _voiceStartFinished == null &&
        _voiceCleanup == null);
  CatalogReport? get selectedReport {
    for (final item in catalog?.reportes ?? <CatalogReport>[]) {
      if (item.id == draft?.reporte) return item;
    }
    return null;
  }

  void bindAccount(String? account) {
    if (_disposed) return;
    if (_account == account) return;
    _account = account;
    ++_generation;
    ++_voiceContextVersion;
    ++_interpretTicket;
    interpreting = false;
    _autoChainActive = false;
    unawaited(_cancelVoice());
    requestText = ''; pendingTranscript = null;
    interpretation = null; interpretError = null;
    sendWhenStopped = false; voiceNotice = null; voiceError = null;
    catalog = null; options = null; draft = null; result = null;
    loadingCatalog = false; loadingReport = false; exporting = false;
    error = null; exportError = null; savedFile = null; dirty = false;
    notifyListeners();
    if (account != null) loadCatalog();
  }

  Future<void> loadCatalog() async {
    if (_account == null) return;
    final ticket = ++_generation;
    ++_voiceContextVersion;
    loadingCatalog = true; error = null; notifyListeners();
    try {
      final nextCatalog = await repository.catalog();
      final nextOptions = await repository.options();
      if (ticket != _generation || _account == null) return;
      catalog = nextCatalog; options = nextOptions;
      if (draft == null && nextCatalog.reportes.isNotEmpty) {
        final report = nextCatalog.reportes.first;
        final today = DateTime.now();
        final from = DateTime(today.year, today.month, 1);
        draft = ReportQuery(reporte: report.id, desde: _iso(from), hasta: _iso(today),
          columnas: [report.metricaPrincipal]);
      }
    } catch (caught) {
      if (ticket != _generation) return;
      _handleError(caught);
    } finally {
      if (ticket == _generation) { loadingCatalog = false; notifyListeners(); }
    }
  }

  static String _iso(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  void edit(ReportQuery next) {
    if (_account == null || catalog == null) return;
    final old = draft;
    if (old != null && old.sameDefinition(next)) return;
    draft = next.copyWith(pagina: 1);
    ++_generation;
    ++_voiceContextVersion;
    ++_interpretTicket;
    interpreting = false;
    interpretation = null; interpretError = null;
    dirty = result != null && !result!.definicion.sameDefinition(draft!);
    loadingReport = false; error = null; savedFile = null;
    notifyListeners();
  }

  void selectReport(CatalogReport report) {
    final current = draft;
    if (current == null) return;
    edit(ReportQuery(reporte: report.id, desde: current.desde,
      hasta: current.hasta, columnas: [report.metricaPrincipal],
      tamanoPagina: current.tamanoPagina));
  }

  void setRequestText(String value) {
    if (_disposed || _account == null) return;
    ++_textRevision;
    ++_interpretTicket;
    requestText = value;
    interpreting = false;
    interpretation = null; interpretError = null;
    notifyListeners();
  }

  void clearText() {
    if (!canClearText) return;
    setRequestText('');
    voiceNotice = null;
    notifyListeners();
  }

  void setSendWhenStopped(bool value) {
    if (!canToggleAutoSend) return;
    sendWhenStopped = value;
    notifyListeners();
  }

  Future<void> interpretText({required bool generateAfter, DateTime? now}) async {
    if (_account == null || catalog == null || options == null ||
        voiceState != 'idle' || pendingTranscript != null ||
        interpreting || loadingReport || loadingCatalog) {
      return;
    }
    final text = requestText.trim();
    if (text.isEmpty || text.length > 1000) {
      interpretError = 'Escribe una solicitud de hasta 1000 caracteres.';
      notifyListeners();
      return;
    }
    final ticket = ++_interpretTicket;
    final account = _account;
    ++_voiceContextVersion;
    ++_generation; // descarta páginas/exports en vuelo antes de interpretar
    loadingReport = false; exporting = false;
    interpretation = null; interpretError = null; voiceNotice = null;
    interpreting = true;
    notifyListeners();
    try {
      final response = await repository.interpret(text, _iso(now ?? DateTime.now()));
      if (_disposed || ticket != _interpretTicket || account != _account) return;
      interpreting = false;
      if (response.estado != 'valida') {
        interpretation = response;
        notifyListeners();
        return;
      }
      final definition = response.definicion;
      if (definition == null || definition.pagina != 1 ||
          validateDefinition(definition) != null) {
        interpretError = 'La definición recibida no coincide con el catálogo. Intenta de nuevo o usa los filtros manuales.';
        notifyListeners();
        return;
      }
      // La respuesta construye una definición completa; no retiene filtros anteriores.
      draft = definition;
      ++_generation;
      savedFile = null; exportError = null; error = null;
      dirty = result != null && !result!.definicion.sameDefinition(definition);
      interpretation = response;
      notifyListeners();
      if (generateAfter) await generate();
    } catch (caught) {
      if (_disposed || ticket != _interpretTicket || account != _account) return;
      interpreting = false;
      if (caught is UnauthorizedException || caught is ForbiddenException) {
        _handleError(caught);
      } else {
        interpretError = caught is ApiException ? caught.message
            : 'No se pudo interpretar la solicitud. Intenta de nuevo o usa los filtros manuales.';
        notifyListeners();
      }
    }
  }

  Future<void> toggleRecording() async {
    if (voiceState == 'recording') {
      await _stopRecording(explicit: true);
      return;
    }
    if (_account == null || catalog == null || options == null ||
        voiceState != 'idle' || interpreting || loadingReport ||
        pendingTranscript != null || _voiceStartFinished != null ||
        _voiceCleanup != null) {
      return;
    }
    final startFinished = Completer<void>();
    _voiceStartFinished = startFinished;
    final ticket = ++_voiceTicket;
    final account = _account;
    _voiceAutoAtStart = sendWhenStopped;
    _voiceTextAtStart = _textRevision;
    _voiceContextAtStart = _voiceContextVersion;
    _voiceAccountAtStart = account;
    voiceState = 'requesting'; voiceSeconds = 0;
    voiceError = null; voiceNotice = null;
    notifyListeners();
    try {
      await recorder.start(onFailure: (failure) {
        if (ticket != _voiceTicket || _disposed) return;
        unawaited(_cancelVoice());
        voiceError = failure is StateError ? failure.message.toString()
            : 'Se interrumpió la grabación. Usa el texto manual.';
        notifyListeners();
      });
      if (_disposed || ticket != _voiceTicket || account != _account) {
        if (!_disposed) await recorder.cancel();
        return;
      }
      voiceState = 'recording';
      _voiceTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (ticket != _voiceTicket || voiceState != 'recording') return;
        voiceSeconds++;
        notifyListeners();
        if (voiceSeconds >= 60) unawaited(_stopRecording(explicit: false));
      });
      notifyListeners();
    } catch (caught) {
      if (_disposed) return;
      try { await recorder.cancel(); } catch (_) { /* Mantener texto manual. */ }
      if (ticket != _voiceTicket || account != _account) return;
      voiceState = 'idle';
      voiceError = caught is StateError ? caught.message.toString()
          : 'No se pudo iniciar el micrófono. Usa el texto manual.';
      notifyListeners();
    } finally {
      if (identical(_voiceStartFinished, startFinished)) {
        _voiceStartFinished = null;
      }
      startFinished.complete();
      if (!_disposed && voiceState == 'idle') notifyListeners();
    }
  }

  Future<void> _stopRecording({required bool explicit}) async {
    if (voiceState != 'recording') return;
    _voiceTimer?.cancel(); _voiceTimer = null;
    voiceState = 'transcribing';
    final ticket = _voiceTicket, account = _account;
    notifyListeners();
    try {
      final stopping = recorder.stop();
      _stoppingVoice = stopping;
      late final ReportAudio audio;
      try {
        audio = await stopping;
      } finally {
        if (identical(_stoppingVoice, stopping)) _stoppingVoice = null;
      }
      if (_disposed || ticket != _voiceTicket || account != _account) return;
      if (audio.bytes.isEmpty || audio.bytes.length > ReportVoiceRecorderImpl.maxAudioBytes ||
          audio.mimeType != 'audio/wav' || audio.filename != 'dictado.wav') {
        throw StateError('El audio no cumple el formato o tamaño admitido. Reintenta.');
      }
      final transcript = (await repository.transcribe(audio)).trim();
      if (_disposed || ticket != _voiceTicket || account != _account) return;
      voiceState = 'idle';
      if (transcript.isEmpty) {
        voiceError = 'La transcripción no produjo texto. Reintenta o escribe la solicitud.';
      } else if (_textRevision != _voiceTextAtStart || pendingTranscript != null) {
        pendingTranscript = pendingTranscript == null ? transcript
            : '$pendingTranscript $transcript';
        voiceNotice = 'Revisa el dictado pendiente y envía la solicitud manualmente.';
      } else {
        final previous = requestText.trim();
        final combined = previous.isEmpty ? transcript : '$previous $transcript';
        if (combined.length > 1000) {
          pendingTranscript = transcript;
          voiceNotice = 'Reduce el texto e incorpora el dictado manualmente.';
        } else {
          final safeAuto = explicit && _voiceAutoAtStart &&
              _voiceContextAtStart == _voiceContextVersion &&
              _voiceAccountAtStart == _account && !loadingReport && !interpreting;
          setRequestText(combined);
          if (safeAuto) {
            _autoChainActive = true;
            try {
              await interpretText(generateAfter: true);
            } finally {
              _autoChainActive = false;
            }
          } else if (_voiceAutoAtStart) {
            voiceNotice = 'Revisa la transcripción y envía la solicitud manualmente.';
          }
        }
      }
      notifyListeners();
    } catch (caught) {
      if (_disposed || ticket != _voiceTicket || account != _account) return;
      try { await recorder.cancel(); } catch (_) { /* Mantener texto manual. */ }
      voiceState = 'idle';
      if (caught is UnauthorizedException || caught is ForbiddenException) {
        _handleError(caught);
      } else {
        voiceError = caught is ApiException ? caught.message
            : caught is StateError ? caught.message.toString()
            : 'No se pudo transcribir. Reintenta o escribe la solicitud.';
        notifyListeners();
      }
    }
  }

  void incorporatePendingTranscript() {
    final transcript = pendingTranscript;
    if (transcript == null || voiceState != 'idle') return;
    final previous = requestText.trim();
    final combined = previous.isEmpty ? transcript : '$previous $transcript';
    if (combined.length > 1000) {
      voiceError = 'La solicitud supera 1000 caracteres. Reduce el texto.';
      notifyListeners();
      return;
    }
    setRequestText(combined);
    pendingTranscript = null; voiceNotice = null; voiceError = null;
    notifyListeners();
  }

  void discardPendingTranscript() {
    pendingTranscript = null; voiceNotice = null;
    notifyListeners();
  }

  void cancelVoiceForLifecycle() {
    if (voiceState == 'idle' && !_autoChainActive) return;
    if (_autoChainActive) {
      ++_interpretTicket;
      ++_generation;
      interpreting = false; loadingReport = false;
      _autoChainActive = false;
    }
    unawaited(_cancelVoice());
    voiceNotice = 'Se interrumpió el dictado. Revisa el texto y envía manualmente.';
    notifyListeners();
  }

  Future<void> _cancelVoice() async {
    final active = voiceState != 'idle' && voiceState != 'requesting';
    ++_voiceTicket;
    _voiceTimer?.cancel(); _voiceTimer = null;
    voiceState = 'idle'; voiceSeconds = 0;
    final prior = _voiceCleanup;
    if (prior != null) {
      await prior;
      return;
    }
    if (active) {
      final stopping = _stoppingVoice;
      final cleanup = () async {
        if (stopping != null) {
          try { await stopping; } catch (_) { /* La captura ya falló. */ }
        }
        await recorder.cancel();
      }();
      _voiceCleanup = cleanup;
      try { await cleanup; } catch (_) { /* Se conserva entrada manual. */ }
      finally {
        if (identical(_voiceCleanup, cleanup)) _voiceCleanup = null;
        if (!_disposed && voiceState == 'idle') notifyListeners();
      }
    }
  }

  String? validate() => validateDefinition(draft);

  String? validateDefinition(ReportQuery? definition) {
    final info = catalog;
    CatalogReport? source;
    for (final report in info?.reportes ?? <CatalogReport>[]) {
      if (report.id == definition?.reporte) source = report;
    }
    if (definition == null || source == null || info == null) return 'Selecciona un reporte.';
    final query = definition;
    final resolvedSource = source;
    final catalogInfo = info;
    if (query.pagina != 1 && (draft == null || !identical(query, draft))) {
      return 'La interpretación debe comenzar en la primera página.';
    }
    if (options == null) return 'No se cargaron las opciones del reporte.';
    DateTime? date(String value) {
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return null;
      final parsed = DateTime.tryParse(value);
      return parsed != null && _iso(parsed) == value ? parsed : null;
    }
    final from = date(query.desde), to = date(query.hasta);
    if (from == null || to == null || to.isBefore(from)) return 'Selecciona un período válido.';
    final days = DateTime.utc(to.year, to.month, to.day)
        .difference(DateTime.utc(from.year, from.month, from.day)).inDays + 1;
    if (days > (catalogInfo.limites['periodo_dias'] ?? 366)) {
      return 'El período supera el límite del catálogo.';
    }
    if (query.tamanoPagina < 1 || query.tamanoPagina >
        (catalogInfo.limites['tamano_pagina'] ?? 100)) {
      return 'Tamaño de página no permitido.';
    }
    if (query.filtros.length > (catalogInfo.limites['filtros'] ?? 8) ||
        query.filtros.map((e) => e.campo).toSet().length != query.filtros.length ||
        query.filtros.any((e) => !resolvedSource.filtros.contains(e.campo))) {
      return 'Filtros incompatibles con el reporte.';
    }
    for (final filter in query.filtros) {
      final value = filter.valor;
      if (filter.campo == 'id_medico' &&
          (value is! int || !options!.medicos.any((item) => item['id_medico'] == value))) {
        return 'Selecciona un médico de las opciones disponibles.';
      }
      if (filter.campo == 'id_especialidad' &&
          (value is! int || !options!.especialidades.any(
              (item) => item['id_especialidad'] == value))) {
        return 'Selecciona una especialidad de las opciones disponibles.';
      }
      if (filter.campo == 'modalidad' &&
          (value is! String || !catalogInfo.modalidades.contains(value))) {
        return 'Modalidad no permitida.';
      }
      if (filter.campo == 'estado' &&
          (value is! String || !const [
            'PENDIENTE', 'CONFIRMADA', 'COMPLETADA', 'FINALIZADA', 'CANCELADA',
          ].contains(value))) {
        return 'Estado no permitido.';
      }
    }
    if (query.agrupacion.length > (catalogInfo.limites['agrupaciones'] ?? 2) ||
        query.agrupacion.toSet().length != query.agrupacion.length ||
        query.agrupacion.any((e) => !resolvedSource.dimensiones.contains(e))) {
      return 'Agrupación incompatible con el reporte.';
    }
    if (query.columnas.isEmpty || query.columnas.length >
        (catalogInfo.limites['columnas'] ?? 6) ||
        query.columnas.toSet().length != query.columnas.length ||
        !query.columnas.contains(resolvedSource.metricaPrincipal) ||
        query.columnas.any((e) => !resolvedSource.columnas.contains(e) ||
          (resolvedSource.dimensiones.contains(e) && !query.agrupacion.contains(e))) ||
        query.agrupacion.any((e) => !query.columnas.contains(e))) {
      return 'Selecciona columnas compatibles, agrupaciones y métrica principal.';
    }
    if (query.orden.length > (catalogInfo.limites['columnas'] ?? 6) ||
        query.orden.map((e) => e.campo).toSet().length != query.orden.length ||
        query.orden.any((e) => !query.columnas.contains(e.campo) ||
          !resolvedSource.ordenables.contains(e.campo) ||
          !const {'asc', 'desc'}.contains(e.direccion))) {
      return 'El orden debe usar columnas seleccionadas sin repetir.';
    }
    return null;
  }

  Future<void> generate() async {
    if (_account == null || loadingReport) return;
    if (interpreting) {
      ++_interpretTicket;
      interpreting = false;
    }
    ++_voiceContextVersion;
    final invalid = validate();
    if (invalid != null) { error = invalid; notifyListeners(); return; }
    final ticket = ++_generation;
    final definition = draft!;
    loadingReport = true; error = null; savedFile = null; notifyListeners();
    try {
      final response = await repository.query(definition);
      if (ticket != _generation || _account == null) return;
      result = response;
      draft = response.definicion;
      dirty = false;
    } catch (caught) {
      if (ticket != _generation) return;
      _handleError(caught);
    } finally {
      if (ticket == _generation) { loadingReport = false; notifyListeners(); }
    }
  }

  Future<void> page(int number) async {
    if (_account == null || dirty || loadingReport || result == null || number < 1) return;
    if (interpreting) {
      ++_interpretTicket;
      interpreting = false;
    }
    final prior = result!;
    final pages = (prior.total + prior.definicion.tamanoPagina - 1) ~/
        prior.definicion.tamanoPagina;
    if (number > pages) return;
    ++_voiceContextVersion;
    final ticket = ++_generation;
    loadingReport = true; error = null; notifyListeners();
    try {
      final response = await repository.query(prior.definicion.copyWith(pagina: number));
      if (ticket != _generation || _account == null) return;
      result = response; draft = response.definicion;
    } catch (caught) {
      if (ticket != _generation) return;
      _handleError(caught);
    } finally {
      if (ticket == _generation) { loadingReport = false; notifyListeners(); }
    }
  }

  Future<void> export(String format) async {
    if (!canExport || !catalog!.formatos.contains(format)) return;
    ++_voiceContextVersion;
    final ticket = _generation;
    exporting = true; exportError = null; savedFile = null; notifyListeners();
    try {
      final name = await exporter.export(result!.definicion, format,
        isCurrent: () => ticket == _generation && _account != null && !dirty);
      if (ticket == _generation && _account != null) savedFile = name;
    } catch (caught) {
      if (ticket != _generation) return;
      if (caught is UnauthorizedException) {
        bindAccount(null); await onUnauthorized?.call(); return;
      }
      if (caught is ForbiddenException) {
        bindAccount(null); onForbidden?.call();
        error = caught.message; notifyListeners(); return;
      }
      exportError = caught is ApiException && caught.statusCode == 413
          ? 'El reporte supera 5.000 grupos. Reduce el período o ajusta los filtros.'
          : caught is ApiException ? caught.message : 'No se pudo guardar el archivo.';
    } finally {
      if (ticket == _generation) { exporting = false; notifyListeners(); }
    }
  }

  void _handleError(Object caught) {
    if (caught is UnauthorizedException) {
      bindAccount(null);
      onUnauthorized?.call();
    } else if (caught is ForbiddenException) {
      bindAccount(null);
      onForbidden?.call();
      error = caught.message;
      notifyListeners();
    } else {
      error = caught is ApiException ? caught.message : 'No se pudo cargar el reporte.';
    }
  }

  @override
  void dispose() {
    final wasRequesting = voiceState == 'requesting';
    final startFinished = _voiceStartFinished?.future;
    _disposed = true;
    _account = null;
    ++_generation;
    ++_interpretTicket;
    unawaited(() async {
      await _cancelVoice();
      if (wasRequesting) {
        if (startFinished != null) await startFinished;
        try { await recorder.cancel(); } catch (_) { /* Continuar liberación. */ }
      }
      try { await recorder.dispose(); } catch (_) { /* Pantalla cerrada. */ }
    }());
    super.dispose();
  }
}
