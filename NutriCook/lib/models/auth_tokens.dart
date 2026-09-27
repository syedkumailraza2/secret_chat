import 'auth_user.dart';

/// The token pair plus the account, as every auth endpoint returns it.
class AuthResult {
  final String accessToken;
  final String refreshToken;
  final AuthUser user;

  const AuthResult({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      accessToken: json['access_token'] as String? ?? '',
      refreshToken: json['refresh_token'] as String? ?? '',
      user: AuthUser.fromJson(
        json['user'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}
