import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:family_planner/features/notifications/data/repositories/supabase_notifications_repository.dart';
import 'package:family_planner/features/notifications/domain/entities/notification_item.dart';

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

http.Response _json(Object body, http.Request request, {int status = 200}) {
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
        return _json(_sessionJson()['user']!, request);
      }
      return _json(_sessionJson(), request);
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

/// Строка task_occurrences, как её возвращает select для ленты.
Map<String, dynamic> _taskRow({
  String id = 'task-1',
  String householdId = 'household-1',
  String title = 'Убраться',
  String status = 'pending',
  String createdAt = '2026-08-01T10:00:00.000Z',
  String? completedAt,
  String updatedAt = '2026-08-08T12:00:00.000Z',
  String plannedFor = '2026-08-08',
  String? assignedMemberId,
  String? createdBy,
  Map<String, dynamic>? profiles,
}) {
  return {
    'id': id,
    'household_id': householdId,
    'title': title,
    'status': status,
    'created_at': createdAt,
    'completed_at': completedAt,
    'updated_at': updatedAt,
    'planned_for': plannedFor,
    'assigned_member_id': assignedMemberId,
    'created_by': createdBy,
    'profiles': profiles,
  };
}

/// Строка household_invitations для ленты.
Map<String, dynamic> _invitationRow({
  String id = 'inv-1',
  String householdId = 'household-1',
  String status = 'pending',
  String createdAt = '2026-08-02T10:00:00.000Z',
  String expiresAt = '2026-09-01T10:00:00.000Z',
  String? invitedByProfileId,
  Map<String, dynamic>? profiles,
}) {
  return {
    'id': id,
    'household_id': householdId,
    'status': status,
    'created_at': createdAt,
    'expires_at': expiresAt,
    'invited_by_profile_id': invitedByProfileId,
    'profiles': profiles,
  };
}

