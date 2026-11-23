import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

class HospitalBrandHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool compact;

  const HospitalBrandHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Brand Shield / Hospital Icon
        Container(
          width: compact ? 64 : 80,
          height: compact ? 64 : 80,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.local_hospital_rounded,
                  color: Colors.white,
                  size: compact ? 34 : 42,
                ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: AppColors.tealAccent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.videocam_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: compact ? 12 : 18),

        // Hospital Brand Name
        Text(
          'HOSPITAL SAN JUAN DE DIOS',
          style: AppTypography.labelLarge.copyWith(
            color: AppColors.secondary,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            fontSize: compact ? 11 : 12,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),

        // Screen Action Title
        Text(
          title,
          style: (compact ? AppTypography.displayMedium : AppTypography.displayLarge).copyWith(
            fontSize: compact ? 22 : 26,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),

        // Subtitle explanation
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            subtitle,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
