import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:family_planner/features/tasks/presentation/cubit/create_task_state.dart';

void main() {
  group('CreateTaskState', () {
    group('CreateTaskInitial', () {
      test('конструируется без ошибок', () {
        const state = CreateTaskInitial();
        expect(state, isA<CreateTaskState>());
      });

      test('равен сам себе', () {
        const a = CreateTaskInitial();
        const b = CreateTaskInitial();
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });
    });

    group('CreateTaskInProgress', () {
      test('конструируется без ошибок', () {
        const state = CreateTaskInProgress();
        expect(state, isA<CreateTaskState>());
      });

      test('равен сам себе', () {
        const a = CreateTaskInProgress();
        const b = CreateTaskInProgress();
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });
    });

    group('CreateTaskSuccess', () {
      final plannedFor = DateTime.utc(2026, 7, 19);
      final createdAt = DateTime.utc(2026, 7, 19, 12);

      final task = Task(
        id: 'task-1',
        householdId: 'household-1',
        title: 'Купить продукты',
        estimatedDurationMinutes: 30,
        plannedFor: plannedFor,
        allowedMemberIds: const ['user-1'],
        status: TaskStatus.pending,
        createdAt: createdAt,
      );

      test('конструируется с задачей', () {
        final otherTask = Task(
          id: 'task-2',
          householdId: 'household-2',
          title: 'Другая задача',
          estimatedDurationMinutes: 15,
          plannedFor: plannedFor,
          allowedMemberIds: ['user-2'],
          status: TaskStatus.pending,
          createdAt: createdAt,
        );

        final state = CreateTaskSuccess(task: task);
        expect(state, isA<CreateTaskState>());
        expect(state.task, equals(task));
        expect(state.task.id, equals('task-1'));
        expect(state.task.title, equals('Купить продукты'));

        final state2 = CreateTaskSuccess(task: otherTask);
        expect(state2.task.id, equals('task-2'));
        expect(state2.task.title, equals('Другая задача'));
      });

      test('stores task reference', () {
        final state = CreateTaskSuccess(task: task);
        expect(state.task, same(task));
      });

      test('равен другому CreateTaskSuccess с такой же задачей', () {
        final a = CreateTaskSuccess(task: task);
        final b = CreateTaskSuccess(task: task);
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('не равен CreateTaskSuccess с другой задачей', () {
        final otherTask = Task(
          id: 'task-2',
          householdId: 'household-1',
          title: 'Другая задача',
          estimatedDurationMinutes: 15,
          plannedFor: plannedFor,
          allowedMemberIds: const ['user-2'],
          status: TaskStatus.pending,
          createdAt: createdAt,
        );

        final a = CreateTaskSuccess(task: task);
        final b = CreateTaskSuccess(task: otherTask);
        expect(a, isNot(equals(b)));
      });
    });

    group('CreateTaskFailure', () {
      test('конструируется с сообщением об ошибке', () {
        const state = CreateTaskFailure(message: 'Ошибка');
        expect(state, isA<CreateTaskState>());
        expect(state.message, equals('Ошибка'));
      });

      test('stores failure message', () {
        const state = CreateTaskFailure(message: 'Нет подключения');
        expect(state.message, equals('Нет подключения'));
      });

      test('равен другому CreateTaskFailure с таким же сообщением', () {
        const a = CreateTaskFailure(message: 'Ошибка');
        const b = CreateTaskFailure(message: 'Ошибка');
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('не равен CreateTaskFailure с другим сообщением', () {
        const a = CreateTaskFailure(message: 'Ошибка А');
        const b = CreateTaskFailure(message: 'Ошибка Б');
        expect(a, isNot(equals(b)));
      });
    });

    group('Equatable перекрёстные сравнения', () {
      test('разные типы состояний не равны', () {
        expect(
          const CreateTaskInitial(),
          isNot(equals(const CreateTaskInProgress())),
        );
      });

      test('CreateTaskInitial не равен CreateTaskSuccess', () {
        final plannedFor = DateTime.utc(2026, 7, 19);

        expect(
          const CreateTaskInitial(),
          isNot(equals(CreateTaskSuccess(
            task: Task(
              id: '1',
              householdId: 'h1',
              title: 't',
              estimatedDurationMinutes: 10,
              plannedFor: plannedFor,
              allowedMemberIds: ['m1'],
              status: TaskStatus.pending,
              createdAt: plannedFor,
            ),
          ))),
        );
      });

      test('CreateTaskInProgress не равен CreateTaskFailure', () {
        expect(
          const CreateTaskInProgress(),
          isNot(equals(const CreateTaskFailure(message: 'err'))),
        );
      });
    });
  });
}
