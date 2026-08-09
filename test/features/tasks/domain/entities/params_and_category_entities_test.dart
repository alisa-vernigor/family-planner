import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/tasks/domain/entities/create_task_category_params.dart';
import 'package:family_planner/features/tasks/domain/entities/create_task_subtask_params.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_category.dart';
import 'package:family_planner/features/tasks/domain/entities/task_recurrence.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:family_planner/features/tasks/domain/entities/update_recurring_task_params.dart';

void main() {
  group('TaskCategory', () {
    test('создаётся со всеми полями', () {
      final category = TaskCategory(
        id: 'cat-1',
        householdId: 'h-1',
        name: 'Работа',
        colorHex: '6759A0',
        iconName: 'work',
      );

      expect(category.id, 'cat-1');
      expect(category.householdId, 'h-1');
      expect(category.name, 'Работа');
      expect(category.colorHex, '6759A0');
      expect(category.iconName, 'work');
    });

    test('colorHex и iconName опциональны', () {
      final category = TaskCategory(id: 'cat-1', householdId: 'h-1', name: 'Дом');

      expect(category.colorHex, isNull);
      expect(category.iconName, isNull);
    });

    test('равенство по полям', () {
      final a = TaskCategory(
        id: 'cat-1',
        householdId: 'h-1',
        name: 'Работа',
        colorHex: '6759A0',
        iconName: 'work',
      );
      final b = TaskCategory(
        id: 'cat-1',
        householdId: 'h-1',
        name: 'Работа',
        colorHex: '6759A0',
        iconName: 'work',
      );
      final c = TaskCategory(id: 'cat-1', householdId: 'h-1', name: 'Дом');

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.props, ['cat-1', 'h-1', 'Работа', '6759A0', 'work']);
    });
  });

  group('CreateTaskCategoryParams', () {
    test('создаётся и равняется по полям', () {
      final a = CreateTaskCategoryParams(
        householdId: 'h1',
        name: 'Работа',
        colorHex: '#FF0000',
        iconName: 'work',
      );
      final b = CreateTaskCategoryParams(
        householdId: 'h1',
        name: 'Работа',
        colorHex: '#FF0000',
        iconName: 'work',
      );
      final c = CreateTaskCategoryParams(
        householdId: 'h1',
        name: 'Дом',
        colorHex: '#00FF00',
        iconName: 'home',
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.props, ['h1', 'Работа', '#FF0000', 'work']);
    });
  });

  group('CreateTaskSubtaskParams', () {
    test('создаётся и равняется по полям', () {
      final a = CreateTaskSubtaskParams(taskId: 't1', title: 'Подзадача');
      final b = CreateTaskSubtaskParams(taskId: 't1', title: 'Подзадача');
      final c = CreateTaskSubtaskParams(taskId: 't2', title: 'Подзадача');

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.props, ['t1', 'Подзадача']);
    });
  });

  group('RecurrenceEditScope', () {
    test('databaseValue возвращает правильные строки', () {
      expect(RecurrenceEditScope.onlyThis.databaseValue, 'only_this');
      expect(
        RecurrenceEditScope.thisAndFollowing.databaseValue,
        'this_and_following',
      );
      expect(RecurrenceEditScope.all.databaseValue, 'all');
    });
  });

  group('UpdateRecurringTaskParams', () {
    final plannedFor = DateTime.utc(2026, 8, 10);
    final task = Task(
      id: 'task-1',
      householdId: 'household-1',
      title: 'Задача',
      estimatedDurationMinutes: 30,
      plannedFor: plannedFor,
      allowedMemberIds: const ['user-1'],
      status: TaskStatus.pending,
      createdAt: DateTime.utc(2026, 8, 1),
    );

    test('конструктор присваивает все поля', () {
      final start = DateTime.utc(2026, 8, 1);
      final end = DateTime.utc(2026, 9, 1);
      final newStart = DateTime.utc(2026, 8, 15);

      final params = UpdateRecurringTaskParams(
        task: task,
        recurrence: const TaskRecurrence.weekly(weekdays: [1, 3]),
        scope: RecurrenceEditScope.thisAndFollowing,
        recurrenceStartDate: start,
        recurrenceEndDate: end,
        newStartDate: newStart,
      );

      expect(params.task, task);
      expect(params.recurrence, const TaskRecurrence.weekly(weekdays: [1, 3]));
      expect(params.scope, RecurrenceEditScope.thisAndFollowing);
      expect(params.recurrenceStartDate, start);
      expect(params.recurrenceEndDate, end);
      expect(params.newStartDate, newStart);
    });

    test('copyWith переопределяет поля', () {
      final params = UpdateRecurringTaskParams(
        task: task,
        recurrence: const TaskRecurrence.daily(),
        scope: RecurrenceEditScope.onlyThis,
      );

      final updated = params.copyWith(
        task: task.copyWith(title: 'Новый заголовок'),
        recurrence: const TaskRecurrence.weekly(weekdays: [2, 4]),
        scope: RecurrenceEditScope.all,
        recurrenceStartDate: DateTime.utc(2026, 8, 5),
        recurrenceEndDate: DateTime.utc(2026, 9, 5),
        newStartDate: DateTime.utc(2026, 8, 20),
      );

      expect(updated.task.title, 'Новый заголовок');
      expect(updated.recurrence, const TaskRecurrence.weekly(weekdays: [2, 4]));
      expect(updated.scope, RecurrenceEditScope.all);
      expect(updated.recurrenceStartDate, DateTime.utc(2026, 8, 5));
      expect(updated.recurrenceEndDate, DateTime.utc(2026, 9, 5));
      expect(updated.newStartDate, DateTime.utc(2026, 8, 20));
    });

    test('copyWith оставляет поля, если они не переданы', () {
      final params = UpdateRecurringTaskParams(
        task: task,
        recurrence: const TaskRecurrence.daily(),
        scope: RecurrenceEditScope.onlyThis,
        recurrenceStartDate: DateTime.utc(2026, 8, 5),
        recurrenceEndDate: DateTime.utc(2026, 9, 5),
        newStartDate: DateTime.utc(2026, 8, 20),
      );

      final kept = params.copyWith(scope: RecurrenceEditScope.all);

      expect(kept.recurrenceStartDate, DateTime.utc(2026, 8, 5));
      expect(kept.recurrenceEndDate, DateTime.utc(2026, 9, 5));
      expect(kept.newStartDate, DateTime.utc(2026, 8, 20));
      expect(kept.task, task);
    });

    test('copyWith обнуляет даты при передаче null', () {
      final params = UpdateRecurringTaskParams(
        task: task,
        recurrence: const TaskRecurrence.daily(),
        scope: RecurrenceEditScope.onlyThis,
        recurrenceStartDate: DateTime.utc(2026, 8, 5),
        recurrenceEndDate: DateTime.utc(2026, 9, 5),
        newStartDate: DateTime.utc(2026, 8, 20),
      );

      final cleared = params.copyWith(
        recurrenceStartDate: null,
        recurrenceEndDate: null,
        newStartDate: null,
      );

      expect(cleared.recurrenceStartDate, isNull);
      expect(cleared.recurrenceEndDate, isNull);
      expect(cleared.newStartDate, isNull);
    });

    test('props содержит все поля', () {
      final start = DateTime.utc(2026, 8, 5);
      final end = DateTime.utc(2026, 9, 5);

      final params = UpdateRecurringTaskParams(
        task: task,
        recurrence: const TaskRecurrence.daily(),
        scope: RecurrenceEditScope.onlyThis,
        recurrenceStartDate: start,
        recurrenceEndDate: end,
      );

      expect(params.props, [
        task,
        const TaskRecurrence.daily(),
        RecurrenceEditScope.onlyThis,
        start,
        end,
        null, // newStartDate
      ]);
    });
  });
}
