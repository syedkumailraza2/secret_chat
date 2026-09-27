import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/constants/app_constants.dart';
import 'auth_session.dart';

/// A failure that already carries copy safe to show a user.
///
/// Nothing in the app should ever surface a status code or a stack trace, so
/// every transport-level problem is translated here exactly once.
class ApiException implements Exception {
  /// Shown to the user.
  final String message;

  /// Kept for logs only — never rendered.
  final String? detail;

  final int? statusCode;

  const ApiException(this.message, {this.detail, this.statusCode});

  /// True when the server rejected our credentials rather than our request.
  bool get isUnauthorised => statusCode == 401;

  /// True when the address is already registered.
  bool get isConflict => statusCode == 409;

  @override
  String toString() => 'ApiException($statusCode): $message ${detail ?? ''}';
}

/// Thin JSON wrapper over `http`. Knows about the base URL, timeouts, bearer
/// tokens and error translation, and nothing about recipes.
class ApiService {
  final http.Client _client;
  final String baseUrl;

  /// When present, requests carry its access token and a 401 triggers one
  /// silent refresh-and-retry. The auth endpoints themselves pass nothing
  /// here — refreshing a token in order to refresh a token would loop.
  final AuthSession? _session;

  ApiService({http.Client? client, String? baseUrl, AuthSession? session})
      : _client = client ?? http.Client(),
        baseUrl = baseUrl ?? AppConstants.apiBaseUrl,
        _session = session;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
    Duration? timeout,
  }) {
    final uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: (query == null || query.isEmpty) ? null : query,
    );
    return _send(
      (headers) => _client.get(uri, headers: headers),
      timeout ?? AppConstants.requestTimeout,
    );
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    Duration? timeout,
  }) {
    final uri = Uri.parse('$baseUrl$path');
    return _send(
      (headers) => _client.delete(uri, headers: headers),
      timeout ?? AppConstants.requestTimeout,
    );
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    Duration? timeout,
  }) {
    final uri = Uri.parse('$baseUrl$path');
    return _send(
      (headers) => _client.put(
        uri,
        headers: headers,
        body: jsonEncode(body ?? const {}),
      ),
      timeout ?? AppConstants.requestTimeout,
    );
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    Duration? timeout,
  }) {
    final uri = Uri.parse('$baseUrl$path');
    return _send(
      (headers) => _client.post(
        uri,
        headers: headers,
        body: jsonEncode(body ?? const {}),
      ),
      timeout ?? AppConstants.requestTimeout,
    );
  }

  Map<String, String> _headers() {
    final token = _session?.accessToken;
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function(Map<String, String> headers) request,
    Duration timeout, {
    bool allowRetry = true,
  }) async {
    late final http.Response response;
    try {
      response = await request(_headers()).timeout(timeout);
    } on TimeoutException {
      throw const ApiException(AppMessages.timeoutError, detail: 'timeout');
    } on SocketException catch (e) {
      throw ApiException(AppMessages.networkError, detail: e.message);
    } on http.ClientException catch (e) {
      // Also covers web, where a refused connection surfaces here rather than
      // as a SocketException.
      throw ApiException(AppMessages.networkError, detail: e.message);
    }

    // An expired access token is routine — it lasts an hour — so it is
    // renewed and the request replayed rather than shown to the user. Once
    // only: if the fresh token is also rejected, the session is genuinely over.
    if (response.statusCode == 401 && allowRetry && _session != null) {
      if (await _session.refresh()) {
        return _send(request, timeout, allowRetry: false);
      }
      throw const ApiException(
        AppMessages.sessionExpired,
        detail: 'refresh failed',
        statusCode: 401,
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return const {};
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) return decoded;
        // Endpoints in this app always return an object at the top level.
        throw const ApiException(
          AppMessages.genericError,
          detail: 'expected a JSON object',
        );
      } on FormatException catch (e) {
        throw ApiException(AppMessages.genericError, detail: e.message);
      }
    }

    throw ApiException(
      _messageForStatus(response.statusCode),
      detail: response.body,
      statusCode: response.statusCode,
    );
  }

  /// Maps a status code to user-facing copy. The server's own `detail` string
  /// is deliberately ignored here — it may contain provider errors.
  String _messageForStatus(int status) {
    if (status == 401) return AppMessages.sessionExpired;
    if (status == 404) return "We couldn't find that recipe.";
    if (status == 409) return AppMessages.emailTaken;
    if (status == 422) return "Please check what you entered and try again.";
    if (status == 429) {
      return "The kitchen is busy right now. Give it a moment and try again.";
    }
    return AppMessages.genericError;
  }

  void dispose() => _client.close();
}
