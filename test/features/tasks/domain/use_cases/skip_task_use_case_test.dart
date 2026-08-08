import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/create_task_params.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/tasks/domain/use_cases/skip_task_use_case.dart';
import 'package:family_planner/features/tasks/domain/entities/update_recurring_task_params.dart';

void main() {
  late FakeTaskRepository repository;
  late SkipTaskUseCase useCase;

  Task createTask({
    TaskStatus status = TaskStatus.pending,
  }) {
    return Task(
      id: 'task-1',
      householdId: 'household-1',
      title: 'Помыть окна',
      estimatedDurationMinutes: 30,
      plannedFor: DateTime.utc(2026, 7, 20),
      allowedMemberIds: const ['member-1', 'member-2'],
      assignedMemberId: 'member-1',
      status: status,
      createdAt: DateTime.utc(2026, 7, 19, 12),
    );
  }

  setUp(() {
    repository = FakeTaskRepository();
    useCase = SkipTaskUseCase(repository: repository);
  });

  group('SkipTaskUseCase', () {
    test('помечает невыполненную задачу как пропущенную', () async {
      final task = createTask();

      final skippedTask = await useCase(task: task);

      expect(skippedTask.status, TaskStatus.skipped);
      expect(skippedTask.id, task.id);
      // patchStatus (3 поля) — не save
      expect(repository.lastStatusPatched, 'skipped');
    });

    test('не даёт пропустить уже пропущенную задачу', () async {
      final task = createTask(status: TaskStatus.skipped);

      await expectLater(
        () => useCase(task: task),
        throwsA(isA<TaskAlreadySkippedException>()),
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

  String? lastStatusPatched;

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
  Future<void> save(Task task) async {}

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
  }
}
