import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/tasks/domain/entities/create_task_params.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_recurrence.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:family_planner/features/tasks/domain/entities/update_recurring_task_params.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/tasks/domain/use_cases/update_task_use_case.dart';

void main() {
  final plannedFor = DateTime.utc(2026, 7, 19);

  Task makeTask({
    String title = '  Полить цветы  ',
    String? description = '  Кактус и фикус  ',
    int estimatedDurationMinutes = 10,
    TaskStatus status = TaskStatus.pending,
    String? templateId,
    TaskRecurrence? recurrence,
  }) {
    return Task(
      id: 'task-1',
      householdId: 'household-1',
      title: title,
      description: description,
      estimatedDurationMinutes: estimatedDurationMinutes,
      plannedFor: plannedFor,
      allowedMemberIds: const ['user-1'],
      status: status,
      createdAt: DateTime.utc(2026, 7, 19, 12),
      templateId: templateId,
      recurrence: recurrence,
    );
  }

  group('UpdateTaskUseCase.call', () {
    test('обрезает title и пустой description, сохраняет через repository', () async {
      final repository = FakeTaskRepository();
      final useCase = UpdateTaskUseCase(repository: repository);

      await useCase(task: makeTask());

      expect(repository.savedTask, isNotNull);
      expect(repository.savedTask!.title, 'Полить цветы');
      expect(repository.savedTask!.description, 'Кактус и фикус');
    });

    test('сбрасывает description в null, если он пустой/пробелы', () async {
      final repository = FakeTaskRepository();
      final useCase = UpdateTaskUseCase(repository: repository);

      await useCase(task: makeTask(description: '   '));

      expect(repository.savedTask!.description, isNull);
    });

    test('сохраняет описание и когда оно null', () async {
      final repository = FakeTaskRepository();
      final useCase = UpdateTaskUseCase(repository: repository);

      await useCase(task: makeTask(description: null));

      expect(repository.savedTask!.description, isNull);
    });

    test('выбрасывает ArgumentError при пустом названии', () async {
      final repository = FakeTaskRepository();
      final useCase = UpdateTaskUseCase(repository: repository);

      expect(
        () => useCase(task: makeTask(title: '   ')),
        throwsA(isA<ArgumentError>()),
      );
      expect(repository.savedTask, isNull);
    });

    test('выбрасывает ArgumentError при неположительной длительности', () async {
      final repository = FakeTaskRepository();
      final useCase = UpdateTaskUseCase(repository: repository);

      expect(
        () => useCase(task: makeTask(estimatedDurationMinutes: 0)),
        throwsA(isA<ArgumentError>()),
      );
      expect(repository.savedTask, isNull);
    });
  });

  group('UpdateTaskUseCase.updateRecurring — валидация', () {
    UpdateRecurringTaskParams params({
      Task? t,
      TaskRecurrence? recurrence,
      DateTime? start,
      DateTime? end,
    }) {
      return UpdateRecurringTaskParams(
        task: t ?? makeTask(templateId: 'tmpl-1', recurrence: const TaskRecurrence.daily()),
        recurrence: recurrence ?? const TaskRecurrence.weekly(weekdays: [1, 3, 5]),
        scope: RecurrenceEditScope.thisAndFollowing,
        recurrenceStartDate: start ?? plannedFor,
        recurrenceEndDate: end,
      );
    }

    test('выбрасывает ArgumentError при неположительной длительности', () async {
      final repository = FakeTaskRepository();
      final useCase = UpdateTaskUseCase(repository: repository);

      expect(
        () => useCase.updateRecurring(
          params: params(
            t: makeTask(
              title: 'Серия',
              estimatedDurationMinutes: 0,
              templateId: 'tmpl-1',
              recurrence: const TaskRecurrence.daily(),
            ),
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(repository.receivedParams, isNull);
    });
  });
}

final class FakeTaskRepository implements TaskRepository {
  Task? savedTask;
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
  Future<Task> create({required CreateTaskParams params}) async => throw UnimplementedError();

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
  Future<void> save(Task task) async {
    savedTask = task;
  }

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
