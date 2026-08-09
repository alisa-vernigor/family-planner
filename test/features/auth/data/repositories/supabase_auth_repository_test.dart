import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:family_planner/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:family_planner/features/auth/domain/entities/auth_event.dart';

typedef _Router = http.Response Function(http.Request request);

String _fakeAccessToken() {
  String b64url(Object obj) => base64Url
      .encode(utf8.encode(jsonEncode(obj)))
      .replaceAll('=', '');
  final header = b64url({'alg': 'HS256', 'typ': 'JWT'});
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final payload = b64url({
    'sub': 'user-1',
    'aud': 'authenticated',
    'role': 'authenticated',
    'exp': now + 3600,
    'iat': now,
  });
  final signature = b64url({'sig': 'test'});
  return '$header.$payload.$signature';
}

Map<String, dynamic> _sessionJson({String id = 'user-1'}) {
  return {
    'access_token': _fakeAccessToken(),
    'token_type': 'bearer',
    'expires_in': 3600,
    'expires_at': 9999999999,
    'refresh_token': 'refresh-token',
    'user': {
      'id': id,
      'aud': 'authenticated',
      'role': 'authenticated',
      'email': 'a@b.c',
      'app_metadata': {'provider': 'email'},
      'user_metadata': {'display_name': 'Alice'},
      'created_at': '2026-08-01T10:00:00.000Z',
    },
  };
}

http.Response _json(Object? body, http.Request request, {int status = 200}) {
  return http.Response(
    jsonEncode(body),
    status,
    request: request,
    headers: {'content-type': 'application/json'},
  );
}

SupabaseClient _buildClient(
  List<({String method, String path, Map<String, dynamic>? body})>
      capturedRequests, {
  required _Router router,
}) {
  final mockHttp = MockClient((request) async {
    Map<String, dynamic>? body;
    if (request.body.isNotEmpty) {
      try {
        body = jsonDecode(request.body) as Map<String, dynamic>;
      } catch (_) {}
    }
    capturedRequests.add((
      method: request.method,
      path: request.url.path,
      body: body,
    ));
    final path = request.url.path;
    if (path.startsWith('/auth/v1/')) {
      if (path.endsWith('/user') && request.method == 'GET') {
        // setSession / getUser — отдаём пользователя из сессии.
        return _json(_sessionJson()['user']!, request);
      }
      // Все прочие auth-эндпоинты (signup/token/recover/logout) —
      // через router, чтобы тесты могли переопределить ответ.
      return router(request);
    }
    if (path.startsWith('/storage/v1/') || path.startsWith('/realtime/v1/')) {
      return _json({}, request);
    }
    return router(request);
  });

  return SupabaseClient(
    'http://localhost:54321',
    'test-key',
    httpClient: mockHttp,
    authOptions: const AuthClientOptions(
      autoRefreshToken: false,
      authFlowType: AuthFlowType.implicit,
    ),
  );
}

