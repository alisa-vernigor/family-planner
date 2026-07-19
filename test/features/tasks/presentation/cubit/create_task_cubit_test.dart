import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/tasks/domain/entities/create_task_params.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/tasks/domain/use_cases/create_task_use_case.dart';
import 'package:family_planner/features/tasks/presentation/cubit/create_task_cubit.dart';
import 'package:family_planner/features/tasks/presentation/cubit/create_task_state.dart';

void main() {
  final plannedFor = DateTime.utc(2026, 7, 19);

  final params = CreateTaskParams(
    householdId: 'household-1',
    title: 'Купить продукты',
    estimatedDurationMinutes: 30,
    plannedFor: plannedFor,
  );

  final task = Task(
    id: 'task-1',
    householdId: 'household-1',
    title: 'Купить продукты',
    estimatedDurationMinutes: 30,
    plannedFor: plannedFor,
    allowedMemberIds: const ['user-1'],
    status: TaskStatus.pending,
    createdAt: DateTime.utc(2026, 7, 19, 12),
  );

  CreateTaskCubit createCubit({Task? createdTask, Object? exception}) {
    final repository = FakeTaskRepository(
      createdTask: createdTask,
      exception: exception,
    );

    return CreateTaskCubit(
      createTaskUseCase: CreateTaskUseCase(repository: repository),
    );
  }

  blocTest<CreateTaskCubit, CreateTaskState>(
    'выдаёт InProgress и Success после успешного создания',
    build: () => createCubit(createdTask: task),
    act: (cubit) => cubit.create(params: params),
    expect: () => [const CreateTaskInProgress(), CreateTaskSuccess(task: task)],
  );

  blocTest<CreateTaskCubit, CreateTaskState>(
    'выдаёт InProgress и Failure при ошибке репозитория',
    build: () => createCubit(exception: Exception('Нет подключения')),
    act: (cubit) => cubit.create(params: params),
    expect: () => const [
      CreateTaskInProgress(),
      CreateTaskFailure(message: 'Не удалось создать задачу.'),
    ],
  );
}

final class FakeTaskRepository implements TaskRepository {
  FakeTaskRepository({this.createdTask, this.exception});

  final Task? createdTask;
  final Object? exception;

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
  Future<Task> create({required CreateTaskParams params}) async {
    if (exception != null) {
      throw exception!;
    }

    if (createdTask == null) {
      throw StateError('Для теста не задана создаваемая задача.');
    }

    return createdTask!;
  }

  @override
  Future<List<Task>> getForDay({
    required String householdId,
    required DateTime day,
  }) async {
    return const [];
  }

  @override
  Future<void> save(Task task) async {}
}
