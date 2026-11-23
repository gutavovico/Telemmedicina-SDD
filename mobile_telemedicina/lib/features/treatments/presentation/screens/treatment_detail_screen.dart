import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/treatment_entities.dart';
import '../providers/treatment_provider.dart';
import '../widgets/adherencia_card.dart';
import '../widgets/treatment_status_badge.dart';

/// Pantalla de detalle estructurado del plan de tratamiento médico (CU17).
class TreatmentDetailScreen extends StatefulWidget {
  final int? idTratamiento;

  const TreatmentDetailScreen({super.key, this.idTratamiento});

  @override
  State<TreatmentDetailScreen> createState() => _TreatmentDetailScreenState();
}

class _TreatmentDetailScreenState extends State<TreatmentDetailScreen> {
  int? _resolvedId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_resolvedId == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is int) {
        _resolvedId = args;
      } else if (widget.idTratamiento != null) {
        _resolvedId = widget.idTratamiento;
      }

      if (_resolvedId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.read<TreatmentProvider>().loadTreatmentDetail(_resolvedId!);
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    if (_resolvedId != null) {
      await context.read<TreatmentProvider>().loadTreatmentDetail(_resolvedId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TreatmentProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Detalle del Tratamiento'),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Actualizar detalle',
            onPressed: _onRefresh,
          ),
        ],
      ),
      body: _buildBody(provider),
      bottomNavigationBar: _buildBottomBar(provider),
    );
  }

  Widget _buildBody(TreatmentProvider provider) {
    switch (provider.detailStatus) {
      case TreatmentDetailStatus.initial:
      case TreatmentDetailStatus.loading:
        return const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );
      case TreatmentDetailStatus.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.error,
                  size: 52,
                ),
                const SizedBox(height: 16),
                Text(
                  'No se pudo cargar el detalle del tratamiento',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  provider.detailError ?? 'Error de conexión',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _onRefresh,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  label: const Text('Reintentar', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        );
      case TreatmentDetailStatus.loaded:
        final plan = provider.selectedTreatment;
        if (plan == null) {
          return const Center(child: Text('Tratamiento no encontrado'));
        }
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _onRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado del plan
                _buildPlanHeader(plan),
                const SizedBox(height: 16),

                // Semáforo de Adherencia
                AdherenciaCard(
                  adherencia: provider.adherencia ?? plan.adherencia,
                ),
                const SizedBox(height: 16),

                // Notas clínicas si existen
                if (plan.notas != null && plan.notas!.trim().isNotEmpty) ...[
                  _buildNotesCard('Notas del plan', plan.notas!),
                  const SizedBox(height: 16),
                ],

                // Motivo de cierre si existe
                if (plan.motivoCierre != null && plan.motivoCierre!.trim().isNotEmpty) ...[
                  _buildNotesCard(
                    'Motivo de finalización / suspensión',
                    plan.motivoCierre!,
                    isWarning: true,
                  ),
                  const SizedBox(height: 16),
                ],

                // Lista de Medicamentos
                Text(
                  'Medicamentos y Pautas Horarias',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),

                if (plan.medicamentos.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: const Text(
                      'Este plan terapéutico no incluye prescripción farmacológica.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  )
                else
                  ...plan.medicamentos.map(_buildMedicamentoCard),

                const SizedBox(height: 40),
              ],
            ),
          ),
        );
    }
  }

  Widget _buildPlanHeader(TreatmentPlan plan) {
    final diag = plan.diagnostico;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      diag != null && diag.codigoCie != null
                          ? '[${diag.codigoCie}] ${diag.descripcion ?? ''}'
                          : diag?.descripcion ?? 'Plan Médico',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Identificador del Plan: #${plan.idTratamiento}',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TreatmentPlanStatusBadge(status: plan.estado),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 12),

          _buildInfoRow(
            icon: Icons.calendar_month_outlined,
            label: 'Período de vigencia',
            value: '${_formatDate(plan.fechaInicio)} — ${_formatDate(plan.fechaFin)}',
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            icon: Icons.public_rounded,
            label: 'Zona horaria del plan',
            value: plan.zonaHoraria,
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            icon: Icons.medical_services_outlined,
            label: 'Médico tratante',
            value: 'Dr. (ID: #${plan.idMedico})',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotesCard(String title, String notes, {bool isWarning = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isWarning ? AppColors.warningContainer.withValues(alpha: 0.3) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isWarning ? AppColors.onWarning.withValues(alpha: 0.4) : AppColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isWarning ? Icons.warning_amber_rounded : Icons.notes_rounded,
                size: 16,
                color: isWarning ? AppColors.onWarning : AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isWarning ? AppColors.onWarning : AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            notes,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicamentoCard(MedicamentoPlan med) {
    final isSuspended = med.estaSuspendido;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isSuspended ? AppColors.error.withValues(alpha: 0.3) : AppColors.divider,
        ),
      ),
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    med.medicamentoNombre,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isSuspended ? AppColors.textSecondary : AppColors.primary,
                      decoration: isSuspended ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isSuspended ? AppColors.errorContainer : AppColors.successContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    med.estado,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isSuspended ? AppColors.error : AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Posología
            Text(
              '${med.dosis} · Vía: ${med.viaAdministracion}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),

            // Horas locales
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.alarm_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Tomas diarias: ${med.horasLocales.join(', ')}'
                      '${med.intervaloHoras != null ? ' (cada ${med.intervaloHoras} hrs)' : ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (med.indicaciones != null && med.indicaciones!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Indicaciones: ${med.indicaciones}',
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget? _buildBottomBar(TreatmentProvider provider) {
    final plan = provider.selectedTreatment;
    if (plan == null) return null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).pushNamed(
              '/tratamientos/cronograma',
              arguments: plan.idTratamiento,
            );
          },
          icon: const Icon(Icons.event_note_rounded, color: Colors.white),
          label: const Text(
            'Ver Cronograma de Tomas',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
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
}
