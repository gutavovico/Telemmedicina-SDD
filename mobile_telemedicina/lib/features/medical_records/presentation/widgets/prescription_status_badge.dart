import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/prescription.dart';

/// Badge semántico del estado visual de una receta.
///
/// Usa exclusivamente tokens `AppColors`/`AppTypography` e incluye
/// texto + icono para no depender únicamente del color.
class PrescriptionStatusBadge extends StatelessWidget {
  final EstadoVisualReceta status;

  const PrescriptionStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final config = _configFor(status);
    return Semantics(
      label: 'Estado de la receta: ${config.label}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: config.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: config.foreground.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(config.icon, size: 16, color: config.foreground),
            const SizedBox(width: 6),
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

class _BadgeConfig {
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;

  const _BadgeConfig({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
  });
}

_BadgeConfig _configFor(EstadoVisualReceta status) {
  switch (status) {
    case EstadoVisualReceta.vigente:
      return const _BadgeConfig(
        label: 'Vigente',
        icon: Icons.check_circle_outline_rounded,
        background: AppColors.successContainer,
        foreground: AppColors.success,
      );
    case EstadoVisualReceta.vencida:
      return const _BadgeConfig(
        label: 'Vencida',
        icon: Icons.schedule_rounded,
        background: AppColors.warningContainer,
        foreground: AppColors.onWarning,
      );
    case EstadoVisualReceta.anulada:
      return const _BadgeConfig(
        label: 'Anulada',
        icon: Icons.cancel_outlined,
        background: AppColors.errorContainer,
        foreground: AppColors.error,
      );
    case EstadoVisualReceta.desconocido:
      return const _BadgeConfig(
        label: 'Desconocido',
        icon: Icons.help_outline_rounded,
        background: AppColors.surfaceVariant,
        foreground: AppColors.textSecondary,
      );
  }
}

/// Etiqueta accesible del estado visual (para pruebas y Semantics).
String prescriptionStatusLabel(EstadoVisualReceta status) {
  switch (status) {
    case EstadoVisualReceta.vigente:
      return 'Vigente';
    case EstadoVisualReceta.vencida:
      return 'Vencida';
    case EstadoVisualReceta.anulada:
      return 'Anulada';
    case EstadoVisualReceta.desconocido:
      return 'Desconocido';
  }
}
