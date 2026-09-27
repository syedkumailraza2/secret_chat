import 'package:shared_preferences/shared_preferences.dart';

/// Persists the chat nickname locally (the only thing stored on device).
class NicknameStore {
  static const key = 'secret_chat.nickname';
  static const maxLength = 24;

  static Future<String?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getString(key)?.trim();
      return (v == null || v.isEmpty) ? null : v;
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, name.trim());
    } catch (_) {
      // Non-fatal: the user will simply be asked again next time.
    }
  }
}
