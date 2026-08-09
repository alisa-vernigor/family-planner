import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/notifications/domain/entities/notification_item.dart';
import 'package:family_planner/features/notifications/presentation/cubit/notifications_state.dart';

void main() {
  NotificationItem item(String id) {
    return NotificationItem(
      id: id,
      kind: NotificationKind.taskAssigned,
      actorId: 'actor-1',
      actorName: 'Мария',
      title: 'Задача назначена',
      subtitle: 'Описание',
      occurredAt: DateTime(2026, 8, 8, 10),
      taskId: 'task-$id',
      taskStatus: 'pending',
      householdId: 'household-1',
    );
  }

  group('NotificationsLoaded', () {
    test('unreadCount считает только непрочитанные', () {
      const state = NotificationsLoaded(
        items: [],
        readIds: {},
      );
      expect(state.unreadCount, 0);
    });

    test('unreadCount игнорирует прочитанные', () {
      final state = NotificationsLoaded(
        items: [item('1'), item('2'), item('3')],
        readIds: const {'1', '3'},
      );
      expect(state.unreadCount, 1);
    });

    test('unreadCount учитывает прочитанные, отсутствующие в ленте', () {
      final state = NotificationsLoaded(
        items: [item('1'), item('2')],
        readIds: const {'3', '4'},
      );
      expect(state.unreadCount, 2);
    });

    test('props содержат items и readIds (equatable)', () {
      final a = NotificationsLoaded(
        items: [item('1')],
        readIds: const {'1'},
      );
      final b = NotificationsLoaded(
        items: [item('1')],
        readIds: const {'1'},
      );
      final c = NotificationsLoaded(
        items: [item('1')],
        readIds: const {'2'},
      );
      expect(a, b);
      expect(a == c, isFalse);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('NotificationsFailure', () {
    test('props содержат message (equatable)', () {
      const a = NotificationsFailure(message: 'Ошибка');
      const b = NotificationsFailure(message: 'Ошибка');
      const c = NotificationsFailure(message: 'Другая');
      expect(a, b);
      expect(a == c, isFalse);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('NotificationsInitial / NotificationsLoading', () {
    test('равны сами себе (equatable)', () {
      const a = NotificationsInitial();
      const b = NotificationsInitial();
      const loadingA = NotificationsLoading();
      const loadingB = NotificationsLoading();
      expect(a, b);
      expect(loadingA, loadingB);
      expect(a == loadingA, isFalse);
    });
  });
}
