import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/laboratory_result.dart';
import '../../domain/repositories/laboratory_result_repository.dart';
import '../../domain/usecases/download_lab_result_usecase.dart';
import '../providers/lab_result_file_controller.dart';
import '../services/lab_result_temp_storage.dart';
import '../widgets/lab_result_status_badge.dart';

/// Construye el visor de PDF (inyectable para pruebas, donde Syncfusion no se puede renderizar).
typedef LabPdfViewerBuilder = Widget Function(
  BuildContext context,
  LabResultFileController controller,
);

/// Visor propio de CU11: descarga el archivo con Bearer, lo guarda en un temporal
/// y lo muestra (PDF con Syncfusion, JPG/PNG con `Image`). Borra el temporal al salir.
/// No reutiliza `DocumentViewerScreen` (CU12).
class LabResultViewerScreen extends StatefulWidget {
  final LaboratoryResult result;
  final LaboratoryResultRepository? repository;
  final LabResultTempStorage? tempStorage;
  final LabPdfViewerBuilder? pdfViewerBuilder;

  const LabResultViewerScreen({
    super.key,
    required this.result,
    this.repository,
    this.tempStorage,
    this.pdfViewerBuilder,
  });

  @override
  State<LabResultViewerScreen> createState() => _LabResultViewerScreenState();
}

class _LabResultViewerScreenState extends State<LabResultViewerScreen> {
  late final LabResultFileController _controller;

  @override
  void initState() {
    super.initState();
    _controller = LabResultFileController(
      idResultado: widget.result.idResultado,
      declaredContentType: widget.result.contentType,
      download: DownloadLabResultUseCase(repository: widget.repository),
      storage: widget.tempStorage,
    );
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose(); // borra el archivo temporal
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    return ChangeNotifierProvider<LabResultFileController>.value(
      value: _controller,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            result.estudio,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          backgroundColor: AppColors.surface,
          elevation: 0,
          centerTitle: true,
        ),
        body: Column(
          children: [
            _MetadataCard(result: result),
            Expanded(
              child: Consumer<LabResultFileController>(
                builder: (context, controller, _) => _buildContent(context, controller),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, LabResultFileController controller) {
    switch (controller.status) {
      case LabResultFileStatus.initial:
      case LabResultFileStatus.loading:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 12),
              Text(
                'Descargando archivo…',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        );
      case LabResultFileStatus.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                const SizedBox(height: 16),
                Text(
                  controller.errorMessage ?? 'No se pudo abrir el archivo.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: controller.load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      case LabResultFileStatus.ready:
        if (controller.kind == LabResultFileKind.pdf) {
          final builder = widget.pdfViewerBuilder;
          if (builder != null) return builder(context, controller);
          final path = controller.filePath;
          if (path != null) return SfPdfViewer.file(File(path));
          return SfPdfViewer.memory(controller.bytes!);
        }
        final path = controller.filePath;
        final image = path != null
            ? Image.file(File(path), fit: BoxFit.contain, errorBuilder: _imageError)
            : Image.memory(controller.bytes!, fit: BoxFit.contain, errorBuilder: _imageError);
        return InteractiveViewer(minScale: 0.5, maxScale: 5, child: Center(child: image));
    }
  }

  Widget _imageError(BuildContext context, Object error, StackTrace? stack) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Text(
        'No se pudo mostrar la imagen.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textSecondary),
      ),
    );
  }
}

class _MetadataCard extends StatelessWidget {
  final LaboratoryResult result;

  const _MetadataCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final observaciones = result.observaciones;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    result.estudio,
                    style: AppTypography.titleMedium.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                LabResultStatusBadge(status: result.estado),
              ],
            ),
            const SizedBox(height: 6),
            _line('Laboratorio', result.laboratorioOrigen),
            _line('Fecha de realización', formatLabDate(result.fechaRealizacion)),
            _line('Archivo', '${result.nombreArchivo} (${formatLabSize(result.tamanoBytes)})'),
            if (observaciones != null && observaciones.trim().isNotEmpty)
              _line('Observaciones', observaciones),
          ],
        ),
      ),
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

/// `YYYY-MM-DD...` -> `DD/MM/YYYY`; si no se puede interpretar, devuelve el texto original.
String formatLabDate(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
}

String formatLabSize(int bytes) {
  if (bytes <= 0) return '—';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
