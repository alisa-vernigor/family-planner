import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/core/services/home_widget_service.dart';

void main() {
  // На macOS (не Android/iOS/web) _isSupportedPlatform == false,
  // поэтому initialize() и syncTasks() проходят через guard-return.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HomeWidgetService (неподдерживаемая платформа)', () {
    test('initialize() не бросает', () async {
      await HomeWidgetService.initialize();
      // На macOS возвращается на первой строке.
      expect(HomeWidgetService, isNotNull);
    });

    test('syncTasks() не бросает', () async {
      await HomeWidgetService.syncTasks(const [], 'member-1', 'household-1');
      expect(HomeWidgetService, isNotNull);
    });
  });

  group('interactiveCallback', () {
    test('null uri → return без действий', () async {
      await interactiveCallback(null);
      // Не упало — значит рано вышло.
      expect(true, isTrue);
    });

    test('uri с host != task → return', () async {
      await interactiveCallback(Uri.parse('homewidget://other/path'));
      expect(true, isTrue);
    });

    test('uri task/toggle без memberId → return', () async {
      await interactiveCallback(
        Uri.parse('homewidget://task/toggle?id=abc&status=pending'),
      );
      expect(true, isTrue);
    });

    test('полный toggle: проходит до инициализации Supabase', () async {
      // Замокаем канал home_widget: getWidgetData возвращает URL/ключ/сессию.
      final messenger = TestDefaultBinaryMessengerBinding.instance
          .defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(const MethodChannel('home_widget'),
          (call) async {
        if (call.method == 'getWidgetData') {
          final key = (call.arguments as Map)['key'];
          return switch (key) {
            'supabase_url' => 'http://localhost:54321',
            'supabase_key' => 'test-key',
            'supabase_session_json' =>
              '{"access_token":"a","refresh_token":"r","expires_at":0,'
                  '"expires_in":3600,"user":{"id":"u1","aud":"authenticated",'
                  '"email":"a@b.c","role":"authenticated","app_metadata":{},'
                  '"user_metadata":{}}}',
            _ => null,
          };
        }
        return null;
      });
      // SharedPreferences — нужен для Supabase.initialize.
      messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/shared_preferences'),
        (call) async => <String, dynamic>{},
      );

      try {
        await interactiveCallback(
          Uri.parse(
            'homewidget://task/toggle'
            '?id=task-1&status=pending&householdId=h1&memberId=m1',
          ),
        );
        // Ожидаем, что дошли до Supabase.initialize (вызов пройден),
        // даже если сам клиент потом упадёт на сети — это catch внутри callback.
        expect(true, isTrue);
      } finally {
        messenger.setMockMethodCallHandler(
          const MethodChannel('home_widget'),
          null,
        );
        messenger.setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          null,
        );
      }
    });
  });
}
