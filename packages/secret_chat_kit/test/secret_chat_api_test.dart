import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_chat_kit/src/secret_chat_api.dart';

void main() {
  test('200 returns the token and posts the code', () async {
    late http.Request seen;
    final client = MockClient((req) async {
      seen = req;
      return http.Response(
        jsonEncode({'token': 'abc', 'expires_in': 3600}),
        200,
      );
    });
    final token = await unlockSecretChat('http://h:1/', '1234', client: client);
    expect(token, 'abc');
    expect(seen.url.toString(), 'http://h:1/api/secret-chat/unlock');
    expect(jsonDecode(seen.body), {'code': '1234'});
  });

  for (final code in [401, 404, 429, 500]) {
    test('$code returns null', () async {
      final client = MockClient(
        (_) async => http.Response('{"detail":"no"}', code),
      );
      expect(await unlockSecretChat('http://h', 'x', client: client), isNull);
    });
  }

  test('malformed body returns null', () async {
    final client = MockClient((_) async => http.Response('not json', 200));
    expect(await unlockSecretChat('http://h', 'x', client: client), isNull);
  });

  test('exception returns null', () async {
    final client = MockClient((_) async => throw const SocketLikeError());
    expect(await unlockSecretChat('http://h', 'x', client: client), isNull);
  });

  test('timeout returns null', () async {
    final client = MockClient((_) => Completer<http.Response>().future);
    final token = await unlockSecretChat(
      'http://h',
      'x',
      client: client,
      timeout: const Duration(milliseconds: 20),
    );
    expect(token, isNull);
  });
}

class SocketLikeError implements Exception {
  const SocketLikeError();
}
