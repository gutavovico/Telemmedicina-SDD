import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/asistencia_tratamiento.dart';

/// Tarjeta para presentar sugerencias y recomendaciones de autocuidado.
class RecomendacionCard extends StatelessWidget {
  final RecomendacionTratamiento recomendacion;

  const RecomendacionCard({
    super.key,
    required this.recomendacion,
  });

  IconData _iconForCategory(String category) {
    switch (category.toUpperCase()) {
      case 'HORARIO_ADMINISTRACION':
        return Icons.access_time_filled;
      case 'ESTILO_VIDA':
        return Icons.favorite_rounded;
      case 'SIGNOS_ALARMA':
        return Icons.notification_important_rounded;
      case 'NUTRICION_HIDRATACION':
        return Icons.water_drop_rounded;
      case 'PRECAUCION_GENERAL':
      default:
        return Icons.health_and_safety_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAi = recomendacion.isGeneradaPorIa;
    final catIcon = _iconForCategory(recomendacion.categoria);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(catIcon, color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    recomendacion.titulo,
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: isAi
                        ? AppColors.primaryLight
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isAi ? 'IA' : 'GUÍA',
                    style: TextStyle(
                      color: isAi ? AppColors.primary : AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              recomendacion.detalle,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

