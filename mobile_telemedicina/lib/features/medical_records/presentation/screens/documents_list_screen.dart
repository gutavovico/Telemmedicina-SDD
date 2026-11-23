import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../medical_records/domain/entities/clinical_document.dart';
import '../providers/clinical_documents_provider.dart';
import 'document_viewer_screen.dart';
import 'lab_results_list_screen.dart';

/// Pantalla de listado de documentos clínicos del paciente (CU12).
/// Consulta `/api/v1/documentos/me` con filtro por tipo de documento.
class DocumentsListScreen extends StatefulWidget {
  const DocumentsListScreen({super.key});

  @override
  State<DocumentsListScreen> createState() => _DocumentsListScreenState();
}

class _DocumentsListScreenState extends State<DocumentsListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClinicalDocumentsProvider>().loadDocuments(
        authController: context.read<AuthController>(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Mis Documentos Clínicos',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
      ),
      body: Consumer<ClinicalDocumentsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.documents == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final errorMessage = provider.errorMessage;
          if (errorMessage != null && provider.documents == null) {
            return _buildError(errorMessage, provider);
          }

          final docs = provider.documents ?? const <ClinicalDocument>[];
          return Column(
            children: [
              _buildFiltroTipos(provider),
              Expanded(
                child: docs.isEmpty
                    ? _buildEmpty(provider)
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: () => provider.loadDocuments(),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: docs.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) =>
                              _DocumentoCard(document: docs[index]),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFiltroTipos(ClinicalDocumentsProvider provider) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('Todos'),
              selected: provider.activeTipoDocumento == null,
              onSelected: (_) => provider.setTipoDocumento(null),
              showCheckmark: false,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: provider.activeTipoDocumento == null
                    ? Colors.white
                    : AppColors.textPrimary,
              ),
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.surface,
              side: BorderSide(color: AppColors.outline, width: 1),
            ),
          ),
          for (final entry in _tipoEtiquetas.entries)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(entry.value),
                selected: provider.activeTipoDocumento == entry.key,
                onSelected: (_) {
                  if (entry.key == 'RESULTADO_LAB') {
                    // CU11: los resultados de laboratorio tienen su propia pantalla.
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LabResultsListScreen()),
                    );
                    return;
                  }
                  provider.setTipoDocumento(
                    provider.activeTipoDocumento == entry.key ? null : entry.key,
                  );
                },
                showCheckmark: false,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: provider.activeTipoDocumento == entry.key
                      ? Colors.white
                      : AppColors.textPrimary,
                ),
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.surface,
                side: BorderSide(color: AppColors.outline, width: 1),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildError(String message, ClinicalDocumentsProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => provider.loadDocuments(),
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

  Widget _buildEmpty(ClinicalDocumentsProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description_outlined,
              size: 56,
              color: AppColors.textMuted.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            const Text(
              'No se encontraron documentos clínicos.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => provider.loadDocuments(),
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentoCard extends StatelessWidget {
  final ClinicalDocument document;

  const _DocumentoCard({required this.document});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.divider, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DocumentViewerScreen(documentId: document.idDocumento),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: AppColors.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.titulo,
                      style: AppTypography.titleMedium.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.tealAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _tipoEtiquetas[document.tipoDocumento] ?? document.tipoDocumento,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _formatearFecha(document.fechaDocumento),
                            style: AppTypography.bodySmall.copyWith(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatearFecha(String fecha) {
  try {
    final parsed = DateTime.parse(fecha);
    return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  } catch (_) {
    return fecha;
  }
}

const Map<String, String> _tipoEtiquetas = {
  'RECETA': 'Recetas',
  'ORDEN_LAB': 'Órdenes de Lab.',
  'RESULTADO_LAB': 'Resultados de Lab.',
  'CERTIFICADO': 'Certificados',
  'INDICACION': 'Indicaciones',
};