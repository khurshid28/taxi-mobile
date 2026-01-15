import 'package:shared_preferences/shared_preferences.dart';

class StorageHelper {
  static Future<SharedPreferences> get _prefs async =>
      await SharedPreferences.getInstance();

  // Save string
  static Future<bool> saveString(String key, String value) async {
    final prefs = await _prefs;
    return await prefs.setString(key, value);
  }

  // Get string
  static Future<String?> getString(String key) async {
    final prefs = await _prefs;
    return prefs.getString(key);
  }

  // Save bool
  static Future<bool> saveBool(String key, bool value) async {
    final prefs = await _prefs;
    return await prefs.setBool(key, value);
  }

  // Get bool
  static Future<bool?> getBool(String key) async {
    final prefs = await _prefs;
    return prefs.getBool(key);
  }

  // Save int
  static Future<bool> saveInt(String key, int value) async {
    final prefs = await _prefs;
    return await prefs.setInt(key, value);
  }

  // Get int
  static Future<int?> getInt(String key) async {
    final prefs = await _prefs;
    return prefs.getInt(key);
  }

  // Remove key
  static Future<bool> remove(String key) async {
    final prefs = await _prefs;
    return await prefs.remove(key);
  }

  // Clear all
  static Future<bool> clear() async {
    final prefs = await _prefs;
    return await prefs.clear();
  }
}
