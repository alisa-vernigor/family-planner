import 'dart:convert';

import 'package:drift/drift.dart' hide Column, isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:family_planner/core/database/app_database.dart';
import 'package:family_planner/core/services/connectivity_service.dart';
import 'package:family_planner/features/tasks/data/repositories/drift_task_repository.dart';
import 'package:family_planner/features/tasks/domain/entities/create_task_params.dart';
import 'package:family_planner/features/tasks/domain/entities/eisenhower_priority.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_recurrence.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:family_planner/features/tasks/domain/entities/update_recurring_task_params.dart';

class MockConnectivityService extends Mock implements ConnectivityService {}

AppDatabase _createDb() => AppDatabase(NativeDatabase.memory());

/// Билдер JSON-строки задачи, как её возвращает Supabase select с
/// вложенными allowed members и template.
Map<String, dynamic> _remoteTaskRow({
  String id = 'task-1',
  String householdId = 'household-1',
  String title = 'Купить молоко',
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
  bool omitAllowedMembers = false,
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
    'task_occurrence_allowed_members': omitAllowedMembers
        ? null
        : allowedMembers ?? [{'profile_id': 'user-1'}],
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

/// Создаёт SupabaseClient с перехватом всех HTTP-запросов через MockClient.
/// Записи запросов копятся в [capturedRequests]. [onRequest] позволяет
/// вернуть кастомный ответ (JSON), иначе — пустой список `[]`.
SupabaseClient _buildClient(
  List<({String method, String path, Map<String, dynamic>? body})>
      capturedRequests, {
  http.Response Function(http.Request)? onRequest,
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
    if (onRequest != null) {
      return onRequest(request);
    }
    return http.Response(
      '[]',
      200,
      request: request,
      headers: {'content-type': 'application/json'},
    );
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
  group('DriftTaskRepository', () {
    late AppDatabase database;
    late MockConnectivityService connectivity;
    late List<({String method, String path, Map<String, dynamic>? body})>
        capturedRequests;
    late SupabaseClient supabase;

    setUp(() {
      database = _createDb();
      connectivity = MockConnectivityService();
      when(() => connectivity.currentOnline).thenReturn(false);
      capturedRequests = [];
      supabase = _buildClient(capturedRequests);
    });

    tearDown(() async {
      await database.close();
    });

    DriftTaskRepository repo() => DriftTaskRepository(
          database: database,
          supabaseClient: supabase,
          connectivityService: connectivity,
        );

    Future<TaskOccurrencesCompanion> seedTask({
      String id = 'task-1',
      String householdId = 'household-1',
      String title = 'Локальная задача',
      String? description,
      int estimatedDurationMinutes = 10,
      String plannedFor = '2026-08-08',
      int? plannedTime,
      String? deadline,
      String? assignedMemberId,
      String? pinnedMemberId,
      String status = 'pending',
      String createdAt = '2026-08-01T10:00:00.000Z',
      String? completedAt,
      String? updatedAt = '2026-08-01T10:00:00.000Z',
      int? priority,
      String allowedMemberIds = '["user-1"]',
      String? templateId,
      String? recurrenceType,
      int? intervalDays,
      String? weekdays,
      String? recurrenceStartDate,
      String? recurrenceEndDate,
      int? reminderMinutesBefore,
      String? categoryId,
      bool? templateActive,
    }) async {
      final companion = TaskOccurrencesCompanion(
        id: Value(id),
        householdId: Value(householdId),
        title: Value(title),
        description: Value(description),
        estimatedDurationMinutes: Value(estimatedDurationMinutes),
        plannedFor: Value(plannedFor),
        plannedTime: Value(plannedTime),
        deadline: Value(deadline),
        assignedMemberId: Value(assignedMemberId),
        pinnedMemberId: Value(pinnedMemberId),
        status: Value(status),
        createdAt: Value(createdAt),
        completedAt: Value(completedAt),
        updatedAt: Value(updatedAt),
        priority: Value(priority),
        allowedMemberIds: Value(allowedMemberIds),
        templateId: Value(templateId),
        recurrenceType: Value(recurrenceType),
        intervalDays: Value(intervalDays),
        weekdays: Value(weekdays),
        recurrenceStartDate: Value(recurrenceStartDate),
        recurrenceEndDate: Value(recurrenceEndDate),
        reminderMinutesBefore: Value(reminderMinutesBefore),
        categoryId: Value(categoryId),
        templateActive: Value(templateActive),
      );
      await database.taskDao.upsertTask(companion);
      return companion;
    }

    group('READ (offline)', () {
      test('getForDay возвращает задачи из кэша и конвертирует в домен',
          () async {
        await seedTask(
          id: 'task-1',
          plannedFor: '2026-08-08',
          plannedTime: 9 * 60 + 30,
          deadline: '2026-08-08T12:00:00.000Z',
          priority: 2,
          reminderMinutesBefore: 30,
          categoryId: 'cat-1',
          templateId: 'tmpl-1',
          recurrenceType: 'weekly',
          weekdays: '[1,3,5]',
          recurrenceStartDate: '2026-08-01',
          recurrenceEndDate: '2026-09-01',
          templateActive: true,
        );

        final tasks = await repo().getForDay(
          householdId: 'household-1',
          day: DateTime(2026, 8, 8),
        );

        expect(tasks, hasLength(1));
        final task = tasks.single;
        expect(task.title, 'Локальная задача');
        expect(task.plannedFor, DateTime(2026, 8, 8));
        expect(task.plannedTime, const Duration(hours: 9, minutes: 30));
        expect(task.deadline, DateTime.parse('2026-08-08T12:00:00.000Z'));
        expect(task.priority, EisenhowerPriority.notUrgentImportant);
        expect(task.reminderMinutesBefore, 30);
        expect(task.categoryId, 'cat-1');
        expect(task.templateId, 'tmpl-1');
        expect(task.recurrence, const TaskRecurrence.weekly(weekdays: [1, 3, 5]));
        expect(task.recurrenceStartDate, DateTime(2026, 8, 1));
        expect(task.recurrenceEndDate, DateTime(2026, 9, 1));
        expect(task.templateActive, isTrue);
        expect(task.allowedMemberIds, ['user-1']);
      });

      test('getForDay исключает skipped задачи из кэша', () async {
        await seedTask(id: 't-pending', status: 'pending');
        await seedTask(id: 't-skipped', status: 'skipped');
        await seedTask(id: 't-completed', status: 'completed');

        final tasks = await repo().getForDay(
          householdId: 'household-1',
          day: DateTime(2026, 8, 8),
        );

        expect(tasks.map((t) => t.id), containsAll(['t-pending', 't-completed']));
        expect(tasks.map((t) => t.id), isNot(contains('t-skipped')));
      });

      test('getScheduledAfter возвращает только будущие pending', () async {
        await seedTask(id: 't-today', plannedFor: '2026-08-08');
        await seedTask(id: 't-future', plannedFor: '2026-08-10');
        await seedTask(id: 't-done', plannedFor: '2026-08-10', status: 'completed');

        final tasks = await repo().getScheduledAfter(
          householdId: 'household-1',
          day: DateTime(2026, 8, 8),
        );

        expect(tasks.map((t) => t.id), ['t-future']);
      });

      test('getAllPending возвращает только pending', () async {
        await seedTask(id: 't-pending', plannedFor: '2026-08-01');
        await seedTask(id: 't-completed', plannedFor: '2026-08-01', status: 'completed');
        await seedTask(id: 't-skipped', plannedFor: '2026-08-01', status: 'skipped');

        final tasks = await repo().getAllPending(householdId: 'household-1');

        expect(tasks.map((t) => t.id), ['t-pending']);
      });

      test('статус completed конвертируется из строки (через getForDay)',
          () async {
        await seedTask(id: 't-pending', status: 'pending');
        await seedTask(id: 't-completed', status: 'completed');

        final tasks = await repo().getForDay(
          householdId: 'household-1',
          day: DateTime(2026, 8, 8),
        );

        final completed = tasks.firstWhere((t) => t.id == 't-completed');
        expect(completed.status, TaskStatus.completed);
      });
    });

    group('READ (online: fetch + cache)', () {
      test('getForDay при онлайне фетчит с сервера и кэширует', () async {
        when(() => connectivity.currentOnline).thenReturn(true);
        supabase = _buildClient(capturedRequests,
          onRequest: (request) {
            if (request.url.path == '/rest/v1/task_occurrences' &&
                request.method == 'GET') {
              return http.Response(
                jsonEncode([
                  _remoteTaskRow(
                    id: 'remote-1',
                    title: 'Серверная задача',
                    plannedFor: '2026-08-08',
                    allowedMembers: [
                      {'profile_id': 'user-1'},
                      {'profile_id': 'user-2'},
                    ],
                  ),
                ]),
                200,
                request: request,
                headers: {'content-type': 'application/json'},
              );
            }
            return http.Response(
              '[]',
              200,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          },
        );

        final tasks = await repo().getForDay(
          householdId: 'household-1',
          day: DateTime(2026, 8, 8),
        );

        expect(tasks, hasLength(1));
        expect(tasks.single.id, 'remote-1');
        expect(tasks.single.allowedMemberIds, ['user-1', 'user-2']);

        // Данные закэшированы в SQLite.
        final cached = await database.taskDao.getTaskById('remote-1');
        expect(cached, isNotNull);
        expect(cached!.title, 'Серверная задача');
      });

      test('сбой фетча не роняет чтение — отдаёт локальный кэш', () async {
        await seedTask(id: 'local-1', title: 'Локальная');
        when(() => connectivity.currentOnline).thenReturn(true);
        supabase = _buildClient(capturedRequests,
          onRequest: (_) => http.Response(
            '{"message":"error"}',
            500,
            headers: {'content-type': 'application/json'},
          ),
        );

        final tasks = await repo().getForDay(
          householdId: 'household-1',
          day: DateTime(2026, 8, 8),
        );

        expect(tasks, hasLength(1));
        expect(tasks.single.id, 'local-1');
      });

      test('getScheduledAfter при онлайне фетчит будущие задачи и кэширует', () async {
        when(() => connectivity.currentOnline).thenReturn(true);
        supabase = _buildClient(capturedRequests,
          onRequest: (request) {
            if (request.url.path == '/rest/v1/task_occurrences' &&
                request.method == 'GET') {
              return http.Response(
                jsonEncode([
                  _remoteTaskRow(
                    id: 'remote-future',
                    title: 'Будущая',
                    plannedFor: '2026-08-20',
                    allowedMembers: [
                      {'profile_id': 'user-1'},
                    ],
                  ),
                ]),
                200,
                request: request,
                headers: {'content-type': 'application/json'},
              );
            }
            return http.Response(
              '[]',
              200,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          },
        );

        final tasks = await repo().getScheduledAfter(
          householdId: 'household-1',
          day: DateTime(2026, 8, 10),
        );

        expect(tasks, hasLength(1));
        expect(tasks.single.id, 'remote-future');
        // Закэшировано.
        final cached = await database.taskDao.getTaskById('remote-future');
        expect(cached, isNotNull);
      });

      test('getAllPending при онлайне фетчит и кэширует', () async {
        when(() => connectivity.currentOnline).thenReturn(true);
        supabase = _buildClient(capturedRequests,
          onRequest: (request) {
            if (request.url.path == '/rest/v1/task_occurrences' &&
                request.method == 'GET') {
              return http.Response(
                jsonEncode([
                  _remoteTaskRow(
                    id: 'remote-pending',
                    title: 'Pending-задача',
                    plannedFor: '2026-08-11',
                  ),
                ]),
                200,
                request: request,
                headers: {'content-type': 'application/json'},
              );
            }
            return http.Response(
              '[]',
              200,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          },
        );

        final tasks = await repo().getAllPending(householdId: 'household-1');

        expect(tasks, hasLength(1));
        expect(tasks.single.id, 'remote-pending');
        final cached = await database.taskDao.getTaskById('remote-pending');
        expect(cached, isNotNull);
      });

      test('маппинг remote-строки с null-полями шаблона', () async {
        when(() => connectivity.currentOnline).thenReturn(true);
        supabase = _buildClient(capturedRequests,
          onRequest: (request) {
            if (request.url.path == '/rest/v1/task_occurrences' &&
                request.method == 'GET') {
              return http.Response(
                jsonEncode([
                  // template есть, но recurrence_start_date/end_date null →
                  // fallback-ветки (243-246).
                  _remoteTaskRow(
                    id: 'remote-template',
                    title: 'С шаблоном',
                    templateId: 'template-1',
                    recurrenceType: 'daily',
                    recurrenceStartDate: null,
                    recurrenceEndDate: null,
                    isActive: false,
                  ),
                  // allowed_members отсутствует в ответе → fallback-ветка 211 (?? []).
                  _remoteTaskRow(
                    id: 'remote-no-allowed',
                    title: 'Без исполнителей',
                    omitAllowedMembers: true,
                  ),
                ]),
                200,
                request: request,
                headers: {'content-type': 'application/json'},
              );
            }
            return http.Response(
              '[]',
              200,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          },
        );

        final tasks = await repo().getForDay(
          householdId: 'household-1',
          day: DateTime(2026, 8, 8),
        );

        expect(tasks, hasLength(2));
        final templated = tasks.singleWhere((t) => t.id == 'remote-template');
        expect(templated.isRecurring, isTrue);
        expect(templated.isSeriesPaused, isTrue);
        expect(templated.recurrenceStartDate, isNull);
        expect(templated.recurrenceEndDate, isNull);
        final noAllowed = tasks.singleWhere((t) => t.id == 'remote-no-allowed');
        expect(noAllowed.allowedMemberIds, isEmpty);
      });

      test('задачи с pending-операциями в очереди не перезатираются', () async {
        when(() => connectivity.currentOnline).thenReturn(true);
        await seedTask(
          id: 'task-pending',
          title: 'Локальное изменение',
        );
        // Ставим в очередь pending-операцию для этой задачи.
        await database.syncQueueDao.enqueue(
          entityType: 'task_occurrence',
          operation: 'UPDATE',
          entityId: 'task-pending',
          householdId: 'household-1',
          payload: {'base_updated_at': '2026-08-01T10:00:00.000Z'},
        );

        supabase = _buildClient(capturedRequests,
          onRequest: (request) {
            if (request.url.path == '/rest/v1/task_occurrences') {
              // Сервер прислал бы старую версию — не должен перезаписать.
              return http.Response(
                jsonEncode([
                  _remoteTaskRow(id: 'task-pending', title: 'Старое с сервера'),
                ]),
                200,
                request: request,
                headers: {'content-type': 'application/json'},
              );
            }
            return http.Response(
              '[]',
              200,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          },
        );

        final tasks = await repo().getForDay(
          householdId: 'household-1',
          day: DateTime(2026, 8, 8),
        );

        expect(tasks.single.title, 'Локальное изменение');
      });
    });

    group('CREATE', () {
      test('создаёт локальную задачу, ставит в очередь CREATE', () async {
        // supabase уже создан в setUp
        final params = CreateTaskParams(
          householdId: 'household-1',
          title: 'Новая задача',
          description: 'Описание',
          estimatedDurationMinutes: 25,
          plannedFor: DateTime(2026, 8, 10),
          deadline: DateTime(2026, 8, 10, 18, 30),
          priority: EisenhowerPriority.urgentImportant,
          reminderMinutesBefore: 15,
          categoryId: 'cat-1',
          plannedTime: const Duration(hours: 14, minutes: 5),
        );

        final task = await repo().create(params: params);

        expect(task.id, isNotEmpty);
        expect(task.status, TaskStatus.pending);
        expect(task.allowedMemberIds, contains('')); // currentUser пуст

        final stored = await database.taskDao.getTaskById(task.id);
        expect(stored, isNotNull);
        expect(stored!.plannedTime, 14 * 60 + 5);
        expect(stored.categoryId, 'cat-1');
        expect(stored.priority, 1);

        final pending = await database.syncQueueDao.getPending();
        expect(pending, hasLength(1));
        final entry = pending.single;
        expect(entry.operation, 'CREATE');
        expect(entry.entityId, task.id);
        final payload = jsonDecode(entry.payload) as Map<String, dynamic>;
        expect(payload['is_recurring'], isFalse);
        expect(payload['p_planned_for'], '2026-08-10');
        expect(payload['p_planned_time'], '14:05:00');
        expect(payload['p_priority'], 1);
      });

      test('recurring create добавляет recurring-поля в payload', () async {
        // supabase уже создан в setUp
        final params = CreateTaskParams(
          householdId: 'household-1',
          title: 'Поливать цветы',
          estimatedDurationMinutes: 5,
          plannedFor: DateTime(2026, 8, 10),
          recurrence: const TaskRecurrence.weekly(weekdays: [1, 4]),
          recurrenceEndDate: DateTime(2026, 9, 10),
          deadline: DateTime(2026, 8, 10, 9),
        );

        await repo().create(params: params);

        final pending = await database.syncQueueDao.getPending();
        final payload = jsonDecode(pending.single.payload) as Map<String, dynamic>;
        expect(payload['is_recurring'], isTrue);
        expect(payload['p_recurrence_type'], 'weekly');
        expect(payload['p_weekdays'], [1, 4]);
        expect(payload['p_start_date'], '2026-08-10');
        expect(payload['p_end_date'], '2026-09-10');
        expect(payload['p_deadline_time'], '09:00:00');
        expect(payload.containsKey('p_planned_for'), isFalse);
      });
    });

    group('SAVE / UPDATE', () {
      test('save обновляет кэш и ставит UPDATE в очередь', () async {
        // supabase уже создан в setUp
        final task = Task(
          id: 'task-1',
          householdId: 'household-1',
          title: 'Обновлённая',
          estimatedDurationMinutes: 15,
          plannedFor: DateTime(2026, 8, 8),
          allowedMemberIds: const ['user-1'],
          status: TaskStatus.pending,
          createdAt: DateTime(2026, 8, 1),
          updatedAt: DateTime(2026, 8, 1, 12),
        );

        await repo().save(task);

        final stored = await database.taskDao.getTaskById('task-1');
        expect(stored!.title, 'Обновлённая');

        final pending = await database.syncQueueDao.getPending();
        expect(pending.single.operation, 'UPDATE');
        final payload = jsonDecode(pending.single.payload) as Map<String, dynamic>;
        expect(payload['base_updated_at'], isNotNull);
      });

      test('updateTemplate обновляет локальный экземпляр и очередь UPDATE_TEMPLATE',
          () async {
        // supabase уже создан в setUp
        final task = Task(
          id: 'task-series',
          householdId: 'household-1',
          title: 'Серия',
          estimatedDurationMinutes: 10,
          plannedFor: DateTime(2026, 8, 8),
          deadline: DateTime(2026, 8, 8, 18, 30),
          allowedMemberIds: const ['user-1'],
          status: TaskStatus.pending,
          createdAt: DateTime(2026, 8, 1),
          updatedAt: DateTime(2026, 8, 1, 12),
          templateId: 'tmpl-1',
          recurrence: const TaskRecurrence.daily(),
          plannedTime: const Duration(hours: 9),
        );

        await repo().updateTemplate(
          params: UpdateRecurringTaskParams(
            task: task,
            recurrence: const TaskRecurrence.daily(),
            scope: RecurrenceEditScope.thisAndFollowing,
            newStartDate: DateTime(2026, 8, 20),
            recurrenceStartDate: DateTime(2026, 8, 8),
            recurrenceEndDate: DateTime(2026, 9, 8),
          ),
        );

        final stored = await database.taskDao.getTaskById('task-series');
        expect(stored!.recurrenceType, 'daily');

        final pending = await database.syncQueueDao.getPending();
        expect(pending.single.operation, 'UPDATE_TEMPLATE');
        final payload = jsonDecode(pending.single.payload) as Map<String, dynamic>;
        expect(payload['p_scope'], 'this_and_following');
        expect(payload['p_recurrence_type'], 'daily');
        expect(payload['p_new_start_date'], '2026-08-20');
        expect(payload['p_task_occurrence_id'], 'task-series');
        // Ветки 427-438: deadline и recurrence даты в payload.
        expect(payload['p_deadline_time'], '18:30:00');
        expect(payload['p_planned_time'], '09:00:00');
        expect(payload['p_start_date'], '2026-08-08');
        expect(payload['p_end_date'], '2026-09-08');
      });
    });

    group('PAUSE / RESUME', () {
      test('pauseTemplate помечает локально и ставит PAUSE_TEMPLATE', () async {
        // supabase уже создан в setUp
        await seedTask(id: 'task-1', templateId: 'tmpl-1', templateActive: true);

        await repo().pauseTemplate(templateId: 'tmpl-1');

        final stored = await database.taskDao.getTaskById('task-1');
        expect(stored!.templateActive, isFalse);

        final pending = await database.syncQueueDao.getPending();
        expect(pending.single.operation, 'PAUSE_TEMPLATE');
        final payload = jsonDecode(pending.single.payload) as Map<String, dynamic>;
        expect(payload['p_task_template_id'], 'tmpl-1');
        expect(pending.single.householdId, 'household-1');
      });

      test('resumeTemplate снимает паузу локально и ставит RESUME_TEMPLATE',
          () async {
        // supabase уже создан в setUp
        await seedTask(id: 'task-1', templateId: 'tmpl-1', templateActive: false);

        await repo().resumeTemplate(templateId: 'tmpl-1');

        final stored = await database.taskDao.getTaskById('task-1');
        expect(stored!.templateActive, isTrue);

        final pending = await database.syncQueueDao.getPending();
        expect(pending.single.operation, 'RESUME_TEMPLATE');
      });
    });

    group('PATCH STATUS', () {
      test('patchStatus обновляет кэш и очередь с 3 полями', () async {
        // supabase уже создан в setUp
        await seedTask(id: 'task-1', status: 'pending');

        await repo().patchStatus(
          taskId: 'task-1',
          status: 'completed',
          completedByMemberId: 'user-1',
          completedAt: '2026-08-08T12:00:00.000Z',
          assignedMemberId: 'user-1',
        );

        final stored = await database.taskDao.getTaskById('task-1');
        expect(stored!.status, 'completed');

        final pending = await database.syncQueueDao.getPending();
        expect(pending.single.operation, 'PATCH_STATUS');
        final payload = jsonDecode(pending.single.payload) as Map<String, dynamic>;
        expect(payload['status'], 'completed');
        expect(payload['completed_by_member_id'], 'user-1');
        expect(payload['completed_at'], '2026-08-08T12:00:00.000Z');
        expect(payload['assigned_member_id'], 'user-1');
      });

      test('patchStatus несуществующей задачи не падает, очередь пишется',
          () async {
        // supabase уже создан в setUp

        await repo().patchStatus(taskId: 'missing', status: 'skipped');

        final pending = await database.syncQueueDao.getPending();
        expect(pending.single.operation, 'PATCH_STATUS');
        expect(pending.single.householdId, '');
      });
    });

    group('DELETE', () {
      test('delete удаляет из кэша и ставит DELETE', () async {
        // supabase уже создан в setUp
        await seedTask(id: 'task-1', status: 'pending');

        await repo().delete(taskId: 'task-1');

        expect(await database.taskDao.getTaskById('task-1'), isNull);
        final pending = await database.syncQueueDao.getPending();
        expect(pending.single.operation, 'DELETE');
        expect(pending.single.entityId, 'task-1');
      });

      test('delete несуществующей задачи всё равно ставит DELETE', () async {
        // supabase уже создан в setUp

        await repo().delete(taskId: 'missing');

        final pending = await database.syncQueueDao.getPending();
        expect(pending.single.operation, 'DELETE');
        expect(pending.single.householdId, '');
      });
    });

    group('ALLOWED MEMBERS', () {
      test('addAllowedMember добавляет в кэш и ставит ADD_ALLOWED', () async {
        await seedTask(id: 'task-1', allowedMemberIds: '["user-1"]');

        await repo().addAllowedMember(taskId: 'task-1', memberId: 'user-2');

        final stored = await database.taskDao.getTaskById('task-1');
        expect(stored!.allowedMemberIds, contains('user-2'));

        final pending = await database.syncQueueDao.getPending();
        expect(pending.single.operation, 'ADD_ALLOWED');
        final payload = jsonDecode(pending.single.payload) as Map<String, dynamic>;
        expect(payload['profile_id'], 'user-2');
      });

      test('addAllowedMember не дублирует уже существующего участника',
          () async {
        await seedTask(id: 'task-1', allowedMemberIds: '["user-1"]');

        await repo().addAllowedMember(taskId: 'task-1', memberId: 'user-1');

        final stored = await database.taskDao.getTaskById('task-1');
        expect(jsonDecode(stored!.allowedMemberIds) as List, ['user-1']);
      });

      test('addAllowedMember для несуществующей задачи ставит ADD_ALLOWED',
          () async {
        await repo().addAllowedMember(taskId: 'missing', memberId: 'user-2');

        final pending = await database.syncQueueDao.getPending();
        expect(pending.single.operation, 'ADD_ALLOWED');
        final payload = jsonDecode(pending.single.payload) as Map<String, dynamic>;
        expect(payload['profile_id'], 'user-2');
      });

      test('removeAllowedMember удаляет из кэша и ставит REMOVE_ALLOWED',
          () async {
        await seedTask(
          id: 'task-1',
          allowedMemberIds: '["user-1","user-2"]',
        );

        await repo().removeAllowedMember(
          taskId: 'task-1',
          memberId: 'user-2',
        );

        final stored = await database.taskDao.getTaskById('task-1');
        expect(jsonDecode(stored!.allowedMemberIds) as List, ['user-1']);

        final pending = await database.syncQueueDao.getPending();
        expect(pending.single.operation, 'REMOVE_ALLOWED');
      });

      test('removeAllowedMember для несуществующей задачи ставит REMOVE_ALLOWED',
          () async {
        await repo().removeAllowedMember(
          taskId: 'missing',
          memberId: 'user-1',
        );

        final pending = await database.syncQueueDao.getPending();
        expect(pending.single.operation, 'REMOVE_ALLOWED');
      });
    });

    group('replaceHouseholdData', () {
      test('заменяет все данные семьи задачами из параметров', () async {
        // supabase уже создан в setUp
        await seedTask(id: 'old-1', title: 'Старая');
        await seedTask(id: 'keep-2', householdId: 'household-2', title: 'Другая семья');

        final tasks = [
          Task(
            id: 'new-1',
            householdId: 'household-1',
            title: 'Новая 1',
            estimatedDurationMinutes: 5,
            plannedFor: DateTime(2026, 8, 8),
            allowedMemberIds: const ['user-1'],
            status: TaskStatus.pending,
            createdAt: DateTime(2026, 8, 1),
          ),
          Task(
            id: 'new-2',
            householdId: 'household-1',
            title: 'Новая 2',
            estimatedDurationMinutes: 7,
            plannedFor: DateTime(2026, 8, 9),
            allowedMemberIds: const ['user-1'],
            status: TaskStatus.completed,
            createdAt: DateTime(2026, 8, 1),
            completedAt: DateTime(2026, 8, 8),
          ),
        ];

        await repo().replaceHouseholdData(
          householdId: 'household-1',
          tasks: tasks,
          members: const [],
        );

        expect(await database.taskDao.getTaskById('old-1'), isNull);
        expect(await database.taskDao.getTaskById('keep-2'), isNotNull);
        expect(await database.taskDao.getAllPending('household-1'), hasLength(1));
        final new2 = await database.taskDao.getTaskById('new-2');
        expect(new2!.status, 'completed');
        expect(new2.completedAt, isNotNull);
      });

      test('пустой список очищает семью', () async {
        // supabase уже создан в setUp
        await seedTask(id: 'old-1');

        await repo().replaceHouseholdData(
          householdId: 'household-1',
          tasks: const [],
          members: const [],
        );

        expect(await database.taskDao.getAllPending('household-1'), isEmpty);
      });
    });
  });
}
