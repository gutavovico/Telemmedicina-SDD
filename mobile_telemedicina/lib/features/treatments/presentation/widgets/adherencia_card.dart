import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/treatment_entities.dart';

/// Tarjeta visual que presenta el semáforo y métricas de adherencia clínica (CU17).
///
/// Semáforo según contrato:
/// - `OPTIMA`: >= 80% (Verde)
/// - `REGULAR`: >= 50% y < 80% (Ámbar / Naranja)
/// - `CRITICA`: < 50% (Rojo)
/// - `SIN_DATOS`: Gris ("Sin datos suficientes")
class AdherenciaCard extends StatelessWidget {
  final Adherencia? adherencia;

  const AdherenciaCard({super.key, required this.adherencia});

  @override
  Widget build(BuildContext context) {
    final adh = adherencia;
    final semaforo = _semaforoFor(adh);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: semaforo.color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: semaforo.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(semaforo.icon, color: semaforo.color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Adherencia al Tratamiento',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'Semáforo clínico de seguimiento',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // Nivel Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: semaforo.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: semaforo.color.withValues(alpha: 0.4)),
                ),
                child: Text(
                  semaforo.label,
                  style: TextStyle(
                    color: semaforo.color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Percentage display and progress
          if (adh != null && adh.porcentaje != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${adh.porcentaje!.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: semaforo.color,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'de tomas puntuales',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (adh.porcentaje! / 100.0).clamp(0.0, 1.0),
                backgroundColor: AppColors.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(semaforo.color),
                minHeight: 8,
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Sin datos suficientes acumulados',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 12),

          // Numerator and Denominator
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Tomas puntuales',
                  value: adh != null ? '${adh.numeradorPuntual}' : '0',
                  color: AppColors.success,
                ),
              ),
              Container(width: 1, height: 32, color: AppColors.divider),
              Expanded(
                child: _buildMetricItem(
                  icon: Icons.calendar_today_outlined,
                  label: 'Tomas acumuladas',
                  value: adh != null ? '${adh.denominadorProgramado}' : '0',
                  color: AppColors.primary,
                ),
              ),
            ],
          ),

          if (adh?.calculadoEn != null && adh!.calculadoEn!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Calculado al: ${_formatCalculadoEn(adh.calculadoEn!)}',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textMuted,
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatCalculadoEn(String raw) {
    try {
      final parsed = DateTime.parse(raw).toLocal();
      final day = parsed.day.toString().padLeft(2, '0');
      final month = parsed.month.toString().padLeft(2, '0');
      final hour = parsed.hour.toString().padLeft(2, '0');
      final min = parsed.minute.toString().padLeft(2, '0');
      return '$day/$month/${parsed.year} $hour:$min';
    } catch (_) {
      return raw;
    }
  }
}

class _SemaforoConfig {
  final String label;
  final IconData icon;
  final Color color;
  final Color background;

  const _SemaforoConfig({
    required this.label,
    required this.icon,
    required this.color,
    required this.background,
  });
}

_SemaforoConfig _semaforoFor(Adherencia? adherencia) {
  if (adherencia == null || adherencia.sinDatos || adherencia.porcentaje == null) {
    return const _SemaforoConfig(
      label: 'Sin datos',
      icon: Icons.hourglass_empty_rounded,
      color: AppColors.textSecondary,
      background: AppColors.surfaceVariant,
    );
  }

  final nivel = adherencia.nivel.toUpperCase();
  if (nivel == 'OPTIMA' || adherencia.porcentaje! >= 80.0) {
    return const _SemaforoConfig(
      label: 'Óptima',
      icon: Icons.sentiment_very_satisfied_rounded,
      color: AppColors.success,
      background: AppColors.successContainer,
    );
  } else if (nivel == 'REGULAR' ||
      (adherencia.porcentaje! >= 50.0 && adherencia.porcentaje! < 80.0)) {
    return const _SemaforoConfig(
      label: 'Regular',
      icon: Icons.sentiment_neutral_rounded,
      color: Color(0xFFD97706),
      background: AppColors.warningContainer,
    );
  } else {
    return const _SemaforoConfig(
      label: 'Crítica',
      icon: Icons.sentiment_very_dissatisfied_rounded,
      color: AppColors.error,
      background: AppColors.errorContainer,
    );
  }
}
