import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:family_planner/features/tasks/data/repositories/supabase_task_repository.dart';
import 'package:family_planner/features/tasks/domain/entities/create_task_params.dart';
import 'package:family_planner/features/tasks/domain/entities/eisenhower_priority.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_recurrence.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:family_planner/features/tasks/domain/entities/update_recurring_task_params.dart';

/// Роутер-ответов: path → (method → JSON-ответ).
typedef _Router = http.Response Function(http.Request request);

Map<String, dynamic> _taskRow({
  String id = 'task-1',
  String householdId = 'household-1',
  String title = 'Задача',
  String? description,
  int estimatedDurationMinutes = 10,
  String plannedFor = '2026-08-08',
  String? plannedTime,
  String? deadlineAt,
  String? assignedMemberId,
  String? pinnedMemberId,
  String status = 'pending',
  String createdAt = '2026-08-01T10:00:00.000Z',
  String? completedAt,
  String? updatedAt = '2026-08-01T10:00:00.000Z',
  int? priority,
  String? templateId,
  String? recurrenceType,
  int? intervalDays,
  List<int>? weekdays,
  String? recurrenceStartDate,
  String? recurrenceEndDate,
  int? reminderMinutesBefore,
  String? categoryId,
  bool? isActive,
  List<Map<String, dynamic>>? allowedMembers,
}) {
  return {
    'id': id,
    'household_id': householdId,
    'title': title,
    'description': description,
    'estimated_duration_minutes': estimatedDurationMinutes,
    'planned_for': plannedFor,
    'planned_time': plannedTime,
    'deadline_at': deadlineAt,
    'assigned_member_id': assignedMemberId,
    'pinned_member_id': pinnedMemberId,
    'status': status,
    'created_at': createdAt,
    'completed_at': completedAt,
    'updated_at': updatedAt,
    'priority': priority,
    'reminder_minutes_before': reminderMinutesBefore,
    'category_id': categoryId,
    'template_id': templateId,
    'task_occurrence_allowed_members':
        allowedMembers ?? [{'profile_id': 'user-1'}],
    'task_templates': templateId == null
        ? null
        : {
            'recurrence_type': recurrenceType,
            'interval_days': intervalDays,
            'weekdays': weekdays ?? const [],
            'recurrence_start_date': recurrenceStartDate,
            'recurrence_end_date': recurrenceEndDate,
            'is_active': isActive,
          },
  };
}

/// Собирает валидный JWT-вид access_token для gotrue (base64url header.payload.signature).
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

