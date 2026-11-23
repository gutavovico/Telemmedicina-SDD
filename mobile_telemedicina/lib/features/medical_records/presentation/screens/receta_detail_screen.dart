import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/prescription.dart';
import '../providers/prescription_provider.dart';
import '../services/prescription_pdf_sharer.dart';
import '../services/system_prescription_pdf_sharer.dart';
import '../utils/prescription_dates.dart';
import '../widgets/prescription_status_badge.dart';

/// Detalle estructurado de una receta propia (CU16, solo lectura).
///
/// Muestra folio, vigencia, médico, medicamentos ordenados por `posicion`,
/// anulación cuando corresponda, integridad colapsable y descarga del PDF.
/// No ofrece acciones de mutación.
class RecetaDetailScreen extends StatefulWidget {
  final int idReceta;
  final PrescriptionPdfSharer? sharer;

  const RecetaDetailScreen({super.key, required this.idReceta, this.sharer});

  @override
  State<RecetaDetailScreen> createState() => _RecetaDetailScreenState();
}

class _RecetaDetailScreenState extends State<RecetaDetailScreen> {
  late final PrescriptionPdfSharer _sharer;

  @override
  void initState() {
    super.initState();
    _sharer = widget.sharer ?? SystemPrescriptionPdfSharer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PrescriptionProvider>().loadDetail(widget.idReceta);
    });
  }

  Future<void> _onDownload(
    BuildContext context,
    PrescriptionProvider provider,
    Prescription prescription,
  ) async {
    final bytes = await provider.downloadPdf(prescription.idReceta);
    if (!context.mounted) return;
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.downloadError ?? 'No se pudo descargar el PDF.',
          ),
        ),
      );
      return;
    }
    try {
      await _sharer.sharePdf(
        bytes: bytes,
        filename: prescriptionPdfFilename(prescription.folio),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF listo para guardar o compartir.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo compartir el PDF. Intenta nuevamente.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Detalle de receta',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
      ),
      body: Consumer<PrescriptionProvider>(
        builder: (context, provider, _) {
          switch (provider.detailStatus) {
            case PrescriptionDetailStatus.initial:
            case PrescriptionDetailStatus.loading:
              return Semantics(
                label: 'Cargando detalle de la receta',
                child: const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              );
            case PrescriptionDetailStatus.error:
              return _buildError(provider);
            case PrescriptionDetailStatus.loaded:
              final prescription = provider.selected;
              if (prescription == null) return _buildError(provider);
              return _buildContent(context, provider, prescription);
          }
        },
      ),
    );
  }

  Widget _buildError(PrescriptionProvider provider) {
    return Semantics(
      label: 'Error al cargar la receta',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AppColors.error,
              ),
              const SizedBox(height: 16),
              Text(
                provider.detailError ??
                    'La receta solicitada no fue encontrada.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyLarge,
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => provider.loadDetail(widget.idReceta),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    PrescriptionProvider provider,
    Prescription prescription,
  ) {
    final downloading =
        provider.downloadStatus == PrescriptionDownloadStatus.downloading;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _headerCard(prescription),
          const SizedBox(height: 12),
          _medicoCard(prescription),
          const SizedBox(height: 12),
          _medicamentosCard(prescription),
          if (prescription.indicacionesGenerales != null &&
              prescription.indicacionesGenerales!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _indicacionesCard(prescription),
          ],
          if (prescription.estaAnulada) ...[
            const SizedBox(height: 12),
            _anulacionCard(prescription),
          ],
          const SizedBox(height: 12),
          _integridadCard(prescription),
          const SizedBox(height: 16),
          Semantics(
            label: 'Descargar PDF de la receta ${prescription.folio}',
            button: true,
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: Tooltip(
                message: 'Descargar PDF de la receta',
                child: ElevatedButton.icon(
                  onPressed: downloading
                      ? null
                      : () => _onDownload(context, provider, prescription),
                  icon: downloading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.onPrimary,
                          ),
                        )
                      : const Icon(Icons.download_rounded),
                  label: Text(
                    downloading ? 'Descargando…' : 'Descargar PDF',
                    style: AppTypography.button,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    disabledBackgroundColor: AppColors.primary.withValues(
                      alpha: 0.6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (provider.downloadStatus == PrescriptionDownloadStatus.error &&
              provider.downloadError != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Semantics(
                label: 'Error de descarga',
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          provider.downloadError!,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _headerCard(Prescription p) {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  p.folio,
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              PrescriptionStatusBadge(status: p.estadoVisual),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _infoItem(
                  'Fecha de emisión',
                  formatVisibleDate(p.fechaEmision),
                ),
              ),
              Expanded(
                child: _infoItem(
                  'Fecha de vencimiento',
                  formatVisibleDate(p.fechaVencimiento),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _medicoCard(Prescription p) {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Médico emisor',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          _row('Nombre', p.medico.nombreCompleto),
          _row('Matrícula', p.medico.matriculaProfesional),
          _row(
            'Especialidad',
            (p.medico.especialidad == null ||
                    p.medico.especialidad!.trim().isEmpty)
                ? '—'
                : p.medico.especialidad!,
          ),
          _row('Paciente', p.paciente.nombreCompleto),
        ],
      ),
    );
  }

  Widget _medicamentosCard(Prescription p) {
    final detalles = p.detallesOrdenados;
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Medicamentos (${detalles.length})',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          if (detalles.isEmpty)
            Text(
              'Sin medicamentos registrados.',
              style: AppTypography.bodyMedium,
            ),
          for (var i = 0; i < detalles.length; i++) ...[
            _medicamentoItem(detalles[i], i + 1),
            if (i < detalles.length - 1) const Divider(height: 20),
          ],
        ],
      ),
    );
  }

  Widget _medicamentoItem(PrescriptionDetalle d, int numero) {
    return Semantics(
      label: 'Medicamento $numero: ${d.medicamentoNombre}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$numero',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  d.medicamentoNombre,
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (d.principioActivo != null && d.principioActivo!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Principio activo: ${d.principioActivo}'
                '${(d.concentracion != null && d.concentracion!.isNotEmpty) ? ' · ${d.concentracion}' : ''}',
                style: AppTypography.bodySmall,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            )
          else if (d.concentracion != null && d.concentracion!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Concentración: ${d.concentracion}',
                style: AppTypography.bodySmall,
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('Dosis: ${d.dosis}'),
              _chip('Frecuencia: ${d.frecuencia}'),
              _chip('Duración: ${d.duracion}'),
              _chip('Vía: ${d.viaAdministracion}'),
              _chip('Cantidad: ${d.cantidad}'),
            ],
          ),
          if (d.indicaciones != null && d.indicaciones!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Indicaciones: ${d.indicaciones}',
                style: AppTypography.bodyMedium,
              ),
            ),
        ],
      ),
    );
  }

  Widget _indicacionesCard(Prescription p) {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Indicaciones generales',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            p.indicacionesGenerales!,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _anulacionCard(Prescription p) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.cancel_outlined, color: AppColors.error, size: 20),
              SizedBox(width: 8),
              Text(
                'Receta anulada',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _row('Motivo', p.motivoAnulacion ?? '—'),
          _row('Observaciones', p.observacionesAnulacion ?? '—'),
          _row(
            'Fecha de anulación',
            p.fechaAnulacion == null
                ? '—'
                : formatVisibleDate(p.fechaAnulacion!),
          ),
        ],
      ),
    );
  }

  Widget _integridadCard(Prescription p) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Theme(
          // Colors.transparent solo aquí: ExpansionTile dibuja un divider por
          // defecto y no existe token para "sin divider". Se documenta el uso.
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              'Datos de integridad',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            subtitle: Text(
              'Información técnica de la firma digital',
              style: AppTypography.bodySmall,
            ),
            children: [
              _row('Algoritmo', p.algoritmoFirma),
              _row('Key ID', p.keyId),
              _row('Versión', '${p.versionPayload}'),
              _row('Hash', p.hashPdf),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: child,
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: AppTypography.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.bodySmall.copyWith(fontSize: 11)),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Text(
        text,
        style: AppTypography.bodySmall.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
