import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:family_planner/features/tasks/domain/services/task_schedule.dart';

void main() {
  final day = DateTime(2026, 7, 19, 12);

  Task createTask({required String id, required DateTime plannedFor}) {
    return Task(
      id: id,
      householdId: 'household-1',
      title: 'Задача $id',
      estimatedDurationMinutes: 30,
      plannedFor: plannedFor,
      allowedMemberIds: const ['member-1'],
      status: TaskStatus.pending,
      createdAt: DateTime(2026, 7, 1),
    );
  }

  group('TaskSchedule.forDay', () {
    test('возвращает задачу, запланированную на этот же день утром', () {
      final task = createTask(
        id: 'morning',
        plannedFor: DateTime(2026, 7, 19, 0, 1),
      );

      final result = TaskSchedule.forDay(tasks: [task], day: day);

      expect(result, [task]);
    });

    test('возвращает задачу, запланированную на этот же день вечером', () {
      final task = createTask(
        id: 'evening',
        plannedFor: DateTime(2026, 7, 19, 23, 59),
      );

      final result = TaskSchedule.forDay(tasks: [task], day: day);

      expect(result, [task]);
    });

    test('не возвращает задачу, запланированную на завтра', () {
      final tomorrowTask = createTask(
        id: 'tomorrow',
        plannedFor: DateTime(2026, 7, 20, 0, 1),
      );

      final result = TaskSchedule.forDay(tasks: [tomorrowTask], day: day);

      expect(result, isEmpty);
    });

    test('не возвращает задачу из прошлого дня', () {
      final yesterdayTask = createTask(
        id: 'yesterday',
        plannedFor: DateTime(2026, 7, 18, 23, 59),
      );

      final result = TaskSchedule.forDay(tasks: [yesterdayTask], day: day);

      expect(result, isEmpty);
    });
  });

  group('TaskSchedule.scheduledAfter', () {
    test('возвращает только задачи с завтрашнего дня и сортирует по дате', () {
      final laterTask = createTask(
        id: 'later',
        plannedFor: DateTime(2026, 7, 25),
      );
      final tomorrowTask = createTask(
        id: 'tomorrow',
        plannedFor: DateTime(2026, 7, 20),
      );
      final todayTask = createTask(
        id: 'today',
        plannedFor: DateTime(2026, 7, 19, 23, 59),
      );

      final result = TaskSchedule.scheduledAfter(
        tasks: [laterTask, todayTask, tomorrowTask],
        day: day,
      );

      expect(result, [tomorrowTask, laterTask]);
    });
  });

  group('TaskSchedule.overdueBefore', () {
    test('возвращает только задачи до сегодняшнего дня', () {
      final overdueTask = createTask(
        id: 'overdue',
        plannedFor: DateTime(2026, 7, 18, 23, 59),
      );
      final todayTask = createTask(
        id: 'today',
        plannedFor: DateTime(2026, 7, 19),
      );

      final result = TaskSchedule.overdueBefore(
        tasks: [overdueTask, todayTask],
        day: day,
      );

      expect(result, [overdueTask]);
    });
  });
}
