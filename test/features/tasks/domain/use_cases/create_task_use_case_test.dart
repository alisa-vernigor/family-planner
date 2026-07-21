import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/tasks/domain/entities/create_task_params.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/tasks/domain/use_cases/create_task_use_case.dart';
import 'package:family_planner/features/tasks/domain/entities/task_recurrence.dart';

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

  test('принимает дату окончания, равную дате начала повторения', () async {
    final repository = FakeTaskRepository(taskToCreate: createdTask);
    final useCase = CreateTaskUseCase(repository: repository);

    final startDate = DateTime.utc(2026, 7, 22);

    await useCase(
      params: CreateTaskParams(
        householdId: 'household-1',
        title: 'Полить цветы',
        estimatedDurationMinutes: 10,
        plannedFor: plannedFor,
        recurrence: const TaskRecurrence.daily(),
        recurrenceStartDate: startDate,
        recurrenceEndDate: startDate,
      ),
    );

    expect(repository.receivedParams!.recurrenceStartDate, startDate);
    expect(repository.receivedParams!.recurrenceEndDate, startDate);
  });

  test('не принимает окончание повторения раньше начала', () {
    final repository = FakeTaskRepository(taskToCreate: createdTask);
    final useCase = CreateTaskUseCase(repository: repository);

    expect(
      () => useCase(
        params: CreateTaskParams(
          householdId: 'household-1',
          title: 'Полить цветы',
          estimatedDurationMinutes: 10,
          plannedFor: plannedFor,
          recurrence: const TaskRecurrence.daily(),
          recurrenceStartDate: DateTime.utc(2026, 7, 25),
          recurrenceEndDate: DateTime.utc(2026, 7, 24),
        ),
      ),
      throwsA(isA<TaskRecurrenceDatesInvalidException>()),
    );
  });

  test('передаёт ежедневное повторение в репозиторий', () async {
    final repository = FakeTaskRepository(taskToCreate: createdTask);
    final useCase = CreateTaskUseCase(repository: repository);

    const recurrence = TaskRecurrence.daily();

    await useCase(
      params: CreateTaskParams(
        householdId: 'household-1',
        title: 'Полить цветы',
        estimatedDurationMinutes: 10,
        plannedFor: plannedFor,
        recurrence: recurrence,
      ),
    );

    expect(repository.receivedParams!.recurrence, recurrence);
    expect(repository.receivedParams!.isRecurring, isTrue);
  });

  test('передаёт еженедельное повторение с днями недели', () async {
    final repository = FakeTaskRepository(taskToCreate: createdTask);
    final useCase = CreateTaskUseCase(repository: repository);

    const recurrence = TaskRecurrence.weekly(weekdays: [1, 3, 5]);

    await useCase(
      params: CreateTaskParams(
        householdId: 'household-1',
        title: 'Тренировка',
        estimatedDurationMinutes: 45,
        plannedFor: plannedFor,
        recurrence: recurrence,
      ),
    );

    expect(repository.receivedParams!.recurrence, recurrence);
  });

  test('не принимает еженедельное повторение без дней', () async {
    final repository = FakeTaskRepository(taskToCreate: createdTask);
    final useCase = CreateTaskUseCase(repository: repository);

    expect(
      () => useCase(
        params: CreateTaskParams(
          householdId: 'household-1',
          title: 'Уборка',
          estimatedDurationMinutes: 30,
          plannedFor: plannedFor,
          recurrence: const TaskRecurrence.weekly(weekdays: []),
        ),
      ),
      throwsA(isA<TaskRecurrenceWeekdaysEmptyException>()),
    );
  });

  test('не принимает интервал повторения, равный нулю', () async {
    final repository = FakeTaskRepository(taskToCreate: createdTask);
    final useCase = CreateTaskUseCase(repository: repository);

    expect(
      () => useCase(
        params: CreateTaskParams(
          householdId: 'household-1',
          title: 'Проверить почту',
          estimatedDurationMinutes: 5,
          plannedFor: plannedFor,
          recurrence: const TaskRecurrence.intervalDays(intervalDays: 0),
        ),
      ),
      throwsA(isA<TaskRecurrenceIntervalInvalidException>()),
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
