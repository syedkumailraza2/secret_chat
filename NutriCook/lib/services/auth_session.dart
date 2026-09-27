import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/auth_tokens.dart';
import 'token_store.dart';

/// Holds the tokens and knows how to renew them.
///
/// Deliberately separate from `AuthProvider`: the API layer needs the current
/// token and a way to refresh it on a 401, and it should not have to reach
/// into UI state to get either.
class AuthSession extends ChangeNotifier {
  final TokenStore _store;

  /// Posts the refresh token and returns a new pair. Injected rather than
  /// imported so this class has no dependency on the API layer that depends
  /// on it.
  Future<AuthResult> Function(String refreshToken)? refresher;

  AuthSession({TokenStore? store}) : _store = store ?? TokenStore();

  String? _accessToken;
  String? _refreshToken;
  bool _loaded = false;

  /// In-flight refresh, so several requests that all 401 at once renew the
  /// token once between them instead of racing — and losing, since each
  /// rotation invalidates the last token.
  Future<bool>? _refreshing;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  bool get isLoaded => _loaded;
  bool get hasTokens => _accessToken != null && _accessToken!.isNotEmpty;

  Future<void> load() async {
    final stored = await _store.read();
    _accessToken = stored.access;
    _refreshToken = stored.refresh;
    _loaded = true;
    notifyListeners();
  }

  Future<void> adopt(AuthResult result) async {
    _accessToken = result.accessToken;
    _refreshToken = result.refreshToken;
    await _store.write(
      access: result.accessToken,
      refresh: result.refreshToken,
    );
    notifyListeners();
  }

  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    await _store.clear();
    notifyListeners();
  }

  /// Renews the pair. Returns false when the session is truly over, which is
  /// the signal to send the user back to the sign-in screen.
  Future<bool> refresh() {
    return _refreshing ??= _performRefresh().whenComplete(() {
      _refreshing = null;
    });
  }

  Future<bool> _performRefresh() async {
    final token = _refreshToken;
    final refresh = refresher;
    if (token == null || token.isEmpty || refresh == null) return false;

    try {
      await adopt(await refresh(token));
      return true;
    } catch (_) {
      // The refresh token is spent, revoked or expired. Nothing to salvage.
      await clear();
      return false;
    }
  }
}
