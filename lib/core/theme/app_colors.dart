import 'package:flutter/material.dart';

class AppColors {
  // Primary Color
  static const Color primary = Color(0xFF4CAF50);
  static const Color primaryDark = Color(0xFF388E3C);
  static const Color primaryLight = Color(0xFF66BB6A);

  // Background — modern minimal: pure white surfaces
  static const Color background = Colors.white;
  static const Color surface = Colors.white;
  static const Color surfaceVariant = Color(0xFFF7F8FA); // very subtle off-white

  // Text
  static const Color textPrimary = Color(0xFF111418);
  static const Color textSecondary = Color(0xFF5C6470);
  static const Color textHint = Color(0xFF9AA3AF);
  static const Color textMuted = Color(0xFFB7BDC6);

  // Status
  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // Order States
  static const Color orderWaiting = Color(0xFFF59E0B);
  static const Color orderActive = Color(0xFF22C55E);
  static const Color orderCompleted = Color(0xFF3B82F6);

  // Others
  static const Color divider = Color(0xFFEDEFF3);
  static const Color dividerLight = Color(0xFFF1F3F6);
  static const Color shadow = Color(0x0A000000); // 4% black for soft shadows
  static const Color overlay = Color(0x66000000);

  /// Canonical soft elevation used by cards/sheets in the modern minimal UI.
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x0A000000), // 4%
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x05000000), // 2%
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];

  /// Slightly stronger shadow for floating elements (FAB, bottom sheets).
  static const List<BoxShadow> floatingShadow = [
    BoxShadow(
      color: Color(0x14000000), // 8%
      blurRadius: 28,
      offset: Offset(0, 12),
    ),
  ];
}

/// Unified radius tokens (use everywhere instead of magic numbers).
class AppRadius {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double sheet = 28;
  static const double pill = 999;
}

/// Unified spacing tokens.
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}
