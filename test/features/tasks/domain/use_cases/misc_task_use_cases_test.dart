import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/tasks/domain/use_cases/delete_task_use_case.dart';
import 'package:family_planner/features/tasks/domain/use_cases/get_all_pending_tasks_use_case.dart';
import 'package:family_planner/features/tasks/domain/use_cases/get_scheduled_tasks_use_case.dart';
import 'package:family_planner/features/tasks/domain/use_cases/uncomplete_task_use_case.dart';
import 'package:family_planner/features/tasks/domain/use_cases/update_task_use_case.dart';

class MockTaskRepository extends Mock implements TaskRepository {}

void main() {
  late MockTaskRepository repository;

  final task = Task(
    id: 'task-1',
    householdId: 'household-1',
    title: 'Купить продукты',
    description: 'Молоко и хлеб',
    estimatedDurationMinutes: 30,
    plannedFor: DateTime.utc(2026, 7, 22),
    deadline: DateTime.utc(2026, 7, 22, 18),
    allowedMemberIds: const ['member-1'],
    status: TaskStatus.pending,
    createdAt: DateTime.utc(2026, 7, 19),
  );

  setUp(() {
    repository = MockTaskRepository();
  });

  setUpAll(() {
    registerFallbackValue(
      Task(
        id: 'fallback',
        householdId: 'fallback',
        title: 'fallback',
        estimatedDurationMinutes: 1,
        plannedFor: DateTime.utc(2026, 1, 1),
        allowedMemberIds: const [],
        status: TaskStatus.pending,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
  });

  group('DeleteTaskUseCase', () {
    test('calls repository.delete with correct taskId', () async {
      when(() => repository.delete(taskId: any(named: 'taskId')))
          .thenAnswer((_) async {});

      await DeleteTaskUseCase(repository: repository)(taskId: task.id);

      verify(() => repository.delete(taskId: 'task-1')).called(1);
    });
  });

  group('GetScheduledTasksUseCase', () {
    test('calls repository.getScheduledAfter with correct arguments and returns tasks', () async {
      when(
        () => repository.getScheduledAfter(
          householdId: any(named: 'householdId'),
          day: any(named: 'day'),
        ),
      ).thenAnswer((_) async => [task]);

      final result = await GetScheduledTasksUseCase(repository: repository)(
        householdId: 'household-1',
        day: DateTime.utc(2026, 7, 19),
      );

      expect(result, [task]);
      verify(
        () => repository.getScheduledAfter(
          householdId: 'household-1',
          day: DateTime.utc(2026, 7, 19),
        ),
      ).called(1);
    });

    test('forwards repository exception', () async {
      when(
        () => repository.getScheduledAfter(
          householdId: any(named: 'householdId'),
          day: any(named: 'day'),
        ),
      ).thenAnswer((_) async => Future.error(Exception('db error')));

      expect(
        GetScheduledTasksUseCase(repository: repository)(
          householdId: 'household-1',
          day: DateTime.utc(2026, 7, 19),
        ),
        throwsException,
      );
    });
  });

  group('GetAllPendingTasksUseCase', () {
    test('calls repository.getAllPending with correct householdId and returns tasks', () async {
      when(
        () => repository.getAllPending(householdId: any(named: 'householdId')),
      ).thenAnswer((_) async => [task]);

      final result = await GetAllPendingTasksUseCase(repository: repository)(
        householdId: 'household-1',
      );

      expect(result, [task]);
      verify(
        () => repository.getAllPending(householdId: 'household-1'),
      ).called(1);
    });
  });

  group('UncompleteTaskUseCase', () {
    test('saves completed task with status=TaskStatus.pending and clears assignment/completion', () async {
      final completedTask = task.copyWith(
        assignedMemberId: 'member-1',
        status: TaskStatus.completed,
        completedAt: DateTime.utc(2026, 7, 22, 10),
      );

      final expectedTask = completedTask.copyWith(
        assignedMemberId: null,
        status: TaskStatus.pending,
        completedAt: null,
      );

      when(() => repository.patchStatus(
        taskId: any(named: 'taskId'),
        status: any(named: 'status'),
        completedByMemberId: any(named: 'completedByMemberId'),
        completedAt: any(named: 'completedAt'),
        assignedMemberId: any(named: 'assignedMemberId'),
      )).thenAnswer((_) async {});

      final result = await UncompleteTaskUseCase(repository: repository)(
        task: completedTask,
      );

      expect(result, expectedTask);
      verify(() => repository.patchStatus(
        taskId: 'task-1',
        status: 'pending',
        completedByMemberId: null,
        completedAt: null,
        assignedMemberId: any(named: 'assignedMemberId'),
      )).called(1);
    });

    test('throws TaskNotCompletedException for non-completed task', () async {
      when(() => repository.patchStatus(
        taskId: any(named: 'taskId'),
        status: any(named: 'status'),
        completedByMemberId: any(named: 'completedByMemberId'),
        completedAt: any(named: 'completedAt'),
        assignedMemberId: any(named: 'assignedMemberId'),
      )).thenAnswer((_) async {});

      await expectLater(
        UncompleteTaskUseCase(repository: repository)(task: task),
        throwsA(isA<TaskNotCompletedException>()),
      );

      verifyNever(() => repository.patchStatus(
        taskId: any(named: 'taskId'),
        status: any(named: 'status'),
        completedByMemberId: any(named: 'completedByMemberId'),
        completedAt: any(named: 'completedAt'),
        assignedMemberId: any(named: 'assignedMemberId'),
      ));
    });
  });

  group('UpdateTaskUseCase', () {
    test('saves task with trimmed title and trims non-empty description', () async {
      final editedTask = task.copyWith(
        title: '  Купить продукты для ужина  ',
        estimatedDurationMinutes: 45,
      );

      when(() => repository.save(any())).thenAnswer((_) async {});

      await UpdateTaskUseCase(repository: repository)(task: editedTask);

      verify(
        () => repository.save(
          editedTask.copyWith(
            title: 'Купить продукты для ужина',
            description: 'Молоко и хлеб',
          ),
        ),
      ).called(1);
    });

    test('throws ArgumentError for empty title', () async {
      final editedTask = task.copyWith(title: '   ');

      when(() => repository.save(any())).thenAnswer((_) async {});

      await expectLater(
        UpdateTaskUseCase(repository: repository)(task: editedTask),
        throwsArgumentError,
      );

      verifyNever(() => repository.save(any()));
    });

    test('throws ArgumentError for zero duration', () async {
      final editedTask = task.copyWith(estimatedDurationMinutes: 0);

      when(() => repository.save(any())).thenAnswer((_) async {});

      await expectLater(
        UpdateTaskUseCase(repository: repository)(task: editedTask),
        throwsArgumentError,
      );

      verifyNever(() => repository.save(any()));
    });

    test('sets whitespace-only description to null', () async {
      final editedTask = task.copyWith(description: '   ');

      when(() => repository.save(any())).thenAnswer((_) async {});

      await UpdateTaskUseCase(repository: repository)(task: editedTask);

      verify(
        () => repository.save(
          editedTask.copyWith(
            title: 'Купить продукты',
            description: null,
          ),
        ),
      ).called(1);
    });

    test('trims non-empty description', () async {
      final editedTask = task.copyWith(description: '  Купить ещё и сыр  ');

      when(() => repository.save(any())).thenAnswer((_) async {});

      await UpdateTaskUseCase(repository: repository)(task: editedTask);

      verify(
        () => repository.save(
          editedTask.copyWith(
            title: 'Купить продукты',
            description: 'Купить ещё и сыр',
          ),
        ),
      ).called(1);
    });
  });
}
