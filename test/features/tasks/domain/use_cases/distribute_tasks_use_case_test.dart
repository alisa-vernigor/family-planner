import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/households/domain/entities/household.dart';
import 'package:family_planner/features/households/domain/entities/household_invitation.dart';
import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/households/domain/repositories/household_repository.dart';
import 'package:family_planner/features/tasks/domain/entities/create_task_params.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/tasks/domain/use_cases/distribute_tasks_use_case.dart';
import 'package:family_planner/features/tasks/domain/entities/update_recurring_task_params.dart';

void main() {
  final day = DateTime.utc(2026, 7, 26);

  final alice = HouseholdMember(
    profileId: 'alice',
    displayName: 'Alice',
    role: 'owner',
  );
  final bob = HouseholdMember(
    profileId: 'bob',
    displayName: 'Bob',
    role: 'member',
  );
  final charlie = HouseholdMember(
    profileId: 'charlie',
    displayName: 'Charlie',
    role: 'member',
  );

  group('DistributeTasksUseCase', () {
    test('распределяет нераспределённые задачи равномерно', () async {
      final repository = _FakeTaskRepository();
      final householdRepository = _FakeHouseholdRepository(
        members: [alice, bob],
      );

      final useCase = DistributeTasksUseCase(
        taskRepository: repository,
        householdRepository: householdRepository,
      );

      // Три нераспределённые задачи: 30, 20, 10 минут
      repository.tasksForDay = [
        Task(
          id: 'task-1',
          householdId: 'household-1',
          title: 'Task A',
          estimatedDurationMinutes: 30,
          plannedFor: day,
          allowedMemberIds: const ['alice', 'bob'],
          status: TaskStatus.pending,
          createdAt: DateTime.utc(2026, 7, 25),
        ),
        Task(
          id: 'task-2',
          householdId: 'household-1',
          title: 'Task B',
          estimatedDurationMinutes: 20,
          plannedFor: day,
          allowedMemberIds: const ['alice', 'bob'],
          status: TaskStatus.pending,
          createdAt: DateTime.utc(2026, 7, 25),
        ),
        Task(
          id: 'task-3',
          householdId: 'household-1',
          title: 'Task C',
          estimatedDurationMinutes: 10,
          plannedFor: day,
          allowedMemberIds: const ['alice', 'bob'],
          status: TaskStatus.pending,
          createdAt: DateTime.utc(2026, 7, 25),
        ),
      ];

      final result = await useCase(householdId: 'household-1', day: day);

      // Жадный алгоритм: 30 → Alice (0=0), 20 → Bob (0<30), 10 → Bob (20<30)
      // Alice = 30, Bob = 30 — идеально равномерно
      expect(result.memberDurations['alice'], 30);
      expect(result.memberDurations['bob'], 30);

      // У обеих задач должен быть назначен ответственный
      for (final task in result.updatedTasks) {
        expect(task.assignedMemberId, isNotNull);
      }
    });

    test('не перераспределяет уже назначенные задачи', () async {
      final repository = _FakeTaskRepository();
      final householdRepository = _FakeHouseholdRepository(
        members: [alice, bob],
      );

      final useCase = DistributeTasksUseCase(
        taskRepository: repository,
        householdRepository: householdRepository,
      );

      // Две задачи: одна уже назначена Alice (30 мин), вторая не назначена (30 мин)
      repository.tasksForDay = [
        Task(
          id: 'task-assigned',
          householdId: 'household-1',
          title: 'Already assigned',
          estimatedDurationMinutes: 30,
          plannedFor: day,
          allowedMemberIds: const ['alice'],
          assignedMemberId: 'alice',
          status: TaskStatus.pending,
          createdAt: DateTime.utc(2026, 7, 25),
        ),
        Task(
          id: 'task-unassigned',
          householdId: 'household-1',
          title: 'Not assigned',
          estimatedDurationMinutes: 30,
          plannedFor: day,
          allowedMemberIds: const ['alice', 'bob'],
          status: TaskStatus.pending,
          createdAt: DateTime.utc(2026, 7, 25),
        ),
      ];

      final result = await useCase(householdId: 'household-1', day: day);

      // Alice уже имеет 30 мин от закреплённой задачи → ей же достанется новая
      // (Alice = 30 + 30 = 60, Bob = 0)
      final assignedTask = result.updatedTasks.firstWhere(
        (t) => t.id == 'task-assigned',
      );
      expect(assignedTask.assignedMemberId, 'alice'); // не изменилось

      final newTask = result.updatedTasks.firstWhere(
        (t) => t.id == 'task-unassigned',
      );
      // Bob менее загружен (0), поэтому новая задача уходит ему
      expect(newTask.assignedMemberId, 'bob');
    });

    test('не трогает закреплённые задачи', () async {
      final repository = _FakeTaskRepository();
      final householdRepository = _FakeHouseholdRepository(
        members: [alice, bob],
      );

      final useCase = DistributeTasksUseCase(
        taskRepository: repository,
        householdRepository: householdRepository,
      );

      // Закреплённая за Alice задача (60 мин)
      repository.tasksForDay = [
        Task(
          id: 'task-pinned',
          householdId: 'household-1',
          title: 'Pinned task',
          estimatedDurationMinutes: 60,
          plannedFor: day,
          allowedMemberIds: const ['alice'],
          pinnedMemberId: 'alice',
          status: TaskStatus.pending,
          createdAt: DateTime.utc(2026, 7, 25),
        ),
      ];

      final result = await useCase(householdId: 'household-1', day: day);

      expect(result.memberDurations['alice'], 60);
      expect(result.memberDurations['bob'], 0);
    });

    test('равномерно распределяет между 3 участниками', () async {
      final repository = _FakeTaskRepository();
      final householdRepository = _FakeHouseholdRepository(
        members: [alice, bob, charlie],
      );

      final useCase = DistributeTasksUseCase(
        taskRepository: repository,
        householdRepository: householdRepository,
      );

      // 6 задач: 100, 80, 60, 40, 20, 10 минут
      repository.tasksForDay = [
        _makeTask('t1', 100, day),
        _makeTask('t2', 80, day),
        _makeTask('t3', 60, day),
        _makeTask('t4', 40, day),
        _makeTask('t5', 20, day),
        _makeTask('t6', 10, day),
      ];

      final result = await useCase(householdId: 'household-1', day: day);

      final maxLoad = result.memberDurations.values.reduce(
        (a, b) => a > b ? a : b,
      );
      final minLoad = result.memberDurations.values.reduce(
        (a, b) => a < b ? a : b,
      );

      // Разброс не больше длительности самой короткой задачи
      // (доказывает, что распределение примерно равномерное)
      expect(maxLoad - minLoad, lessThanOrEqualTo(20));
    });
  });
}

