import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/laboratory_result.dart';
import '../../domain/repositories/laboratory_result_repository.dart';
import '../../domain/usecases/get_my_lab_results_usecase.dart';
import '../providers/laboratory_results_provider.dart';
import '../services/lab_result_temp_storage.dart';
import '../widgets/lab_result_status_badge.dart';
import 'lab_result_viewer_screen.dart';

/// Listado de resultados de laboratorio del paciente (CU11, solo lectura).
/// Consulta `GET /api/v1/resultados-laboratorio/me`. Trae su propio provider:
/// no depende ni modifica `ClinicalDocumentsProvider` (CU12).
class LabResultsListScreen extends StatefulWidget {
  final LaboratoryResultRepository? repository;
  final LabResultTempStorage? tempStorage;
  final LabPdfViewerBuilder? pdfViewerBuilder;

  const LabResultsListScreen({
    super.key,
    this.repository,
    this.tempStorage,
    this.pdfViewerBuilder,
  });

  @override
  State<LabResultsListScreen> createState() => _LabResultsListScreenState();
}

class _LabResultsListScreenState extends State<LabResultsListScreen> {
  late final LaboratoryResultsProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = LaboratoryResultsProvider(
      getMyResults: GetMyLabResultsUseCase(repository: widget.repository),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _provider.load());
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LaboratoryResultsProvider>.value(
      value: _provider,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'Resultados de Laboratorio',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          backgroundColor: AppColors.surface,
          elevation: 0,
          centerTitle: true,
        ),
        body: Consumer<LaboratoryResultsProvider>(
          builder: (context, provider, _) {
            switch (provider.status) {
              case LabResultsStatus.initial:
              case LabResultsStatus.loading:
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              case LabResultsStatus.error:
                return _buildError(provider);
              case LabResultsStatus.success:
                return provider.isEmpty ? _buildEmpty(provider) : _buildList(provider);
            }
          },
        ),
      ),
    );
  }

  Widget _buildList(LaboratoryResultsProvider provider) {
    final items = provider.items;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 200) provider.loadMore();
        return false;
      },
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: provider.load,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: items.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index == items.length) return _buildFooter(provider);
            return _ResultCard(
              result: items[index],
              onTap: () => _openViewer(items[index]),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFooter(LaboratoryResultsProvider provider) {
    if (provider.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
          ),
        ),
      );
    }
    final error = provider.loadMoreError;
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
            TextButton(onPressed: provider.loadMore, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildError(LaboratoryResultsProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              provider.errorMessage ?? 'No se pudieron cargar tus resultados.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: provider.load,
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

  Widget _buildEmpty(LaboratoryResultsProvider provider) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: provider.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Icon(
            Icons.science_outlined,
            size: 56,
            color: AppColors.textMuted.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Aún no tienes resultados de laboratorio disponibles.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: OutlinedButton.icon(
              onPressed: provider.load,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar'),
            ),
          ),
        ],
      ),
    );
  }

  void _openViewer(LaboratoryResult result) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LabResultViewerScreen(
          result: result,
          repository: widget.repository,
          tempStorage: widget.tempStorage,
          pdfViewerBuilder: widget.pdfViewerBuilder,
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final LaboratoryResult result;
  final VoidCallback onTap;

  const _ResultCard({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isPdf = result.contentType == 'application/pdf';
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
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
                child: Icon(
                  isPdf ? Icons.picture_as_pdf_rounded : Icons.image_outlined,
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
                      result.estudio,
                      style: AppTypography.titleMedium.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      result.laboratorioOrigen,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        LabResultStatusBadge(status: result.estado),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            formatLabDate(result.fechaRealizacion),
                            textAlign: TextAlign.right,
                            style: AppTypography.bodySmall.copyWith(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
