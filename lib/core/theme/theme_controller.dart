import 'package:flutter/material.dart';
import '../utils/storage_helper.dart';
import 'app_colors.dart';

/// App-level theme mode holder. Persists the user's choice (light / dark /
/// system) and notifies [MaterialApp] to rebuild via [mode].
class ThemeController {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  static const String _key = 'theme_mode';

  final ValueNotifier<ThemeMode> mode = ValueNotifier<ThemeMode>(
    ThemeMode.light,
  );

  /// Loads the saved theme mode from storage (call once at startup).
  Future<void> load() async {
    final saved = await StorageHelper.getString(_key);
    mode.value = _fromString(saved);
    _applyIsDark(mode.value);
  }

  /// Updates and persists the theme mode.
  Future<void> setMode(ThemeMode value) async {
    _applyIsDark(value);
    mode.value = value;
    await StorageHelper.saveString(_key, _toString(value));
  }

  /// Global [AppColors.isDark] flag'ni darhol (sinxron) yangilaydi - shunda
  /// mode listener'lari (ThemeRebuilder) qayta qurilganda rang allaqachon
  /// to'g'ri bo'ladi. Tizim rejimida OS yorqinligidan foydalanamiz.
  void _applyIsDark(ThemeMode m) {
    final platformDark = WidgetsBinding
            .instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
    AppColors.isDark =
        m == ThemeMode.dark || (m == ThemeMode.system && platformDark);
  }

  static ThemeMode _fromString(String? value) {
    switch (value) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }

  static String _toString(ThemeMode value) {
    switch (value) {
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
      case ThemeMode.light:
        return 'light';
    }
  }
}
