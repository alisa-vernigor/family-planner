import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/core/services/reminder_service.dart';

void main() {
  // На macOS (не Android/iOS/web) _isSupportedPlatform == false,
  // поэтому весь путь инициализации/планирования проходит через guard-return.
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
}
