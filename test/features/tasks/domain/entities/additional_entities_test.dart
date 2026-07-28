import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/tasks/domain/entities/create_task_params.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_recurrence.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';

void main() {
  group('TaskRecurrence', () {
    group('named constructors', () {
      test('daily() задаёт type = daily, intervalDays = null, weekdays = []', () {
        final recurrence = const TaskRecurrence.daily();

        expect(recurrence.type, TaskRecurrenceType.daily);
        expect(recurrence.intervalDays, isNull);
        expect(recurrence.weekdays, isEmpty);
      });

      test('weekly() задаёт type = weekly, intervalDays = null', () {
        final recurrence = const TaskRecurrence.weekly(weekdays: [1, 3, 5]);

        expect(recurrence.type, TaskRecurrenceType.weekly);
        expect(recurrence.intervalDays, isNull);
        expect(recurrence.weekdays, [1, 3, 5]);
      });

      test('intervalDays() задаёт type = intervalDays, weekdays = []', () {
        final recurrence = const TaskRecurrence.intervalDays(intervalDays: 3);

        expect(recurrence.type, TaskRecurrenceType.intervalDays);
        expect(recurrence.intervalDays, 3);
        expect(recurrence.weekdays, isEmpty);
      });
    });

    group('props', () {
      test('содержит type, intervalDays, weekdays', () {
        final recurrence = const TaskRecurrence.weekly(weekdays: [2, 4]);

        expect(recurrence.props, [
          TaskRecurrenceType.weekly,
          null,
          [2, 4],
        ]);
      });
    });

    group('equality', () {
      test('одинаковые значения равны', () {
        const a = TaskRecurrence.weekly(weekdays: [1, 2, 3]);
        const b = TaskRecurrence.weekly(weekdays: [1, 2, 3]);

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('разный intervalDays делает объекты неравными', () {
        const a = TaskRecurrence.intervalDays(intervalDays: 2);
        const b = TaskRecurrence.intervalDays(intervalDays: 3);

        expect(a, isNot(equals(b)));
      });

      test('разный weekdays делает объекты неравными', () {
        const a = TaskRecurrence.weekly(weekdays: [1, 3]);
        const b = TaskRecurrence.weekly(weekdays: [1, 4]);

        expect(a, isNot(equals(b)));
      });
    });
  });

  group('CreateTaskParams', () {
    final plannedFor = DateTime.utc(2026, 7, 28);

    test('конструктор присваивает все поля', () {
      final recurrence = const TaskRecurrence.daily();
      final params = CreateTaskParams(
        householdId: 'household-1',
        title: 'Полить цветы',
        description: 'Все комнатные растения',
        estimatedDurationMinutes: 15,
        plannedFor: plannedFor,
        deadline: DateTime.utc(2026, 7, 28, 18),
        assignedMemberId: 'member-2',
        pinnedMemberId: 'member-1',
        recurrence: recurrence,
        recurrenceStartDate: DateTime.utc(2026, 7, 28),
        recurrenceEndDate: DateTime.utc(2026, 8, 28),
      );

      expect(params.householdId, 'household-1');
      expect(params.title, 'Полить цветы');
      expect(params.description, 'Все комнатные растения');
      expect(params.estimatedDurationMinutes, 15);
      expect(params.plannedFor, plannedFor);
      expect(params.deadline, DateTime.utc(2026, 7, 28, 18));
      expect(params.assignedMemberId, 'member-2');
      expect(params.pinnedMemberId, 'member-1');
      expect(params.recurrence, recurrence);
      expect(params.recurrenceStartDate, DateTime.utc(2026, 7, 28));
      expect(params.recurrenceEndDate, DateTime.utc(2026, 8, 28));
    });

    test('isRecurring возвращает true при наличии recurrence', () {
      final recurring = CreateTaskParams(
        householdId: 'h-1',
        title: 'Test',
        estimatedDurationMinutes: 5,
        plannedFor: plannedFor,
        recurrence: const TaskRecurrence.daily(),
      );
      final nonRecurring = CreateTaskParams(
        householdId: 'h-1',
        title: 'Test',
        estimatedDurationMinutes: 5,
        plannedFor: plannedFor,
      );

      expect(recurring.isRecurring, isTrue);
      expect(nonRecurring.isRecurring, isFalse);
    });

    test('props содержит все поля', () {
      final params = CreateTaskParams(
        householdId: 'h-1',
        title: 'Test',
        description: 'Desc',
        estimatedDurationMinutes: 10,
        plannedFor: plannedFor,
        deadline: DateTime.utc(2026, 7, 28, 18),
        assignedMemberId: 'm-1',
        pinnedMemberId: 'm-2',
        recurrence: const TaskRecurrence.daily(),
        recurrenceStartDate: DateTime.utc(2026, 7, 28),
        recurrenceEndDate: DateTime.utc(2026, 8, 28),
      );

      expect(params.props, [
        'h-1',
        'Test',
        'Desc',
        10,
        plannedFor,
        DateTime.utc(2026, 7, 28, 18),
        'm-1',
        'm-2',
        const TaskRecurrence.daily(),
        DateTime.utc(2026, 7, 28),
        DateTime.utc(2026, 8, 28),
      ]);
    });
  });

  group('Task — дополнительные методы', () {
    final createdAt = DateTime.utc(2026, 7, 19, 12);
    final plannedFor = DateTime.utc(2026, 7, 20);

    Task baseTask({
      TaskStatus status = TaskStatus.pending,
      String? pinnedMemberId,
      List<String>? allowedMemberIds,
      String? assignedMemberId,
      DateTime? completedAt,
    }) {
      return Task(
        id: 'task-1',
        householdId: 'household-1',
        title: 'Вынести мусор',
        estimatedDurationMinutes: 10,
        plannedFor: plannedFor,
        allowedMemberIds: allowedMemberIds ?? const ['member-1', 'member-2'],
        assignedMemberId: assignedMemberId,
        pinnedMemberId: pinnedMemberId,
        status: status,
        createdAt: createdAt,
        completedAt: completedAt,
      );
    }

    test('isCompleted — true только при статусе completed', () {
      final pending = baseTask();
      final completed = baseTask(
        status: TaskStatus.completed,
        completedAt: DateTime.utc(2026, 7, 20, 9, 15),
      );
      final skipped = baseTask(status: TaskStatus.skipped);

      expect(pending.isCompleted, isFalse);
      expect(completed.isCompleted, isTrue);
      expect(skipped.isCompleted, isFalse);
    });

    test('isPinned — true только при pinnedMemberId != null', () {
      final pinned = baseTask(pinnedMemberId: 'member-1');
      final notPinned = baseTask();

      expect(pinned.isPinned, isTrue);
      expect(notPinned.isPinned, isFalse);
    });

    test('canBeCompletedBy — true для участника из allowedMemberIds', () {
      final task = baseTask(allowedMemberIds: ['member-1', 'member-3']);

      expect(task.canBeCompletedBy('member-1'), isTrue);
      expect(task.canBeCompletedBy('member-3'), isTrue);
    });

    test('canBeCompletedBy — false для участника вне allowedMemberIds', () {
      final task = baseTask(allowedMemberIds: ['member-1', 'member-3']);

      expect(task.canBeCompletedBy('member-2'), isFalse);
      expect(task.canBeCompletedBy('member-4'), isFalse);
    });

    test('copyWith переопределяет assignedMemberId', () {
      final original = baseTask();
      final updated = original.copyWith(assignedMemberId: 'member-2');

      expect(original.assignedMemberId, isNull);
      expect(updated.assignedMemberId, 'member-2');
      expect(updated.id, original.id);
      expect(updated.title, original.title);
    });

    test('copyWith переопределяет completedAt', () {
      final completedAt = DateTime.utc(2026, 7, 20, 10);
      final original = baseTask();
      final updated = original.copyWith(completedAt: completedAt);

      expect(original.completedAt, isNull);
      expect(updated.completedAt, completedAt);
    });

    test('copyWith переопределяет title', () {
      final original = baseTask();
      final updated = original.copyWith(title: 'Обновлённое название');

      expect(original.title, 'Вынести мусор');
      expect(updated.title, 'Обновлённое название');
      expect(updated.id, original.id);
    });

    test('copyWith обнуляет assignedMemberId при передаче null', () {
      final original = baseTask(assignedMemberId: 'member-1');
      final updated = original.copyWith(assignedMemberId: null);

      expect(original.assignedMemberId, 'member-1');
      expect(updated.assignedMemberId, isNull);
    });

    test('Task equality — одинаковые значения равны', () {
      final a = baseTask(
        status: TaskStatus.completed,
        completedAt: DateTime.utc(2026, 7, 20, 9, 15),
        pinnedMemberId: 'member-1',
        assignedMemberId: 'member-2',
      );
      final b = baseTask(
        status: TaskStatus.completed,
        completedAt: DateTime.utc(2026, 7, 20, 9, 15),
        pinnedMemberId: 'member-1',
        assignedMemberId: 'member-2',
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
