import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/laboratory_result.dart';

/// Insignia visible del estado de un resultado de laboratorio (icono + texto, accesible).
class LabResultStatusBadge extends StatelessWidget {
  final LabResultStatus status;

  const LabResultStatusBadge({super.key, required this.status});

  static String labelFor(LabResultStatus status) {
    switch (status) {
      case LabResultStatus.incorporado:
        return 'Incorporado';
      case LabResultStatus.pendienteRevision:
        return 'Pendiente de revisión';
      case LabResultStatus.anulado:
        return 'Anulado';
      case LabResultStatus.desconocido:
        return 'Estado desconocido';
    }
  }

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color background, Color foreground) = switch (status) {
      LabResultStatus.incorporado => (
          Icons.check_circle_outline,
          AppColors.successContainer,
          AppColors.onSuccessContainer,
        ),
      LabResultStatus.pendienteRevision => (
          Icons.hourglass_top_rounded,
          AppColors.warningContainer,
          AppColors.onWarning,
        ),
      LabResultStatus.anulado => (
          Icons.block_rounded,
          AppColors.errorContainer,
          AppColors.error,
        ),
      LabResultStatus.desconocido => (
          Icons.help_outline_rounded,
          AppColors.primaryLight,
          AppColors.textSecondary,
        ),
    };
    final label = labelFor(status);

    return Semantics(
      label: 'Estado del resultado: $label',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: foreground),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
