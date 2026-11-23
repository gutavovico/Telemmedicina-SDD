import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

enum BannerType { error, success, info }

class AuthBanner extends StatelessWidget {
  final String message;
  final BannerType type;
  final VoidCallback? onDismiss;

  const AuthBanner({
    super.key,
    required this.message,
    this.type = BannerType.error,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty) return const SizedBox.shrink();

    Color backgroundColor;
    Color borderColor;
    Color textColor;
    IconData icon;

    switch (type) {
      case BannerType.error:
        backgroundColor = AppColors.errorContainer.withValues(alpha: 0.85);
        borderColor = AppColors.error.withValues(alpha: 0.3);
        textColor = AppColors.onErrorContainer;
        icon = Icons.error_outline_rounded;
        break;
      case BannerType.success:
        backgroundColor = AppColors.successContainer;
        borderColor = AppColors.success.withValues(alpha: 0.3);
        textColor = AppColors.onSuccessContainer;
        icon = Icons.check_circle_outline_rounded;
        break;
      case BannerType.info:
        backgroundColor = AppColors.primaryLight;
        borderColor = AppColors.primary.withValues(alpha: 0.3);
        textColor = AppColors.primaryDark;
        icon = Icons.info_outline_rounded;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodySmall.copyWith(
                color: textColor,
                fontWeight: FontWeight.w500,
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ),
          if (onDismiss != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onDismiss,
              child: Icon(Icons.close, color: textColor.withValues(alpha: 0.7), size: 18),
            ),
          ],
        ],
      ),
    );
  }
}
