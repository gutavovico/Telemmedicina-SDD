import 'package:flutter/material.dart';

class AppColors {
  // Brand Primary & Navy Colors
  static const Color primary = Color(0xFF003667);
  static const Color primaryContainer = Color(0xFF0A4D8C);
  static const Color primaryDark = Color(0xFF002244);
  static const Color primaryLight = Color(0xFFE3F2FD);
  static const Color onPrimary = Colors.white;

  // Secondary & Teal Acolors
  static const Color secondary = Color(0xFF006B5F);
  static const Color secondaryContainer = Color(0xFF6DF5E1);
  static const Color tealAccent = Color(0xFF14B8A6);
  static const Color onSecondary = Colors.white;

  // Background & Surfaces
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F5F9);
  static const Color cardSurface = Colors.white;

  // Neutral & Outlines
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color outline = Color(0xFFCBD5E1);
  static const Color outlineFocus = Color(0xFF003667);
  static const Color divider = Color(0xFFE2E8F0);

  // Status & Feedback
  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onError = Colors.white;
  static const Color onErrorContainer = Color(0xFF410002);

  static const Color success = Color(0xFF059669);
  static const Color successContainer = Color(0xFFD1FAE5);
  static const Color onSuccess = Colors.white;
  static const Color onSuccessContainer = Color(0xFF065F46);

  static const Color warning = Color(0xFFF59E0B);
  static const Color warningContainer = Color(0xFFFEF3C7);
  static const Color onWarning = Color(0xFF92400E);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF003667), Color(0xFF0A4D8C)],
  );

  static const LinearGradient tealGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF006B5F), Color(0xFF14B8A6)],
  );

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF002A50), Color(0xFF003667)],
  );
}
