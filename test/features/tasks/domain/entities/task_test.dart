import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';

void main() {
  group('Task', () {
    final createdAt = DateTime.utc(2026, 7, 19, 12);
    final plannedFor = DateTime.utc(2026, 7, 20);

    Task createTask({
      String? assignedMemberId,
      TaskStatus status = TaskStatus.pending,
      DateTime? completedAt,
    }) {
      return Task(
        id: 'task-1',
        householdId: 'household-1',
        title: 'Вынести мусор',
        description: 'Пакеты стоят у входной двери',
        estimatedDurationMinutes: 10,
        plannedFor: plannedFor,
        allowedMemberIds: const ['member-1', 'member-2'],
        assignedMemberId: assignedMemberId,
        status: status,
        createdAt: createdAt,
        completedAt: completedAt,
      );
    }

    test('создаётся с обязательными полями', () {
      final task = createTask();

      expect(task.id, 'task-1');
      expect(task.householdId, 'household-1');
      expect(task.title, 'Вынести мусор');
      expect(task.estimatedDurationMinutes, 10);
      expect(task.plannedFor, plannedFor);
      expect(task.status, TaskStatus.pending);
      expect(task.isCompleted, isFalse);
    });

    test('считает задачу завершённой только при статусе completed', () {
      final pendingTask = createTask();
      final completedTask = createTask(
        assignedMemberId: 'member-1',
        status: TaskStatus.completed,
        completedAt: DateTime.utc(2026, 7, 20, 9, 15),
      );

      expect(pendingTask.isCompleted, isFalse);
      expect(completedTask.isCompleted, isTrue);
    });

    test('считает участника допустимым исполнителем', () {
      final task = createTask();

      expect(task.canBeCompletedBy('member-1'), isTrue);
      expect(task.canBeCompletedBy('member-2'), isTrue);
      expect(task.canBeCompletedBy('member-3'), isFalse);
    });

    test('создаёт изменённую копию и не меняет исходную задачу', () {
      final originalTask = createTask();
      final updatedTask = originalTask.copyWith(assignedMemberId: 'member-2');

      expect(originalTask.assignedMemberId, isNull);
      expect(updatedTask.assignedMemberId, 'member-2');
      expect(updatedTask.id, originalTask.id);
      expect(updatedTask.title, originalTask.title);
    });

    test('одинаковые задачи равны по значениям', () {
      final firstTask = createTask();
      final secondTask = createTask();

      expect(firstTask, secondTask);
    });
  });
}
