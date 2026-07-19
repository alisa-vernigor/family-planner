import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/tasks/domain/entities/create_task_params.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/tasks/domain/use_cases/create_task_use_case.dart';

void main() {
  final plannedFor = DateTime.utc(2026, 7, 19);

  final params = CreateTaskParams(
    householdId: 'household-1',
    title: '  Купить продукты  ',
    description: '  Молоко и хлеб  ',
    estimatedDurationMinutes: 30,
    plannedFor: plannedFor,
  );

  final createdTask = Task(
    id: 'task-1',
    householdId: 'household-1',
    title: 'Купить продукты',
    description: 'Молоко и хлеб',
    estimatedDurationMinutes: 30,
    plannedFor: plannedFor,
    allowedMemberIds: const ['user-1'],
    status: TaskStatus.pending,
    createdAt: DateTime.utc(2026, 7, 19, 12),
  );

  test('очищает title и description перед передачей в репозиторий', () async {
    final repository = FakeTaskRepository(taskToCreate: createdTask);
    final useCase = CreateTaskUseCase(repository: repository);

    await useCase(params: params);

    expect(
      repository.receivedParams,
      CreateTaskParams(
        householdId: 'household-1',
        title: 'Купить продукты',
        description: 'Молоко и хлеб',
        estimatedDurationMinutes: 30,
        plannedFor: plannedFor,
      ),
    );
  });

  test('выбрасывает исключение для пустого названия', () async {
    final repository = FakeTaskRepository(taskToCreate: createdTask);
    final useCase = CreateTaskUseCase(repository: repository);

    expect(
      () => useCase(
        params: CreateTaskParams(
          householdId: 'household-1',
          title: '   ',
          estimatedDurationMinutes: 30,
          plannedFor: plannedFor,
        ),
      ),
      throwsA(isA<TaskTitleEmptyException>()),
    );
  });

  test('выбрасывает исключение для нулевой длительности', () async {
    final repository = FakeTaskRepository(taskToCreate: createdTask);
    final useCase = CreateTaskUseCase(repository: repository);

    expect(
      () => useCase(
        params: CreateTaskParams(
          householdId: 'household-1',
          title: 'Купить продукты',
          estimatedDurationMinutes: 0,
          plannedFor: plannedFor,
        ),
      ),
      throwsA(isA<TaskDurationInvalidException>()),
    );
  });
}

final class FakeTaskRepository implements TaskRepository {
  FakeTaskRepository({required this.taskToCreate});

  final Task taskToCreate;
  CreateTaskParams? receivedParams;

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
    receivedParams = params;
    return taskToCreate;
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