void main() {
  group('SupabaseNotificationsRepository', () {
    late List<({String method, String path, Map<String, dynamic>? body})>
        captured;
    late _Router router;
    late SupabaseClient client;
    late SupabaseNotificationsRepository repo;

    setUp(() {
      captured = [];
      router = (request) => _json(const [], request);
      client = _buildClient(captured, router: (request) => router(request));
      repo = SupabaseNotificationsRepository(client: client);
    });

    Future<void> auth() async {
      await client.auth.setSession(
        'refresh-token',
        accessToken: _fakeAccessToken(),
      );
    }

    void mockRouter(_Router r) {
      router = r;
    }

    test('без авторизации кидает NotificationsNotAuthenticatedException',
        () async {
      expect(() => repo.getActivityFeed(), throwsA(
        isA<NotificationsNotAuthenticatedException>(),
      ));
    });

    test('собирает taskAssigned для задач, назначенных мне другим', () async {
      await auth();
      mockRouter((request) {
        final path = request.url.path;
        if (path == '/rest/v1/task_occurrences') {
          return _json([
            _taskRow(
              id: 'task-1',
              title: 'Убраться',
              assignedMemberId: 'user-1',
              createdBy: 'user-2',
              profiles: {'display_name': 'Боб'},
            ),
          ], request);
        }
        return _json(const [], request);
      });

      final items = await repo.getActivityFeed();

      expect(items, hasLength(1));
      final item = items.single;
      expect(item.kind, NotificationKind.taskAssigned);
      expect(item.id, 'task:task-1:assigned');
      expect(item.actorName, 'Боб');
      expect(item.taskId, 'task-1');
      expect(item.householdId, 'household-1');
      expect(item.taskStatus, 'pending');
      expect(item.subtitle, contains('Убраться'));
    });

    test('не дублирует задачи, назначенные мне мной же', () async {
      await auth();
      mockRouter((request) {
        final path = request.url.path;
        if (path == '/rest/v1/task_occurrences') {
          return _json([
            _taskRow(
              id: 'task-1',
              assignedMemberId: 'user-1',
              createdBy: 'user-1',
            ),
          ], request);
        }
        return _json(const [], request);
      });

      final items = await repo.getActivityFeed();

      expect(items, isEmpty);
    });

    test('собирает taskCompleted для чужих выполненных задач', () async {
      await auth();
      mockRouter((request) {
        final path = request.url.path;
        if (path == '/rest/v1/task_occurrences') {
          return _json([
            _taskRow(
              id: 'task-2',
              title: 'Купить хлеб',
              status: 'completed',
              completedAt: '2026-08-08T12:00:00.000Z',
              createdBy: 'user-2',
              profiles: {'display_name': 'Боб'},
            ),
          ], request);
        }
        return _json(const [], request);
      });

      final items = await repo.getActivityFeed();

      expect(items, hasLength(1));
      final item = items.single;
      expect(item.kind, NotificationKind.taskCompleted);
      expect(item.id, 'task:task-2:completed');
      expect(item.occurredAt, DateTime.parse('2026-08-08T12:00:00.000Z'));
      expect(item.taskStatus, 'completed');
    });

    test('собирает taskSkipped для чужих пропущенных задач', () async {
      await auth();
      mockRouter((request) {
        final path = request.url.path;
        if (path == '/rest/v1/task_occurrences') {
          return _json([
            _taskRow(
              id: 'task-3',
              status: 'skipped',
              createdBy: 'user-2',
              profiles: {'display_name': 'Боб'},
            ),
          ], request);
        }
        return _json(const [], request);
      });

      final items = await repo.getActivityFeed();

      expect(items.single.kind, NotificationKind.taskSkipped);
      expect(items.single.id, 'task:task-3:skipped');
    });

    test('собирает invitation из household_invitations', () async {
      await auth();
      mockRouter((request) {
        final path = request.url.path;
        if (path == '/rest/v1/task_occurrences') {
          return _json(const [], request);
        }
        if (path == '/rest/v1/household_invitations') {
          return _json([
            _invitationRow(
              id: 'inv-1',
              invitedByProfileId: 'user-2',
              profiles: {'display_name': 'Мария'},
            ),
          ], request);
        }
        return _json(const [], request);
      });

      final items = await repo.getActivityFeed();

      expect(items, hasLength(1));
      final item = items.single;
      expect(item.kind, NotificationKind.invitation);
      expect(item.id, 'invitation:inv-1');
      expect(item.actorName, 'Мария');
      expect(item.invitationId, 'inv-1');
      expect(item.invitationStatus, 'pending');
      expect(item.isInvitation, isTrue);
    });

    test('сортирует ленту по occurredAt, новые сверху', () async {
      await auth();
      mockRouter((request) {
        final path = request.url.path;
        if (path == '/rest/v1/task_occurrences') {
          return _json([
            _taskRow(
              id: 'old',
              status: 'completed',
              completedAt: '2026-08-01T10:00:00.000Z',
              createdBy: 'user-2',
            ),
            _taskRow(
              id: 'new',
              status: 'completed',
              completedAt: '2026-08-08T10:00:00.000Z',
              createdBy: 'user-2',
            ),
          ], request);
        }
        if (path == '/rest/v1/household_invitations') {
          return _json([
            _invitationRow(
              id: 'inv-1',
              createdAt: '2026-08-05T10:00:00.000Z',
              invitedByProfileId: 'user-2',
            ),
          ], request);
        }
        return _json(const [], request);
      });

      final items = await repo.getActivityFeed();

      expect(items, hasLength(3));
      expect(items.first.id, 'task:new:completed');
      expect(items.last.id, 'task:old:completed');
    });

    test('markAllRead — no-op, не шлёт запросов к данным', () async {
      await auth();
      await repo.markAllRead();

      final dataRequests =
          captured.where((r) => !r.path.startsWith('/auth/v1/'));
      expect(dataRequests, isEmpty);
    });
  });
}
