import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/clinical_documents_provider.dart';

/// Pantalla de visualización segura de un documento clínico (CU12).
/// Muestra metadatos, visor PDF y acciones de descarga/compartir.
class DocumentViewerScreen extends StatefulWidget {
  final int documentId;

  const DocumentViewerScreen({super.key, required this.documentId});

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  Uint8List? _pdfBytes;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  Future<void> _loadAll() async {
    final provider = context.read<ClinicalDocumentsProvider>();

    // 1. Cargar detalle del documento (metadatos)
    await provider.loadDetail(widget.documentId);

    // 2. Descargar PDF
    if (mounted) {
      final bytes = await provider.downloadDocument(widget.documentId);
      if (mounted) {
        setState(() => _pdfBytes = bytes);
      }
    }
  }

  Future<void> _handleDownload() async {
    if (_pdfBytes == null || _isDownloading) return;

    setState(() {
      _isDownloading = true;
    });

    try {
      final bytes = _pdfBytes!;
      if (bytes.isEmpty) throw StateError('El PDF está vacío.');
      final name = 'documento_clinico_${widget.documentId}';
      final saved = kIsWeb
          ? await FileSaver.instance.saveFile(
              name: name, bytes: bytes, fileExtension: 'pdf',
              mimeType: MimeType.pdf,
            )
          : await FileSaver.instance.saveAs(
              name: name, bytes: bytes, fileExtension: 'pdf',
              mimeType: MimeType.pdf,
            );
      if (saved == null) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF guardado correctamente.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar el PDF. Intenta nuevamente.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Detalle Documento',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Consumer<ClinicalDocumentsProvider>(
        builder: (context, provider, _) {
          final document = provider.selectedDocument;

          if (document == null) {
            return _buildLoading();
          }

          return Column(
            children: [
              // 1. Información del documento
              _buildDocumentInfoCard(document),

              // 2. Visor PDF
              Expanded(
                child: _buildPdfViewer(),
              ),

              // 3. Botones de acción
              if (_pdfBytes != null) _buildActionButtons(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            'Cargando documento...',
            style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentInfoCard(dynamic document) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tipo de documento badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getTipoColor(document.tipoDocumento).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getTipoLabel(document.tipoDocumento),
                  style: AppTypography.bodySmall.copyWith(
                    color: _getTipoColor(document.tipoDocumento),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: document.estaActivo
                      ? AppColors.successContainer
                      : AppColors.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  document.estado.replaceAll('_', ' '),
                  style: AppTypography.bodySmall.copyWith(
                    color: document.estaActivo ? AppColors.success : AppColors.error,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Título
          Text(
            document.titulo,
            style: AppTypography.titleMedium.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),

          // Descripción
          if (document.descripcion != null && document.descripcion!.isNotEmpty) ...[
            Text(
              document.descripcion!,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
          ],

          // Metadatos en grid
          Row(
            children: [
              Expanded(
                child: _buildMetaItem(
                  icon: Icons.person_outline_rounded,
                  label: 'Paciente',
                  value: document.pacienteNombre ?? '—',
                ),
              ),
              Expanded(
                child: _buildMetaItem(
                  icon: Icons.medical_services_outlined,
                  label: 'Médico',
                  value: document.firmanteNombre ?? '—',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetaItem(
                  icon: Icons.calendar_today_rounded,
                  label: 'Fecha',
                  value: _formatFecha(document.fechaDocumento),
                ),
              ),
              Expanded(
                child: _buildMetaItem(
                  icon: Icons.fingerprint_rounded,
                  label: 'Hash SHA-256',
                  value: '${document.idDocumento}', // placeholder si no hay hash en entidad
                  isSmall: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaItem({
    required IconData icon,
    required String label,
    required String value,
    bool isSmall = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: isSmall ? 14 : 16, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textMuted,
                fontSize: isSmall ? 10 : 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.bodyMedium.copyWith(
            fontSize: isSmall ? 11 : 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildPdfViewer() {
    if (_pdfBytes != null) {
      return SfPdfViewer.memory(
        _pdfBytes!,
        canShowScrollHead: false,
        canShowPaginationDialog: true,
        enableDoubleTapZooming: true,
        initialZoomLevel: 100,
        pageLayoutMode: PdfPageLayoutMode.single,
      );
    }

    return Consumer<ClinicalDocumentsProvider>(
      builder: (context, provider, _) {
        if (provider.isViewerLoading) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 16),
                Text(
                  'Procesando PDF...',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          );
        }

        if (provider.errorMessage != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text(
                    provider.errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _loadAll,
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
        }

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                'Descargando documento de forma segura...',
                style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButtons() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.divider, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Botón Descargar (primario)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isDownloading ? null : _handleDownload,
              icon: _isDownloading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.download_rounded, size: 20),
              label: Text(_isDownloading ? 'Descargando...' : 'Descargar PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: AppTypography.labelLarge.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Botón Compartir (outline)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _pdfBytes == null ? null : _handleShare,
              icon: const Icon(Icons.share_rounded, size: 20),
              label: const Text('Compartir'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: AppTypography.labelLarge.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleShare() async {
    if (_pdfBytes == null) return;
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(
        _pdfBytes!,
        name: 'documento_clinico_${widget.documentId}.pdf',
        mimeType: 'application/pdf',
      )],
      text: 'Documento clínico',
    ));
  }

  Color _getTipoColor(String tipo) {
    switch (tipo) {
      case 'RECETA':
        return const Color(0xFF0284C7); // Sky blue
      case 'ORDEN_LAB':
        return const Color(0xFF7C3AED); // Violet
      case 'RESULTADO_LAB':
        return const Color(0xFF059669); // Emerald
      case 'CERTIFICADO':
        return const Color(0xFFD97706); // Amber
      case 'INDICACION':
        return const Color(0xFFDC2626); // Red
      default:
        return AppColors.primary;
    }
  }

  String _getTipoLabel(String tipo) {
    switch (tipo) {
      case 'RECETA':
        return 'Receta';
      case 'ORDEN_LAB':
        return 'Orden Lab.';
      case 'RESULTADO_LAB':
        return 'Resultado Lab.';
      case 'CERTIFICADO':
        return 'Certificado';
      case 'INDICACION':
        return 'Indicación';
      default:
        return tipo;
    }
  }

  String _formatFecha(String fecha) {
    try {
      final parsed = DateTime.parse(fecha);
      return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
    } catch (_) {
      return fecha;
    }
  }
}
