import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/models/report_models.dart';
import '../controllers/reports_controller.dart';

const _states = ['PENDIENTE', 'CONFIRMADA', 'COMPLETADA', 'FINALIZADA', 'CANCELADA'];
const _labels = <String, String>{
  'fecha': 'Fecha', 'id_medico': 'Médico', 'id_especialidad': 'Especialidad',
  'estado': 'Estado', 'modalidad': 'Modalidad', 'encuentros': 'Encuentros',
  'citas': 'Citas', 'cancelaciones': 'Cancelaciones',
  'pacientes_unicos': 'Pacientes únicos', 'ausentismo': 'Ausentismo',
};
String _label(String key) => _labels[key] ?? key;

class ReportsScreen extends StatefulWidget {
  final ReportsController? controller;
  const ReportsScreen({super.key, this.controller});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with WidgetsBindingObserver {
  late final AuthController _auth;
  late final ReportsController _reports;
  final TextEditingController _requestInput = TextEditingController();
  late final FocusNode _requestFocus;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthController>();
    _reports = widget.controller ?? ReportsController(
      onUnauthorized: () => _auth.handleReportsUnauthorized(),
      onForbidden: _auth.denyReportsAccess,
    );
    _requestFocus = FocusNode(onKeyEvent: (_, event) {
      if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.enter ||
          HardwareKeyboard.instance.isShiftPressed ||
          !_requestInput.value.composing.isCollapsed) {
        return KeyEventResult.ignored;
      }
      _reports.interpretText(generateAfter: true);
      return KeyEventResult.handled;
    });
    _reports.addListener(_syncRequestText);
    _auth.addListener(_syncSession);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_auth.isCheckingAuth) _auth.checkAuthStatus();
      _syncSession();
    });
  }

  void _syncSession() => _reports.bindAccount(_auth.reportsAccountKey);

  void _syncRequestText() {
    if (_requestInput.text == _reports.requestText) return;
    _requestInput.value = TextEditingValue(text: _reports.requestText,
      selection: TextSelection.collapsed(offset: _reports.requestText.length));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden || state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _reports.cancelVoiceForLifecycle();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _auth.removeListener(_syncSession);
    _reports.removeListener(_syncRequestText);
    _requestFocus.dispose();
    _requestInput.dispose();
    if (widget.controller == null) {
      _reports.dispose();
    } else {
      _reports.cancelVoiceForLifecycle();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Reportes'), backgroundColor: AppColors.surface),
      body: auth.isCheckingAuth ? const Center(child: CircularProgressIndicator())
          : !auth.canAccessReports ? _accessDenied(context)
          : AnimatedBuilder(animation: _reports, builder: (context, _) => _content(context)),
    );
  }

  Widget _accessDenied(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.lock_outline, size: 48, color: AppColors.textSecondary),
        const SizedBox(height: 12),
        Text('Reportes disponibles solo para ADMIN autorizado.',
          textAlign: TextAlign.center, style: AppTypography.titleMedium),
        const SizedBox(height: 16),
        if (AuthController.eligibleForReports(_auth.currentUser))
          TextButton(onPressed: () async {
            if (_auth.isProfileVerified) {
              await _auth.verifyReportsAccess();
            } else {
              await _auth.checkAuthStatus();
            }
          },
            child: const Text('Reintentar autorización')),
        OutlinedButton(onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
          _auth.isAuthenticated ? '/home' : '/login', (_) => false),
          child: const Text('Volver')),
      ])));

  Widget _content(BuildContext context) {
    final c = _reports;
    if (c.loadingCatalog) return const Center(child: CircularProgressIndicator());
    if (c.catalog == null || c.options == null || c.draft == null) {
      return Center(child: Padding(padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(c.error ?? 'No se pudo cargar el catálogo.'),
          const SizedBox(height: 12),
          if (c.account == null)
            OutlinedButton(onPressed: () => Navigator.of(context)
              .pushNamedAndRemoveUntil('/home', (_) => false),
              child: const Text('Volver'))
          else ElevatedButton(onPressed: c.loadCatalog, child: const Text('Reintentar')),
        ])));
    }
    return SingleChildScrollView(padding: const EdgeInsets.all(16),
      child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 900),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _section('Pide un reporte con texto', _request()),
          const SizedBox(height: 16),
          _section('Definición del reporte', _definition()),
          const SizedBox(height: 16),
          if (c.dirty) _notice('La definición cambió. Genera de nuevo para exportar.'),
          if (c.error != null) _notice(c.error!, error: true),
          FilledButton.icon(onPressed: c.loadingReport ? null : c.generate,
            icon: c.loadingReport
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.bar_chart), label: const Text('Generar reporte')),
          if (c.result != null) ...[
            const SizedBox(height: 16), _section('Resultados', _results()),
            const SizedBox(height: 16), _section('Exportar conjunto filtrado', _exports()),
          ],
        ]))));
  }

  Widget _section(String title, Widget child) => Card(color: AppColors.surface,
    elevation: 0, child: Padding(padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12), child,
      ])));

  Widget _notice(String text, {bool error = false}) => Container(
    margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: error ? AppColors.errorContainer : AppColors.warningContainer,
      borderRadius: BorderRadius.circular(10)),
    child: Text(text, style: TextStyle(
      color: error ? AppColors.onErrorContainer : AppColors.onWarning)));

  Widget _request() {
    final c = _reports;
    final voiceActive = c.voiceState != 'idle';
    final canInterpret = !voiceActive && !c.interpreting && !c.loadingReport &&
        c.pendingTranscript == null && c.requestText.trim().isNotEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Describe el reporte y el período. Aplicar filtros configura; Enviar genera el reporte.'),
      const SizedBox(height: 10),
      TextField(controller: _requestInput, focusNode: _requestFocus,
        minLines: 2, maxLines: 5, maxLength: 1000,
        textInputAction: TextInputAction.newline,
        onChanged: c.setRequestText,
        decoration: InputDecoration(labelText: 'Solicitud de reporte',
          hintText: 'Ej.: Citas de septiembre de 2026',
          suffixIcon: c.requestText.isEmpty ? null : IconButton(
            tooltip: 'Limpiar texto', icon: const Icon(Icons.close),
            onPressed: c.canClearText ? () {
              c.clearText();
              _requestFocus.requestFocus();
            } : null)),
      ),
      Text('Enter envía · Shift+Enter añade una línea. En móvil usa las acciones visibles.',
        style: AppTypography.bodySmall),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: c.canToggleVoice ? c.toggleRecording : null,
            icon: Icon(c.voiceState == 'recording' ? Icons.stop_circle_outlined : Icons.mic_none),
            label: Text(c.voiceState == 'recording' ? 'Detener' : 'Micrófono')),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 280),
            child: SwitchListTile.adaptive(contentPadding: EdgeInsets.zero,
              title: const Text('Enviar al terminar'),
              subtitle: const Text('Al detener el dictado, transcribe y genera el reporte'),
              value: c.sendWhenStopped,
              onChanged: c.canToggleAutoSend ? c.setSendWhenStopped : null)),
          OutlinedButton.icon(onPressed: canInterpret
              ? () => c.interpretText(generateAfter: false) : null,
            icon: const Icon(Icons.filter_alt_outlined),
            label: const Text('Aplicar filtros')),
          FilledButton.icon(onPressed: canInterpret
              ? () => c.interpretText(generateAfter: true) : null,
            icon: const Icon(Icons.send), label: const Text('Enviar')),
        ]),
      if (c.voiceState == 'requesting') const Text('Solicitando acceso al micrófono…'),
      if (c.voiceState == 'recording') Text('Grabando · ${c.voiceSeconds}s / 60s'),
      if (c.voiceState == 'transcribing') const Text('Transcribiendo…'),
      if (c.interpreting) const Text('Interpretando…'),
      if (c.voiceError != null) _notice(c.voiceError!, error: true),
      if (c.voiceNotice != null) _notice(c.voiceNotice!),
      if (c.pendingTranscript != null) ...[
        _notice('Dictado pendiente: ${c.pendingTranscript}'),
        Wrap(spacing: 8, children: [
          OutlinedButton(onPressed: c.incorporatePendingTranscript,
            child: const Text('Incorporar dictado')),
          OutlinedButton(onPressed: c.discardPendingTranscript,
            child: const Text('Descartar dictado')),
        ]),
      ],
      if (c.interpretError != null) _notice(c.interpretError!, error: true),
      if (c.interpretation != null) ...[
        _notice('${c.interpretation!.estado == 'valida' ? 'Interpretación aplicada' :
            c.interpretation!.estado == 'aclaracion' ? 'Necesita aclaración' :
            'Solicitud no admitida'}: ${c.interpretation!.resumen}',
          error: c.interpretation!.estado == 'no_admitida'),
        if (c.interpretation!.camposAclaracion.isNotEmpty)
          Text('Revisa: ${c.interpretation!.camposAclaracion.join(', ')}'),
        for (final warning in c.interpretation!.advertencias) _notice(warning),
      ],
    ]);
  }

  Widget _definition() {
    final c = _reports, d = c.draft!, report = c.selectedReport!, catalog = c.catalog!;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      DropdownButtonFormField<String>(initialValue: d.reporte,
        decoration: const InputDecoration(labelText: 'Tipo de reporte'),
        isExpanded: true,
        items: [for (final item in catalog.reportes) DropdownMenuItem(
          value: item.id, child: Text(item.titulo, overflow: TextOverflow.ellipsis))],
        onChanged: (value) {
          if (value != null) {
            c.selectReport(catalog.reportes.firstWhere((item) => item.id == value));
          }
        }),
      const SizedBox(height: 12),
      Text(report.semantica, style: AppTypography.bodySmall),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _dateButton('Desde', d.desde, (value) => c.edit(d.copyWith(desde: value))),
        _dateButton('Hasta', d.hasta, (value) => c.edit(d.copyWith(hasta: value))),
      ]),
      const SizedBox(height: 16),
      Text('Filtros', style: AppTypography.titleMedium),
      const SizedBox(height: 8),
      for (final field in report.filtros) ...[_filter(field, d), const SizedBox(height: 10)],
      Text('Agrupación (máximo ${catalog.limites['agrupaciones']})',
        style: AppTypography.titleMedium),
      Wrap(spacing: 8, children: [for (final field in report.dimensiones)
        FilterChip(label: Text(_label(field)), selected: d.agrupacion.contains(field),
          onSelected: (selected) {
            final groups = [...d.agrupacion], columns = [...d.columnas];
            if (selected) {
              if (groups.length >= (catalog.limites['agrupaciones'] ?? 2) ||
                  columns.length >= (catalog.limites['columnas'] ?? 6)) {
                return;
              }
              groups.add(field);
              if (!columns.contains(field)) columns.insert(0, field);
            } else { groups.remove(field); columns.remove(field); }
            c.edit(d.copyWith(agrupacion: groups, columnas: columns,
              orden: d.orden.where((item) => item.campo != field || selected).toList()));
          })]),
      const SizedBox(height: 12),
      Text('Columnas y posición (máximo ${catalog.limites['columnas']})',
        style: AppTypography.titleMedium),
      Wrap(spacing: 8, children: [for (final field in report.columnas)
        FilterChip(label: Text(_label(field)), selected: d.columnas.contains(field),
          onSelected: field == report.metricaPrincipal || report.dimensiones.contains(field)
            ? null : (selected) {
              final columns = [...d.columnas];
              if (selected) {
                if (columns.length >= (catalog.limites['columnas'] ?? 6)) return;
                columns.add(field);
              } else { columns.remove(field); }
              c.edit(d.copyWith(columnas: columns,
                orden: d.orden.where((item) => item.campo != field || selected).toList()));
            })]),
      for (var i = 0; i < d.columnas.length; i++) _orderedTile(
        _label(d.columnas[i]), i, d.columnas.length, (delta) {
          final values = [...d.columnas], item = values.removeAt(i);
          values.insert(i + delta, item); c.edit(d.copyWith(columnas: values));
        }),
      const SizedBox(height: 12),
      Text('Orden de resultados', style: AppTypography.titleMedium),
      DropdownButtonFormField<String>(
        key: ValueKey('orden-${d.orden.map((item) => item.campo).join('-')}'),
        initialValue: null,
        decoration: const InputDecoration(labelText: 'Agregar criterio de orden'),
        items: [for (final field in d.columnas.where((field) =>
          report.ordenables.contains(field) &&
          !d.orden.any((sort) => sort.campo == field)))
          DropdownMenuItem(value: field, child: Text(_label(field)))],
        onChanged: (value) {
          if (value != null) {
            c.edit(d.copyWith(orden: [...d.orden, ReportSort(value, 'asc')]));
          }
        }),
      for (var i = 0; i < d.orden.length; i++) Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${i + 1}. ${_label(d.orden[i].campo)}'),
        Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
        IconButton(tooltip: 'Prioridad anterior', onPressed: i == 0 ? null : () {
          final sorts = [...d.orden], item = sorts.removeAt(i);
          sorts.insert(i - 1, item); c.edit(d.copyWith(orden: sorts));
        }, icon: const Icon(Icons.arrow_upward, size: 18)),
        IconButton(tooltip: 'Prioridad siguiente', onPressed: i == d.orden.length - 1 ? null : () {
          final sorts = [...d.orden], item = sorts.removeAt(i);
          sorts.insert(i + 1, item); c.edit(d.copyWith(orden: sorts));
        }, icon: const Icon(Icons.arrow_downward, size: 18)),
        TextButton(onPressed: () { final sorts = [...d.orden];
          sorts[i] = ReportSort(sorts[i].campo,
            sorts[i].direccion == 'asc' ? 'desc' : 'asc');
          c.edit(d.copyWith(orden: sorts)); },
          child: Text(d.orden[i].direccion.toUpperCase())),
        IconButton(tooltip: 'Quitar criterio', onPressed: () {
          final sorts = [...d.orden]..removeAt(i); c.edit(d.copyWith(orden: sorts));
        }, icon: const Icon(Icons.close)),
        ]),
      ]),
      DropdownButtonFormField<int>(initialValue: d.tamanoPagina,
        decoration: const InputDecoration(labelText: 'Grupos por página'),
        items: [for (final size in [10, 20, 50, 100].where(
          (size) => size <= (catalog.limites['tamano_pagina'] ?? 100)))
          DropdownMenuItem(value: size, child: Text('$size'))],
        onChanged: (size) { if (size != null) c.edit(d.copyWith(tamanoPagina: size)); }),
    ]);
  }

  Widget _orderedTile(String title, int index, int count, void Function(int) move) =>
    Row(children: [Expanded(child: Text('${index + 1}. $title')),
      IconButton(tooltip: 'Mover arriba', onPressed: index == 0 ? null : () => move(-1),
        icon: const Icon(Icons.arrow_upward, size: 20)),
      IconButton(tooltip: 'Mover abajo', onPressed: index == count - 1 ? null : () => move(1),
        icon: const Icon(Icons.arrow_downward, size: 20))]);

  Widget _dateButton(String label, String value, void Function(String) changed) =>
    OutlinedButton.icon(icon: const Icon(Icons.calendar_month), label: Text('$label: $value'),
      onPressed: () async {
        final account = _reports.account;
        final selected = await showDatePicker(context: context,
          initialDate: DateTime.tryParse(value) ?? DateTime.now(),
          firstDate: DateTime(1), lastDate: DateTime(9999, 12, 31));
        if (!mounted || _reports.account != account) return;
        if (selected != null) {
          changed('${selected.year.toString().padLeft(4, '0')}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}');
        }
      });

  Widget _filter(String field, ReportQuery d) {
    final selected = d.filtros.where((item) => item.campo == field);
    final value = selected.isEmpty ? '' : selected.first.valor.toString();
    final options = <String, String>{'': 'Todos'};
    if (field == 'id_medico') {
      for (final item in _reports.options!.medicos) {
        options['${item['id_medico']}'] = item['nombre'].toString();
      }
    } else if (field == 'id_especialidad') {
      for (final item in _reports.options!.especialidades) {
        options['${item['id_especialidad']}'] = item['nombre'].toString();
      }
    } else if (field == 'modalidad') {
      for (final item in _reports.catalog!.modalidades) { options[item] = item; }
    } else if (field == 'estado') {
      for (final item in _states) { options[item] = item; }
    }
    return DropdownButtonFormField<String>(initialValue: options.containsKey(value) ? value : '',
      decoration: InputDecoration(labelText: _label(field)), isExpanded: true,
      items: [for (final item in options.entries) DropdownMenuItem(
        value: item.key, child: Text(item.value, overflow: TextOverflow.ellipsis))],
      onChanged: (next) {
        if (next == null) return;
        final filters = d.filtros.where((item) => item.campo != field).toList();
        if (next.isNotEmpty) {
          filters.add(ReportFilter(field, field.startsWith('id_') ? int.parse(next) : next));
        }
        _reports.edit(d.copyWith(filtros: filters));
      });
  }

  Widget _results() {
    final c = _reports, result = c.result!;
    final pages = (result.total / result.definicion.tamanoPagina).ceil();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(result.semantica, style: AppTypography.bodySmall),
      const SizedBox(height: 6),
      Text('Generado: ${result.generadoEn} · ${result.total} grupos',
        style: AppTypography.bodySmall),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [for (final entry in result.metricas.entries)
        Tooltip(message: entry.value.causa == 'SIN_ESTADO_AUSENCIA'
          ? 'No hay un estado de ausencia que permita calcularlo.'
          : entry.value.causa ?? _label(entry.key),
          child: Chip(label: Text('${_label(entry.key)}: ${entry.value.display}')))]),
      for (final warning in result.advertencias) _notice(warning),
      if (result.filas.isEmpty) const Padding(padding: EdgeInsets.all(16),
        child: Text('Sin registros para los filtros indicados.'))
      else Scrollbar(child: SingleChildScrollView(scrollDirection: Axis.horizontal,
        child: DataTable(columns: [for (final field in result.definicion.columnas)
          DataColumn(label: Text(_label(field)))],
          rows: [for (final row in result.filas) DataRow(cells: [
            for (final field in result.definicion.columnas)
              DataCell(Text(row[field] == null && field == 'id_especialidad'
                ? (c.catalog!.categoriasNulas[field] ?? '—')
                : (row[field]?.toString() ?? '—'))),
          ])]))),
      if (pages > 1) Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(tooltip: 'Página anterior', onPressed: c.loadingReport ||
          result.definicion.pagina <= 1 || c.dirty ? null
            : () => c.page(result.definicion.pagina - 1),
          icon: const Icon(Icons.chevron_left)),
        Text('${result.definicion.pagina} / $pages'),
        IconButton(tooltip: 'Página siguiente', onPressed: c.loadingReport ||
          result.definicion.pagina >= pages || c.dirty ? null
            : () => c.page(result.definicion.pagina + 1),
          icon: const Icon(Icons.chevron_right)),
      ]),
    ]);
  }

  Widget _exports() {
    final c = _reports;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Incluye todos los grupos filtrados, hasta el límite del servidor.'),
      if (c.exporting) const LinearProgressIndicator(),
      if (c.exportError != null) _notice(c.exportError!, error: true),
      if (c.savedFile != null) Text('Archivo preparado: ${c.savedFile}'),
      Wrap(spacing: 8, runSpacing: 8, children: [for (final format in c.catalog!.formatos)
        OutlinedButton.icon(icon: const Icon(Icons.download),
          label: Text(format.toUpperCase()),
          onPressed: c.canExport ? () => c.export(format) : null)]),
    ]);
  }
}
