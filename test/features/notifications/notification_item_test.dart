import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:family_planner/features/notifications/data/notification_read_store.dart';
import 'package:family_planner/features/notifications/domain/entities/notification_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  NotificationItem item(String id) {
    return NotificationItem(
      id: id,
      kind: NotificationKind.taskAssigned,
      actorId: 'actor-1',
      actorName: 'Мария',
      title: 'Задача назначена',
      subtitle: 'Мария назначила вам задачу «Убраться»',
      occurredAt: DateTime(2026, 8, 8, 10),
      taskId: 'task-1',
      taskStatus: 'pending',
      householdId: 'household-1',
    );
  }

  group('NotificationReadStore', () {
    test('loadReadIds возвращает пустое множество изначально', () async {
      final store = NotificationReadStore();
      expect(await store.loadReadIds(), isEmpty);
    });

    test('markAllRead сохраняет и переживает пересоздание стора', () async {
      final store = NotificationReadStore();
      await store.markAllRead(['a', 'b', 'c']);

      final freshStore = NotificationReadStore();
      final loaded = await freshStore.loadReadIds();
      expect(loaded, containsAll(['a', 'b', 'c']));
    });

    test('markAllRead объединяет с уже сохранёнными, без дублей', () async {
      final store = NotificationReadStore();
      await store.markAllRead(['a', 'b']);
      await store.markAllRead(['b', 'c']);

      final loaded = await store.loadReadIds();
      expect(loaded, {'a', 'b', 'c'});
    });
  });

  group('NotificationItem', () {
    test('copyWith сохраняет поля и обновляет только переданные', () {
      final updated = item('n1').copyWith(taskStatus: 'completed');
      expect(updated.taskStatus, 'completed');
      expect(updated.id, 'n1');
      expect(updated.actorName, 'Мария');
    });

    test('props содержат все поля (equatable)', () {
      final a = item('n1');
      final b = item('n1');
      final c = item('n2');
      expect(a, b);
      expect(a == c, isFalse);
      expect(a.hashCode, b.hashCode);
    });
  });
}
