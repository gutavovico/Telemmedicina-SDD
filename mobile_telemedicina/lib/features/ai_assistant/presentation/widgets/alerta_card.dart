import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/asistencia_tratamiento.dart';

/// Banner compacto para representar alertas de interacción farmacológica.
///
/// La severidad se distingue tanto por color como por icono y etiqueta textual
/// explícita (accesibilidad y semántica visual).
class AlertaCard extends StatelessWidget {
  final AlertaInteraccion alerta;
  final VoidCallback? onUrgenciasTap;

  const AlertaCard({
    super.key,
    required this.alerta,
    this.onUrgenciasTap,
  });

  @override
  Widget build(BuildContext context) {
    final isGrave = alerta.isGrave;
    final isModerada = alerta.isModerada;

    // Configuración visual según severidad
    final Color bgColor;
    final Color borderColor;
    final Color textColor;
    final IconData iconData;
    final String labelSeveridad;

    if (isGrave) {
      bgColor = AppColors.errorContainer;
      borderColor = AppColors.error.withValues(alpha: 0.4);
      textColor = AppColors.onErrorContainer;
      iconData = Icons.shield_outlined;
      labelSeveridad = 'SEVERIDAD GRAVE';
    } else if (isModerada) {
      bgColor = AppColors.warningContainer;
      borderColor = AppColors.warning.withValues(alpha: 0.4);
      textColor = AppColors.onWarning;
      iconData = Icons.warning_amber_rounded;
      labelSeveridad = 'SEVERIDAD MODERADA';
    } else {
      bgColor = Colors.white;
      borderColor = AppColors.outline.withValues(alpha: 0.6);
      textColor = AppColors.textPrimary;
      iconData = Icons.info_outline;
      labelSeveridad = 'SEVERIDAD LEVE';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera: Icono, etiqueta de severidad y medicamentos
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(iconData, color: textColor, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isGrave
                                  ? AppColors.error
                                  : isModerada
                                      ? AppColors.warning
                                      : AppColors.textMuted,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              labelSeveridad,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${alerta.medicamento1Nombre} + ${alerta.medicamento2Nombre}',
                        style: AppTypography.titleMedium.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Mensaje explicativo en lenguaje accesible
            Text(
              alerta.mensajeAlerta,
              style: AppTypography.bodyMedium.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),

            // Pauta precautoria
            Text(
              alerta.pautaPrecaucion,
              style: AppTypography.bodySmall.copyWith(
                color: textColor.withValues(alpha: 0.9),
                height: 1.35,
              ),
            ),

            // Botón de orientación ante alertas graves
            if (isGrave) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error, width: 1.5),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: onUrgenciasTap,
                  icon: const Icon(Icons.info_outline, size: 18),
                  label: const Text(
                    'Qué hacer ante una urgencia',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

