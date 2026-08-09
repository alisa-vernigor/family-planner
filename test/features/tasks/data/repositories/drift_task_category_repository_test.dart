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
import 'package:family_planner/features/tasks/data/repositories/drift_task_category_repository.dart';
import 'package:family_planner/features/tasks/domain/entities/create_task_category_params.dart';
import 'package:family_planner/features/tasks/domain/entities/task_category.dart'
    as domain;

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

Map<String, dynamic> _remoteCategoryRow({
  String id = 'cat-1',
  String householdId = 'household-1',
  String name = 'Дом',
  String? colorHex = 'FF5722',
  String? iconName = 'home',
}) {
  return {
    'id': id,
    'household_id': householdId,
    'name': name,
    'color_hex': colorHex,
    'icon_name': iconName,
  };
}

Future<void> _seedCategory(
  AppDatabase db, {
  String id = 'cat-1',
  String householdId = 'household-1',
  String name = 'Дом',
  String? colorHex = 'FF5722',
  String? iconName = 'home',
}) async {
  await db.taskCategoriesDao.upsert(TaskCategoriesCompanion(
    id: Value(id),
    householdId: Value(householdId),
    name: Value(name),
    colorHex: Value(colorHex),
    iconName: Value(iconName),
  ));
}

void main() {
  group('DriftTaskCategoryRepository', () {
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

    DriftTaskCategoryRepository repo() => DriftTaskCategoryRepository(
          database: database,
          supabaseClient: supabase,
          connectivityService: connectivity,
        );

    group('READ', () {
      test('getForHousehold отдаёт категории из кэша в порядке имени', () async {
        await _seedCategory(database, id: 'c2', name: 'Б');
        await _seedCategory(database, id: 'c1', name: 'А');
        await _seedCategory(
          database,
          id: 'c3',
          name: 'Другая семья',
          householdId: 'household-2',
        );

        final items = await repo().getForHousehold('household-1');

        expect(items.map((c) => c.id), ['c1', 'c2']);
        final cat = items.first;
        expect(cat.name, 'А');
        expect(cat.colorHex, 'FF5722');
        expect(cat.iconName, 'home');
      });

      test('getForHousehold при онлайне фетчит и кэширует', () async {
        when(() => connectivity.currentOnline).thenReturn(true);
        supabase = _buildClient(captured,
          onRequest: (request) {
            if (request.url.path == '/rest/v1/task_categories') {
              return _json([
                _remoteCategoryRow(id: 'remote-1', name: 'Серверная'),
              ], request);
            }
            return _json(const [], request);
          },
        );

        final items = await repo().getForHousehold('household-1');

        expect(items.single.id, 'remote-1');
        expect(items.single.name, 'Серверная');

        final cached = await database.taskCategoriesDao.getForHousehold(
          'household-1',
        );
        expect(cached, hasLength(1));
      });

      test('сбой фетча не роняет чтение — отдаёт кэш', () async {
        await _seedCategory(database, id: 'local-1', name: 'Локальная');
        when(() => connectivity.currentOnline).thenReturn(true);
        supabase = _buildClient(captured,
          onRequest: (_) => http.Response(
            '{"message":"error"}',
            500,
            headers: {'content-type': 'application/json'},
          ),
        );

        final items = await repo().getForHousehold('household-1');

        expect(items.single.id, 'local-1');
      });
    });

    group('WRITE', () {
      test('create вставляет на сервер и кэширует локально', () async {
        supabase = _buildClient(captured,
          onRequest: (request) {
            if (request.url.path == '/rest/v1/task_categories' &&
                request.method == 'POST') {
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              return _json(
                _remoteCategoryRow(
                  id: 'cat-new',
                  name: body['name'] as String,
                  colorHex: body['color_hex'] as String?,
                  iconName: body['icon_name'] as String?,
                ),
                request,
              );
            }
            return _json(const [], request);
          },
        );

        final created = await repo().create(
          const CreateTaskCategoryParams(
            householdId: 'household-1',
            name: '  Работа  ',
            colorHex: '2196F3',
            iconName: 'work',
          ),
        );

        expect(created.id, 'cat-new');
        expect(created.name, 'Работа');
        expect(created.colorHex, '2196F3');

        final post = captured.singleWhere(
          (r) => r.path == '/rest/v1/task_categories' && r.method == 'POST',
        );
        expect(post.body!['name'], 'Работа');
        expect(post.body!['household_id'], 'household-1');
        expect(post.body!['color_hex'], '2196F3');
        expect(post.body!['icon_name'], 'work');

        final cached = await database.taskCategoriesDao.getForHousehold(
          'household-1',
        );
        expect(cached, hasLength(1));
        expect(cached.single.name, 'Работа');
      });

      test('update шлёт PATCH и обновляет кэш', () async {
        await _seedCategory(database, id: 'cat-1', name: 'Старое');
        supabase = _buildClient(captured,
          onRequest: (request) {
            expect(request.method, 'PATCH');
            return _json(const [], request);
          },
        );

        await repo().update(
          const domain.TaskCategory(
            id: 'cat-1',
            householdId: 'household-1',
            name: 'Новое',
            colorHex: '000000',
            iconName: 'star',
          ),
        );

        final patch = captured.singleWhere((r) => r.method == 'PATCH');
        expect(patch.path, '/rest/v1/task_categories');
        expect(patch.body!['name'], 'Новое');
        expect(patch.body!['color_hex'], '000000');
        expect(patch.body!['icon_name'], 'star');

        final cached = await database.taskCategoriesDao.getForHousehold(
          'household-1',
        );
        expect(cached.single.name, 'Новое');
      });

      test('delete шлёт DELETE и удаляет из кэша', () async {
        await _seedCategory(database, id: 'cat-1');
        supabase = _buildClient(captured,
          onRequest: (request) {
            expect(request.method, 'DELETE');
            return _json(const [], request);
          },
        );

        await repo().delete('cat-1');

        final req = captured.singleWhere((r) => r.method == 'DELETE');
        expect(req.path, '/rest/v1/task_categories');
        expect(
          await database.taskCategoriesDao.getForHousehold('household-1'),
          isEmpty,
        );
      });
    });
  });
}
