import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:family_planner/features/tasks/presentation/cubit/task_completion_state.dart';

void main() {
  late final Task task;

  setUpAll(() {
    task = Task(
      id: 'task-1',
      householdId: 'household-1',
      title: 'Test task',
      estimatedDurationMinutes: 15,
      plannedFor: DateTime.utc(2026, 7, 28),
      allowedMemberIds: ['member-1'],
      status: TaskStatus.pending,
      createdAt: DateTime.utc(2026, 7, 27, 10),
    );
  });

  group('TaskCompletionState construction', () {
    test('TaskCompletionInitial constructs correctly', () {
      const state = TaskCompletionInitial();
      expect(state, isA<TaskCompletionInitial>());
      expect(state.props, isEmpty);
    });

    test('TaskCompletionInProgress constructs correctly', () {
      const state = TaskCompletionInProgress();
      expect(state, isA<TaskCompletionInProgress>());
      expect(state.props, isEmpty);
    });

    test('TaskCompletionSuccess constructs correctly with a task', () {
      final state = TaskCompletionSuccess(task: task);
      expect(state, isA<TaskCompletionSuccess>());
      expect(state.task, same(task));
    });

    test('TaskCompletionFailure constructs correctly with a message', () {
      const state = TaskCompletionFailure(message: 'Something went wrong');
      expect(state, isA<TaskCompletionFailure>());
      expect(state.message, 'Something went wrong');
    });
  });

  group('TaskCompletionSuccess stores task', () {
    test('returns the same task instance via getter', () {
      final state = TaskCompletionSuccess(task: task);
      expect(state.task.id, 'task-1');
      expect(state.task.title, 'Test task');
      expect(state.task.status, TaskStatus.pending);
    });
  });

  group('Equatable equality', () {
    test('two TaskCompletionInitial instances are equal', () {
      const a = TaskCompletionInitial();
      const b = TaskCompletionInitial();
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('two TaskCompletionInProgress instances are equal', () {
      const a = TaskCompletionInProgress();
      const b = TaskCompletionInProgress();
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('two TaskCompletionSuccess instances with the same task are equal', () {
      final a = TaskCompletionSuccess(task: task);
      final b = TaskCompletionSuccess(task: task);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('two TaskCompletionSuccess instances with different tasks are not equal', () {
      final differentTask = Task(
        id: 'task-2',
        householdId: 'household-1',
        title: 'Another task',
        estimatedDurationMinutes: 30,
        plannedFor: DateTime.utc(2026, 7, 28),
        allowedMemberIds: ['member-2'],
        status: TaskStatus.pending,
        createdAt: DateTime.utc(2026, 7, 27, 12),
      );
      final a = TaskCompletionSuccess(task: task);
      final b = TaskCompletionSuccess(task: differentTask);
      expect(a, isNot(equals(b)));
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });

    test('two TaskCompletionFailure instances with the same message are equal', () {
      const a = TaskCompletionFailure(message: 'Error');
      const b = TaskCompletionFailure(message: 'Error');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('two TaskCompletionFailure instances with different messages are not equal', () {
      const a = TaskCompletionFailure(message: 'Error one');
      const b = TaskCompletionFailure(message: 'Error two');
      expect(a, isNot(equals(b)));
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });
  });

  group('Different states are not equal', () {
    test('TaskCompletionInitial is not equal to TaskCompletionInProgress', () {
      const a = TaskCompletionInitial();
      const b = TaskCompletionInProgress();
      expect(a, isNot(equals(b)));
    });

    test('TaskCompletionInitial is not equal to TaskCompletionSuccess', () {
      final a = TaskCompletionInitial();
      final b = TaskCompletionSuccess(task: task);
      expect(a, isNot(equals(b)));
    });

    test('TaskCompletionInitial is not equal to TaskCompletionFailure', () {
      const a = TaskCompletionInitial();
      const b = TaskCompletionFailure(message: 'Error');
      expect(a, isNot(equals(b)));
    });

    test('TaskCompletionInProgress is not equal to TaskCompletionSuccess', () {
      final a = TaskCompletionInProgress();
      final b = TaskCompletionSuccess(task: task);
      expect(a, isNot(equals(b)));
    });

    test('TaskCompletionInProgress is not equal to TaskCompletionFailure', () {
      const a = TaskCompletionInProgress();
      const b = TaskCompletionFailure(message: 'Error');
      expect(a, isNot(equals(b)));
    });

    test('TaskCompletionSuccess is not equal to TaskCompletionFailure', () {
      final a = TaskCompletionSuccess(task: task);
      const b = TaskCompletionFailure(message: 'Error');
      expect(a, isNot(equals(b)));
    });
  });
}
