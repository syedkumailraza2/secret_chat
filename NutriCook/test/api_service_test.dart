import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutricook/core/constants/app_constants.dart';
import 'package:nutricook/models/auth_tokens.dart';
import 'package:nutricook/models/auth_user.dart';
import 'package:nutricook/services/api_service.dart';
import 'package:nutricook/services/auth_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

AuthResult _result(String access, String refresh) => AuthResult(
      accessToken: access,
      refreshToken: refresh,
      user: const AuthUser(id: 'u1', email: 'chef@example.com'),
    );

/// A session already holding [access], with no server behind it unless the
/// test supplies a refresher.
Future<AuthSession> _signedInSession(String access) async {
  SharedPreferences.setMockInitialValues({});
  final session = AuthSession();
  await session.load();
  await session.adopt(_result(access, 'refresh-1'));
  return session;
}

ApiService _serviceReturning(
  int status, {
  String body = '{}',
  void Function(http.Request)? onRequest,
}) {
  final client = MockClient((request) async {
    onRequest?.call(request);
    return http.Response(body, status);
  });
  return ApiService(client: client, baseUrl: 'http://test.local');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('error translation', () {
    // The brief is explicit: never surface a raw status code to the user.
    test('a 503 becomes friendly copy, not a status code', () async {
      final service = _serviceReturning(
        503,
        body: '{"detail":"The recipe database is unavailable right now"}',
      );

      await expectLater(
        service.get('/api/recipes'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.message, 'message', AppMessages.genericError)
              .having((e) => e.message, 'no code', isNot(contains('503'))),
        ),
      );
    });

    test('a 500 becomes friendly copy', () async {
      final service = _serviceReturning(500, body: 'Internal Server Error');

      await expectLater(
        service.get('/api/recipes'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            AppMessages.genericError,
          ),
        ),
      );
    });

    test('a 404 says the recipe was not found', () async {
      final service = _serviceReturning(404);

      await expectLater(
        service.get('/api/recipes/nope'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains("couldn't find"),
          ),
        ),
      );
    });

    test('a 429 asks the user to wait', () async {
      final service = _serviceReturning(429);

      await expectLater(
        service.get('/api/recipes'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('busy'),
          ),
        ),
      );
    });

    test('the server detail string never reaches the user', () async {
      // A backend that leaked an internal message must not have it rendered.
      final service = _serviceReturning(
        500,
        body: '{"detail":"psycopg2.OperationalError at 10.0.0.4:5432"}',
      );

      try {
        await service.get('/api/recipes');
        fail('expected an ApiException');
      } on ApiException catch (e) {
        expect(e.message, AppMessages.genericError);
        expect(e.message, isNot(contains('10.0.0.4')));
      }
    });

    test('a connection refusal reads as a network problem', () async {
      final client = MockClient((_) async => throw const SocketException('refused'));
      final service = ApiService(client: client, baseUrl: 'http://test.local');

      await expectLater(
        service.get('/api/recipes'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            AppMessages.networkError,
          ),
        ),
      );
    });

    test('malformed JSON does not leak a parser error', () async {
      final service = _serviceReturning(200, body: 'not json at all');

      await expectLater(
        service.get('/api/recipes'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            AppMessages.genericError,
          ),
        ),
      );
    });
  });

  group('bearer token', () {
    test('a signed-in request carries the access token', () async {
      final session = await _signedInSession('token-abc');

      http.Request? seen;
      final client = MockClient((request) async {
        seen = request;
        return http.Response('{}', 200);
      });
      final service = ApiService(
        client: client,
        baseUrl: 'http://test.local',
        session: session,
      );

      await service.get('/api/recipes');

      expect(seen!.headers['Authorization'], 'Bearer token-abc');
      expect(seen!.headers['Content-Type'], contains('application/json'));
    });

    test('a signed-out request sends no Authorization header', () async {
      SharedPreferences.setMockInitialValues({});
      final session = AuthSession();
      await session.load();

      http.Request? seen;
      final client = MockClient((request) async {
        seen = request;
        return http.Response('{}', 200);
      });
      final service = ApiService(
        client: client,
        baseUrl: 'http://test.local',
        session: session,
      );

      await service.get('/api/recipes');

      expect(seen!.headers.containsKey('Authorization'), isFalse);
    });

    test('a service with no session never sends a token', () async {
      http.Request? seen;
      final service = _serviceReturning(200, onRequest: (r) => seen = r);

      await service.get('/api/recipes');

      expect(seen!.headers.containsKey('Authorization'), isFalse);
    });
  });

  group('silent refresh', () {
    test('a 401 refreshes the token and replays the request', () async {
      final session = await _signedInSession('stale-token');
      session.refresher = (_) async => _result('fresh-token', 'refresh-2');

      final tokensSeen = <String?>[];
      final client = MockClient((request) async {
        final token = request.headers['Authorization'];
        tokensSeen.add(token);
        if (token == 'Bearer stale-token') {
          return http.Response('{"detail":"Not authenticated"}', 401);
        }
        return http.Response('{"recipes":[]}', 200);
      });
      final service = ApiService(
        client: client,
        baseUrl: 'http://test.local',
        session: session,
      );

      final body = await service.get('/api/users/me/saved');

      expect(body, containsPair('recipes', isEmpty));
      expect(tokensSeen, ['Bearer stale-token', 'Bearer fresh-token']);
      expect(session.accessToken, 'fresh-token');
    });

    test('the request is replayed once, not repeatedly', () async {
      final session = await _signedInSession('stale-token');
      session.refresher = (_) async => _result('also-stale', 'refresh-2');

      var attempts = 0;
      final client = MockClient((_) async {
        attempts += 1;
        return http.Response('{"detail":"Not authenticated"}', 401);
      });
      final service = ApiService(
        client: client,
        baseUrl: 'http://test.local',
        session: session,
      );

      await expectLater(
        service.get('/api/users/me'),
        throwsA(isA<ApiException>()),
      );
      expect(attempts, 2, reason: 'one original call and one replay');
    });

    test('a failed refresh clears the session and reports it plainly',
        () async {
      final session = await _signedInSession('stale-token');
      session.refresher = (_) async =>
          throw const ApiException('nope', statusCode: 401);

      final client = MockClient(
        (_) async => http.Response('{"detail":"Not authenticated"}', 401),
      );
      final service = ApiService(
        client: client,
        baseUrl: 'http://test.local',
        session: session,
      );

      await expectLater(
        service.get('/api/users/me'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            AppMessages.sessionExpired,
          ),
        ),
      );
      expect(session.hasTokens, isFalse);
    });

    test('concurrent 401s trigger exactly one refresh', () async {
      // Rotation invalidates the old refresh token, so a second concurrent
      // refresh would sign the user out for no reason.
      final session = await _signedInSession('stale-token');

      var refreshes = 0;
      session.refresher = (_) async {
        refreshes += 1;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return _result('fresh-token', 'refresh-2');
      };

      final client = MockClient((request) async {
        if (request.headers['Authorization'] == 'Bearer stale-token') {
          return http.Response('{}', 401);
        }
        return http.Response('{}', 200);
      });
      final service = ApiService(
        client: client,
        baseUrl: 'http://test.local',
        session: session,
      );

      await Future.wait([
        service.get('/api/users/me'),
        service.get('/api/users/me/saved'),
        service.get('/api/recipes'),
      ]);

      expect(refreshes, 1);
    });
  });

  group('verbs', () {
    test('put and delete reach the right method and path', () async {
      final seen = <String>[];

      final client = MockClient((request) async {
        seen.add('${request.method} ${request.url.path}');
        return http.Response(jsonEncode({}), 200);
      });
      final service =
          ApiService(client: client, baseUrl: 'http://test.local');

      await service.put('/api/users/me/preferences', body: {'a': 1});
      await service.delete('/api/users/me/saved/r1');

      expect(seen, [
        'PUT /api/users/me/preferences',
        'DELETE /api/users/me/saved/r1',
      ]);
    });

    // Every user endpoint is behind a bearer token, so every verb has to
    // carry it — not just GET.
    test('every verb carries the bearer token', () async {
      final session = await _signedInSession('token-abc');
      final headers = <String, String?>{};

      final client = MockClient((request) async {
        headers[request.method] = request.headers['Authorization'];
        return http.Response(jsonEncode({}), 200);
      });
      final service = ApiService(
        client: client,
        baseUrl: 'http://test.local',
        session: session,
      );

      await service.get('/api/users/me');
      await service.post('/api/users/me/saved', body: {'recipe_id': 'r1'});
      await service.put('/api/users/me/preferences', body: {'a': 1});
      await service.delete('/api/users/me/saved/r1');

      expect(headers, {
        'GET': 'Bearer token-abc',
        'POST': 'Bearer token-abc',
        'PUT': 'Bearer token-abc',
        'DELETE': 'Bearer token-abc',
      });
    });
  });
}
