import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:family_planner/features/today/presentation/cubit/today_tasks_state.dart';

void main() {
  group('TodayTasksInitial', () {
    test('constructs correctly', () {
      const state = TodayTasksInitial();
      expect(state, isA<TodayTasksState>());
    });

    test('props is empty', () {
      expect(const TodayTasksInitial().props, []);
    });

    test('same instances are equal', () {
      const a = TodayTasksInitial();
      const b = TodayTasksInitial();
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('TodayTasksLoading', () {
    test('constructs correctly', () {
      const state = TodayTasksLoading();
      expect(state, isA<TodayTasksState>());
    });

    test('props is empty', () {
      expect(const TodayTasksLoading().props, []);
    });

    test('same instances are equal', () {
      const a = TodayTasksLoading();
      const b = TodayTasksLoading();
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('TodayTasksLoaded', () {
    final plannedFor = DateTime.utc(2026, 7, 28);
    final createdAt = DateTime.utc(2026, 7, 28, 10);

    final task = Task(
      id: 'task-1',
      householdId: 'household-1',
      title: 'Buy groceries',
      estimatedDurationMinutes: 30,
      plannedFor: plannedFor,
      allowedMemberIds: const ['member-1'],
      status: TaskStatus.pending,
      createdAt: createdAt,
    );

    final otherTask = Task(
      id: 'task-2',
      householdId: 'household-1',
      title: 'Walk the dog',
      estimatedDurationMinutes: 15,
      plannedFor: plannedFor,
      allowedMemberIds: const ['member-2'],
      status: TaskStatus.pending,
      createdAt: createdAt,
    );

    final member = const HouseholdMember(
      profileId: 'member-1',
      displayName: 'Alice',
      role: 'owner',
    );

    final otherMember = const HouseholdMember(
      profileId: 'member-2',
      displayName: 'Bob',
      role: 'member',
    );

    test('constructs with tasks and members', () {
      const state = TodayTasksLoaded(tasks: [], members: []);
      expect(state, isA<TodayTasksState>());
      expect(state, isA<TodayTasksLoaded>());
    });

    test('stores tasks', () {
      final state = TodayTasksLoaded(tasks: [task, otherTask]);
      expect(state.tasks, hasLength(2));
      expect(state.tasks[0], equals(task));
      expect(state.tasks[1], equals(otherTask));
    });

    test('stores members', () {
      final state = TodayTasksLoaded(
        tasks: [task],
        members: [member, otherMember],
      );
      expect(state.members, hasLength(2));
      expect(state.members[0], equals(member));
      expect(state.members[1], equals(otherMember));
    });

    test('members defaults to empty list', () {
      final state = TodayTasksLoaded(tasks: [task]);
      expect(state.members, isEmpty);
    });

    test('isEmpty is true when tasks is empty', () {
      final state = TodayTasksLoaded(tasks: []);
      expect(state.isEmpty, isTrue);
    });

    test('isEmpty is false when tasks is not empty', () {
      final state = TodayTasksLoaded(tasks: [task]);
      expect(state.isEmpty, isFalse);
    });

    test('isEmpty is false with multiple tasks', () {
      final state = TodayTasksLoaded(tasks: [task, otherTask]);
      expect(state.isEmpty, isFalse);
    });

    test('same instances are equal', () {
      final a = TodayTasksLoaded(tasks: [task], members: [member]);
      final b = TodayTasksLoaded(tasks: [task], members: [member]);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different tasks are not equal', () {
      final a = TodayTasksLoaded(tasks: [task]);
      final b = TodayTasksLoaded(tasks: [otherTask]);
      expect(a, isNot(equals(b)));
    });

    test('different members are not equal', () {
      final a = TodayTasksLoaded(tasks: [task], members: [member]);
      final b = TodayTasksLoaded(tasks: [task], members: [otherMember]);
      expect(a, isNot(equals(b)));
    });

    test('empty tasks vs non-empty tasks are not equal', () {
      final a = TodayTasksLoaded(tasks: []);
      final b = TodayTasksLoaded(tasks: [task]);
      expect(a, isNot(equals(b)));
    });
  });

  group('TodayTasksFailure', () {
    test('constructs with error message', () {
      const state = TodayTasksFailure(message: 'An error occurred');
      expect(state, isA<TodayTasksState>());
      expect(state.message, equals('An error occurred'));
    });

    test('stores failure message', () {
      const state = TodayTasksFailure(message: 'Network error');
      expect(state.message, equals('Network error'));
    });

    test('same instances are equal', () {
      const a = TodayTasksFailure(message: 'Error');
      const b = TodayTasksFailure(message: 'Error');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different messages are not equal', () {
      const a = TodayTasksFailure(message: 'Error A');
      const b = TodayTasksFailure(message: 'Error B');
      expect(a, isNot(equals(b)));
    });
  });

  group('Equatable cross-state comparisons', () {
    final plannedFor = DateTime.utc(2026, 7, 28);
    final createdAt = DateTime.utc(2026, 7, 28, 10);

    test('TodayTasksInitial is not equal to TodayTasksLoading', () {
      expect(
        const TodayTasksInitial(),
        isNot(equals(const TodayTasksLoading())),
      );
    });

    test('TodayTasksInitial is not equal to TodayTasksLoaded', () {
      expect(
        const TodayTasksInitial(),
        isNot(equals(TodayTasksLoaded(tasks: []))),
      );
    });

    test('TodayTasksInitial is not equal to TodayTasksFailure', () {
      expect(
        const TodayTasksInitial(),
        isNot(equals(const TodayTasksFailure(message: 'err'))),
      );
    });

    test('TodayTasksLoading is not equal to TodayTasksFailure', () {
      expect(
        const TodayTasksLoading(),
        isNot(equals(const TodayTasksFailure(message: 'err'))),
      );
    });

    test('TodayTasksLoaded is not equal to TodayTasksFailure', () {
      expect(
        TodayTasksLoaded(tasks: []),
        isNot(equals(const TodayTasksFailure(message: 'err'))),
      );
    });

    test('TodayTasksLoaded is not equal to TodayTasksLoading', () {
      expect(
        TodayTasksLoaded(
          tasks: [
            Task(
              id: '1',
              householdId: 'h1',
              title: 'Test',
              estimatedDurationMinutes: 10,
              plannedFor: plannedFor,
              allowedMemberIds: ['m1'],
              status: TaskStatus.pending,
              createdAt: createdAt,
            ),
          ],
        ),
        isNot(equals(const TodayTasksLoading())),
      );
    });
  });
}
