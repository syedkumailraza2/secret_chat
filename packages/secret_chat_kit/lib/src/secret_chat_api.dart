import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Exchanges the secret code for a short-lived chat token.
///
/// Returns null on ANY failure (wrong code, rate limit, feature disabled,
/// network error, timeout, malformed response) so the caller can close the
/// dialog without revealing anything.
Future<String?> unlockSecretChat(
  String baseUrl,
  String code, {
  http.Client? client,
  Duration timeout = const Duration(seconds: 10),
}) async {
  final ownClient = client == null;
  final c = client ?? http.Client();
  try {
    final uri = Uri.parse('${_trimSlash(baseUrl)}/api/secret-chat/unlock');
    final res = await c
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'code': code}),
        )
        .timeout(timeout);
    if (res.statusCode != 200) return null;
    final body = jsonDecode(res.body);
    if (body is! Map) return null;
    final token = body['token'];
    if (token is! String || token.isEmpty) return null;
    return token;
  } catch (_) {
    return null;
  } finally {
    if (ownClient) c.close();
  }
}

String _trimSlash(String s) =>
    s.endsWith('/') ? s.substring(0, s.length - 1) : s;