void main() {
  group('SupabaseAuthRepository', () {
    late List<({String method, String path, Map<String, dynamic>? body})>
        captured;
    late _Router router;
    late SupabaseClient client;
    late SupabaseAuthRepository repo;

    setUp(() {
      captured = [];
      router = (request) {
        final path = request.url.path;
        if (path.startsWith('/auth/v1/')) {
          // По умолчанию auth-эндпоинты возвращают полную сессию.
          return _json(_sessionJson(), request);
        }
        return _json(const [], request);
      };
      client = _buildClient(captured, router: (request) => router(request));
      repo = SupabaseAuthRepository(client: client);
    });

    test('currentUser без сессии возвращает null', () {
      expect(repo.currentUser, isNull);
    });

    test('currentUser возвращает AppUser после setSession', () async {
      await client.auth.setSession(
        'refresh-token',
        accessToken: _fakeAccessToken(),
      );

      final user = repo.currentUser;

      expect(user, isNotNull);
      expect(user!.id, 'user-1');
      expect(user.email, 'a@b.c');
    });

    test('signUp шлёт POST /auth/v1/signup и возвращает AppUser', () async {
      final user = await repo.signUp(
        email: 'new@example.com',
        password: 'secret123',
        displayName: 'Новичок',
      );

      expect(user, isNotNull);
      expect(user!.id, 'user-1');
      expect(user.email, 'a@b.c');

      final signup = captured.singleWhere((r) => r.path == '/auth/v1/signup');
      expect(signup.method, 'POST');
      expect(signup.body!['email'], 'new@example.com');
      expect(signup.body!['password'], 'secret123');
      final data = signup.body!['data'] as Map<String, dynamic>;
      expect(data['display_name'], 'Новичок');
    });

    test('signUp без сессии возвращает null', () async {
      router = (request) {
        if (request.url.path == '/auth/v1/signup') {
          // Ответ без session (email confirmation).
          return _json({
            'user': {
              'id': 'user-2',
              'aud': 'authenticated',
              'role': 'authenticated',
              'email': 'a@b.c',
              'app_metadata': {'provider': 'email'},
              'user_metadata': {},
              'created_at': '2026-08-01T10:00:00.000Z',
            },
          }, request);
        }
        return _json(const [], request);
      };

      final user = await repo.signUp(
        email: 'a@b.c',
        password: 'secret123',
        displayName: 'Alice',
      );

      expect(user, isNull);
    });

    test('signIn шлёт POST /auth/v1/token с grant_type=password', () async {
      final user = await repo.signIn(email: 'a@b.c', password: 'secret123');

      expect(user.id, 'user-1');
      expect(user.email, 'a@b.c');

      final token = captured.singleWhere((r) => r.path == '/auth/v1/token');
      expect(token.method, 'POST');
      expect(token.body!['email'], 'a@b.c');
      expect(token.body!['password'], 'secret123');
    });

    test('signIn без user кидает AuthUserNotReturnedException', () async {
      router = (request) {
        if (request.url.path == '/auth/v1/token') {
          return _json({'access_token': null, 'token_type': 'bearer'}, request);
        }
        return _json(const [], request);
      };

      await expectLater(
        repo.signIn(email: 'a@b.c', password: 'x'),
        throwsA(isA<AuthUserNotReturnedException>()),
      );
    });

    test('signOut шлёт POST /auth/v1/logout', () async {
      await client.auth.setSession(
        'refresh-token',
        accessToken: _fakeAccessToken(),
      );

      await repo.signOut();

      final logout = captured.singleWhere(
        (r) => r.path == '/auth/v1/logout' && r.method == 'POST',
      );
      expect(logout, isNotNull);
    });

    test('signOut без сессии не падает', () async {
      await repo.signOut();
      // Никакого исключения.
    });

    test('sendPasswordReset шлёт POST /auth/v1/recover', () async {
      await repo.sendPasswordReset(email: 'a@b.c');

      final recover = captured.singleWhere((r) => r.path == '/auth/v1/recover');
      expect(recover.method, 'POST');
      expect(recover.body!['email'], 'a@b.c');
    });

    test('updatePassword шлёт PUT /auth/v1/user', () async {
      await client.auth.setSession(
        'refresh-token',
        accessToken: _fakeAccessToken(),
      );

      await repo.updatePassword(newPassword: 'new-secret');

      final userPut = captured.singleWhere(
        (r) => r.path == '/auth/v1/user' && r.method == 'PUT',
      );
      expect(userPut.body!['password'], 'new-secret');
    });

    test('authStateEvents эмитит signedOut при выходе', () async {
      await client.auth.setSession(
        'refresh-token',
        accessToken: _fakeAccessToken(),
      );
      final events = <AuthStateEvent>[];
      final sub = repo.authStateEvents.listen(events.add);

      await repo.signOut();

      expect(events, contains(AuthStateEvent.signedOut));
      await sub.cancel();
    });
  });
}
