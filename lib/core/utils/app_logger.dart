import 'package:flutter/foundation.dart';

/// Rangli konsol loglari. `flutter run` terminalida ANSI ranglar ko'rinadi.
/// Faqat debug rejimida chiqadi — release build'da jim turadi.
///
/// Maqsad: buyurtma kelganda nima sodir bo'layotganini (ayniqsa `orderId`)
/// bir qarashda ko'rish.
class AppLogger {
  AppLogger._();

  // ANSI escape kodlari
  static const String _reset = '\x1B[0m';
  static const String _bold = '\x1B[1m';

  // Matn ranglari
  static const String _red = '\x1B[31m';
  static const String _green = '\x1B[32m';
  static const String _yellow = '\x1B[33m';
  static const String _blue = '\x1B[34m';
  static const String _cyan = '\x1B[36m';

  // Fon ranglari (e'tibor tortadigan loglar uchun)
  static const String _bgGreen = '\x1B[42m';
  static const String _black = '\x1B[30m';

  static void _out(String msg) {
    if (!kDebugMode) return;
    // ignore: avoid_print
    print(msg);
  }

  /// Yangi buyurtma — eng ko'zga tashlanadigan (yashil fon + qora matn).
  static void order(String msg) =>
      _out('$_bgGreen$_black$_bold 🆕 $msg $_reset');

  /// Mercure / real-time (cyan).
  static void mercure(String msg) => _out('$_cyan$_bold📡 $msg$_reset');

  /// Muvaffaqiyat (yashil).
  static void success(String msg) => _out('$_green$_bold✅ $msg$_reset');

  /// Xato (qizil).
  static void error(String msg) => _out('$_red$_bold❌ $msg$_reset');

  /// Ogohlantirish (sariq).
  static void warn(String msg) => _out('$_yellow$_bold⚠️  $msg$_reset');

  /// Ma'lumot (ko'k).
  static void info(String msg) => _out('$_blue$_bold🔹 $msg$_reset');

  /// Ajratuvchi sarlavha (cyan, qalin).
  static void header(String msg) =>
      _out('$_cyan$_bold━━━━━ $msg ━━━━━$_reset');
}
