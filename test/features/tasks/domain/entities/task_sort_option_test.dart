import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/tasks/domain/entities/eisenhower_priority.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_sort_option.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';

Task _task({
  required String id,
  String title = 'Задача',
  DateTime? deadline,
  int duration = 30,
  int? priority,
  DateTime? createdAt,
  DateTime? plannedFor,
}) {
  return Task(
    id: id,
    householdId: 'h1',
    title: title,
    description: null,
    estimatedDurationMinutes: duration,
    plannedFor: plannedFor ?? DateTime.utc(2026, 8, 10),
    deadline: deadline,
    allowedMemberIds: const ['m1'],
    status: TaskStatus.pending,
    priority: priority == null ? null : EisenhowerPriority.values[priority - 1],
    createdAt: createdAt ?? DateTime.utc(2026, 8, 1),
  );
}

List<Task> _apply(List<Task> tasks, TaskSortOption option, {bool ascending = true}) {
  return TaskSortOption.apply(tasks, option, ascending: ascending);
}

void main() {
  group('TaskSortOption', () {
    test('label корректный', () {
      expect(TaskSortOption.deadline.label, 'По сроку');
      expect(TaskSortOption.priority.label, 'По приоритету');
      expect(TaskSortOption.plannedFor.label, 'По плановой дате');
    });

    test('deadline: просроченные задачи первыми', () {
      final now = DateTime.now();
      final overdue = _task(id: '1', deadline: now.subtract(const Duration(days: 1)));
      final later = _task(id: '2', deadline: now.add(const Duration(days: 3)));
      final sooner = _task(id: '3', deadline: now.add(const Duration(days: 1)));

      final sorted = _apply([later, overdue, sooner], TaskSortOption.deadline);

      expect(sorted.first.id, '1'); // overdue first
      expect(sorted.last.id, '2'); // later deadline last
    });

    test('deadline: задачи с дедлайном раньше задач без', () {
      final withDeadline = _task(id: '1', deadline: DateTime(2026, 9, 1));
      final without = _task(id: '2');

      final sorted = _apply([without, withDeadline], TaskSortOption.deadline);

      expect(sorted.first.id, '1');
    });

    test('deadline: без дедлайнов порядок сохраняется', () {
      final a = _task(id: '1');
      final b = _task(id: '2');

      final sorted = _apply([a, b], TaskSortOption.deadline);

      expect(sorted.map((t) => t.id).toList(), ['1', '2']);
    });

    test('priority: сортирует по приоритету', () {
      final low = _task(id: '1', priority: 4);
      final high = _task(id: '2', priority: 1);

      final sorted = _apply([low, high], TaskSortOption.priority);

      expect(sorted.first.id, '2');
      expect(sorted.last.id, '1');
    });

    test('duration: сортирует по длительности', () {
      final long = _task(id: '1', duration: 120);
      final short = _task(id: '2', duration: 10);

      final sorted = _apply([long, short], TaskSortOption.duration);

      expect(sorted.first.id, '2');
    });

    test('title: сортирует по названию', () {
      final b = _task(id: '1', title: 'Бета');
      final a = _task(id: '2', title: 'Альфа');

      final sorted = _apply([b, a], TaskSortOption.title);

      expect(sorted.map((t) => t.title).toList(), ['Альфа', 'Бета']);
    });

    test('createdAt: новые задачи первыми (descending)', () {
      final old = _task(id: '1', createdAt: DateTime.utc(2026, 8, 1));
      final new_ = _task(id: '2', createdAt: DateTime.utc(2026, 8, 5));

      final sorted = _apply([old, new_], TaskSortOption.createdAt);

      expect(sorted.first.id, '2');
    });

    test('plannedFor: сортирует по плановой дате', () {
      final later = _task(id: '1', plannedFor: DateTime.utc(2026, 8, 20));
      final earlier = _task(id: '2', plannedFor: DateTime.utc(2026, 8, 5));

      final sorted = _apply([later, earlier], TaskSortOption.plannedFor);

      expect(sorted.first.id, '2');
    });

    test('ascending=false разворачивает порядок', () {
      final a = _task(id: '1', duration: 10);
      final b = _task(id: '2', duration: 60);

      final sorted = _apply([a, b], TaskSortOption.duration, ascending: false);

      expect(sorted.first.id, '2');
    });

    test('не мутирует исходный список', () {
      final a = _task(id: '1', duration: 60);
      final b = _task(id: '2', duration: 10);
      final original = [a, b];

      TaskSortOption.apply(original, TaskSortOption.duration);

      expect(original, [a, b]);
    });
  });
}
