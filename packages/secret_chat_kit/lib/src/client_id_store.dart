import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// A random id that stays with this device, so the server can tell a
/// nickname change from a new person. Never shown in the UI.
class ClientIdStore {
  static const key = 'secret_chat.client_id';

  static Future<String> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString(key);
      if (existing != null && existing.length >= 8) return existing;
      final id = generate();
      await prefs.setString(key, id);
      return id;
    } catch (_) {
      // Storage unavailable: still chat, just as a fresh identity.
      return generate();
    }
  }

  /// 128 random bits as 32 hex characters.
  static String generate() {
    final r = Random.secure();
    return List.generate(
      16,
      (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}
