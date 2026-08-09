import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/notifications/domain/entities/notification_item.dart';
import 'package:family_planner/features/notifications/presentation/cubit/notifications_state.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_category.dart';
import 'package:family_planner/features/tasks/domain/entities/task_recurrence.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:family_planner/features/tasks/domain/entities/update_recurring_task_params.dart';
import 'package:family_planner/features/tasks/presentation/cubit/task_action_state.dart';

void main() {
  final task = Task(
    id: 'task-1',
    householdId: 'house-1',
    title: 'Помыть посуду',
    estimatedDurationMinutes: 30,
    plannedFor: DateTime(2026, 8, 10),
    allowedMemberIds: const ['m1'],
    status: TaskStatus.pending,
    createdAt: DateTime(2026, 8, 1),
  );

  group('RecurrenceEditScope', () {
    test('databaseValue для всех значений', () {
      expect(RecurrenceEditScope.onlyThis.databaseValue, 'only_this');
      expect(RecurrenceEditScope.thisAndFollowing.databaseValue,
          'this_and_following');
      expect(RecurrenceEditScope.all.databaseValue, 'all');
    });
  });

  group('UpdateRecurringTaskParams', () {
    final recurrence = const TaskRecurrence.weekly(weekdays: [1, 3]);

    test('equatable по полям', () {
      final a = UpdateRecurringTaskParams(
        task: task,
        recurrence: recurrence,
        scope: RecurrenceEditScope.all,
      );
      final b = UpdateRecurringTaskParams(
        task: task,
        recurrence: recurrence,
        scope: RecurrenceEditScope.all,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('не равны при другом scope/recurrence', () {
      final a = UpdateRecurringTaskParams(
        task: task,
        recurrence: recurrence,
        scope: RecurrenceEditScope.all,
      );
      final b = UpdateRecurringTaskParams(
        task: task,
        recurrence: recurrence,
        scope: RecurrenceEditScope.onlyThis,
      );
      expect(a, isNot(b));
    });

    test('copyWith меняет поля и сбрасывает nullable', () {
      final p = UpdateRecurringTaskParams(
        task: task,
        recurrence: recurrence,
        scope: RecurrenceEditScope.thisAndFollowing,
        recurrenceStartDate: DateTime(2026, 8, 1),
        recurrenceEndDate: DateTime(2026, 9, 1),
        newStartDate: DateTime(2026, 8, 15),
      );

      final changed = p.copyWith(
        scope: RecurrenceEditScope.all,
        recurrenceStartDate: DateTime(2026, 9, 1),
        recurrenceEndDate: null,
        newStartDate: null,
      );

      expect(changed.task, task);
      expect(changed.recurrence, recurrence);
      expect(changed.scope, RecurrenceEditScope.all);
      expect(changed.recurrenceStartDate, DateTime(2026, 9, 1));
      expect(changed.recurrenceEndDate, isNull);
      expect(changed.newStartDate, isNull);

      // Неизменённые поля остаются.
      expect(changed.recurrenceStartDate, isNot(DateTime(2026, 8, 1)));
    });
  });

  group('TaskCategory', () {
    test('equatable по всем полям включая null', () {
      final a = const TaskCategory(
        id: 'cat-1',
        householdId: 'house-1',
        name: 'Дом',
      );
      final b = const TaskCategory(
        id: 'cat-1',
        householdId: 'house-1',
        name: 'Дом',
      );
      final c = const TaskCategory(
        id: 'cat-1',
        householdId: 'house-1',
        name: 'Дом',
        colorHex: 'FF5722',
        iconName: 'home',
      );
      expect(a, b);
      expect(a, isNot(c));
    });
  });

  group('NotificationsLoaded', () {
    final items = [
      NotificationItem(
        id: 'n1',
        kind: NotificationKind.taskAssigned,
        actorId: 'm1',
        actorName: 'Мама',
        title: 'Задача назначена',
        subtitle: 'Помыть посуду',
        occurredAt: DateTime(2026, 8, 2),
      ),
      NotificationItem(
        id: 'n2',
        kind: NotificationKind.taskAssigned,
        actorId: 'm1',
        actorName: 'Мама',
        title: 'Ещё одна',
        subtitle: 'Вынести мусор',
        occurredAt: DateTime(2026, 8, 3),
      ),
    ];

    test('unreadCount считает непрочитанные', () {
      final state = NotificationsLoaded(items: items, readIds: const {'n1'});
      expect(state.unreadCount, 1);
    });

    test('равенство учитывает items и readIds', () {
      final a = NotificationsLoaded(items: items, readIds: const {'n1'});
      final b = NotificationsLoaded(items: items, readIds: const {'n1'});
      final c = NotificationsLoaded(items: items, readIds: const {'n2'});
      expect(a, b);
      expect(a, isNot(c));
    });
  });

  group('TaskActionState', () {
    test('TaskActionSuccess несёт задачу и равняется по ней', () {
      final a = TaskActionSuccess(task: task);
      final b = TaskActionSuccess(task: task);
      final c = TaskActionSuccess(
        task: Task(
          id: 'task-2',
          householdId: 'house-1',
          title: 'Другая',
          estimatedDurationMinutes: 10,
          plannedFor: DateTime(2026, 8, 11),
          allowedMemberIds: const ['m1'],
          status: TaskStatus.pending,
          createdAt: DateTime(2026, 8, 1),
        ),
      );
      expect(a, b);
      expect(a, isNot(c));
      expect(a.task, task);
    });

    test('TaskActionFailure несёт сообщение и равняется по нему', () {
      final a = const TaskActionFailure(message: 'Ошибка');
      final b = const TaskActionFailure(message: 'Ошибка');
      final c = const TaskActionFailure(message: 'Другая');
      expect(a, b);
      expect(a, isNot(c));
      expect(a.message, 'Ошибка');
    });
  });
}
