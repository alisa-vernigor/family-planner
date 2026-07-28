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

    test('с задачами из разных дней возвращает только задачи за указанный день', () {
      final dayTask = createTask(
        id: 'today',
        plannedFor: DateTime(2026, 7, 19, 10, 0),
      );
      final tomorrowTask = createTask(
        id: 'tomorrow',
        plannedFor: DateTime(2026, 7, 20, 0, 1),
      );
      final yesterdayTask = createTask(
        id: 'yesterday',
        plannedFor: DateTime(2026, 7, 18, 23, 59),
      );

      final result = TaskSchedule.forDay(
        tasks: [tomorrowTask, dayTask, yesterdayTask],
        day: day,
      );

      expect(result, [dayTask]);
    });

    test('включает задачу ровно в полночь указанного дня', () {
      final midnightTask = createTask(
        id: 'midnight',
        plannedFor: DateTime(2026, 7, 19, 0, 0),
      );

      final result = TaskSchedule.forDay(tasks: [midnightTask], day: day);

      expect(result, [midnightTask]);
    });

    test('не включает задачу ровно в полночь следующего дня', () {
      final nextMidnightTask = createTask(
        id: 'next-midnight',
        plannedFor: DateTime(2026, 7, 20, 0, 0),
      );

      final result = TaskSchedule.forDay(tasks: [nextMidnightTask], day: day);

      expect(result, isEmpty);
    });

    test('возвращает все задачи за один день', () {
      final task1 = createTask(
        id: 'task-1',
        plannedFor: DateTime(2026, 7, 19, 8, 0),
      );
      final task2 = createTask(
        id: 'task-2',
        plannedFor: DateTime(2026, 7, 19, 12, 0),
      );
      final task3 = createTask(
        id: 'task-3',
        plannedFor: DateTime(2026, 7, 19, 18, 0),
      );

      final result = TaskSchedule.forDay(
        tasks: [task1, task2, task3],
        day: day,
      );

      expect(result, [task1, task2, task3]);
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

  group('TaskSchedule.forDateRange', () {
    test('возвращает задачи внутри диапазона', () {
      final task1 = createTask(
        id: 'in-range-1',
        plannedFor: DateTime(2026, 7, 10, 10, 0),
      );
      final task2 = createTask(
        id: 'in-range-2',
        plannedFor: DateTime(2026, 7, 15, 14, 30),
      );

      final result = TaskSchedule.forDateRange(
        tasks: [task1, task2],
        start: DateTime(2026, 7, 10),
        end: DateTime(2026, 7, 20),
      );

      expect(result, [task1, task2]);
    });

    test('с пустым списком возвращает пустой список', () {
      final result = TaskSchedule.forDateRange(
        tasks: [],
        start: DateTime(2026, 7, 10),
        end: DateTime(2026, 7, 20),
      );

      expect(result, isEmpty);
    });

    test('исключает задачи до начала диапазона', () {
      final beforeTask = createTask(
        id: 'before',
        plannedFor: DateTime(2026, 7, 5, 10, 0),
      );
      final insideTask = createTask(
        id: 'inside',
        plannedFor: DateTime(2026, 7, 12, 10, 0),
      );

      final result = TaskSchedule.forDateRange(
        tasks: [beforeTask, insideTask],
        start: DateTime(2026, 7, 10),
        end: DateTime(2026, 7, 20),
      );

      expect(result, [insideTask]);
    });

    test('исключает задачи после окончания диапазона', () {
      final insideTask = createTask(
        id: 'inside',
        plannedFor: DateTime(2026, 7, 12, 10, 0),
      );
      final afterTask = createTask(
        id: 'after',
        plannedFor: DateTime(2026, 7, 25, 10, 0),
      );

      final result = TaskSchedule.forDateRange(
        tasks: [insideTask, afterTask],
        start: DateTime(2026, 7, 10),
        end: DateTime(2026, 7, 20),
      );

      expect(result, [insideTask]);
    });

    test('исключает задачи с обеих сторон диапазона', () {
      final beforeTask = createTask(
        id: 'before',
        plannedFor: DateTime(2026, 7, 5),
      );
      final insideTask = createTask(
        id: 'inside',
        plannedFor: DateTime(2026, 7, 15),
      );
      final afterTask = createTask(
        id: 'after',
        plannedFor: DateTime(2026, 7, 25),
      );

      final result = TaskSchedule.forDateRange(
        tasks: [beforeTask, afterTask, insideTask],
        start: DateTime(2026, 7, 10),
        end: DateTime(2026, 7, 20),
      );

      expect(result, [insideTask]);
    });

    test('включает задачу ровно на дате начала диапазона', () {
      final task = createTask(
        id: 'on-start',
        plannedFor: DateTime(2026, 7, 10, 0, 0),
      );

      final result = TaskSchedule.forDateRange(
        tasks: [task],
        start: DateTime(2026, 7, 10),
        end: DateTime(2026, 7, 20),
      );

      expect(result, [task]);
    });

    test('включает задачу ровно на дате окончания диапазона', () {
      final task = createTask(
        id: 'on-end',
        plannedFor: DateTime(2026, 7, 20, 0, 0),
      );

      final result = TaskSchedule.forDateRange(
        tasks: [task],
        start: DateTime(2026, 7, 10),
        end: DateTime(2026, 7, 20),
      );

      expect(result, [task]);
    });
  });
}
