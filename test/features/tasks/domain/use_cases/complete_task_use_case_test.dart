import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/create_task_params.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/tasks/domain/use_cases/complete_task_use_case.dart';
import 'package:family_planner/features/tasks/domain/entities/update_recurring_task_params.dart';

void main() {
  late FakeTaskRepository repository;
  late CompleteTaskUseCase useCase;

  final completedAt = DateTime.utc(2026, 7, 20, 9, 30);

  Task createTask({
    List<String> allowedMemberIds = const ['member-1', 'member-2'],
    String? assignedMemberId,
    TaskStatus status = TaskStatus.pending,
  }) {
    return Task(
      id: 'task-1',
      householdId: 'household-1',
      title: 'Погулять с собакой',
      estimatedDurationMinutes: 30,
      plannedFor: DateTime.utc(2026, 7, 20),
      allowedMemberIds: allowedMemberIds,
      assignedMemberId: assignedMemberId,
      status: status,
      createdAt: DateTime.utc(2026, 7, 19, 12),
    );
  }

  setUp(() {
    repository = FakeTaskRepository();
    useCase = CompleteTaskUseCase(
      repository: repository,
      now: () => completedAt,
    );
  });

  group('CompleteTaskUseCase', () {
    test('отмечает допустимую невыполненную задачу выполненной', () async {
      final task = createTask();

      final completedTask = await useCase(task: task, memberId: 'member-1');

      expect(completedTask.status, TaskStatus.completed);
      expect(completedTask.completedAt, completedAt);
      expect(completedTask.assignedMemberId, 'member-1');
      // task-менеджмент теперь использует patchStatus (3 поля вместо 11)
      expect(repository.lastStatusPatched, 'completed');
      expect(repository.lastCompletedByPatched, 'member-1');
      expect(repository.lastCompletedAtPatched, completedAt.toUtc().toIso8601String());
      expect(repository.lastAssignedIdPatched, 'member-1');
    });

    test('не даёт выполнить задачу недопустимому участнику', () async {
      final task = createTask();

      await expectLater(
        () => useCase(task: task, memberId: 'member-3'),
        throwsA(isA<TaskCompletionNotAllowedException>()),
      );

      expect(repository.savedTasks, isEmpty);
    });

    test('не даёт выполнить задачу повторно', () async {
      final task = createTask(status: TaskStatus.completed);

      await expectLater(
        () => useCase(task: task, memberId: 'member-1'),
        throwsA(isA<TaskAlreadyCompletedException>()),
      );

      expect(repository.savedTasks, isEmpty);
    });

    test('сообщения исключений понятные', () {
      expect(
        const TaskAlreadyCompletedException().toString(),
        contains('TaskAlreadyCompletedException'),
      );
      expect(
        const TaskCompletionNotAllowedException(
          taskId: 'task-1',
          memberId: 'member-3',
        ).toString(),
        contains('TaskCompletionNotAllowedException'),
      );
    });
  });
}

final class FakeTaskRepository implements TaskRepository {
  @override
  Future<void> updateTemplate({
    required UpdateRecurringTaskParams params,
  }) async {}
  @override
  Future<void> pauseTemplate({required String templateId}) async {}

  @override
  Future<void> resumeTemplate({required String templateId}) async {}

  final List<Task> savedTasks = [];
  String? lastStatusPatched;
  String? lastCompletedByPatched;
  String? lastCompletedAtPatched;
  String? lastAssignedIdPatched;

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
    lastStatusPatched = status;
    lastCompletedByPatched = completedByMemberId;
    lastCompletedAtPatched = completedAt;
    lastAssignedIdPatched = assignedMemberId;
  }
}
