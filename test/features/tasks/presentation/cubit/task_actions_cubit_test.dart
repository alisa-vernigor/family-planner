import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/tasks/domain/entities/create_task_params.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/tasks/domain/use_cases/skip_task_use_case.dart';
import 'package:family_planner/features/tasks/domain/use_cases/uncomplete_task_use_case.dart';
import 'package:family_planner/features/tasks/presentation/cubit/task_actions_cubit.dart';
import 'package:family_planner/features/tasks/presentation/cubit/task_action_state.dart';
import 'package:family_planner/features/tasks/domain/entities/update_recurring_task_params.dart';

void main() {
  late _FakeTaskRepository repository;
  late TaskActionsCubit cubit;

  final task = Task(
    id: 'task-1',
    householdId: 'household-1',
    title: 'Помыть окна',
    estimatedDurationMinutes: 45,
    plannedFor: DateTime.utc(2026, 7, 22),
    allowedMemberIds: const ['member-1'],
    status: TaskStatus.completed,
    createdAt: DateTime.utc(2026, 7, 19),
    assignedMemberId: 'member-1',
    completedAt: DateTime.utc(2026, 7, 22, 14),
  );

  setUp(() {
    repository = _FakeTaskRepository();
    cubit = TaskActionsCubit(
      uncompleteTaskUseCase: UncompleteTaskUseCase(repository: repository),
      skipTaskUseCase: SkipTaskUseCase(repository: repository),
      taskRepository: repository,
    );
  });

  tearDown(() async {
    await cubit.close();
  });

  group('initial state', () {
    blocTest<TaskActionsCubit, TaskActionState>(
      'должен быть TaskActionInitial',
      build: () => cubit,
      expect: () => const [],
    );
  });

  group('uncompleteTask', () {
    blocTest<TaskActionsCubit, TaskActionState>(
      'возвращает задачу и переводит в Initial',
      build: () => cubit,
      act: (cubit) => cubit.uncompleteTask(task: task),
      expect: () => const [
        TaskActionInProgress(),
        TaskActionInitial(),
      ],
      verify: (_) {
        expect(repository.savedTask, isNotNull);
        expect(repository.savedTask!.status, TaskStatus.pending);
      },
    );

    blocTest<TaskActionsCubit, TaskActionState>(
      'возвращает null и Failure для невыполненной задачи',
      build: () {
        final repository = _FakeTaskRepository();
        return TaskActionsCubit(
          uncompleteTaskUseCase: UncompleteTaskUseCase(repository: repository),
          skipTaskUseCase: SkipTaskUseCase(repository: repository),
          taskRepository: repository,
        );
      },
      act: (cubit) => cubit.uncompleteTask(
        task: task.copyWith(
          status: TaskStatus.pending,
          assignedMemberId: null,
          completedAt: null,
        ),
      ),
      expect: () => const [
        TaskActionInProgress(),
        TaskActionFailure(message: 'Не удалось отменить выполнение.'),
      ],
      verify: (_) {
        expect(repository.savedTask, isNull);
      },
    );

    test('возвращает объект Task при успешном выполнении', () async {
      final result = await cubit.uncompleteTask(task: task);
      expect(result, isA<Task>());
      final completed = result!;
      expect(completed.status, TaskStatus.pending);
      expect(completed.id, task.id);
    });

    test('возвращает null при попытке отменить невыполненную задачу', () async {
      final result = await cubit.uncompleteTask(
        task: task.copyWith(
          status: TaskStatus.pending,
          assignedMemberId: null,
          completedAt: null,
        ),
      );
      expect(result, isNull);
    });

    test('задача с напоминанием: uncomplete перепланирует напоминание '
        '(ReminderService no-op) и возвращает Task', () async {
      final withReminder = task.copyWith(reminderMinutesBefore: 30);
      final result = await cubit.uncompleteTask(task: withReminder);
      expect(result, isA<Task>());
      expect(result!.reminderMinutesBefore, 30);
    });

    blocTest<TaskActionsCubit, TaskActionState>(
      'выдаёт Failure при ошибке сохранения в репозитории',
      build: () {
        final repository = _FakeTaskRepository(shouldThrowOnSave: true);
        return TaskActionsCubit(
          uncompleteTaskUseCase: UncompleteTaskUseCase(repository: repository),
          skipTaskUseCase: SkipTaskUseCase(repository: repository),
          taskRepository: repository,
        );
      },
      act: (cubit) => cubit.uncompleteTask(task: task),
      expect: () => const [
        TaskActionInProgress(),
        TaskActionFailure(message: 'Не удалось отменить выполнение.'),
      ],
    );
  });

  group('deleteTask', () {
    blocTest<TaskActionsCubit, TaskActionState>(
      'удаляет задачу и переводит в Initial',
      build: () => cubit,
      act: (cubit) => cubit.deleteTask(taskId: 'task-1'),
      expect: () => const [
        TaskActionInProgress(),
        TaskActionInitial(),
      ],
      verify: (_) {
        expect(repository.deletedTaskId, 'task-1');
      },
    );

    blocTest<TaskActionsCubit, TaskActionState>(
      'возвращает false и Failure при ошибке репозитория',
      build: () {
        final repository = _FakeTaskRepository(shouldThrowOnDelete: true);
        return TaskActionsCubit(
          uncompleteTaskUseCase: UncompleteTaskUseCase(repository: repository),
          skipTaskUseCase: SkipTaskUseCase(repository: repository),
          taskRepository: repository,
        );
      },
      act: (cubit) => cubit.deleteTask(taskId: 'task-1'),
      expect: () => const [
        TaskActionInProgress(),
        TaskActionFailure(message: 'Не удалось удалить задачу.'),
      ],
    );

    test('возвращает true при успешном удалении', () async {
      final result = await cubit.deleteTask(taskId: 'task-1');
      expect(result, isTrue);
    });

    test('возвращает false при ошибке удаления', () async {
      final repository = _FakeTaskRepository(shouldThrowOnDelete: true);
      final cubit = TaskActionsCubit(
        uncompleteTaskUseCase: UncompleteTaskUseCase(repository: repository),
        skipTaskUseCase: SkipTaskUseCase(repository: repository),
        taskRepository: repository,
      );
      final result = await cubit.deleteTask(taskId: 'task-1');
      expect(result, isFalse);
      await cubit.close();
    });
  });

  group('skipTask', () {
    final pendingTask = task.copyWith(
      status: TaskStatus.pending,
      assignedMemberId: null,
      completedAt: null,
    );

    blocTest<TaskActionsCubit, TaskActionState>(
      'помечает задачу как пропущенную и переводит в Initial',
      build: () => cubit,
      act: (cubit) => cubit.skipTask(task: pendingTask),
      expect: () => const [
        TaskActionInProgress(),
        TaskActionInitial(),
      ],
      verify: (_) {
        expect(repository.savedTask, isNotNull);
        expect(repository.savedTask!.status, TaskStatus.skipped);
      },
    );

    test('возвращает Task со статусом skipped при успехе', () async {
      final result = await cubit.skipTask(task: pendingTask);
      expect(result, isA<Task>());
      expect(result!.status, TaskStatus.skipped);
      expect(result.id, task.id);
    });

    test('возвращает null при ошибке репозитория', () async {
      final repository = _FakeTaskRepository(shouldThrowOnSave: true);
      final cubit = TaskActionsCubit(
        uncompleteTaskUseCase: UncompleteTaskUseCase(repository: repository),
        skipTaskUseCase: SkipTaskUseCase(repository: repository),
        taskRepository: repository,
      );
      final result = await cubit.skipTask(task: pendingTask);
      expect(result, isNull);
      await cubit.close();
    });
  });
}

