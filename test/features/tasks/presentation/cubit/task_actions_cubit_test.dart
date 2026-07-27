import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/tasks/domain/entities/create_task_params.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/tasks/domain/use_cases/delete_task_use_case.dart';
import 'package:family_planner/features/tasks/domain/use_cases/uncomplete_task_use_case.dart';
import 'package:family_planner/features/tasks/presentation/cubit/task_actions_cubit.dart';
import 'package:family_planner/features/tasks/presentation/cubit/task_completion_state.dart';

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
      deleteTaskUseCase: DeleteTaskUseCase(repository: repository),
    );
  });

  tearDown(() async {
    await cubit.close();
  });

  blocTest<TaskActionsCubit, TaskCompletionState>(
    'uncompleteTask возвращает задачу и переводит в Initial',
    build: () => cubit,
    act: (cubit) => cubit.uncompleteTask(task: task),
    expect: () => const [
      TaskCompletionInProgress(),
      TaskCompletionInitial(),
    ],
    verify: (_) {
      expect(repository.savedTask, isNotNull);
      expect(repository.savedTask!.status, TaskStatus.pending);
    },
  );

  blocTest<TaskActionsCubit, TaskCompletionState>(
    'uncompleteTask возвращает null и Failure для невыполненной задачи',
    build: () {
      final repository = _FakeTaskRepository();
      return TaskActionsCubit(
        uncompleteTaskUseCase: UncompleteTaskUseCase(repository: repository),
        deleteTaskUseCase: DeleteTaskUseCase(repository: repository),
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
      TaskCompletionInProgress(),
      TaskCompletionFailure(message: 'Не удалось отменить выполнение.'),
    ],
    verify: (_) {
      expect(repository.savedTask, isNull);
    },
  );

  blocTest<TaskActionsCubit, TaskCompletionState>(
    'deleteTask удаляет задачу и переводит в Initial',
    build: () => cubit,
    act: (cubit) => cubit.deleteTask(taskId: 'task-1'),
    expect: () => const [
      TaskCompletionInProgress(),
      TaskCompletionInitial(),
    ],
    verify: (_) {
      expect(repository.deletedTaskId, 'task-1');
    },
  );

  blocTest<TaskActionsCubit, TaskCompletionState>(
    'deleteTask возвращает false и Failure при ошибке репозитория',
    build: () {
      final repository = _FakeTaskRepository(shouldThrowOnDelete: true);
      return TaskActionsCubit(
        uncompleteTaskUseCase: UncompleteTaskUseCase(repository: repository),
        deleteTaskUseCase: DeleteTaskUseCase(repository: repository),
      );
    },
    act: (cubit) => cubit.deleteTask(taskId: 'task-1'),
    expect: () => const [
      TaskCompletionInProgress(),
      TaskCompletionFailure(message: 'Не удалось удалить задачу.'),
    ],
  );
}

final class _FakeTaskRepository implements TaskRepository {
  _FakeTaskRepository({this.shouldThrowOnDelete = false});

  final bool shouldThrowOnDelete;

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
    savedTask = task;
  }

  @override
  Future<void> addAllowedMember({
    required String taskId,
    required String memberId,
  }) async {}

  @override
  Future<void> removeAllowedMember({
    required String taskId,
    required String memberId,
  }) async {}
}
