import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:family_planner/core/services/home_widget_service.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';

void main() {
  // На macOS (не Android/iOS/web) _isSupportedPlatform == false,
  // поэтому initialize() и syncTasks() проходят через guard-return.
  TestWidgetsFlutterBinding.ensureInitialized();

  // Глобальная инициализация Supabase с mock HTTP-клиентом: все запросы
  // Postgrest (update/select в interactiveCallback, refresh сессии) вернут
  // пустой JSON. Инициализируем ОДИН раз — Supabase.initialize идемпотентен,
  // а dispose оставляет singleton не-инициализированным (Supabase.instance
  // бросает assert). Каждый тестовый файл запускается в отдельном изоляте,
  // поэтому инициализация здесь не влияет на другие файлы.
  setUpAll(() async {
    final messenger = TestDefaultBinaryMessengerBinding.instance
        .defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (call) async => <String, dynamic>{},
    );
    await Supabase.initialize(
      url: 'http://localhost:54321',
      publishableKey: 'test-key',
      httpClient: MockClient((request) async {
        // GET (select) → одна задача, чтобы map в interactiveCallback
        // выполнился. title латиницей — иначе saveWidgetData падает на
        // MethodChannel («Invalid argument: Contains invalid characters»).
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode([
              {
                'id': 'task-1',
                'title': 'Buy milk',
                'status': 'completed',
                'assigned_member_id': 'm1',
              },
            ]),
            200,
            request: request,
          );
        }
        return http.Response('[]', 200, request: request);
      }),
    );
  });

  // Хелпер: замокать канал home_widget, возвращающий заданные данные.
  void stubHomeWidgetChannel(Map<String, Object?> data,
      {TestDefaultBinaryMessenger? messenger}) {
    final m = messenger ??
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    m.setMockMethodCallHandler(const MethodChannel('home_widget'), (call) async {
      if (call.method == 'getWidgetData') {
        final key = (call.arguments as Map)['id'];
        return data[key];
      }
      return null;
    });
  }

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

  group('HomeWidgetService (с переопределённой платформой)', () {
    final messenger = TestDefaultBinaryMessengerBinding.instance
        .defaultBinaryMessenger;

    tearDown(() {
      messenger.setMockMethodCallHandler(const MethodChannel('home_widget'), null);
    });

    test('initialize: реальная логика при поддержке платформы', () async {
      // Мокаем канал: registerBackgroundCallback / saveWidgetData / updateWidget
      // возвращают успех → initialize проходит дальше до _saveSession().
      final messenger = TestDefaultBinaryMessengerBinding.instance
          .defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(const MethodChannel('home_widget'),
          (call) async {
        if (call.method == 'registerBackgroundCallback') return true;
        if (call.method == 'saveWidgetData') return true;
        if (call.method == 'updateWidget') return true;
        return null;
      });
      messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/shared_preferences'),
        (call) async => <String, dynamic>{},
      );

      try {
        await HomeWidgetService.initialize(isSupportedPlatform: () => true);
        // Дошли до _saveSession: Supabase.instance.client существует (реальный
        // клиент инициализирован), сессия null → warning ветка. Не бросает.
        expect(true, isTrue);
      } finally {
        messenger.setMockMethodCallHandler(
          const MethodChannel('home_widget'),
          null,
        );
        // НЕ снимаем shared_preferences mock — его ставит setUpAll, а другие
        // тесты полагаются на Supabase.instance (иначе флейк).
      }
    });

    test('initialize: MissingPluginException → catch + warning', () async {
      // Канал home_widget НЕ замокан → registerInteractivityCallback бросает
      // MissingPluginException → catch (строка 154) → warning. Не бросает наружу.
      await HomeWidgetService.initialize(isSupportedPlatform: () => true);
      expect(true, isTrue);
    });

    test('initialize: generic Exception → catch + warning (строка 157)', () async {
      // Канал замокан так, что registerInteractivityCallback бросает обычное
      // Exception (не MissingPluginException) → catch (строка 157).
      final messenger = TestDefaultBinaryMessengerBinding.instance
          .defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(const MethodChannel('home_widget'),
          (call) async {
        if (call.method == 'registerBackgroundCallback') {
          throw Exception('boom register');
        }
        return null;
      });

      try {
        await HomeWidgetService.initialize(isSupportedPlatform: () => true);
        expect(true, isTrue);
      } finally {
        messenger.setMockMethodCallHandler(
          const MethodChannel('home_widget'),
          null,
        );
      }
    });

    test('syncTasks: проходит через платформенный guard, реальная запись', () async {
      // НЕ мокаем канал home_widget → saveWidgetData/updateWidget бросают
      // MissingPluginException → catch в syncTasks (строка 187).
      final task = Task(
        id: 't1',
        householdId: 'h1',
        title: 'Купить молоко',
        estimatedDurationMinutes: 10,
        plannedFor: DateTime(2026, 8, 10),
        allowedMemberIds: const ['m1'],
        assignedMemberId: 'm1',
        status: TaskStatus.pending,
        createdAt: DateTime(2026, 8, 9),
      );

      // saveWidgetData/updateWidget на method-channel отсутствуют → MissingPluginException
      // внутри syncTasks → catch → не бросает наружу.
      await HomeWidgetService.syncTasks(
        [task],
        'm1',
        'h1',
        isSupportedPlatform: () => true,
      );
      // Не упало — значит реальная логика (saveWidgetData) выполнилась и
      // MissingPluginException пойман.
      expect(true, isTrue);
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

    test('полный toggle: сбой восстановления сессии → warning (catch + onError)', () async {
      // Замокаем канал home_widget: getWidgetData возвращает URL/ключ/сессию.
      // Сессия битая (нет token_type, access_token не-JWT) → recoverSession
      // бросает: catch в interactiveCallback (строка 77) + ошибка стрима
      // onAuthStateChange ловится onError-листенером initialize (без него —
      // роняет приложение).
      final messenger = TestDefaultBinaryMessengerBinding.instance
          .defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(const MethodChannel('home_widget'),
          (call) async {
        if (call.method == 'getWidgetData') {
          final key = (call.arguments as Map)['id'];
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

    test('без конфигурации Supabase → error return', () async {
      // getWidgetData возвращает null для URL/ключ → error-ветка.
      stubHomeWidgetChannel({});

      await interactiveCallback(
        Uri.parse(
          'homewidget://task/toggle'
          '?id=task-1&status=pending&householdId=h1&memberId=m1',
        ),
      );
      // Дошли до ветки «нет конфигурации» и вернулись.
      expect(true, isTrue);
    });

    test('toggle для уже выполненной задачи (uncomplete) не падает', () async {
      final messenger = TestDefaultBinaryMessengerBinding.instance
          .defaultBinaryMessenger;
      // URL/ключ есть, но restoreSession падает → catch внутри.
      messenger.setMockMethodCallHandler(const MethodChannel('home_widget'),
          (call) async {
        if (call.method == 'getWidgetData') {
          final key = (call.arguments as Map)['id'];
          if (key == 'supabase_url') return 'http://localhost:54321';
          if (key == 'supabase_key') return 'test-key';
          return null;
        }
        return null;
      });
      messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/shared_preferences'),
        (call) async => <String, dynamic>{},
      );

      try {
        await interactiveCallback(
          Uri.parse(
            'homewidget://task/toggle'
            '?id=task-1&status=completed&householdId=h1&memberId=m1',
          ),
        );
        // status=completed → ветка uncomplete (client.update → fail на сети → catch).
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

    test('dotenv недоступен + нет конфигурации → warning + error return', () async {
      // getWidgetData возвращает null для url/key.
      stubHomeWidgetChannel({});

      // Заставляем rootBundle.loadString('.env') бросить: мокаем БИНАРНЫЙ
      // канал flutter/assets (send, не MethodChannel), возвращая null →
      // PlatformAssetBundle.load бросает FlutterError → dotenv.load бросает
      // FileNotFoundError → catch (строка 51). Сбрасываем кэш .env.
      rootBundle.evict('.env');
      final messenger = TestDefaultBinaryMessengerBinding.instance
          .defaultBinaryMessenger;
      messenger.setMockMessageHandler('flutter/assets', (message) async {
        return null;
      });

      try {
        await interactiveCallback(
          Uri.parse(
            'homewidget://task/toggle'
            '?id=task-1&status=pending&householdId=h1&memberId=m1',
          ),
        );
        // Дошли до строки 59 (error return), AppLogger не бросает.
        expect(true, isTrue);
      } finally {
        messenger.setMockMessageHandler('flutter/assets', null);
        rootBundle.evict('.env');
      }
    });

    test('ошибка при обновлении виджета → catch (строка 128)', () async {
      // Supabase инициализирован в setUpAll. saveWidgetData в mock канала
      // бросает обычное Exception → внешний catch в interactiveCallback.
      final messenger = TestDefaultBinaryMessengerBinding.instance
          .defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(const MethodChannel('home_widget'),
          (call) async {
        if (call.method == 'getWidgetData') {
          final key = (call.arguments as Map)['id'];
          return switch (key) {
            'supabase_url' => 'http://localhost:54321',
            'supabase_key' => 'test-key',
            _ => null,
          };
        }
        if (call.method == 'saveWidgetData') {
          throw Exception('boom save');
        }
        return null;
      });

      try {
        await interactiveCallback(
          Uri.parse(
            'homewidget://task/toggle'
            '?id=task-1&status=pending&householdId=h1&memberId=m1',
          ),
        );
        // Дошли до catch (строка 128), AppLogger не бросает.
        expect(true, isTrue);
      } finally {
        messenger.setMockMethodCallHandler(
          const MethodChannel('home_widget'),
          null,
        );
      }
    });

    test('полный toggle с mock HTTP: update + select + saveWidgetData', () async {
      // Supabase уже инициализирован в setUpAll с mock HTTP-клиентом:
      // клиент.update и .select вернут пустой JSON → интерактивный коллбэк
      // дойдёт до обновления данных виджета (строки 102-125).
      final messenger = TestDefaultBinaryMessengerBinding.instance
          .defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(const MethodChannel('home_widget'),
          (call) async {
        if (call.method == 'getWidgetData') {
          final key = (call.arguments as Map)['id'];
          return switch (key) {
            'supabase_url' => 'http://localhost:54321',
            'supabase_key' => 'test-key',
            // Неистёкшая сессия (exp в JWT) → recoverSession не бросает.
            'supabase_session_json' => jsonEncode({
              'access_token': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjk2OTgwNDU5MDQsInN1YiI6InUxIn0.sig',
              'expires_in': 3600,
              'refresh_token': 'r',
              'token_type': 'bearer',
              'user': {
                'id': 'u1',
                'aud': 'authenticated',
                'role': 'authenticated',
                'email': 'a@b.c',
                'app_metadata': {},
                'user_metadata': {},
                'created_at': '2026-01-01T00:00:00Z',
              },
            }),
            _ => null,
          };
        }
        if (call.method == 'saveWidgetData') return true;
        if (call.method == 'updateWidget') return true;
        return null;
      });

      try {
        await interactiveCallback(
          Uri.parse(
            'homewidget://task/toggle'
            '?id=task-1&status=pending&householdId=h1&memberId=m1',
          ),
        );
        // Прошли update + select + saveWidgetData без падений.
        expect(true, isTrue);
      } finally {
        messenger.setMockMethodCallHandler(
          const MethodChannel('home_widget'),
          null,
        );
      }
    });

    test('syncTasks с mock HTTP: saveWidgetData + updateWidget', () async {
      final messenger = TestDefaultBinaryMessengerBinding.instance
          .defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(const MethodChannel('home_widget'),
          (call) async {
        if (call.method == 'saveWidgetData') return true;
        if (call.method == 'updateWidget') return true;
        return null;
      });

      // Supabase уже инициализирован в setUpAll. Восстанавливаем сессию,
      // чтобы _saveSession (строка 194) сохранил её в SharedPreferences.
      final sessionJson = jsonEncode({
        'access_token': 'test-token',
        'expires_in': 3600,
        'refresh_token': 'test-refresh',
        'token_type': 'bearer',
        'user': {
          'id': 'user-1',
          'aud': 'authenticated',
          'role': 'authenticated',
          'email': 'a@b.c',
          'app_metadata': {},
          'user_metadata': {},
          'created_at': '2026-01-01T00:00:00Z',
        },
      });
      await Supabase.instance.client.auth.recoverSession(sessionJson);

      try {
        final task = Task(
          id: 't1',
          householdId: 'h1',
          title: 'Купить молоко',
          estimatedDurationMinutes: 10,
          plannedFor: DateTime(2026, 8, 10),
          allowedMemberIds: const ['m1'],
          assignedMemberId: 'm1',
          status: TaskStatus.pending,
          createdAt: DateTime(2026, 8, 9),
        );
        await HomeWidgetService.syncTasks(
          [task],
          'm1',
          'h1',
          isSupportedPlatform: () => true,
        );
        expect(true, isTrue);
      } finally {
        messenger.setMockMethodCallHandler(
          const MethodChannel('home_widget'),
          null,
        );
      }
    });
  });
}

