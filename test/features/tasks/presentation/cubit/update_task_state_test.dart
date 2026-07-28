import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:family_planner/features/tasks/presentation/cubit/update_task_state.dart';

void main() {
  group('UpdateTaskState', () {
    late DateTime now;
    late Task task;

    setUp(() {
      now = DateTime.utc(2026, 7, 28, 12);
      task = Task(
        id: 'task-1',
        householdId: 'household-1',
        title: 'Test task',
        estimatedDurationMinutes: 30,
        plannedFor: DateTime.utc(2026, 7, 28),
        allowedMemberIds: const ['member-1'],
        status: TaskStatus.pending,
        createdAt: now,
      );
    });

    group('states construct correctly', () {
      test('UpdateTaskInitial can be const', () {
        const state = UpdateTaskInitial();
        expect(state, isA<UpdateTaskState>());
      });

      test('UpdateTaskInProgress can be const', () {
        const state = UpdateTaskInProgress();
        expect(state, isA<UpdateTaskState>());
      });

      test('UpdateTaskSuccess constructs with a task', () {
        final state = UpdateTaskSuccess(task: task);
        expect(state, isA<UpdateTaskState>());
        expect(state.task, task);
      });

      test('UpdateTaskFailure constructs with a message', () {
        const message = 'Something went wrong';
        final state = UpdateTaskFailure(message: message);
        expect(state, isA<UpdateTaskState>());
        expect(state.message, message);
      });
    });

    group('UpdateTaskSuccess stores task', () {
      test('stores the provided task', () {
        final state = UpdateTaskSuccess(task: task);
        expect(state.task.id, 'task-1');
        expect(state.task.title, 'Test task');
        expect(state.task.status, TaskStatus.pending);
      });

      test('stores a different task instance', () {
        final otherTask = task.copyWith(id: 'task-2', title: 'Other task');
        final state = UpdateTaskSuccess(task: otherTask);
        expect(state.task.id, 'task-2');
        expect(state.task.title, 'Other task');
      });
    });

    group('Equatable equality', () {
      test('UpdateTaskInitial instances are equal', () {
        expect(const UpdateTaskInitial(), const UpdateTaskInitial());
      });

      test('UpdateTaskInProgress instances are equal', () {
        expect(const UpdateTaskInProgress(), const UpdateTaskInProgress());
      });

      test('UpdateTaskSuccess instances with same task are equal', () {
        final state1 = UpdateTaskSuccess(task: task);
        final state2 = UpdateTaskSuccess(task: task);
        expect(state1, state2);
      });

      test(
          'UpdateTaskSuccess instances with different tasks are not equal',
          () {
        final state1 = UpdateTaskSuccess(task: task);
        final state2 = UpdateTaskSuccess(
          task: task.copyWith(id: 'task-2'),
        );
        expect(state1, isNot(state2));
      });

      test('UpdateTaskFailure instances with same message are equal', () {
        const state1 = UpdateTaskFailure(message: 'error');
        const state2 = UpdateTaskFailure(message: 'error');
        expect(state1, state2);
      });

      test(
          'UpdateTaskFailure instances with different messages are not equal',
          () {
        const state1 = UpdateTaskFailure(message: 'error-1');
        const state2 = UpdateTaskFailure(message: 'error-2');
        expect(state1, isNot(state2));
      });

      test('different state types are not equal', () {
        expect(
          const UpdateTaskInitial(),
          isNot(const UpdateTaskInProgress()),
        );
        expect(
          const UpdateTaskInProgress(),
          isNot(UpdateTaskSuccess(task: task)),
        );
        expect(
          UpdateTaskSuccess(task: task),
          isNot(const UpdateTaskFailure(message: 'error')),
        );
      });
    });
  });
}
