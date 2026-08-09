import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:family_planner/features/tasks/data/repositories/supabase_task_subtask_repository.dart';
import 'package:family_planner/features/tasks/domain/entities/create_task_subtask_params.dart';

typedef _Router = http.Response Function(http.Request request);

Map<String, dynamic> _subtaskRow({
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
      return _json({}, request);
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
  group('SupabaseTaskSubtaskRepository', () {
    late List<({String method, String path, Map<String, dynamic>? body})>
        captured;
    late _Router router;
    late SupabaseClient client;
    late SupabaseTaskSubtaskRepository repo;

    setUp(() {
      captured = [];
      router = (request) => _json(const [], request);
      client = _buildClient(captured, router: (request) => router(request));
      repo = SupabaseTaskSubtaskRepository(client: client);
    });

    void mockRouter(_Router r) {
      router = r;
    }

    test('getForTask делает SELECT task_subtasks по taskId и парсит', () async {
      mockRouter((request) {
        expect(request.url.path, '/rest/v1/task_subtasks');
        expect(request.method, 'GET');
        return _json([
          _subtaskRow(id: 'sub-1', title: 'Первая', position: 0),
          _subtaskRow(
            id: 'sub-2',
            title: 'Вторая',
            position: 1,
            isCompleted: true,
            completedAt: '2026-08-08T12:00:00.000Z',
          ),
        ], request);
      });

      final items = await repo.getForTask('task-1');

      expect(items, hasLength(2));
      expect(items.first.id, 'sub-1');
      expect(items.first.title, 'Первая');
      expect(items.last.isCompleted, isTrue);
      expect(items.last.completedAt, DateTime.parse('2026-08-08T12:00:00.000Z'));
      expect(items.first.createdAt, DateTime.parse('2026-08-01T10:00:00.000Z'));

      final req = captured.singleWhere((r) => r.method == 'GET');
      expect(req.path, '/rest/v1/task_subtasks');
    });

    test('create вставляет строку с position = кол-во существующих', () async {
      mockRouter((request) {
        if (request.method == 'GET') {
          return _json([
            _subtaskRow(id: 'sub-1', position: 0),
          ], request);
        }
        if (request.method == 'POST') {
          expect(request.url.path, '/rest/v1/task_subtasks');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          return _json(
            _subtaskRow(
              id: 'sub-new',
              title: body['title'] as String,
              position: (body['position'] as num).toInt(),
            ),
            request,
          );
        }
        return _json(const [], request);
      });

      final created = await repo.create(
        const CreateTaskSubtaskParams(taskId: 'task-1', title: '  Новая  '),
      );

      expect(created.id, 'sub-new');
      expect(created.title, 'Новая');
      expect(created.position, 1);

      final post = captured.singleWhere((r) => r.method == 'POST');
      expect(post.body!['task_occurrence_id'], 'task-1');
      expect(post.body!['title'], 'Новая');
      expect(post.body!['position'], 1);
    });

    test('toggle шлёт UPDATE с is_completed и completed_at', () async {
      mockRouter((request) {
        expect(request.method, 'PATCH');
        return _json(
          _subtaskRow(
            id: 'sub-1',
            isCompleted: true,
            completedAt: '2026-08-08T12:00:00.000Z',
          ),
          request,
        );
      });

      final updated = await repo.toggle('sub-1', true);

      expect(updated.isCompleted, isTrue);
      expect(updated.completedAt, isNotNull);

      final patch = captured.singleWhere((r) => r.method == 'PATCH');
      expect(patch.body!['is_completed'], isTrue);
      expect(patch.body!['completed_at'], isNotNull);
    });

    test('toggle false сбрасывает completed_at в null', () async {
      mockRouter((request) {
        return _json(
          _subtaskRow(id: 'sub-1', isCompleted: false, completedAt: null),
          request,
        );
      });

      final updated = await repo.toggle('sub-1', false);

      expect(updated.isCompleted, isFalse);
      final patch = captured.singleWhere((r) => r.method == 'PATCH');
      expect(patch.body!['is_completed'], isFalse);
      expect(patch.body!['completed_at'], isNull);
    });

    test('updateTitle шлёт UPDATE с новым title', () async {
      mockRouter((request) {
        expect(request.method, 'PATCH');
        return _json(
          _subtaskRow(id: 'sub-1', title: 'Обновлённый'),
          request,
        );
      });

      final updated = await repo.updateTitle('sub-1', '  Обновлённый  ');

      expect(updated.title, 'Обновлённый');
      final patch = captured.singleWhere((r) => r.method == 'PATCH');
      expect(patch.body!['title'], 'Обновлённый');
    });

    test('reorder шлёт PATCH для каждого id с позицией', () async {
      final patches = <String>[];
      mockRouter((request) {
        if (request.method == 'PATCH') {
          patches.add(request.body);
          return _json(const [], request);
        }
        return _json(const [], request);
      });

      await repo.reorder('task-1', ['c', 'a', 'b']);

      expect(patches, hasLength(3));
      final bodies = patches.map((b) => jsonDecode(b) as Map<String, dynamic>);
      expect(bodies.map((b) => b['position']), [0, 1, 2]);
    });

    test('delete шлёт DELETE по id', () async {
      mockRouter((request) {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/rest/v1/task_subtasks');
        return _json(const [], request);
      });

      await repo.delete('sub-1');

      final req = captured.singleWhere((r) => r.method == 'DELETE');
      expect(req.path, '/rest/v1/task_subtasks');
    });
  });
}
