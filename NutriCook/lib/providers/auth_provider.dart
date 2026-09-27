import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../models/auth_tokens.dart';
import '../models/auth_user.dart';
import '../models/user_preferences.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/auth_session.dart';

/// Which screen the app should be showing at the top level.
enum AuthStatus {
  /// Still reading stored tokens. Lasts a frame or two.
  unknown,

  /// No valid session — show the welcome hero with Sign Up and Log In.
  signedOut,

  /// Signed in, but the preference steps have not been answered yet.
  onboarding,

  /// Signed in and set up.
  ready,
}

/// Owns the signed-in account and the sign-in / sign-up flows.
class AuthProvider extends ChangeNotifier {
  final AuthService _service;
  final AuthSession _session;

  AuthProvider({AuthService? service, required AuthSession session})
      : _service = service ?? AuthService(),
        _session = session {
    // The API layer renews tokens on a 401 by calling back into here, which
    // is also how a dead session reaches the UI: `clear()` notifies, and this
    // provider is listening.
    _session.refresher = _service.refresh;
    _session.addListener(_onSessionChanged);
  }

  AuthUser? _user;
  AuthStatus _status = AuthStatus.unknown;
  bool _busy = false;
  String? _error;

  AuthUser? get user => _user;
  AuthStatus get status => _status;
  bool get isBusy => _busy;
  String? get error => _error;
  bool get isSignedIn => _user != null && _session.hasTokens;

  AuthSession get session => _session;

  /// Restores a session from disk at launch.
  Future<void> restore() async {
    await _session.load();

    if (!_session.hasTokens) {
      _setStatus(AuthStatus.signedOut);
      return;
    }

    // Exchanging the refresh token settles two things at once: whether the
    // session is still good, and what the account looks like now — including
    // preferences changed on another device.
    final refreshToken = _session.refreshToken;
    if (refreshToken == null) {
      _setStatus(AuthStatus.signedOut);
      return;
    }

    try {
      final result = await _service.refresh(refreshToken);
      await _session.adopt(result);
      _user = result.user;
      _setStatus(_statusFor(result.user));
    } on ApiException catch (e) {
      if (e.isUnauthorised) {
        await _session.clear();
        _setStatus(AuthStatus.signedOut);
      } else {
        // Offline at launch. The stored access token may well still be valid,
        // so the user is kept signed in rather than thrown out by a flaky
        // connection; the next 401 will settle it properly.
        _setStatus(AuthStatus.ready);
      }
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    String? displayName,
    UserPreferences? preferences,
  }) {
    return _attempt(
      () => _service.register(
        email: email,
        password: password,
        displayName: displayName,
        preferences: preferences,
      ),
      fallbackMessage: AppMessages.signUpFailed,
    );
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) {
    return _attempt(
      () => _service.login(email: email, password: password),
      fallbackMessage: AppMessages.signInFailed,
    );
  }

  Future<void> signOut() async {
    final refreshToken = _session.refreshToken;
    if (refreshToken != null) {
      await _service.logout(refreshToken);
    }
    await _session.clear();
    _user = null;
    _setStatus(AuthStatus.signedOut);
  }

  /// Called once the preference steps are done, so the shell swaps from
  /// onboarding to the main app.
  void markOnboardingComplete(UserPreferences preferences) {
    _user = _user?.copyWith(
      preferences: preferences,
      onboardingComplete: true,
    );
    _setStatus(AuthStatus.ready);
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<bool> _attempt(
    Future<AuthResult> Function() call, {
    required String fallbackMessage,
  }) async {
    _busy = true;
    _error = null;
    notifyListeners();

    try {
      final result = await call();
      await _session.adopt(result);
      _user = result.user;
      _busy = false;
      _setStatus(_statusFor(result.user));
      return true;
    } on ApiException catch (e) {
      // On the auth endpoints a 401 means bad credentials, not an expired
      // session, so ApiService's generic "session has ended" copy is wrong here.
      _error = e.isUnauthorised ? fallbackMessage : e.message;
      _busy = false;
      notifyListeners();
      return false;
    } catch (_) {
      _error = fallbackMessage;
      _busy = false;
      notifyListeners();
      return false;
    }
  }

  AuthStatus _statusFor(AuthUser user) =>
      user.onboardingComplete ? AuthStatus.ready : AuthStatus.onboarding;

  void _setStatus(AuthStatus status) {
    _status = status;
    notifyListeners();
  }

  /// The session clearing itself — which is what a failed refresh does —
  /// means the user is out, wherever in the app they happened to be.
  void _onSessionChanged() {
    if (!_session.hasTokens && _status != AuthStatus.signedOut) {
      _user = null;
      _setStatus(AuthStatus.signedOut);
    }
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    super.dispose();
  }
}
