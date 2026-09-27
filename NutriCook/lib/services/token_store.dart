import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';

/// Where the access and refresh tokens live between launches.
///
/// SharedPreferences rather than the platform keychain: it is already a
/// dependency and works identically everywhere the app runs. That is a real
/// trade-off — on a rooted or jailbroken device these are readable — and it is
/// the reason this is its own class. Moving to `flutter_secure_storage` means
/// reimplementing these four methods and nothing else.
class TokenStore {
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _instance async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<({String? access, String? refresh})> read() async {
    final prefs = await _instance;
    return (
      access: prefs.getString(AppConstants.kAccessToken),
      refresh: prefs.getString(AppConstants.kRefreshToken),
    );
  }

  Future<void> write({
    required String access,
    required String refresh,
  }) async {
    final prefs = await _instance;
    await prefs.setString(AppConstants.kAccessToken, access);
    await prefs.setString(AppConstants.kRefreshToken, refresh);
  }

  Future<void> clear() async {
    final prefs = await _instance;
    await prefs.remove(AppConstants.kAccessToken);
    await prefs.remove(AppConstants.kRefreshToken);
  }
}
