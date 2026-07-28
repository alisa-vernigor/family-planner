import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/create_task_params.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/tasks/domain/use_cases/get_tasks_for_day_use_case.dart';

void main() {
  late FakeTaskRepository repository;
  late GetTasksForDayUseCase useCase;

  final day = DateTime.utc(2026, 7, 20);

  final tasks = [
    Task(
      id: 'task-1',
      householdId: 'household-1',
      title: 'Покормить кота',
      estimatedDurationMinutes: 5,
      plannedFor: day,
      allowedMemberIds: const ['member-1'],
      status: TaskStatus.pending,
      createdAt: DateTime.utc(2026, 7, 19, 12),
    ),
  ];

  setUp(() {
    repository = FakeTaskRepository(tasksToReturn: tasks);
    useCase = GetTasksForDayUseCase(repository: repository);
  });

  test('возвращает задачи семьи за выбранный день', () async {
    final result = await useCase(householdId: 'household-1', day: day);

    expect(result, tasks);
    expect(repository.requestedHouseholdId, 'household-1');
    expect(repository.requestedDay, day);
  });

  test('возвращает пустой список, если на день нет задач', () async {
    repository = FakeTaskRepository(tasksToReturn: const []);
    useCase = GetTasksForDayUseCase(repository: repository);

    final result = await useCase(householdId: 'household-1', day: day);

    expect(result, isEmpty);
  });
}

final class FakeTaskRepository implements TaskRepository {
  FakeTaskRepository({required this.tasksToReturn});

  final List<Task> tasksToReturn;
  String? requestedHouseholdId;
  DateTime? requestedDay;

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
  Future<Task> create({required CreateTaskParams params}) {
    throw UnimplementedError();
  }

  @override
  Future<List<Task>> getForDay({
    required String householdId,
    required DateTime day,
  }) async {
    requestedHouseholdId = householdId;
    requestedDay = day;

    return tasksToReturn;
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
  Future<void> patchStatus({required String taskId, required String status, String? completedByMemberId, String? completedAt, String? assignedMemberId}) async {}
}
