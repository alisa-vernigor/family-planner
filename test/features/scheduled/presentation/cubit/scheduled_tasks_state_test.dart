import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/scheduled/presentation/cubit/scheduled_tasks_state.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';

void main() {
  final task = Task(
    id: 'task-1',
    householdId: 'household-1',
    title: 'Buy groceries',
    estimatedDurationMinutes: 30,
    plannedFor: DateTime(2026, 7, 22),
    deadline: DateTime(2026, 7, 22, 18),
    allowedMemberIds: const ['member-1'],
    status: TaskStatus.pending,
    createdAt: DateTime(2026, 7, 19),
  );

  final anotherTask = Task(
    id: 'task-2',
    householdId: 'household-1',
    title: 'Clean garage',
    estimatedDurationMinutes: 60,
    plannedFor: DateTime(2026, 7, 23),
    allowedMemberIds: const ['member-1'],
    status: TaskStatus.pending,
    createdAt: DateTime(2026, 7, 19),
  );

  final member = HouseholdMember(
    profileId: 'member-1',
    displayName: 'Alice',
    role: 'owner',
  );

  group('ScheduledTasksState', () {
    group('конструкторы', () {
      test('ScheduledTasksInitial создаётся без ошибок', () {
        const state = ScheduledTasksInitial();
        expect(state, isA<ScheduledTasksInitial>());
      });

      test('ScheduledTasksLoading создаётся без ошибок', () {
        const state = ScheduledTasksLoading();
        expect(state, isA<ScheduledTasksLoading>());
      });

      test('ScheduledTasksLoaded создаётся с задачами и участниками', () {
        final state = ScheduledTasksLoaded(
          tasks: [task],
          members: [member],
        );

        expect(state.tasks, [task]);
        expect(state.members, [member]);
      });

      test('ScheduledTasksLoaded использует пустой список участников по умолчанию', () {
        final state = ScheduledTasksLoaded(tasks: [task]);

        expect(state.members, isEmpty);
      });

      test('ScheduledTasksFailure создаётся с сообщением', () {
        const state = ScheduledTasksFailure(message: 'Error occurred');

        expect(state.message, 'Error occurred');
      });
    });

    group('ScheduledTasksLoaded хранит tasks и members', () {
      test('tasks содержит переданный список задач', () {
        final state = ScheduledTasksLoaded(
          tasks: [task, anotherTask],
          members: [member],
        );

        expect(state.tasks.length, 2);
        expect(state.tasks[0], task);
        expect(state.tasks[1], anotherTask);
      });

      test('members содержит переданный список участников', () {
        final anotherMember = HouseholdMember(
          profileId: 'member-2',
          displayName: 'Bob',
          role: 'member',
        );

        final state = ScheduledTasksLoaded(
          tasks: [task],
          members: [member, anotherMember],
        );

        expect(state.members.length, 2);
        expect(state.members[0], member);
        expect(state.members[1], anotherMember);
      });
    });

    group('isEmpty', () {
      test('пустой список задач', () {
        final state = ScheduledTasksLoaded(tasks: []);

        expect(state.tasks.isEmpty, isTrue);
      });

      test('непустой список задач', () {
        final state = ScheduledTasksLoaded(tasks: [task]);

        expect(state.tasks.isEmpty, isFalse);
      });
    });

    group('Equatable equality', () {
      test('ScheduledTasksInitial экземпляры равны', () {
        const state1 = ScheduledTasksInitial();
        const state2 = ScheduledTasksInitial();

        expect(state1, equals(state2));
      });

      test('ScheduledTasksLoading экземпляры равны', () {
        const state1 = ScheduledTasksLoading();
        const state2 = ScheduledTasksLoading();

        expect(state1, equals(state2));
      });

      test('ScheduledTasksLoaded экземпляры равны при одинаковых tasks и members', () {
        final state1 = ScheduledTasksLoaded(
          tasks: [task],
          members: [member],
        );
        final state2 = ScheduledTasksLoaded(
          tasks: [task],
          members: [member],
        );

        expect(state1, equals(state2));
      });

      test('ScheduledTasksLoaded экземпляры не равны при разных tasks', () {
        final state1 = ScheduledTasksLoaded(
          tasks: [task],
          members: [member],
        );
        final state2 = ScheduledTasksLoaded(
          tasks: [anotherTask],
          members: [member],
        );

        expect(state1, isNot(equals(state2)));
      });

      test('ScheduledTasksLoaded экземпляры не равны при разных members', () {
        final anotherMember = HouseholdMember(
          profileId: 'member-2',
          displayName: 'Bob',
          role: 'member',
        );

        final state1 = ScheduledTasksLoaded(
          tasks: [task],
          members: [member],
        );
        final state2 = ScheduledTasksLoaded(
          tasks: [task],
          members: [anotherMember],
        );

        expect(state1, isNot(equals(state2)));
      });

      test('ScheduledTasksFailure экземпляры равны при одинаковых сообщениях', () {
        const state1 = ScheduledTasksFailure(message: 'Error');
        const state2 = ScheduledTasksFailure(message: 'Error');

        expect(state1, equals(state2));
      });

      test('ScheduledTasksFailure экземпляры не равны при разных сообщениях', () {
        const state1 = ScheduledTasksFailure(message: 'Error A');
        const state2 = ScheduledTasksFailure(message: 'Error B');

        expect(state1, isNot(equals(state2)));
      });

      test('разные типы состояний не равны', () {
        const initial = ScheduledTasksInitial();
        const loading = ScheduledTasksLoading();

        expect(initial, isNot(equals(loading)));
      });
    });
  });
}
