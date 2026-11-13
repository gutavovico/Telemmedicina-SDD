import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/treatment_entities.dart';
import '../providers/treatment_provider.dart';
import '../widgets/treatment_status_badge.dart';

/// Pantalla principal: Listado de tratamientos médicos del paciente (CU17).
class TreatmentsListScreen extends StatefulWidget {
  const TreatmentsListScreen({super.key});

  @override
  State<TreatmentsListScreen> createState() => _TreatmentsListScreenState();
}

class _TreatmentsListScreenState extends State<TreatmentsListScreen> {
  String? _selectedFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<TreatmentProvider>();
      provider.loadTreatments(refresh: true);
      provider.loadAvisos();
    });
  }

  Future<void> _onRefresh() async {
    final provider = context.read<TreatmentProvider>();
    await Future.wait([
      provider.loadTreatments(refresh: true, estado: _selectedFilter),
      provider.loadAvisos(),
    ]);
  }

  void _applyFilter(String? filter) {
    setState(() => _selectedFilter = filter);
    context.read<TreatmentProvider>().loadTreatments(
          refresh: false,
          estado: filter,
        );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TreatmentProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mis Tratamientos'),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          // Botón de Avisos con badge de no leídos
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                tooltip: 'Bandeja de avisos',
                onPressed: () {
                  Navigator.of(context).pushNamed('/tratamientos/avisos');
                },
              ),
              if (provider.unreadAvisosCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Center(
                      child: Text(
                        provider.unreadAvisosCount > 99
                            ? '99+'
                            : '${provider.unreadAvisosCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          _buildFilterBar(),

          // List Body
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _onRefresh,
              child: _buildBody(provider),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(
              label: 'Todos',
              isSelected: _selectedFilter == null,
              onTap: () => _applyFilter(null),
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: 'Activos',
              isSelected: _selectedFilter == 'ACTIVO',
              onTap: () => _applyFilter('ACTIVO'),
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: 'Finalizados',
              isSelected: _selectedFilter == 'FINALIZADO',
              onTap: () => _applyFilter('FINALIZADO'),
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: 'Suspendidos',
              isSelected: _selectedFilter == 'SUSPENDIDO_POR_RECETA',
              onTap: () => _applyFilter('SUSPENDIDO_POR_RECETA'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surfaceVariant,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.outline,
        ),
      ),
    );
  }

  Widget _buildBody(TreatmentProvider provider) {
    switch (provider.listStatus) {
      case TreatmentListStatus.initial:
      case TreatmentListStatus.loading:
        return const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );
      case TreatmentListStatus.error:
        return _buildErrorState(provider);
      case TreatmentListStatus.empty:
        return _buildEmptyState();
      case TreatmentListStatus.loaded:
        return _buildListView(provider);
    }
  }

  Widget _buildErrorState(TreatmentProvider provider) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.15),
        Center(
          child: Column(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 54,
              ),
              const SizedBox(height: 16),
              Text(
                'No se pudieron cargar los tratamientos',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                provider.listError ?? 'Error de conexión',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => provider.loadTreatments(refresh: true),
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                label: const Text('Reintentar', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.15),
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.healing_rounded,
                  color: AppColors.primary,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No tienes tratamientos registrados',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Los planes y esquemas de medicación indicados por tu médico tratante aparecerán aquí.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildListView(TreatmentProvider provider) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: provider.treatments.length,
      itemBuilder: (context, index) {
        final plan = provider.treatments[index];
        return _buildTreatmentCard(plan);
      },
    );
  }

  Widget _buildTreatmentCard(TreatmentPlan plan) {
    final diag = plan.diagnostico;
    final diagTitle = diag != null
        ? '${diag.codigoCie != null ? '[${diag.codigoCie}] ' : ''}${diag.descripcion ?? 'Diagnóstico clínico'}'
        : 'Plan de Tratamiento';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.divider),
      ),
      elevation: 0,
      color: Colors.white,
      child: InkWell(
        onTap: () {
          Navigator.of(context).pushNamed(
            '/tratamientos/detalle',
            arguments: plan.idTratamiento,
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con diagnóstico y badge de estado
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          diagTitle,
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            fontSize: 15,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Plan #${plan.idTratamiento}',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TreatmentPlanStatusBadge(status: plan.estado),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: 12),

              // Rango de fechas
              Row(
                children: [
                  const Icon(
                    Icons.date_range_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_formatDate(plan.fechaInicio)} — ${_formatDate(plan.fechaFin)}',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Zona horaria
              Row(
                children: [
                  const Icon(
                    Icons.public_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Zona horaria: ${plan.zonaHoraria}',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Medicamentos y adherencia chip
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.medication_outlined,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${plan.medicamentos.length} medicamento${plan.medicamentos.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (plan.adherencia?.porcentaje != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _adherenciaColor(plan.adherencia!.nivel).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Adherencia: ${plan.adherencia!.porcentaje!.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _adherenciaColor(plan.adherencia!.nivel),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(String iso) {
    try {
      final parts = iso.split('-');
      if (parts.length == 3) {
        return '${parts[2]}/${parts[1]}/${parts[0]}';
      }
      return iso;
    } catch (_) {
      return iso;
    }
  }

  static Color _adherenciaColor(String nivel) {
    switch (nivel.toUpperCase()) {
      case 'OPTIMA':
        return AppColors.success;
      case 'REGULAR':
        return const Color(0xFFD97706);
      case 'CRITICA':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }
}