final class _FakeTaskRepository implements TaskRepository {
  @override
  Future<void> updateTemplate({
    required UpdateRecurringTaskParams params,
  }) async {}
  @override
  Future<void> pauseTemplate({required String templateId}) async {}

  @override
  Future<void> resumeTemplate({required String templateId}) async {}

  _FakeTaskRepository({
    this.shouldThrowOnDelete = false,
    this.shouldThrowOnSave = false,
  });

  final bool shouldThrowOnDelete;
  final bool shouldThrowOnSave;

  Task? savedTask;
  String? deletedTaskId;

  @override
  Future<Task> create({required CreateTaskParams params}) {
    throw UnimplementedError();
  }

  @override
  Future<void> delete({required String taskId}) async {
    if (shouldThrowOnDelete) {
      throw Exception('Ошибка сети');
    }
    deletedTaskId = taskId;
  }

  @override
  Future<List<Task>> getForDay({
    required String householdId,
    required DateTime day,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<Task>> getScheduledAfter({
    required String householdId,
    required DateTime day,
  }) async {
    return const [];
  }

  @override
  Future<List<Task>> getAllPending({
    required String householdId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> save(Task task) async {
    if (shouldThrowOnSave) {
      throw Exception('Ошибка сети');
    }
    savedTask = task;
  }

  @override
  Future<void> addAllowedMember({
    required String taskId,
    required String memberId,
  }) async {}

  @override
  Future<void> removeAllowedMember({required String taskId, required String memberId}) async {}

  @override
  Future<void> patchStatus({required String taskId, required String status, String? completedByMemberId, String? completedAt, String? assignedMemberId}) async {
    if (shouldThrowOnSave) {
      throw Exception('Ошибка сети');
    }
    // Сохраняем точный статус (pending/completed/skipped), чтобы тесты
    // skipTask могли проверить TaskStatus.skipped.
    final mappedStatus = switch (status) {
      'completed' => TaskStatus.completed,
      'skipped' => TaskStatus.skipped,
      _ => TaskStatus.pending,
    };
    if (savedTask != null) {
      savedTask = savedTask!.copyWith(
        status: mappedStatus,
        assignedMemberId: assignedMemberId,
      );
    } else {
      // Фейковый task для тестов
      savedTask = Task(
        id: taskId,
        householdId: '',
        title: '',
        estimatedDurationMinutes: 0,
        plannedFor: DateTime.now(),
        allowedMemberIds: const [],
        status: mappedStatus,
        assignedMemberId: assignedMemberId,
        createdAt: DateTime.now(),
      );
    }
  }
}