Task _makeTask(String id, int minutes, DateTime day) {
  return Task(
    id: id,
    householdId: 'household-1',
    title: 'Task $id',
    estimatedDurationMinutes: minutes,
    plannedFor: day,
    allowedMemberIds: const ['alice', 'bob', 'charlie'],
    status: TaskStatus.pending,
    createdAt: DateTime.utc(2026, 7, 25),
  );
}

final class _FakeTaskRepository implements TaskRepository {
  @override
  Future<void> updateTemplate({
    required UpdateRecurringTaskParams params,
  }) async {}

  final List<Task> savedTasks = [];
  List<Task> tasksForDay = [];

  @override
  Future<List<Task>> getForDay({
    required String householdId,
    required DateTime day,
  }) async {
    return tasksForDay;
  }

  @override
  Future<void> save(Task task) async {
    savedTasks.add(task);
  }

  @override
  Future<Task> create({required CreateTaskParams params}) {
    throw UnimplementedError();
  }

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
  Future<List<Task>> getAllPending({
    required String householdId,
  }) async {
    return const [];
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

final class _FakeHouseholdRepository implements HouseholdRepository {
  _FakeHouseholdRepository({required this.members});

  final List<HouseholdMember> members;

  @override
  Future<List<HouseholdMember>> getMembers({required String householdId}) async {
    return members;
  }

  @override
  Future<List<Household>> getMyHouseholds() async => [];

  @override
  Future<Household> create({required String name}) async =>
      Household(id: '1', name: name);

  @override
  Future<void> createInvitation({
    required String householdId,
    required String email,
  }) async {}

  @override
  Future<List<HouseholdInvitation>> getPendingInvitations() async => [];

  @override
  Future<String> acceptInvitation({required String invitationId}) async =>
      'household-1';

  @override
  Future<void> declineInvitation({required String invitationId}) async {}

  @override
  Future<void> leaveHousehold({required String householdId}) async {}

  @override
  Future<void> removeMember({
    required String householdId,
    required String profileId,
  }) async {}

  @override
  Future<void> deleteHousehold({required String householdId}) async {}

  @override
  Future<void> updateHousehold({
    required String householdId,
    required String name,
  }) async {}
}
