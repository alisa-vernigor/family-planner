import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:family_planner/core/services/reminder_service.dart';

class _MockPlugin extends Mock implements FlutterLocalNotificationsPlugin {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    registerFallbackValue(
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'channel',
          'name',
          channelDescription: 'desc',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
    registerFallbackValue(AndroidScheduleMode.inexactAllowWhileIdle);
    registerFallbackValue(tz.TZDateTime.from(
      DateTime(2026, 8, 10, 12),
      tz.UTC,
    ));
  });

  group('ReminderService (неподдерживаемая платформа)', () {
    test('initialize() не бросает и не инициализирует', () async {
      final service = ReminderService.instance;

      await service.initialize();

      // Внутреннее состояние не доступно — просто проверяем, что не упало.
      expect(service, isNotNull);
    });

    test('schedule() возвращает null когда не инициализирован', () async {
      final id = await ReminderService.instance.schedule(
        taskId: 'task-1',
        title: 'Купить молоко',
        scheduledFor: DateTime(2026, 8, 10, 12),
        minutesBefore: 30,
      );

      expect(id, isNull);
    });

    test('cancel() и cancelAll() не бросают', () async {
      await ReminderService.instance.cancel('task-1');
      await ReminderService.instance.cancelAll();

      expect(ReminderService.instance, isNotNull);
    });

    test('повторная инициализация безопасна', () async {
      final service = ReminderService.instance;
      await service.initialize();
      await service.initialize();

      expect(service, isNotNull);
    });
  });

  group('ReminderService (с переопределённой платформой + мок-плагин)', () {
    test('initialize c реальным плагином: MissingPluginException → catch', () async {
      final service = ReminderService.forTesting();
      // Платформа принудительно поддерживается → доходим до _plugin.initialize.
      // Реальный плагин без мока канала бросает MissingPluginException,
      // initialize его ловит → _initialized остаётся false.
      await service.initialize(isSupportedPlatform: () => true);

      // Последующий schedule вернёт null (не инициализирован).
      final id = await service.schedule(
        taskId: 't1',
        title: 'T',
        scheduledFor: DateTime(2026, 8, 10, 12),
        minutesBefore: 10,
      );
      expect(id, isNull);
    });

    test('инициализация с мок-плагином успешна → schedule планирует', () async {
      final plugin = _MockPlugin();
      when(() => plugin.initialize(settings: any(named: 'settings')))
          .thenAnswer((_) async => true);
      when(
        () => plugin.zonedSchedule(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          scheduledDate: any(named: 'scheduledDate'),
          notificationDetails: any(named: 'notificationDetails'),
          androidScheduleMode: any(named: 'androidScheduleMode'),
        ),
      ).thenAnswer((_) async => true);

      final service = ReminderService.forTesting(plugin: plugin);
      await service.initialize(isSupportedPlatform: () => true);

      // Теперь _initialized == true.
      final id = await service.schedule(
        taskId: 'task-42',
        title: 'Сходить в магазин',
        scheduledFor: DateTime.now().add(const Duration(hours: 5)),
        minutesBefore: 30,
      );

      expect(id, isNotNull);
      expect(id, 'task-42'.hashCode & 0x7fffffff);
      verify(
        () => plugin.zonedSchedule(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          scheduledDate: any(named: 'scheduledDate'),
          notificationDetails: any(named: 'notificationDetails'),
          androidScheduleMode: any(named: 'androidScheduleMode'),
        ),
      ).called(1);
    });

    test('schedule с fireAt в прошлом возвращает null без вызова плагина', () async {
      final plugin = _MockPlugin();
      when(() => plugin.initialize(settings: any(named: 'settings')))
          .thenAnswer((_) async => true);

      final service = ReminderService.forTesting(plugin: plugin);
      await service.initialize(isSupportedPlatform: () => true);

      // scheduledFor в прошлом → fireAt раньше now → return null.
      final id = await service.schedule(
        taskId: 'task-old',
        title: 'Старая задача',
        scheduledFor: DateTime.now().subtract(const Duration(hours: 1)),
        minutesBefore: 5,
      );

      expect(id, isNull);
      verifyNever(
        () => plugin.zonedSchedule(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          scheduledDate: any(named: 'scheduledDate'),
          notificationDetails: any(named: 'notificationDetails'),
          androidScheduleMode: any(named: 'androidScheduleMode'),
        ),
      );
    });

    test('cancel и cancelAll вызывают плагин после инициализации', () async {
      final plugin = _MockPlugin();
      when(() => plugin.initialize(settings: any(named: 'settings')))
          .thenAnswer((_) async => true);
      when(() => plugin.cancel(id: any(named: 'id'))).thenAnswer((_) async => null);
      when(() => plugin.cancelAll()).thenAnswer((_) async => null);

      final service = ReminderService.forTesting(plugin: plugin);
      await service.initialize(isSupportedPlatform: () => true);

      await service.cancel('task-9');
      await service.cancelAll();

      verify(() => plugin.cancel(id: any(named: 'id'))).called(1);
      verify(() => plugin.cancelAll()).called(1);
    });
  });
}
