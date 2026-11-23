import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

class PasswordStrengthMeter extends StatelessWidget {
  final int strengthScore; // 0: None, 1: Weak, 2: Medium, 3: Strong

  const PasswordStrengthMeter({
    super.key,
    required this.strengthScore,
  });

  @override
  Widget build(BuildContext context) {
    if (strengthScore == 0) {
      return const SizedBox.shrink();
    }

    Color getBarColor(int index) {
      if (index > strengthScore) {
        return AppColors.outline.withValues(alpha: 0.4);
      }
      switch (strengthScore) {
        case 1:
          return AppColors.error;
        case 2:
          return AppColors.warning;
        case 3:
          return AppColors.secondary;
        default:
          return AppColors.outline;
      }
    }

    String getStrengthText() {
      switch (strengthScore) {
        case 1:
          return 'Contraseña débil (mín. 6 caracteres)';
        case 2:
          return 'Contraseña media (agrega números y mayúsculas)';
        case 3:
          return 'Contraseña fuerte y segura';
        default:
          return '';
      }
    }

    Color getTextColor() {
      switch (strengthScore) {
        case 1:
          return AppColors.error;
        case 2:
          return AppColors.onWarning;
        case 3:
          return AppColors.secondary;
        default:
          return AppColors.textMuted;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: getBarColor(1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: getBarColor(2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: getBarColor(3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            getStrengthText(),
            style: AppTypography.bodySmall.copyWith(
              color: getTextColor(),
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
