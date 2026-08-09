import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:family_planner/core/mixins/realtime_tasks_subscription.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockRealtimeChannel extends Mock implements RealtimeChannel {}

/// Фейковое PKCE-хранилище, чтобы Supabase.initialize не лез в
/// shared_preferences/secure storage.
final class _FakeAsyncStorage extends GotrueAsyncStorage {
  final Map<String, String> _map = {};

  @override
  Future<String?> getItem({required String key}) async => _map[key];

  @override
  Future<void> removeItem({required String key}) async {
    _map.remove(key);
  }

  @override
  Future<void> setItem({required String key, required String value}) async {
    _map[key] = value;
  }
}

class _TestWidget extends StatefulWidget {
  const _TestWidget({
    required this.onChanged,
    this.householdId = 'household-1',
    this.channelPrefix = 'task-occurrences',
  });

  final VoidCallback onChanged;
  final String householdId;
  final String channelPrefix;

  @override
  State<_TestWidget> createState() => _TestWidgetState();
}

class _TestWidgetState extends State<_TestWidget>
    with RealtimeTasksSubscriptionMixin<_TestWidget> {
  @override
  void dispose() {
    unsubscribeFromTaskChanges();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () {
        subscribeToTaskChanges(
          householdId: widget.householdId,
          channelPrefix: widget.channelPrefix,
          onChanged: widget.onChanged,
        );
      },
      child: const Text('subscribe'),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockSupabaseClient client;
  late _MockRealtimeChannel channel;

  setUpAll(() async {
    registerFallbackValue(PostgresChangeEvent.insert);
    registerFallbackValue(
      const PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'x',
        value: 'y',
      ),
    );
    registerFallbackValue(const Duration(milliseconds: 1));

    // RealtimeTasksSubscriptionMixin обращается к синглтону Supabase.instance.
    // Инициализируем его реально (с фейковым хранилищем), затем подменяем
    // client на mock, чтобы не поднимать WebSocket.
    await Supabase.initialize(
      url: 'http://localhost:54321',
      publishableKey: 'test-key',
      debug: false,
      authOptions: FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        pkceAsyncStorage: _FakeAsyncStorage(),
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
    );
  });

  tearDownAll(() async {
    try {
      await Supabase.instance.dispose();
    } catch (_) {
      // Игнорируем ошибки dispose — после подмены client на mock.
    }
  });

  setUp(() {
    client = _MockSupabaseClient();
    channel = _MockRealtimeChannel();

    // Подменяем client в синглтоне на наш mock.
    Supabase.instance.client = client;

    when(() => client.channel(any())).thenReturn(channel);
    when(() => channel.onPostgresChanges(
          event: any(named: 'event'),
          schema: any(named: 'schema'),
          table: any(named: 'table'),
          filter: any(named: 'filter'),
          callback: any(named: 'callback'),
        )).thenReturn(channel);
    when(() => channel.subscribe(any())).thenReturn(channel);
    when(() => channel.unsubscribe()).thenAnswer((_) => Future.value('ok'));
    when(() => client.dispose()).thenAnswer((_) async {});
  });

  Future<void> pumpSubscribe(
    WidgetTester tester, {
    VoidCallback? onChanged,
    String householdId = 'household-1',
    String channelPrefix = 'task-occurrences',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: _TestWidget(
          onChanged: onChanged ?? () {},
          householdId: householdId,
          channelPrefix: channelPrefix,
        ),
      ),
    );
    await tester.tap(find.text('subscribe'));
    await tester.pump();
  }

  PostgresChangePayload buildPayload(String eventType) {
    return PostgresChangePayload.fromPayload({
      'schema': 'public',
      'table': 'task_occurrences',
      'commit_timestamp': '2026-08-09T10:00:00Z',
      'eventType': eventType,
      'new': {'id': 'task-1'},
      'old': {},
      'errors': null,
    });
  }

  void Function(PostgresChangePayload) capturedCallback() {
    final captured = verify(() => channel.onPostgresChanges(
          event: any(named: 'event'),
          schema: any(named: 'schema'),
          table: any(named: 'table'),
          filter: any(named: 'filter'),
          callback: captureAny(named: 'callback'),
        )).captured;
    expect(captured, hasLength(1));
    return captured.single as void Function(PostgresChangePayload);
  }

  testWidgets('subscribeToTaskChanges подписывается с правильными параметрами',
      (tester) async {
    await pumpSubscribe(tester);

    verify(() => client.channel('task-occurrences-household-1')).called(1);
    final captured = verify(() => channel.onPostgresChanges(
          event: captureAny(named: 'event'),
          schema: captureAny(named: 'schema'),
          table: captureAny(named: 'table'),
          filter: captureAny(named: 'filter'),
          callback: any(named: 'callback'),
        )).captured;
    expect(captured[0], PostgresChangeEvent.all);
    expect(captured[1], 'public');
    expect(captured[2], 'task_occurrences');
    expect((captured[3] as PostgresChangeFilter).toString(),
        'household_id=eq.household-1');
    verify(() => channel.subscribe(any())).called(1);
  });

  testWidgets('realtime-событие вызывает onChanged после debounce 1.5s',
      (tester) async {
    var changes = 0;
    await pumpSubscribe(tester, onChanged: () => changes++);

    capturedCallback()(buildPayload('INSERT'));

    // Внутри debounce — onChanged ещё не вызван.
    await tester.pump(const Duration(milliseconds: 500));
    expect(changes, 0);

    // Прошло 1.5с — callback вызван.
    await tester.pump(const Duration(milliseconds: 1000));
    expect(changes, 1);
  });

  testWidgets('серия realtime-событий схлопывается в один onChanged',
      (tester) async {
    var changes = 0;
    await pumpSubscribe(tester, onChanged: () => changes++);

    final callback = capturedCallback();

    callback(buildPayload('UPDATE'));
    await tester.pump(const Duration(milliseconds: 200));
    callback(buildPayload('UPDATE'));
    await tester.pump(const Duration(milliseconds: 200));
    callback(buildPayload('UPDATE'));

    await tester.pump(const Duration(milliseconds: 1500));

    expect(changes, 1);
  });

  testWidgets('onChanged не вызывается после unmount (mounted == false)',
      (tester) async {
    var changes = 0;
    await pumpSubscribe(tester, onChanged: () => changes++);

    final callback = capturedCallback();

    // Событие приходит, когда виджет ещё смонтирован — debounce стартует.
    callback(buildPayload('INSERT'));

    // Убираем виджет из дерева до истечения debounce.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1600));

    expect(changes, 0);
  });

  testWidgets('realtime-событие после unmount игнорируется (ранний return)',
      (tester) async {
    var changes = 0;
    await pumpSubscribe(tester, onChanged: () => changes++);

    final callback = capturedCallback();

    // Сначала unmount, потом приходит realtime-событие. Callback должен
    // сразу выйти по `if (!mounted) return` и НЕ ставить debounce-таймер.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    callback(buildPayload('INSERT'));
    await tester.pump(const Duration(seconds: 2));

    expect(changes, 0);
  });

  testWidgets('unsubscribe отменяет подписку и таймер', (tester) async {
    await pumpSubscribe(tester);

    // Стартуем debounce.
    capturedCallback()(buildPayload('DELETE'));

    // Unmount виджета вызывает dispose → unsubscribeFromTaskChanges.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    verify(() => channel.unsubscribe()).called(1);

    // Таймер debounce отменён — pending timers не остаётся, тест проходит.
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('subscribe вызывает status callback: subscribed → debug',
      (tester) async {
    late void Function(RealtimeSubscribeStatus, Object?)? statusCallback;
    when(() => channel.subscribe(any())).thenAnswer((invocation) {
      statusCallback = invocation.positionalArguments.first
          as void Function(RealtimeSubscribeStatus, Object?);
      return channel;
    });

    await pumpSubscribe(tester);

    expect(statusCallback, isNotNull);
    statusCallback!(RealtimeSubscribeStatus.subscribed, null);
    await tester.pump();
  });

  testWidgets('subscribe вызывает status callback: channelError → error',
      (tester) async {
    late void Function(RealtimeSubscribeStatus, Object?)? statusCallback;
    when(() => channel.subscribe(any())).thenAnswer((invocation) {
      statusCallback = invocation.positionalArguments.first
          as void Function(RealtimeSubscribeStatus, Object?);
      return channel;
    });

    await pumpSubscribe(tester);

    expect(statusCallback, isNotNull);
    statusCallback!(RealtimeSubscribeStatus.channelError, Exception('net'));
    await tester.pump();
  });

  testWidgets('reattachTaskSubscription: смена household пересоздаёт подписку',
      (tester) async {
    var changes = 0;
    await pumpSubscribe(tester, onChanged: () => changes++);

    final state = tester.state<_TestWidgetState>(find.byType(_TestWidget));
    state.reattachTaskSubscription(
      oldHouseholdId: 'household-1',
      newHouseholdId: 'household-2',
      channelPrefix: 'task-occurrences',
      onChanged: () => changes++,
    );

    verify(() => channel.unsubscribe()).called(1);
    verify(() => client.channel('task-occurrences-household-2')).called(1);
    verify(() => channel.subscribe(any())).called(2);
  });

  testWidgets('reattachTaskSubscription: та же семья не пересоздаёт подписку',
      (tester) async {
    await pumpSubscribe(tester);

    final state = tester.state<_TestWidgetState>(find.byType(_TestWidget));
    state.reattachTaskSubscription(
      oldHouseholdId: 'household-1',
      newHouseholdId: 'household-1',
      channelPrefix: 'task-occurrences',
      onChanged: () {},
    );

    verifyNever(() => channel.unsubscribe());
    verify(() => channel.subscribe(any())).called(1);
  });

  testWidgets('Supabase не инициализирован → guard ловит AssertionError и пропускает',
      (tester) async {
    // Сбрасываем синглтон в неинициализированное состояние.
    // Теперь геттер Supabase.instance бросает AssertionError (assert внутри
    // геттера) — mixin должен поймать его в try/catch и выйти без подписки.
    await Supabase.instance.dispose();

    var changes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: _TestWidget(
          onChanged: () => changes++,
          householdId: 'household-1',
          channelPrefix: 'task-occurrences',
        ),
      ),
    );
    await tester.tap(find.text('subscribe'));
    await tester.pump();

    // Guard сработал — канал не создавался, подписка не устанавливалась.
    verifyNever(() => client.channel(any()));
    verifyNever(() => channel.onPostgresChanges(
          event: any(named: 'event'),
          schema: any(named: 'schema'),
          table: any(named: 'table'),
          filter: any(named: 'filter'),
          callback: any(named: 'callback'),
        ));
    verifyNever(() => channel.subscribe(any()));

    // Возвращаем синглтон в рабочее состояние для tearDownAll.
    // runAsync обязателен: внутри testWidgets (FakeAsync) реальные таймеры
    // Supabase.initialize не завершаются.
    await tester.runAsync(() async {
      await Supabase.initialize(
        url: 'http://localhost:54321',
        publishableKey: 'test-key',
        debug: false,
        authOptions: FlutterAuthClientOptions(
          localStorage: EmptyLocalStorage(),
          pkceAsyncStorage: _FakeAsyncStorage(),
          autoRefreshToken: false,
          detectSessionInUri: false,
        ),
      );
    });
  });
}
