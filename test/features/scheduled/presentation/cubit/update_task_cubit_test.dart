import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/tasks/domain/entities/create_task_params.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/tasks/domain/use_cases/update_task_use_case.dart';
import 'package:family_planner/features/tasks/presentation/cubit/update_task_cubit.dart';
import 'package:family_planner/features/tasks/presentation/cubit/update_task_state.dart';

void main() {
  final task = Task(
    id: 'task-1',
    householdId: 'household-1',
    title: 'Купить продукты',
    estimatedDurationMinutes: 30,
    plannedFor: DateTime(2026, 7, 22),
    deadline: DateTime(2026, 7, 22, 18),
    allowedMemberIds: const ['member-1'],
    status: TaskStatus.pending,
    createdAt: DateTime(2026, 7, 19),
  );

  test('сохраняет изменения и возвращает состояние успеха', () async {
    final repository = _FakeTaskRepository();

    final cubit = UpdateTaskCubit(
      updateTaskUseCase: UpdateTaskUseCase(repository: repository),
    );
    addTearDown(cubit.close);

    final editedTask = task.copyWith(
      title: 'Купить продукты для ужина',
      estimatedDurationMinutes: 45,
    );

    await cubit.update(task: editedTask);

    expect(cubit.state, UpdateTaskSuccess(task: editedTask));
    expect(repository.savedTask, isNotNull);
    expect(repository.savedTask!.title, 'Купить продукты для ужина');
    expect(repository.savedTask!.estimatedDurationMinutes, 45);
  });

  test('показывает ошибку, когда репозиторий не сохранил задачу', () async {
    final cubit = UpdateTaskCubit(
      updateTaskUseCase: UpdateTaskUseCase(
        repository: _FakeTaskRepository(shouldThrowOnSave: true),
      ),
    );
    addTearDown(cubit.close);

    await cubit.update(task: task);

    expect(
      cubit.state,
      const UpdateTaskFailure(
        message: 'Не удалось сохранить изменения задачи.',
      ),
    );
  });
}

final class _FakeTaskRepository implements TaskRepository {
  _FakeTaskRepository({this.shouldThrowOnSave = false});

  final bool shouldThrowOnSave;

  Task? savedTask;

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
}
