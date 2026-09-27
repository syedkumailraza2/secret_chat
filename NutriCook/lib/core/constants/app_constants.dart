class AppConstants {
  AppConstants._();

  /// Base URL of the FastAPI backend.
  ///
  /// Defaults to the deployed backend on Render. Point at a local server at
  /// build time instead:
  ///   flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8010
  /// (the Android emulator reaches the host machine at http://10.0.2.2:8010).
  static String get apiBaseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;
    return productionApiBaseUrl;
  }

  static const String productionApiBaseUrl =
      'https://secret-chat-fyob.onrender.com';

  static const Duration requestTimeout = Duration(seconds: 30);

  /// Recipe generation calls an LLM, so it needs a much longer budget than a
  /// plain read.
  static const Duration generateTimeout = Duration(seconds: 120);

  /// Image generation is slower still.
  static const Duration imageTimeout = Duration(seconds: 180);

  /// How many feed recipes one page holds. Matches the server's default.
  static const int feedPageSize = 10;

  /// How many browse results one page holds.
  static const int browsePageSize = 20;

  // Local persistence keys.
  static const String kSavedRecipes = 'saved_recipes';
  static const String kUserPreferences = 'user_preferences';
  static const String kOnboardingComplete = 'onboarding_complete';
  static const String kAccessToken = 'auth_access_token';
  static const String kRefreshToken = 'auth_refresh_token';
}

/// The friendly, non-technical copy the UI shows when something fails.
/// Per the brief: never surface a raw status code to the user.
class AppMessages {
  AppMessages._();

  static const String genericError = "Hmm… our chef is taking a break 👨‍🍳";
  static const String generateFailed = "We couldn't create your recipe right now.";
  static const String networkError =
      "We can't reach the kitchen. Check your connection and try again.";
  static const String timeoutError =
      "That's taking longer than usual. Let's try once more.";
  static const String loadFeedFailed = "We couldn't load recipes right now.";
  static const String imageFailed = "Couldn't plate this one up.";
  static const String tryAgain = "Try again";

  // --- Authentication ---
  static const String sessionExpired =
      "Your session has ended. Please sign in again.";
  static const String signInFailed =
      "That email and password don't match. Have another go.";
  static const String emailTaken =
      "There's already an account with that email. Try signing in.";
  static const String signUpFailed = "We couldn't create your account.";
  static const String passwordTooShort =
      "Use at least 8 characters for your password.";
  static const String passwordsDoNotMatch = "Those passwords don't match.";
  static const String emailRequired = "Enter your email address.";
  static const String emailInvalid = "That doesn't look like an email address.";
  static const String passwordRequired = "Enter your password.";
  static const String browseEmpty = "No recipes match those filters yet.";
}
