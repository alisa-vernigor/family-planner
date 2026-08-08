import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/tasks/domain/entities/create_task_params.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_recurrence.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:family_planner/features/tasks/domain/entities/update_recurring_task_params.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/tasks/domain/use_cases/create_task_use_case.dart';
import 'package:family_planner/features/tasks/domain/use_cases/update_task_use_case.dart';

void main() {
  final plannedFor = DateTime.utc(2026, 7, 19);

  final task = Task(
    id: 'task-1',
    householdId: 'household-1',
    title: '  Полить цветы  ',
    description: 'Кактус и фикус',
    estimatedDurationMinutes: 10,
    plannedFor: plannedFor,
    allowedMemberIds: const ['user-1'],
    status: TaskStatus.pending,
    createdAt: DateTime.utc(2026, 7, 19, 12),
    templateId: 'template-1',
    recurrence: const TaskRecurrence.daily(),
    recurrenceStartDate: plannedFor,
  );

  UpdateRecurringTaskParams params({TaskRecurrence? recurrence, DateTime? start, DateTime? end, Task? t}) {
    return UpdateRecurringTaskParams(
      task: t ?? task,
      recurrence: recurrence ?? const TaskRecurrence.weekly(weekdays: [1, 3, 5]),
      scope: RecurrenceEditScope.thisAndFollowing,
      recurrenceStartDate: start ?? plannedFor,
      recurrenceEndDate: end,
    );
  }

  test('передаёт params в репозиторий с обрезанным title', () async {
    final repository = FakeTaskRepository();
    final useCase = UpdateTaskUseCase(repository: repository);

    await useCase.updateRecurring(params: params());

    expect(repository.receivedParams, isNotNull);
    expect(repository.receivedParams!.task.title, 'Полить цветы');
    expect(repository.receivedParams!.scope, RecurrenceEditScope.thisAndFollowing);
  });

  test('выбрасывает исключение для пустого названия', () async {
    final repository = FakeTaskRepository();
    final useCase = UpdateTaskUseCase(repository: repository);

    expect(
      () => useCase.updateRecurring(
        params: params(
          t: task.copyWith(title: '   '),
        ),
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('выбрасывает TaskRecurrenceWeekdaysEmptyException для пустых дней недели', () async {
    final repository = FakeTaskRepository();
    final useCase = UpdateTaskUseCase(repository: repository);

    expect(
      () => useCase.updateRecurring(
        params: params(
          recurrence: const TaskRecurrence.weekly(weekdays: []),
        ),
      ),
      throwsA(isA<TaskRecurrenceWeekdaysEmptyException>()),
    );
  });

  test('выбрасывает TaskRecurrenceIntervalInvalidException для неверного интервала', () async {
    final repository = FakeTaskRepository();
    final useCase = UpdateTaskUseCase(repository: repository);

    expect(
      () => useCase.updateRecurring(
        params: params(
          recurrence: const TaskRecurrence.intervalDays(intervalDays: 0),
        ),
      ),
      throwsA(isA<TaskRecurrenceIntervalInvalidException>()),
    );
  });

  test('выбрасывает TaskRecurrenceDatesInvalidException когда end < start', () async {
    final repository = FakeTaskRepository();
    final useCase = UpdateTaskUseCase(repository: repository);

    expect(
      () => useCase.updateRecurring(
        params: params(
          start: DateTime.utc(2026, 7, 20),
          end: DateTime.utc(2026, 7, 19),
        ),
      ),
      throwsA(isA<TaskRecurrenceDatesInvalidException>()),
    );
  });

  test('передаёт только дату (без времени) в валидацию', () async {
    final repository = FakeTaskRepository();
    final useCase = UpdateTaskUseCase(repository: repository);

    await useCase.updateRecurring(
      params: params(
        start: DateTime.utc(2026, 7, 19, 23, 59),
        end: DateTime.utc(2026, 7, 20, 0, 1),
      ),
    );

    expect(repository.receivedParams, isNotNull);
  });
}

final class FakeTaskRepository implements TaskRepository {
  UpdateRecurringTaskParams? receivedParams;

  @override
  Future<void> updateTemplate({
    required UpdateRecurringTaskParams params,
  }) async {
    receivedParams = params;
  }
  @override
  Future<void> pauseTemplate({required String templateId}) async {}

  @override
  Future<void> resumeTemplate({required String templateId}) async {}

  @override
  Future<Task> create({required CreateTaskParams params}) async => taskStub;

  @override
  Future<void> delete({required String taskId}) async {}

  @override
  Future<List<Task>> getForDay({
    required String householdId,
    required DateTime day,
  }) async => [];

  @override
  Future<List<Task>> getScheduledAfter({
    required String householdId,
    required DateTime day,
  }) async => [];

  @override
  Future<void> save(Task task) async {}

  @override
  Future<List<Task>> getAllPending({
    required String householdId,
  }) async => [];

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

  @override
  Future<void> patchStatus({
    required String taskId,
    required String status,
    String? completedByMemberId,
    String? completedAt,
    String? assignedMemberId,
  }) async {}
}

final taskStub = Task(
  id: 'task-1',
  householdId: 'household-1',
  title: 'stub',
  estimatedDurationMinutes: 10,
  plannedFor: DateTime.utc(2026, 7, 19),
  allowedMemberIds: const ['user-1'],
  status: TaskStatus.pending,
  createdAt: DateTime.utc(2026, 7, 19, 12),
);
