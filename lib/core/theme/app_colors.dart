import 'package:flutter/material.dart';

class AppColors {
  /// Global dark-mode flag. Set by MaterialApp.builder from the resolved theme
  /// brightness so that every widget reading these tokens adapts automatically
  /// (including system mode). Theme tokens below are getters backed by this.
  static bool isDark = false;

  // Primary Color (brand — same in both themes)
  static const Color primary = Color(0xFF4CAF50);
  static const Color primaryDark = Color(0xFF388E3C);
  static const Color primaryLight = Color(0xFF66BB6A);

  // Background / surface — theme-aware. Dark ramp keeps cards (surface)
  // slightly lighter than the scaffold (surfaceVariant/background) so they pop.
  static Color get background =>
      isDark ? const Color(0xFF0E1013) : Colors.white;
  static Color get surface =>
      isDark ? const Color(0xFF1E2127) : Colors.white;
  static Color get surfaceVariant =>
      isDark ? const Color(0xFF16191E) : const Color(0xFFF7F8FA);

  // Text — theme-aware
  static Color get textPrimary =>
      isDark ? const Color(0xFFF1F3F6) : const Color(0xFF111418);
  static Color get textSecondary =>
      isDark ? const Color(0xFFA8B0BB) : const Color(0xFF5C6470);
  static Color get textHint =>
      isDark ? const Color(0xFF79818C) : const Color(0xFF9AA3AF);
  static Color get textMuted =>
      isDark ? const Color(0xFF565D67) : const Color(0xFFB7BDC6);

  // Status (brand — same in both themes)
  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // Order States
  static const Color orderWaiting = Color(0xFFF59E0B);
  static const Color orderActive = Color(0xFF22C55E);
  static const Color orderCompleted = Color(0xFF3B82F6);

  // Others — theme-aware where structural
  static Color get divider =>
      isDark ? const Color(0xFF2A2E35) : const Color(0xFFEDEFF3);
  static Color get dividerLight =>
      isDark ? const Color(0xFF20242A) : const Color(0xFFF1F3F6);
  static Color get shadow =>
      isDark ? const Color(0x33000000) : const Color(0x0A000000);
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
