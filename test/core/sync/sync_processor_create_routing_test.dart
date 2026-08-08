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

class MockConnectivityService extends Mock implements ConnectivityService {}

/// Захваченный RPC-вызов: имя функции + JSON-body (params).
typedef _CapturedRpc = ({String fn, Map<String, dynamic>? params});

void main() {
  group('SyncProcessor CREATE routing', () {
    late AppDatabase database;
    late MockConnectivityService connectivity;
    late List<_CapturedRpc> capturedRpcs;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      connectivity = MockConnectivityService();
      when(() => connectivity.currentOnline).thenReturn(true);
      capturedRpcs = [];
    });

    tearDown(() async {
      await database.close();
    });

    /// Создаёт SupabaseClient, перехватывающий все HTTP-запросы.
    /// RPC-вызовы (POST {base}/rest/v1/rpc/<fn>) фиксируются в [capturedRpcs].
    SupabaseClient buildClient() {
      final mockHttp = MockClient((request) async {
        final path = request.url.path;
        final rpcPrefix = '/rest/v1/rpc/';
        if (request.method == 'POST' && path.startsWith(rpcPrefix)) {
          final fn = path.substring(rpcPrefix.length);
          capturedRpcs.add((fn: fn, params: _tryDecodeJson(request.body)));
        }
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

    Future<void> enqueueCreate({
      required String operation,
      required Map<String, dynamic> payload,
    }) async {
      await database.syncQueueDao.enqueue(
        entityType: 'task_occurrence',
        operation: operation,
        entityId: 'task-1',
        householdId: 'household-1',
        payload: payload,
      );
    }

    test('обычная задача → create_task_occurrence, is_recurring удаляется',
        () async {
      await enqueueCreate(operation: 'CREATE', payload: {
        'p_household_id': 'household-1',
        'p_title': 'Купить молоко',
        'p_estimated_duration_minutes': 10,
        'p_planned_for': '2026-08-08',
        'p_reminder_minutes_before': 30,
        'is_recurring': false,
      });

      final processor = SyncProcessor(
        queueDao: database.syncQueueDao,
        supabaseClient: buildClient(),
        connectivityService: connectivity,
      );

      final result = await processor.processPending();

      expect(result.synced, 1);
      expect(capturedRpcs, hasLength(1));
      expect(capturedRpcs.single.fn, 'create_task_occurrence');
      expect(capturedRpcs.single.params, isNotNull);
      expect(capturedRpcs.single.params!['is_recurring'], isNull,
          reason: 'служебный is_recurring не должен уходить в RPC');
      expect(capturedRpcs.single.params!['p_reminder_minutes_before'], 30);
      expect(capturedRpcs.single.params!['p_planned_for'], '2026-08-08');
    });

    test('повторяющаяся задача → create_recurring_task_template', () async {
      await enqueueCreate(operation: 'CREATE', payload: {
        'p_household_id': 'household-1',
        'p_title': 'Поливать цветы',
        'p_estimated_duration_minutes': 5,
        'p_start_date': '2026-08-08',
        'p_recurrence_type': 'weekly',
        'p_weekdays': [1, 4],
        'p_end_date': '2026-09-08',
        'p_deadline_time': '09:00:00',
        'p_reminder_minutes_before': 15,
        'is_recurring': true,
      });

      final processor = SyncProcessor(
        queueDao: database.syncQueueDao,
        supabaseClient: buildClient(),
        connectivityService: connectivity,
      );

      final result = await processor.processPending();

      expect(result.synced, 1);
      expect(capturedRpcs, hasLength(1));
      expect(capturedRpcs.single.fn, 'create_recurring_task_template');
      final params = capturedRpcs.single.params!;
      expect(params['is_recurring'], isNull);
      expect(params['p_recurrence_type'], 'weekly');
      expect(params['p_weekdays'], [1, 4]);
      expect(params['p_reminder_minutes_before'], 15);
    });

    test('non-CREATE операции не роутируются на создание', () async {
      await enqueueCreate(operation: 'PATCH_STATUS', payload: {
        'status': 'completed',
      });

      final processor = SyncProcessor(
        queueDao: database.syncQueueDao,
        supabaseClient: buildClient(),
        connectivityService: connectivity,
      );

      await processor.processPending();

      expect(capturedRpcs, isEmpty,
          reason: 'PATCH_STATUS уходит в .from().update(), не в RPC');
    });
  });
}

Map<String, dynamic>? _tryDecodeJson(String body) {
  if (body.isEmpty) return null;
  try {
    final decoded = jsonDecode(body);
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
  }
}
