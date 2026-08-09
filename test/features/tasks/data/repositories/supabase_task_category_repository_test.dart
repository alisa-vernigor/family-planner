import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:family_planner/features/tasks/data/repositories/supabase_task_category_repository.dart';
import 'package:family_planner/features/tasks/domain/entities/create_task_category_params.dart';
import 'package:family_planner/features/tasks/domain/entities/task_category.dart';

typedef _Router = http.Response Function(http.Request request);

Map<String, dynamic> _categoryRow({
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
  group('SupabaseTaskCategoryRepository', () {
    late List<({String method, String path, Map<String, dynamic>? body})>
        captured;
    late _Router router;
    late SupabaseClient client;
    late SupabaseTaskCategoryRepository repo;

    setUp(() {
      captured = [];
      router = (request) => _json(const [], request);
      client = _buildClient(captured, router: (request) => router(request));
      repo = SupabaseTaskCategoryRepository(client: client);
    });

    void mockRouter(_Router r) {
      router = r;
    }

    test('getForHousehold делает SELECT task_categories и парсит', () async {
      mockRouter((request) {
        expect(request.url.path, '/rest/v1/task_categories');
        expect(request.method, 'GET');
        return _json([
          _categoryRow(id: 'cat-1', name: 'Дом'),
          _categoryRow(
            id: 'cat-2',
            name: 'Работа',
            colorHex: '2196F3',
            iconName: 'work',
          ),
        ], request);
      });

      final items = await repo.getForHousehold('household-1');

      expect(items, hasLength(2));
      expect(items.first.name, 'Дом');
      expect(items.first.colorHex, 'FF5722');
      expect(items.first.iconName, 'home');
      expect(items.last.colorHex, '2196F3');

      final req = captured.singleWhere((r) => r.method == 'GET');
      expect(req.path, '/rest/v1/task_categories');
    });

    test('getForHousehold парсит null color_hex/icon_name', () async {
      mockRouter((request) {
        return _json([
          {
            'id': 'cat-1',
            'household_id': 'household-1',
            'name': 'Без цвета',
            'color_hex': null,
            'icon_name': null,
          },
        ], request);
      });

      final items = await repo.getForHousehold('household-1');

      expect(items.single.colorHex, isNull);
      expect(items.single.iconName, isNull);
    });

    test('create вставляет и возвращает созданную категорию', () async {
      mockRouter((request) {
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        return _json(
          _categoryRow(
            id: 'cat-new',
            name: body['name'] as String,
            colorHex: body['color_hex'] as String?,
            iconName: body['icon_name'] as String?,
          ),
          request,
        );
      });

      final created = await repo.create(
        const CreateTaskCategoryParams(
          householdId: 'household-1',
          name: '  Покупки  ',
          colorHex: '4CAF50',
          iconName: 'shopping_cart',
        ),
      );

      expect(created.id, 'cat-new');
      expect(created.name, 'Покупки');
      expect(created.colorHex, '4CAF50');
      expect(created.iconName, 'shopping_cart');

      final post = captured.singleWhere((r) => r.method == 'POST');
      expect(post.path, '/rest/v1/task_categories');
      expect(post.body!['name'], 'Покупки');
      expect(post.body!['household_id'], 'household-1');
    });

    test('update шлёт PATCH с обновлёнными полями', () async {
      mockRouter((request) {
        expect(request.method, 'PATCH');
        expect(request.url.path, '/rest/v1/task_categories');
        return _json(const [], request);
      });

      await repo.update(
        const TaskCategory(
          id: 'cat-1',
          householdId: 'household-1',
          name: 'Новое',
          colorHex: '000000',
          iconName: 'star',
        ),
      );

      final patch = captured.singleWhere((r) => r.method == 'PATCH');
      expect(patch.body!['name'], 'Новое');
      expect(patch.body!['color_hex'], '000000');
      expect(patch.body!['icon_name'], 'star');
    });

    test('delete шлёт DELETE по id', () async {
      mockRouter((request) {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/rest/v1/task_categories');
        return _json(const [], request);
      });

      await repo.delete('cat-1');

      final req = captured.singleWhere((r) => r.method == 'DELETE');
      expect(req.path, '/rest/v1/task_categories');
    });
  });
}
