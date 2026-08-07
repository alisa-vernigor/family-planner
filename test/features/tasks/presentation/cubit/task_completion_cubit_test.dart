import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:family_planner/features/tasks/domain/entities/create_task_params.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/tasks/domain/use_cases/complete_task_use_case.dart';
import 'package:family_planner/features/tasks/presentation/cubit/task_completion_cubit.dart';
import 'package:family_planner/features/tasks/presentation/cubit/task_completion_state.dart';
import 'package:family_planner/features/tasks/domain/entities/update_recurring_task_params.dart';

void main() {
  late FakeTaskRepository repository;
  late CompleteTaskUseCase completeTask;
  late TaskCompletionCubit cubit;

  final completedAt = DateTime.utc(2026, 7, 20, 10);

  final task = Task(
    id: 'task-1',
    householdId: 'household-1',
    title: 'Пропылесосить гостиную',
    estimatedDurationMinutes: 20,
    plannedFor: DateTime.utc(2026, 7, 20),
    allowedMemberIds: const ['member-1'],
    status: TaskStatus.pending,
    createdAt: DateTime.utc(2026, 7, 19, 12),
  );

  setUp(() {
    repository = FakeTaskRepository();
    completeTask = CompleteTaskUseCase(
      repository: repository,
      now: () => completedAt,
    );
    cubit = TaskCompletionCubit(completeTaskUseCase: completeTask);
  });

  tearDown(() async {
    await cubit.close();
  });

  blocTest<TaskCompletionCubit, TaskCompletionState>(
    'initial state должен быть TaskCompletionInitial',
    build: () => cubit,
    expect: () => const [],
  );

  blocTest<TaskCompletionCubit, TaskCompletionState>(
    'выдаёт InProgress и Success, когда задача успешно выполнена',
    build: () => cubit,
    act: (cubit) => cubit.completeTask(task: task, memberId: 'member-1'),
    expect: () => [
      const TaskCompletionInProgress(),
      TaskCompletionSuccess(
        task: task.copyWith(
          assignedMemberId: 'member-1',
          status: TaskStatus.completed,
          completedAt: completedAt,
        ),
      ),
    ],
    verify: (_) {
      expect(repository.savedTasks, hasLength(1));
    },
  );

  blocTest<TaskCompletionCubit, TaskCompletionState>(
    'выдаёт InProgress и Failure, когда участник не может выполнить задачу',
    build: () => cubit,
    act: (cubit) => cubit.completeTask(task: task, memberId: 'member-2'),
    expect: () => const [
      TaskCompletionInProgress(),
      TaskCompletionFailure(message: 'У вас нет права выполнить эту задачу.'),
    ],
    verify: (_) {
      expect(repository.savedTasks, isEmpty);
    },
  );

  blocTest<TaskCompletionCubit, TaskCompletionState>(
    'выдаёт Failure, когда задача уже выполнена',
    build: () => cubit,
    act: (cubit) => cubit.completeTask(
      task: task.copyWith(
        assignedMemberId: 'member-1',
        status: TaskStatus.completed,
        completedAt: completedAt,
      ),
      memberId: 'member-1',
    ),
    expect: () => const [
      TaskCompletionInProgress(),
      TaskCompletionFailure(message: 'Эта задача уже была выполнена.'),
    ],
  );

  blocTest<TaskCompletionCubit, TaskCompletionState>(
    'выдаёт Failure при неожиданной ошибке репозитория',
    build: () {
      final repository = FakeTaskRepository(shouldThrowOnSave: true);
      final useCase = CompleteTaskUseCase(
        repository: repository,
        now: () => completedAt,
      );
      return TaskCompletionCubit(completeTaskUseCase: useCase);
    },
    act: (cubit) => cubit.completeTask(task: task, memberId: 'member-1'),
    expect: () => const [
      TaskCompletionInProgress(),
      TaskCompletionFailure(
        message: 'Не удалось отметить задачу выполненной.',
      ),
    ],
  );

  blocTest<TaskCompletionCubit, TaskCompletionState>(
    'reset() возвращает в TaskCompletionInitial после успешного выполнения',
    build: () => cubit,
    act: (cubit) async {
      await cubit.completeTask(task: task, memberId: 'member-1');
      cubit.reset();
    },
    expect: () => [
      const TaskCompletionInProgress(),
      TaskCompletionSuccess(
        task: task.copyWith(
          assignedMemberId: 'member-1',
          status: TaskStatus.completed,
          completedAt: completedAt,
        ),
      ),
      const TaskCompletionInitial(),
    ],
    verify: (_) {
      expect(cubit.state, const TaskCompletionInitial());
    },
  );

  blocTest<TaskCompletionCubit, TaskCompletionState>(
    'reset() возвращает в TaskCompletionInitial после Failure',
    build: () => cubit,
    act: (cubit) async {
      await cubit.completeTask(
        task: task.copyWith(
          assignedMemberId: 'member-1',
          status: TaskStatus.completed,
          completedAt: completedAt,
        ),
        memberId: 'member-1',
      );
      cubit.reset();
    },
    expect: () => const [
      TaskCompletionInProgress(),
      TaskCompletionFailure(message: 'Эта задача уже была выполнена.'),
      TaskCompletionInitial(),
    ],
    verify: (_) {
      expect(cubit.state, const TaskCompletionInitial());
    },
  );
}

final class FakeTaskRepository implements TaskRepository {
  @override
  Future<void> updateTemplate({
    required UpdateRecurringTaskParams params,
  }) async {}

  FakeTaskRepository({this.shouldThrowOnSave = false});

  final bool shouldThrowOnSave;
  final List<Task> savedTasks = [];

  @override
  Future<void> delete({required String taskId}) async {}

  @override
  Future<List<Task>> getScheduledAfter({
    required String householdId,
    required DateTime day,
  }) async {
    return const [];
  }

  @override
  Future<List<Task>> getForDay({
    required String householdId,
    required DateTime day,
  }) async {
    return const [];
  }

  @override
  Future<Task> create({required CreateTaskParams params}) {
    throw UnimplementedError();
  }

  @override
  Future<void> save(Task task) async {
    if (shouldThrowOnSave) {
      throw Exception('Ошибка сети');
    }
    savedTasks.add(task);
  }

  @override
  Future<List<Task>> getAllPending({
    required String householdId,
  }) async {
    throw UnimplementedError();
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
    // Record for test assertions (complete use case now uses patchStatus)
    savedTasks.add(Task(
      id: taskId,
      householdId: '',
      title: '',
      estimatedDurationMinutes: 0,
      plannedFor: DateTime.now(),
      allowedMemberIds: const [],
      status: status == 'completed' ? TaskStatus.completed : TaskStatus.pending,
      assignedMemberId: assignedMemberId,
      completedAt: completedAt != null ? DateTime.parse(completedAt) : null,
      createdAt: DateTime.now(),
    ));
  }
}