/// JSON-тело сессии/пользователя для auth-запросов.
Map<String, dynamic> _authSessionJson({String id = 'user-1'}) {
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

    // Auth-эндпоинты: token/signup/user/logout.
    final path = request.url.path;
    if (path.startsWith('/auth/v1/')) {
      if (path.endsWith('/token') && request.method == 'POST') {
        return _json(_authSessionJson(), request);
      }
      if (path.endsWith('/signup') && request.method == 'POST') {
        return _json(_authSessionJson(), request);
      }
      if (path.endsWith('/user') && request.method == 'GET') {
        return _json(_authSessionJson()['user']!, request);
      }
      if (path.endsWith('/logout') && request.method == 'POST') {
        return http.Response(
          '{}',
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }
      return _json({}, request);
    }
    if (path.startsWith('/storage/v1/')) {
      return _json({}, request);
    }
    if (path.startsWith('/realtime/v1/')) {
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
  group('SupabaseTaskRepository', () {
    late List<({String method, String path, Map<String, dynamic>? body})>
        captured;
    late _Router router;
    late SupabaseClient client;
    late SupabaseTaskRepository repo;

    setUp(() {
      captured = [];
      router = (request) => _json(const [], request);
      client = _buildClient(captured, router: (request) => router(request));
      repo = SupabaseTaskRepository(client: client);
    });

    Future<void> auth() async {
      await client.auth.setSession(
        'refresh-token',
        accessToken: _fakeAccessToken(),
      );
    }

    /// Переопределяет router на время теста.
    void mockRouter(_Router r) {
      router = r;
    }

    test('getForDay делает SELECT task_occurrences с фильтром по дню и парсит',
        () async {
      await auth();
      mockRouter((request) {
        if (request.url.path == '/rest/v1/task_occurrences') {
          return _json([
            _taskRow(
              id: 'task-1',
              title: 'Убраться',
              plannedFor: '2026-08-08',
              plannedTime: '09:30:00',
              deadlineAt: '2026-08-08T12:00:00.000Z',
              priority: 1,
              reminderMinutesBefore: 30,
              categoryId: 'cat-1',
              allowedMembers: [
                {'profile_id': 'user-1'},
                {'profile_id': 'user-2'},
              ],
            ),
          ], request);
        }
        return _json(const [], request);
      });

      final tasks = await repo.getForDay(
        householdId: 'household-1',
        day: DateTime(2026, 8, 8),
      );

      expect(tasks, hasLength(1));
      final task = tasks.single;
      expect(task.title, 'Убраться');
      expect(task.plannedTime, const Duration(hours: 9, minutes: 30));
      expect(task.priority, EisenhowerPriority.urgentImportant);
      expect(task.allowedMemberIds, ['user-1', 'user-2']);
      expect(task.categoryId, 'cat-1');

      final request = captured.singleWhere(
        (r) => r.path == '/rest/v1/task_occurrences',
      );
      expect(request.method, 'GET');
      expect(request.path, '/rest/v1/task_occurrences');
    });

    test('getForDay парсит вложенный шаблон серии (recurring)', () async {
      await auth();
      mockRouter((request) {
        return _json([
          _taskRow(
            id: 'task-rec',
            templateId: 'tmpl-1',
            recurrenceType: 'weekly',
            weekdays: [1, 3],
            recurrenceStartDate: '2026-08-01',
            recurrenceEndDate: '2026-09-01',
            isActive: false,
          ),
        ], request);
      });

      final tasks = await repo.getForDay(
        householdId: 'household-1',
        day: DateTime(2026, 8, 8),
      );

      final task = tasks.single;
      expect(task.isRecurring, isTrue);
      expect(task.templateId, 'tmpl-1');
      expect(task.recurrence, const TaskRecurrence.weekly(weekdays: [1, 3]));
      expect(task.recurrenceStartDate, DateTime(2026, 8, 1));
      expect(task.recurrenceEndDate, DateTime(2026, 9, 1));
      expect(task.isSeriesPaused, isTrue);
    });

    test('getScheduledAfter и getAllPending шлют статус-фильтры и парсят',
        () async {
      await auth();
      mockRouter((request) {
        return _json([
          _taskRow(id: 'future-1', plannedFor: '2026-08-10'),
        ], request);
      });

      final scheduled = await repo.getScheduledAfter(
        householdId: 'household-1',
        day: DateTime(2026, 8, 8),
      );
      expect(scheduled, hasLength(1));
      expect(scheduled.single.id, 'future-1');

      final pending = await repo.getAllPending(householdId: 'household-1');
      expect(pending, hasLength(1));
    });

    test('неизвестный статус кидает FormatException', () async {
      await auth();
      mockRouter((request) {
        return _json([_taskRow(status: 'bogus')], request);
      });

      expect(
        () => repo.getForDay(
          householdId: 'household-1',
          day: DateTime(2026, 8, 8),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    group('create', () {
      test('обычная задача через RPC create_task_occurrence', () async {
        await auth();
        final rpcCalls = <String>[];
        mockRouter((request) {
          if (request.url.path == '/rest/v1/rpc/create_task_occurrence') {
            rpcCalls.add(request.body);
            return _json({
              'id': 'task-new',
              'household_id': 'household-1',
              'title': 'Новая',
              'estimated_duration_minutes': 10,
              'planned_for': '2026-08-08',
              'status': 'pending',
              'priority': 2,
              'created_at': '2026-08-08T10:00:00.000Z',
              'updated_at': '2026-08-08T10:00:00.000Z',
              'assigned_member_id': null,
              'pinned_member_id': null,
            }, request);
          }
          return _json(const [], request);
        });

        final task = await repo.create(
          params: CreateTaskParams(
            householdId: 'household-1',
            title: 'Новая',
            estimatedDurationMinutes: 10,
            plannedFor: DateTime(2026, 8, 8),
            priority: EisenhowerPriority.notUrgentImportant,
            plannedTime: const Duration(hours: 8, minutes: 15),
          ),
        );

        expect(rpcCalls, hasLength(1));
        expect(task.id, 'task-new');
        expect(task.allowedMemberIds, ['user-1']);
        expect(task.priority, EisenhowerPriority.notUrgentImportant);
        final rpcBody = jsonDecode(rpcCalls.single) as Map<String, dynamic>;
        expect(rpcBody['p_planned_for'], '2026-08-08');
        expect(rpcBody['p_planned_time'], '08:15:00');
        expect(rpcBody['p_priority'], 2);
      });

      test('recurring задача через create_recurring_task_template', () async {
        await auth();
        final rpcCalls = <String>[];
        mockRouter((request) {
          if (request.url.path ==
              '/rest/v1/rpc/create_recurring_task_template') {
            rpcCalls.add(request.body);
            return _json({
              'id': 'task-rec',
              'household_id': 'household-1',
              'title': 'Серия',
              'estimated_duration_minutes': 5,
              'planned_for': '2026-08-08',
              'status': 'pending',
              'created_at': '2026-08-08T10:00:00.000Z',
              'updated_at': '2026-08-08T10:00:00.000Z',
            }, request);
          }
          return _json(const [], request);
        });

        await repo.create(
          params: CreateTaskParams(
            householdId: 'household-1',
            title: 'Серия',
            estimatedDurationMinutes: 5,
            plannedFor: DateTime(2026, 8, 8),
            recurrence: const TaskRecurrence.daily(),
            recurrenceEndDate: DateTime(2026, 9, 8),
          ),
        );

        expect(rpcCalls, hasLength(1));
        final rpcBody = jsonDecode(rpcCalls.single) as Map<String, dynamic>;
        expect(rpcBody['p_recurrence_type'], 'daily');
        expect(rpcBody['p_start_date'], '2026-08-08');
        expect(rpcBody['p_end_date'], '2026-09-08');
      });

      test('create без авторизации кидает TaskUserNotAuthenticatedException',
          () async {
        mockRouter((request) {
          if (request.url.path == '/rest/v1/rpc/create_task_occurrence') {
            return _json({
              'id': 'task-new',
              'household_id': 'household-1',
              'title': 'Новая',
              'estimated_duration_minutes': 10,
              'planned_for': '2026-08-08',
              'status': 'pending',
              'created_at': '2026-08-08T10:00:00.000Z',
            }, request);
          }
          return _json(const [], request);
        });

        expect(
          () => repo.create(
            params: CreateTaskParams(
              householdId: 'household-1',
              title: 'Новая',
              estimatedDurationMinutes: 10,
              plannedFor: DateTime(2026, 8, 8),
            ),
          ),
          throwsA(isA<TaskUserNotAuthenticatedException>()),
        );
      });

      test('create с назначенным исполнителем делает save + addAllowedMember',
          () async {
        await auth();
        final updates = <String>[];
        mockRouter((request) {
          final path = request.url.path;
          if (path == '/rest/v1/rpc/create_task_occurrence') {
            return _json({
              'id': 'task-new',
              'household_id': 'household-1',
              'title': 'Новая',
              'estimated_duration_minutes': 10,
              'planned_for': '2026-08-08',
              'status': 'pending',
              'created_at': '2026-08-08T10:00:00.000Z',
              'updated_at': '2026-08-08T10:00:00.000Z',
            }, request);
          }
          if (path == '/rest/v1/task_occurrences' &&
              request.method == 'PATCH') {
            updates.add(request.body);
            return _json([
              {'id': 'task-new'}
            ], request);
          }
          if (path == '/rest/v1/task_occurrence_allowed_members' &&
              request.method == 'POST') {
            return _json(const [], request);
          }
          return _json(const [], request);
        });

        await repo.create(
          params: CreateTaskParams(
            householdId: 'household-1',
            title: 'Новая',
            estimatedDurationMinutes: 10,
            plannedFor: DateTime(2026, 8, 8),
            assignedMemberId: 'user-2',
          ),
        );

        expect(updates, hasLength(1));
        final updateBody =
            jsonDecode(updates.single) as Map<String, dynamic>;
        expect(updateBody['assigned_member_id'], 'user-2');
      });
    });

    group('save', () {
      test('save шлёт UPDATE c optimistic-lock по updated_at', () async {
        await auth();
        mockRouter((request) {
          if (request.url.path == '/rest/v1/task_occurrences' &&
              request.method == 'PATCH') {
            return _json([
              {'id': 'task-1'}
            ], request);
          }
          return _json(const [], request);
        });

        await repo.save(
          Task(
            id: 'task-1',
            householdId: 'household-1',
            title: 'Обновлено',
            estimatedDurationMinutes: 15,
            plannedFor: DateTime(2026, 8, 8),
            allowedMemberIds: const ['user-1'],
            status: TaskStatus.pending,
            createdAt: DateTime(2026, 8, 1),
            updatedAt: DateTime(2026, 8, 1, 12),
          ),
        );

        final req = captured.singleWhere(
          (r) => r.path == '/rest/v1/task_occurrences' && r.method == 'PATCH',
        );
        final body = req.body!;
        expect(body['title'], 'Обновлено');
        expect(body.containsKey('completed_by_member_id'), isTrue);
      });

      test('save completed-задачи пишет completed_by_member_id = assigned',
          () async {
        await auth();
        mockRouter((request) {
          return _json([
            {'id': 'task-1'}
          ], request);
        });

        await repo.save(
          Task(
            id: 'task-1',
            householdId: 'household-1',
            title: 'Готово',
            estimatedDurationMinutes: 10,
            plannedFor: DateTime(2026, 8, 8),
            allowedMemberIds: const ['user-1'],
            status: TaskStatus.completed,
            createdAt: DateTime(2026, 8, 1),
            completedAt: DateTime(2026, 8, 8, 12),
            assignedMemberId: 'user-1',
          ),
        );

        final req = captured.singleWhere(
          (r) => r.path == '/rest/v1/task_occurrences' && r.method == 'PATCH',
        );
        expect(req.body!['completed_by_member_id'], 'user-1');
        expect(req.body!['completed_at'], isNotNull);
      });
    });

    group('updateTemplate / pause / resume', () {
      test('updateTemplate вызывает RPC update_task_template', () async {
        await auth();
        final rpcCalls = <String>[];
        mockRouter((request) {
          if (request.url.path == '/rest/v1/rpc/update_task_template') {
            rpcCalls.add(request.body);
            return _json(const [], request);
          }
          return _json(const [], request);
        });

        await repo.updateTemplate(
          params: UpdateRecurringTaskParams(
            task: Task(
              id: 'task-series',
              householdId: 'household-1',
              title: 'Серия',
              estimatedDurationMinutes: 10,
              plannedFor: DateTime(2026, 8, 8),
              allowedMemberIds: const ['user-1'],
              status: TaskStatus.pending,
              createdAt: DateTime(2026, 8, 1),
            ),
            recurrence: const TaskRecurrence.weekly(weekdays: [2, 5]),
            scope: RecurrenceEditScope.thisAndFollowing,
            newStartDate: DateTime(2026, 8, 20),
          ),
        );

        expect(rpcCalls, hasLength(1));
        final body = jsonDecode(rpcCalls.single) as Map<String, dynamic>;
        expect(body['p_scope'], 'this_and_following');
        expect(body['p_recurrence_type'], 'weekly');
        expect(body['p_new_start_date'], '2026-08-20');
        expect(body['p_task_occurrence_id'], 'task-series');
      });

      test('pauseTemplate/resumeTemplate вызывают RPC', () async {
        await auth();
        final rpcCalls = <String>[];
        mockRouter((request) {
          final path = request.url.path;
          if (path == '/rest/v1/rpc/pause_task_template' ||
              path == '/rest/v1/rpc/resume_task_template') {
            rpcCalls.add(path);
            return _json(const [], request);
          }
          return _json(const [], request);
        });

        await repo.pauseTemplate(templateId: 'tmpl-1');
        await repo.resumeTemplate(templateId: 'tmpl-1');

        expect(rpcCalls, [
          '/rest/v1/rpc/pause_task_template',
          '/rest/v1/rpc/resume_task_template',
        ]);
      });
    });

    group('delete / patchStatus / allowed members', () {
      test('delete шлёт DELETE по id', () async {
        await auth();
        await repo.delete(taskId: 'task-1');

        final req = captured.singleWhere((r) => r.method == 'DELETE');
        expect(req.path, '/rest/v1/task_occurrences');
      });

      test('patchStatus шлёт UPDATE с 3 полями + assigned при передаче',
          () async {
        await auth();
        await repo.patchStatus(
          taskId: 'task-1',
          status: 'completed',
          completedByMemberId: 'user-1',
          completedAt: '2026-08-08T12:00:00.000Z',
          assignedMemberId: 'user-1',
        );

        final req = captured.singleWhere((r) => r.method == 'PATCH');
        expect(req.body!['status'], 'completed');
        expect(req.body!['assigned_member_id'], 'user-1');
      });

      test('patchStatus без assignedMemberId не шлёт его', () async {
        await auth();
        await repo.patchStatus(taskId: 'task-1', status: 'skipped');

        final req = captured.singleWhere((r) => r.method == 'PATCH');
        expect(req.body!.containsKey('assigned_member_id'), isFalse);
      });

      test('addAllowedMember вставляет строку', () async {
        await auth();
        await repo.addAllowedMember(taskId: 'task-1', memberId: 'user-2');

        final req = captured.singleWhere((r) => r.method == 'POST');
        expect(req.path, '/rest/v1/task_occurrence_allowed_members');
        expect(req.body!['task_occurrence_id'], 'task-1');
        expect(req.body!['profile_id'], 'user-2');
      });

      test('removeAllowedMember шлёт DELETE по двум eq', () async {
        await auth();
        await repo.removeAllowedMember(taskId: 'task-1', memberId: 'user-2');

        final req = captured.singleWhere((r) => r.method == 'DELETE');
        expect(req.path, '/rest/v1/task_occurrence_allowed_members');
      });
    });
  });
}
