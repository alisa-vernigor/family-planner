import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/tasks/domain/entities/create_task_params.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_recurrence.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/tasks/domain/use_cases/update_task_use_case.dart';
import 'package:family_planner/features/tasks/presentation/cubit/update_task_cubit.dart';
import 'package:family_planner/features/tasks/presentation/cubit/update_task_state.dart';
import 'package:family_planner/features/tasks/domain/entities/update_recurring_task_params.dart';

void main() {
  final task = Task(
    id: 'task-1',
    householdId: 'household-1',
    title: 'Купить продукты',
    estimatedDurationMinutes: 30,
    plannedFor: DateTime(2026, 7, 22),
    allowedMemberIds: const ['member-1'],
    status: TaskStatus.pending,
    createdAt: DateTime(2026, 7, 19),
  );

  group('UpdateTaskCubit', () {
    late UpdateTaskCubit cubit;
    late TaskRepository repository;

    setUp(() {
      repository = _FakeTaskRepository();
      cubit = UpdateTaskCubit(
        updateTaskUseCase: UpdateTaskUseCase(repository: repository),
      );
    });

    tearDown(() async {
      await cubit.close();
    });

    blocTest<UpdateTaskCubit, UpdateTaskState>(
      'initial state is UpdateTaskInitial',
      build: () => cubit,
      verify: (cubit) {
        expect(cubit.state, const UpdateTaskInitial());
      },
    );

    blocTest<UpdateTaskCubit, UpdateTaskState>(
      'emits [UpdateTaskInProgress, UpdateTaskSuccess] on success',
      build: () => cubit,
      act: (cubit) => cubit.update(task: task),
      expect: () => [
        const UpdateTaskInProgress(),
        UpdateTaskSuccess(task: task),
      ],
    );

    blocTest<UpdateTaskCubit, UpdateTaskState>(
      'emits [UpdateTaskInProgress, UpdateTaskFailure] on exception',
      build: () {
        final repository = _FakeTaskRepository(shouldThrowOnSave: true);
        return UpdateTaskCubit(
          updateTaskUseCase: UpdateTaskUseCase(repository: repository),
        );
      },
      act: (cubit) => cubit.update(task: task),
      expect: () => const [
        UpdateTaskInProgress(),
        UpdateTaskFailure(message: 'Не удалось сохранить изменения задачи.'),
      ],
    );

    blocTest<UpdateTaskCubit, UpdateTaskState>(
      'reset() returns to UpdateTaskInitial from any state',
      build: () => cubit,
      seed: () => UpdateTaskSuccess(task: task),
      act: (cubit) => cubit.reset(),
      expect: () => [const UpdateTaskInitial()],
    );

    blocTest<UpdateTaskCubit, UpdateTaskState>(
      'updateTemplate emits [InProgress, Success] and calls repository',
      build: () => cubit,
      act: (cubit) => cubit.updateTemplate(
        params: UpdateRecurringTaskParams(
          task: task,
          recurrence: const TaskRecurrence.weekly(weekdays: [1, 3, 5]),
          scope: RecurrenceEditScope.thisAndFollowing,
          recurrenceStartDate: DateTime(2026, 7, 22),
        ),
      ),
      expect: () => [
        const UpdateTaskInProgress(),
        UpdateTaskSuccess(task: task),
      ],
      verify: (_) {
        expect(
          (repository as _FakeTaskRepository).updateTemplateCalls,
          1,
        );
      },
    );

    blocTest<UpdateTaskCubit, UpdateTaskState>(
      'updateTemplate emits [InProgress, Failure] on exception',
      build: () {
        final repo = _FakeTaskRepository(shouldThrowOnUpdateTemplate: true);
        return UpdateTaskCubit(
          updateTaskUseCase: UpdateTaskUseCase(repository: repo),
        );
      },
      act: (cubit) => cubit.updateTemplate(
        params: UpdateRecurringTaskParams(
          task: task,
          recurrence: const TaskRecurrence.daily(),
          scope: RecurrenceEditScope.all,
          recurrenceStartDate: DateTime(2026, 7, 22),
        ),
      ),
      expect: () => const [
        UpdateTaskInProgress(),
        UpdateTaskFailure(
          message: 'Не удалось сохранить изменения повторяющейся задачи.',
        ),
      ],
    );
  });
}

final class _FakeTaskRepository implements TaskRepository {
  _FakeTaskRepository({
    this.shouldThrowOnSave = false,
    this.shouldThrowOnUpdateTemplate = false,
  });

  final bool shouldThrowOnSave;
  final bool shouldThrowOnUpdateTemplate;

  Task? savedTask;
  int updateTemplateCalls = 0;

  @override
  Future<void> updateTemplate({
    required UpdateRecurringTaskParams params,
  }) async {
    updateTemplateCalls++;
    if (shouldThrowOnUpdateTemplate) {
      throw Exception('Ошибка сети');
    }
  }

  @override
  Future<Task> create({required CreateTaskParams params}) {
    throw UnimplementedError();
  }

  @override
  Future<void> delete({required String taskId}) async {}

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
  Future<void> save(Task task) async {
    if (shouldThrowOnSave) {
      throw Exception('Ошибка сети');
    }

    savedTask = task;
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
    // Complete/Uncomplete use cases call patchStatus instead of save now
    // Record it for test assertions
  }
}
