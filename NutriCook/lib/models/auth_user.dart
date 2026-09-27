import 'user_preferences.dart';

/// The signed-in account as the API describes it.
class AuthUser {
  final String id;
  final String displayName;
  final String? email;
  final UserPreferences preferences;
  final bool onboardingComplete;

  const AuthUser({
    required this.id,
    this.displayName = 'NutriCook Chef',
    this.email,
    this.preferences = const UserPreferences(),
    this.onboardingComplete = false,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final prefs = json['preferences'];
    return AuthUser(
      id: json['id'] as String? ?? '',
      displayName: json['display_name'] as String? ?? 'NutriCook Chef',
      email: json['email'] as String?,
      preferences: prefs is Map<String, dynamic>
          ? UserPreferences.fromJson(prefs)
          : const UserPreferences(),
      onboardingComplete: json['onboarding_complete'] as bool? ?? false,
    );
  }

  AuthUser copyWith({
    String? displayName,
    UserPreferences? preferences,
    bool? onboardingComplete,
  }) {
    return AuthUser(
      id: id,
      displayName: displayName ?? this.displayName,
      email: email,
      preferences: preferences ?? this.preferences,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    );
  }

  /// The initial shown in the profile avatar when there is no photo.
  String get initial {
    final source = (displayName.trim().isNotEmpty ? displayName : email) ?? '';
    return source.isEmpty ? '?' : source.trim()[0].toUpperCase();
  }
}
