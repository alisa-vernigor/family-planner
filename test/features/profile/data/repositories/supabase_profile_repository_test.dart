import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:family_planner/features/profile/data/repositories/supabase_profile_repository.dart';

typedef _Router = http.Response Function(http.Request request);

http.Response _json(Object? body, http.Request request, {int status = 200}) {
  return http.Response(
    jsonEncode(body),
    status,
    request: request,
    headers: {'content-type': 'application/json'},
  );
}

SupabaseClient _buildClient(
  List<({String method, String path, String? body, String? contentType})>
      capturedRequests, {
  required _Router router,
}) {
  final mockHttp = MockClient((request) async {
    capturedRequests.add((
      method: request.method,
      path: request.url.path,
      body: request.body,
      contentType: request.headers['content-type'],
    ));
    final path = request.url.path;
    if (path.startsWith('/auth/v1/')) {
      return _json({}, request);
    }
    if (path.startsWith('/realtime/v1/')) {
      return _json({}, request);
    }
    // Storage endpoints: пропускаем, отвечаем пустыми списками/Key.
    if (path.startsWith('/storage/v1/')) {
      if (path.endsWith('/object/list/avatars')) {
        return _json([
          {'name': 'avatar.jpg', 'id': 'file-1'},
        ], request);
      }
      if (path.endsWith('/object/avatars')) {
        return _json([
          {'name': 'avatar.jpg', 'id': 'file-1'},
        ], request);
      }
      if (path.contains('/object/avatars/')) {
        // uploadBinary → {'Key': path}
        return _json({'Key': 'user-1/avatar.png'}, request);
      }
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

Map<String, dynamic> _profileRow({
  String id = 'user-1',
  String? displayName = 'Алиса',
  String? avatarUrl = 'https://x/a.jpg',
  String? timezone = 'Europe/Moscow',
  String? bio = 'Привет',
}) {
  return {
    'id': id,
    'display_name': displayName,
    'avatar_url': avatarUrl,
    'timezone': timezone,
    'bio': bio,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SupabaseProfileRepository', () {
    late List<({String method, String path, String? body, String? contentType})>
        captured;
    late _Router router;
    late SupabaseClient client;
    late SupabaseProfileRepository repo;

    setUp(() {
      captured = [];
      router = (request) => _json(const [], request);
      client = _buildClient(captured, router: (request) => router(request));
      repo = SupabaseProfileRepository(client: client);
    });

    void mockRouter(_Router r) {
      router = r;
    }

    test('getProfile делает SELECT profiles и парсит с дефолтами', () async {
      mockRouter((request) {
        expect(request.url.path, '/rest/v1/profiles');
        expect(request.method, 'GET');
        return _json({
          'id': 'user-1',
          'display_name': null,
          'avatar_url': null,
          'timezone': null,
          'bio': null,
        }, request);
      });

      final profile = await repo.getProfile('user-1');

      expect(profile.id, 'user-1');
      expect(profile.displayName, '');
      expect(profile.avatarUrl, isNull);
      expect(profile.timezone, 'Europe/Moscow');
      expect(profile.bio, '');
    });

    test('getProfile парсит заполненный профиль', () async {
      mockRouter((request) {
        return _json(_profileRow(), request);
      });

      final profile = await repo.getProfile('user-1');

      expect(profile.displayName, 'Алиса');
      expect(profile.avatarUrl, 'https://x/a.jpg');
      expect(profile.timezone, 'Europe/Moscow');
      expect(profile.bio, 'Привет');
    });

    test('updateProfile шлёт PATCH только с переданными полями', () async {
      mockRouter((request) {
        expect(request.method, 'PATCH');
        expect(request.url.path, '/rest/v1/profiles');
        return _json(const [], request);
      });

      await repo.updateProfile(
        profileId: 'user-1',
        displayName: 'Новое имя',
        timezone: 'UTC',
      );

      final patch = captured.singleWhere((r) => r.method == 'PATCH');
      final body = jsonDecode(patch.body!) as Map<String, dynamic>;
      expect(body['display_name'], 'Новое имя');
      expect(body['timezone'], 'UTC');
      expect(body.containsKey('bio'), isFalse);
    });

    test('updateProfile с пустыми полями — no-op без запроса', () async {
      await repo.updateProfile(profileId: 'user-1');

      final dataRequests = captured.where((r) => !r.path.startsWith('/auth/'));
      expect(dataRequests, isEmpty);
    });

    test('uploadAvatar: удаляет старые, загружает, обновляет avatar_url',
        () async {
      mockRouter((request) {
        if (request.url.path == '/rest/v1/profiles' &&
            request.method == 'PATCH') {
          return _json(const [], request);
        }
        return _json(const [], request);
      });

      final url = await repo.uploadAvatar(
        profileId: 'user-1',
        bytes: Uint8List.fromList([1, 2, 3]),
        contentType: 'image/jpeg',
      );

      expect(url, startsWith('http://localhost:54321/storage/v1/object/public/avatars/user-1/avatar.jpg'));
      expect(url, contains('?t='));

      // Был list → remove → upload → PATCH profiles.
      final paths = captured.map((r) => r.path).toList();
      expect(paths, contains('/storage/v1/object/list/avatars'));
      expect(paths, contains('/storage/v1/object/avatars')); // remove
      expect(paths, contains('/storage/v1/object/avatars/user-1/avatar.jpg')); // uploadBinary
      expect(paths, contains('/rest/v1/profiles'));

      // Content type для upload — multipart/form-data (binary в теле).
      final upload = captured.singleWhere(
        (r) => r.path == '/storage/v1/object/avatars/user-1/avatar.jpg',
      );
      expect(upload.method, 'POST');
      expect(upload.contentType, contains('multipart/form-data'));
      expect(upload.body, contains('image/jpeg'));
    });

    test('uploadAvatar для png использует расширение png', () async {
      mockRouter((request) {
        return _json(const [], request);
      });

      final url = await repo.uploadAvatar(
        profileId: 'user-1',
        bytes: Uint8List.fromList([1, 2, 3]),
        contentType: 'image/png',
      );

      expect(url, contains('/avatars/user-1/avatar.png'));
    });

    test('removeAvatar: удаляет файлы и обнуляет avatar_url', () async {
      mockRouter((request) {
        if (request.url.path == '/rest/v1/profiles' &&
            request.method == 'PATCH') {
          return _json(const [], request);
        }
        return _json(const [], request);
      });

      await repo.removeAvatar('user-1');

      final paths = captured.map((r) => r.path).toList();
      expect(paths, contains('/storage/v1/object/list/avatars'));
      expect(paths, contains('/storage/v1/object/avatars')); // remove

      final patch = captured.singleWhere(
        (r) => r.path == '/rest/v1/profiles' && r.method == 'PATCH',
      );
      final body = jsonDecode(patch.body!) as Map<String, dynamic>;
      expect(body['avatar_url'], isNull);
    });

    test('getStats парсит RPC-ответ и считает completionRate', () async {
      mockRouter((request) {
        expect(request.url.path, '/rest/v1/rpc/get_profile_stats');
        return _json([
          {
            'total_assigned': 10,
            'completed_tasks': 4,
            'completed_this_month': 3,
            'completed_this_week': 1,
          },
        ], request);
      });

      final stats = await repo.getStats('user-1');

      expect(stats.totalAssigned, 10);
      expect(stats.completedTasks, 4);
      expect(stats.completedThisMonth, 3);
      expect(stats.completedThisWeek, 1);
      expect(stats.completionRate, closeTo(0.4, 0.0001));
    });

    test('getStats при пустом ответе возвращает пустую статистику', () async {
      mockRouter((request) {
        return _json(const [], request);
      });

      final stats = await repo.getStats('user-1');

      expect(stats.totalAssigned, 0);
      expect(stats.completedTasks, 0);
    });

    test('getStats при null возвращает пустую статистику', () async {
      mockRouter((request) {
        return _json(null, request);
      });

      final stats = await repo.getStats('user-1');

      expect(stats.totalAssigned, 0);
    });

    test('getStats при ошибке не падает, возвращает пустую статистику',
        () async {
      mockRouter((request) {
        return http.Response(
          '{"message":"error"}',
          500,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      });

      final stats = await repo.getStats('user-1');

      expect(stats.totalAssigned, 0);
    });
  });
}
