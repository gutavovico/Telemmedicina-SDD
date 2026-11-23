import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Badge visual para el estado del plan de tratamiento médico (CU17).
///
/// Estados contemplados: `ACTIVO`, `FINALIZADO`, `SUSPENDIDO_POR_RECETA`.
class TreatmentPlanStatusBadge extends StatelessWidget {
  final String status;

  const TreatmentPlanStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final config = _planConfigFor(status);
    return Semantics(
      label: 'Estado del tratamiento: ${config.label}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: config.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: config.foreground.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(config.icon, size: 14, color: config.foreground),
            const SizedBox(width: 5),
            Text(
              config.label,
              style: AppTypography.bodySmall.copyWith(
                color: config.foreground,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Badge visual para el estado de una dosis programada (CU17).
///
/// Estados contemplados: `PENDIENTE`, `INGERIDA`, `OMITIDA`, `POSPUESTA`, `VENCIDA`.
class DoseStatusBadge extends StatelessWidget {
  final String status;
  final bool isVencida;

  const DoseStatusBadge({
    super.key,
    required this.status,
    this.isVencida = false,
  });

  @override
  Widget build(BuildContext context) {
    final config = _doseConfigFor(status, isVencida: isVencida);
    return Semantics(
      label: 'Estado de la toma: ${config.label}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: config.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: config.foreground.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(config.icon, size: 13, color: config.foreground),
            const SizedBox(width: 5),
            Text(
              config.label,
              style: AppTypography.bodySmall.copyWith(
                color: config.foreground,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Badge visual para indicar si una dosis ingerida fue puntual o fuera de ventana.
class DosePuntualidadBadge extends StatelessWidget {
  final bool puntual;

  const DosePuntualidadBadge({super.key, required this.puntual});

  @override
  Widget build(BuildContext context) {
    final config = puntual ? _puntualConfig : _fueraVentanaConfig;
    return Semantics(
      label: 'Puntualidad: ${config.label}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: config.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: config.foreground.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(config.icon, size: 12, color: config.foreground),
            const SizedBox(width: 4),
            Text(
              config.label,
              style: AppTypography.bodySmall.copyWith(
                color: config.foreground,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadgeConfig {
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;

  const _StatusBadgeConfig({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
  });
}

_StatusBadgeConfig _planConfigFor(String rawStatus) {
  final normalized = rawStatus.trim().toUpperCase();
  switch (normalized) {
    case 'ACTIVO':
      return const _StatusBadgeConfig(
        label: 'Activo',
        icon: Icons.check_circle_outline_rounded,
        background: AppColors.successContainer,
        foreground: AppColors.success,
      );
    case 'FINALIZADO':
      return const _StatusBadgeConfig(
        label: 'Finalizado',
        icon: Icons.done_all_rounded,
        background: AppColors.surfaceVariant,
        foreground: AppColors.textSecondary,
      );
    case 'SUSPENDIDO_POR_RECETA':
      return const _StatusBadgeConfig(
        label: 'Suspendido por receta',
        icon: Icons.block_rounded,
        background: AppColors.errorContainer,
        foreground: AppColors.error,
      );
    default:
      return _StatusBadgeConfig(
        label: rawStatus.isEmpty ? 'Desconocido' : rawStatus,
        icon: Icons.help_outline_rounded,
        background: AppColors.surfaceVariant,
        foreground: AppColors.textSecondary,
      );
  }
}

_StatusBadgeConfig _doseConfigFor(String rawStatus, {bool isVencida = false}) {
  final normalized = rawStatus.trim().toUpperCase();
  if (isVencida && (normalized == 'PENDIENTE' || normalized == 'VENCIDA')) {
    return const _StatusBadgeConfig(
      label: 'Vencida',
      icon: Icons.schedule_rounded,
      background: AppColors.warningContainer,
      foreground: AppColors.onWarning,
    );
  }

  switch (normalized) {
    case 'PENDIENTE':
      return const _StatusBadgeConfig(
        label: 'Pendiente',
        icon: Icons.hourglass_empty_rounded,
        background: AppColors.primaryLight,
        foreground: AppColors.primary,
      );
    case 'INGERIDA':
      return const _StatusBadgeConfig(
        label: 'Ingerida',
        icon: Icons.check_circle_rounded,
        background: AppColors.successContainer,
        foreground: AppColors.success,
      );
    case 'OMITIDA':
      return const _StatusBadgeConfig(
        label: 'Omitida',
        icon: Icons.cancel_rounded,
        background: AppColors.errorContainer,
        foreground: AppColors.error,
      );
    case 'POSPUESTA':
      return const _StatusBadgeConfig(
        label: 'Pospuesta',
        icon: Icons.update_rounded,
        background: AppColors.warningContainer,
        foreground: AppColors.onWarning,
      );
    case 'VENCIDA':
      return const _StatusBadgeConfig(
        label: 'Vencida',
        icon: Icons.schedule_rounded,
        background: AppColors.warningContainer,
        foreground: AppColors.onWarning,
      );
    default:
      return _StatusBadgeConfig(
        label: rawStatus.isEmpty ? 'Desconocido' : rawStatus,
        icon: Icons.help_outline_rounded,
        background: AppColors.surfaceVariant,
        foreground: AppColors.textSecondary,
      );
  }
}

const _puntualConfig = _StatusBadgeConfig(
  label: 'Puntual',
  icon: Icons.alarm_on_rounded,
  background: AppColors.successContainer,
  foreground: AppColors.success,
);

const _fueraVentanaConfig = _StatusBadgeConfig(
  label: 'Fuera de ventana',
  icon: Icons.alarm_off_rounded,
  background: AppColors.warningContainer,
  foreground: AppColors.onWarning,
);
