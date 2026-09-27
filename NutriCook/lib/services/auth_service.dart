import '../models/auth_tokens.dart';
import '../models/user_preferences.dart';
import 'api_service.dart';

/// Registration, sign-in, refresh and sign-out.
///
/// Built on an [ApiService] with no session attached: these calls establish
/// the credentials, so they must not try to use them.
class AuthService {
  final ApiService _api;

  AuthService({ApiService? api}) : _api = api ?? ApiService();

  Future<AuthResult> register({
    required String email,
    required String password,
    String? displayName,
    UserPreferences? preferences,
  }) async {
    final json = await _api.post(
      '/api/auth/register',
      body: {
        'email': email.trim(),
        'password': password,
        if (displayName != null && displayName.trim().isNotEmpty)
          'display_name': displayName.trim(),
        if (preferences != null) 'preferences': preferences.toJson(),
      },
    );
    return AuthResult.fromJson(json);
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final json = await _api.post(
      '/api/auth/login',
      body: {'email': email.trim(), 'password': password},
    );
    return AuthResult.fromJson(json);
  }

  Future<AuthResult> refresh(String refreshToken) async {
    final json = await _api.post(
      '/api/auth/refresh',
      body: {'refresh_token': refreshToken},
    );
    return AuthResult.fromJson(json);
  }

  /// Revokes the refresh token server-side. Failure is ignored: the local
  /// tokens are cleared either way, so the user is signed out regardless of
  /// whether the network was there to hear about it.
  Future<void> logout(String refreshToken) async {
    try {
      await _api.post(
        '/api/auth/logout',
        body: {'refresh_token': refreshToken},
      );
    } on ApiException {
      // Nothing to recover: the local state is what the user sees.
    }
  }
}
