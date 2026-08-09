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
import 'package:family_planner/features/tasks/data/repositories/drift_task_subtask_repository.dart';
import 'package:family_planner/features/tasks/domain/entities/create_task_subtask_params.dart';

class MockConnectivityService extends Mock implements ConnectivityService {}

AppDatabase _createDb() => AppDatabase(NativeDatabase.memory());

http.Response _json(Object body, http.Request request, {int status = 200}) {
  return http.Response(
    jsonEncode(body),
    status,
    request: request,
    headers: {'content-type': 'application/json'},
  );
}

/// Собирает HTTP-запросы и при необходимости подменяет ответы.
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
    return _json(const [], request);
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

Map<String, dynamic> _remoteSubtaskRow({
  String id = 'sub-1',
  String taskOccurrenceId = 'task-1',
  String title = 'Помыть',
  int position = 0,
  bool isCompleted = false,
  String? completedAt,
  String createdAt = '2026-08-01T10:00:00.000Z',
}) {
  return {
    'id': id,
    'task_occurrence_id': taskOccurrenceId,
    'title': title,
    'position': position,
    'is_completed': isCompleted,
    'completed_at': completedAt,
    'created_at': createdAt,
  };
}

/// Сеет подзадачу прямо в локальную Drift-БД.
Future<TaskSubtasksCompanion> _seedSubtask(
  AppDatabase db, {
  String id = 'sub-1',
  String taskId = 'task-1',
  String title = 'Помыть',
  int position = 0,
  bool isCompleted = false,
  String? completedAt,
  String createdAt = '2026-08-01T10:00:00.000Z',
}) async {  final companion = TaskSubtasksCompanion(
    id: Value(id),
    taskOccurrenceId: Value(taskId),
    title: Value(title),
    position: Value(position),
    isCompleted: Value(isCompleted),
    completedAt: Value(completedAt),
    createdAt: Value(createdAt),
  );
  await db.taskSubtasksDao.upsert(companion);
  return companion;
}

