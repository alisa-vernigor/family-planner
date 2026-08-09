import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:family_planner/core/database/app_database.dart';
import 'package:family_planner/core/services/connectivity_service.dart';
import 'package:family_planner/core/sync/sync_processor.dart';

class _MockConnectivityService extends Mock implements ConnectivityService {}

/// Захваченный запрос: метод, путь, query и body.
typedef _CapturedRequest = ({
  String method,
  String path,
  Map<String, String> query,
  String? body,
});

void main() {
  group('SyncProcessor операции и обработка ошибок', () {
    late AppDatabase database;
    late _MockConnectivityService connectivity;
    late List<_CapturedRequest> captured;
    late Object? requestError;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      connectivity = _MockConnectivityService();
      when(() => connectivity.currentOnline).thenReturn(true);
      captured = [];
      requestError = null;
    });

    tearDown(() async {
      await database.close();
    });

    SupabaseClient buildClient() {
      final mockHttp = MockClient((request) async {
        captured.add((
          method: request.method,
          path: request.url.path,
          query: request.url.queryParameters,
          body: request.body.isEmpty ? null : request.body,
        ));
        if (requestError != null) throw requestError!;
        return http.Response(
          '{}',
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      });

      return SupabaseClient(
        'http://localhost:54321',
        'test-key',
        httpClient: mockHttp,
      );
    }

    SyncProcessor buildProcessor() => SyncProcessor(
          queueDao: database.syncQueueDao,
          supabaseClient: buildClient(),
          connectivityService: connectivity,
        );

    Future<void> enqueue({
      required String operation,
      required Map<String, dynamic> payload,
      String entityId = 'entity-1',
    }) async {
      await database.syncQueueDao.enqueue(
        entityType: 'task_occurrence',
        operation: operation,
        entityId: entityId,
        householdId: 'household-1',
        payload: payload,
      );
    }

    test('offline → бросает SyncOfflineException', () async {
      when(() => connectivity.currentOnline).thenReturn(false);
      final processor = buildProcessor();

      expect(
        () => processor.processPending(),
        throwsA(isA<SyncOfflineException>()),
      );
    });

    test('пустая очередь → пустой результат, 2 события', () async {
      final processor = buildProcessor();
      final events = <SyncProcessorEvent>[];
      final sub = processor.events.listen(events.add);

      final result = await processor.processPending();
      await Future<void>.delayed(Duration.zero);

      expect(result.isEmpty, isTrue);
      expect(events, hasLength(2));
      expect(events.first.toString(), contains('Processing'));
      expect(events.last.toString(), contains('Idle'));
      expect(processor.isProcessing, isFalse);
      await sub.cancel();
    });

    test('UPDATE_TEMPLATE → rpc update_task_template', () async {
      await enqueue(
        operation: 'UPDATE_TEMPLATE',
        payload: {'p_template_id': 't1', 'p_title': 'Новое'},
      );

      final result = await buildProcessor().processPending();

      expect(result.synced, 1);
      expect(captured, hasLength(1));
      expect(captured.single.path, contains('rpc/update_task_template'));
      expect(captured.single.method, 'POST');
    });

    test('PAUSE_TEMPLATE → rpc pause_task_template', () async {
      await enqueue(operation: 'PAUSE_TEMPLATE', payload: {'p_template_id': 't1'});

      final result = await buildProcessor().processPending();

      expect(result.synced, 1);
      expect(captured.single.path, contains('rpc/pause_task_template'));
    });

    test('RESUME_TEMPLATE → rpc resume_task_template', () async {
      await enqueue(
        operation: 'RESUME_TEMPLATE',
        payload: {'p_template_id': 't1'},
      );

      final result = await buildProcessor().processPending();

      expect(result.synced, 1);
      expect(captured.single.path, contains('rpc/resume_task_template'));
    });

    test('UPDATE → update в task_occurrences по id', () async {
      await enqueue(operation: 'UPDATE', payload: {'title': 'Изменено'});

      final result = await buildProcessor().processPending();

      expect(result.synced, 1);
      expect(captured.single.method, 'PATCH');
      expect(captured.single.path, contains('task_occurrences'));
    });

    test('DELETE → delete в task_occurrences по id', () async {
      await enqueue(operation: 'DELETE', payload: {});

      final result = await buildProcessor().processPending();

      expect(result.synced, 1);
      expect(captured.single.method, 'DELETE');
      expect(captured.single.path, contains('task_occurrences'));
    });

    test('PATCH_STATUS → update в task_occurrences', () async {
      await enqueue(operation: 'PATCH_STATUS', payload: {'status': 'completed'});

      final result = await buildProcessor().processPending();

      expect(result.synced, 1);
      expect(captured.single.method, 'PATCH');
      expect(captured.single.path, contains('task_occurrences'));
      final body = jsonDecode(captured.single.body!) as Map<String, dynamic>;
      expect(body['status'], 'completed');
    });

    test('ADD_ALLOWED → insert в task_occurrence_allowed_members', () async {
      await enqueue(
        operation: 'ADD_ALLOWED',
        payload: {
          'task_occurrence_id': 't1',
          'profile_id': 'm1',
        },
      );

      final result = await buildProcessor().processPending();

      expect(result.synced, 1);
      expect(captured.single.method, 'POST');
      expect(captured.single.path, contains('task_occurrence_allowed_members'));
    });

    test('REMOVE_ALLOWED → delete по паре ключей', () async {
      await enqueue(
        operation: 'REMOVE_ALLOWED',
        payload: {'task_occurrence_id': 't1', 'profile_id': 'm1'},
      );

      final result = await buildProcessor().processPending();

      expect(result.synced, 1);
      expect(captured.single.method, 'DELETE');
      expect(captured.single.path, contains('task_occurrence_allowed_members'));
      expect(captured.single.query['task_occurrence_id'], 'eq.t1');
      expect(captured.single.query['profile_id'], 'eq.m1');
    });

    test('SUBTASK_CREATE → insert в task_subtasks с полями', () async {
      await enqueue(
        operation: 'SUBTASK_CREATE',
        payload: {'task_occurrence_id': 't1', 'title': 'Подзадача', 'position': 2},
      );

      final result = await buildProcessor().processPending();

      expect(result.synced, 1);
      expect(captured.single.method, 'POST');
      expect(captured.single.path, contains('task_subtasks'));
      final body = jsonDecode(captured.single.body!) as Map<String, dynamic>;
      expect(body['task_occurrence_id'], 't1');
      expect(body['position'], 2);
    });

    test('SUBTASK_UPDATE → update в task_subtasks по id', () async {
      await enqueue(
        operation: 'SUBTASK_UPDATE',
        payload: {
          'title': 'Новое',
          'is_completed': true,
          'completed_at': '2026-08-09T10:00:00Z',
          'position': 1,
        },
        entityId: 'st-1',
      );

      final result = await buildProcessor().processPending();

      expect(result.synced, 1);
      expect(captured.single.method, 'PATCH');
      expect(captured.single.path, contains('task_subtasks'));
    });

    test('SUBTASK_DELETE → delete в task_subtasks по id', () async {
      await enqueue(
        operation: 'SUBTASK_DELETE',
        payload: {},
        entityId: 'st-1',
      );

      final result = await buildProcessor().processPending();

      expect(result.synced, 1);
      expect(captured.single.method, 'DELETE');
      expect(captured.single.path, contains('task_subtasks'));
    });

    test('неизвестная операция → помечается как synced (без исключения)', () async {
      await enqueue(operation: 'UNKNOWN_OP', payload: {});

      final result = await buildProcessor().processPending();

      expect(result.synced, 1);
      expect(captured, isEmpty);
    });

    test('конфликт → conflicts++ и запись удаляется', () async {
      requestError = const SyncConflictException('конфликт версий');
      await enqueue(operation: 'UPDATE', payload: {'title': 'x'});

      final result = await buildProcessor().processPending();

      expect(result.conflicts, 1);
      expect(result.synced, 0);
      expect(await database.syncQueueDao.hasPendingOperations(), isFalse);
    });

    test('ошибка → markFailed, retryCount увеличивается', () async {
      requestError = Exception('network down');
      await enqueue(operation: 'UPDATE', payload: {'title': 'x'});

      final result = await buildProcessor().processPending();

      expect(result.failed, 1);
      final pending = await database.syncQueueDao.getPending();
      expect(pending, hasLength(1));
      expect(pending.single.retryCount, 1);
      expect(pending.single.lastError, isNotNull);
    });

    test('превышение maxRetries → запись дропается', () async {
      requestError = Exception('network down');
      await enqueue(operation: 'UPDATE', payload: {'title': 'x'});
      // Доводим retryCount до предела (0-based: retryCount=4 → 4+1 >= 5).
      final entry = (await database.syncQueueDao.getPending()).single;
      for (var i = 0; i < 4; i++) {
        await database.syncQueueDao.markFailed(entry.id, 'error');
      }

      final result = await buildProcessor().processPending();

      expect(result.failed, 1);
      expect(await database.syncQueueDao.hasPendingOperations(), isFalse);
    });

    test('повторный вызов при активной обработке → пустой результат', () async {
      // Заблокируем процессор: первый вызов зависнет на ожидании.
      final completer = Completer<http.Response>();
      final slowClient = MockClient((request) => completer.future);
      final processor = SyncProcessor(
        queueDao: database.syncQueueDao,
        supabaseClient: SupabaseClient(
          'http://localhost:54321',
          'test-key',
          httpClient: slowClient,
        ),
        connectivityService: connectivity,
      );
      await enqueue(operation: 'UPDATE', payload: {'title': 'x'});

      final first = processor.processPending();
      // Даём первому вызову захватить _isProcessing.
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final result = await processor.processPending();
      expect(result.isEmpty, isTrue);

      completer.complete(http.Response(
        '{}',
        200,
        headers: {'content-type': 'application/json'},
      ));
      await first;
    });
  });
}