void main() {
  group('DriftTaskSubtaskRepository', () {
    late AppDatabase database;
    late MockConnectivityService connectivity;
    late List<({String method, String path, Map<String, dynamic>? body})>
        captured;
    late SupabaseClient supabase;

    setUp(() {
      database = _createDb();
      connectivity = MockConnectivityService();
      when(() => connectivity.currentOnline).thenReturn(false);
      captured = [];
      supabase = _buildClient(captured);
    });

    tearDown(() async {
      await database.close();
    });

    DriftTaskSubtaskRepository repo() => DriftTaskSubtaskRepository(
          database: database,
          supabaseClient: supabase,
          connectivityService: connectivity,
        );

    group('READ', () {
      test('getForTask отдаёт подзадачи из кэша в порядке позиций', () async {
        await _seedSubtask(database, id: 's2', position: 1);
        await _seedSubtask(database, id: 's1', position: 0);
        await _seedSubtask(
          database,
          id: 's3',
          taskId: 'task-other',
          position: 0,
        );

        final items = await repo().getForTask('task-1');

        expect(items.map((s) => s.id), ['s1', 's2']);
        final first = items.first;
        expect(first.taskId, 'task-1');
        expect(first.isCompleted, isFalse);
        expect(first.createdAt, DateTime.parse('2026-08-01T10:00:00.000Z'));
      });

      test('getForTask при онлайне фетчит и кэширует с сервера', () async {
        when(() => connectivity.currentOnline).thenReturn(true);
        supabase = _buildClient(captured,
          onRequest: (request) {
            if (request.url.path == '/rest/v1/task_subtasks') {
              return _json([
                _remoteSubtaskRow(
                  id: 'remote-1',
                  title: 'Серверная подзадача',
                  position: 0,
                ),
                _remoteSubtaskRow(
                  id: 'remote-2',
                  title: 'Вторая',
                  position: 1,
                  isCompleted: true,
                  completedAt: '2026-08-08T12:00:00.000Z',
                ),
              ], request);
            }
            return _json(const [], request);
          },
        );

        final items = await repo().getForTask('task-1');

        expect(items, hasLength(2));
        expect(items.first.id, 'remote-1');
        expect(items.last.isCompleted, isTrue);
        expect(items.last.completedAt, DateTime.parse('2026-08-08T12:00:00.000Z'));

        // Закэшированы локально.
        final cached = await database.taskSubtasksDao.getForTask('task-1');
        expect(cached, hasLength(2));
      });

      test('сбой фетча не роняет чтение — отдаёт локальный кэш', () async {
        await _seedSubtask(database, id: 'local-1');
        when(() => connectivity.currentOnline).thenReturn(true);
        supabase = _buildClient(captured,
          onRequest: (_) => http.Response(
            '{"message":"error"}',
            500,
            headers: {'content-type': 'application/json'},
          ),
        );

        final items = await repo().getForTask('task-1');

        expect(items.map((s) => s.id), ['local-1']);
      });
    });

    group('CREATE', () {
      test('создаёт локально, ставит SUBTASK_CREATE в очередь', () async {
        await _seedSubtask(database, id: 's0', position: 0);

        final created = await repo().create(
          const CreateTaskSubtaskParams(taskId: 'task-1', title: '  Новая  '),
        );

        expect(created.title, 'Новая');
        expect(created.position, 1);
        expect(created.isCompleted, isFalse);

        final stored = await database.taskSubtasksDao.getById(created.id);
        expect(stored, isNotNull);
        expect(stored!.title, 'Новая');
        expect(stored.position, 1);

        final pending = await database.syncQueueDao.getPending();
        expect(pending, hasLength(1));
        final entry = pending.single;
        expect(entry.operation, 'SUBTASK_CREATE');
        expect(entry.entityType, 'task_subtask');
        expect(entry.entityId, 'task-1'); // entityId = task_occurrence_id
        final payload = jsonDecode(entry.payload) as Map<String, dynamic>;
        expect(payload['task_occurrence_id'], 'task-1');
        expect(payload['title'], 'Новая');
        expect(payload['position'], 1);
      });

      test('берёт householdId родительской задачи для очереди', () async {
        await database.taskDao.upsertTask(TaskOccurrencesCompanion(
          id: const Value('task-1'),
          householdId: const Value('household-9'),
          title: const Value('Задача'),
          estimatedDurationMinutes: const Value(5),
          plannedFor: const Value('2026-08-08'),
          status: const Value('pending'),
          createdAt: const Value('2026-08-01T10:00:00.000Z'),
          updatedAt: const Value('2026-08-01T10:00:00.000Z'),
          allowedMemberIds: const Value('["user-1"]'),
        ));

        await repo().create(
          const CreateTaskSubtaskParams(taskId: 'task-1', title: 'Подзадача'),
        );

        final pending = await database.syncQueueDao.getPending();
        expect(pending.single.householdId, 'household-9');
      });
    });

    group('UPDATE', () {
      test('toggle меняет is_completed и ставит SUBTASK_UPDATE', () async {
        await _seedSubtask(database);

        final updated = await repo().toggle('sub-1', true);

        expect(updated.isCompleted, isTrue);
        expect(updated.completedAt, isNotNull);

        final stored = await database.taskSubtasksDao.getById('sub-1');
        expect(stored!.isCompleted, isTrue);
        expect(stored.completedAt, isNotNull);

        final pending = await database.syncQueueDao.getPending();
        expect(pending.single.operation, 'SUBTASK_UPDATE');
        final payload = jsonDecode(pending.single.payload) as Map<String, dynamic>;
        expect(payload['is_completed'], isTrue);
        expect(payload['completed_at'], isNotNull);
        expect(payload['title'], 'Помыть');
      });

      test('toggle неизвестной подзадачи кидает StateError', () async {
        expect(() => repo().toggle('missing', true), throwsStateError);
      });

      test('updateTitle меняет заголовок и ставит SUBTASK_UPDATE', () async {
        await _seedSubtask(database);

        final updated = await repo().updateTitle('sub-1', 'Новый заголовок');

        expect(updated.title, 'Новый заголовок');
        final stored = await database.taskSubtasksDao.getById('sub-1');
        expect(stored!.title, 'Новый заголовок');

        final pending = await database.syncQueueDao.getPending();
        expect(pending.single.operation, 'SUBTASK_UPDATE');
        final payload = jsonDecode(pending.single.payload) as Map<String, dynamic>;
        expect(payload['title'], 'Новый заголовок');
        expect(payload['position'], 0);
      });

      test('updateTitle неизвестной подзадачи кидает StateError', () async {
        expect(() => repo().updateTitle('missing', 'x'), throwsStateError);
      });

      test('reorder обновляет позиции и ставит SUBTASK_UPDATE для каждой',
          () async {
        await _seedSubtask(database, id: 'a', position: 0);
        await _seedSubtask(database, id: 'b', position: 1);
        await _seedSubtask(database, id: 'c', position: 2);

        await repo().reorder('task-1', ['c', 'a', 'b']);

        final stored = await database.taskSubtasksDao.getForTask('task-1');
        expect(stored.map((s) => s.position), [0, 1, 2]);
        expect(stored.map((s) => s.id), ['c', 'a', 'b']);

        final pending = await database.syncQueueDao.getPending();
        expect(pending, hasLength(3));
        expect(pending.every((e) => e.operation == 'SUBTASK_UPDATE'), isTrue);
      });

      test('reorder игнорирует неизвестные id', () async {
        await _seedSubtask(database, id: 'a', position: 0);

        await repo().reorder('task-1', ['a', 'missing']);

        final stored = await database.taskSubtasksDao.getForTask('task-1');
        expect(stored, hasLength(1));
        expect(stored.single.position, 0);
        expect(await database.syncQueueDao.getPending(), hasLength(1));
      });
    });

    group('DELETE', () {
      test('delete удаляет локально и ставит SUBTASK_DELETE', () async {
        await _seedSubtask(database);

        await repo().delete('sub-1');

        expect(await database.taskSubtasksDao.getById('sub-1'), isNull);
        final pending = await database.syncQueueDao.getPending();
        expect(pending.single.operation, 'SUBTASK_DELETE');
        expect(pending.single.entityId, 'sub-1');
      });

      test('delete неизвестной подзадачи всё равно ставит SUBTASK_DELETE',
          () async {
        await repo().delete('missing');

        final pending = await database.syncQueueDao.getPending();
        expect(pending.single.operation, 'SUBTASK_DELETE');
        expect(pending.single.householdId, '');
      });
    });
  });
}
