import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/households/domain/entities/household.dart';
import 'package:family_planner/features/households/domain/entities/household_invitation.dart';
import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/households/domain/repositories/household_repository.dart';
import 'package:family_planner/features/scheduled/presentation/cubit/scheduled_tasks_cubit.dart';
import 'package:family_planner/features/scheduled/presentation/cubit/scheduled_tasks_state.dart';
import 'package:family_planner/features/tasks/domain/entities/create_task_params.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/tasks/domain/use_cases/get_all_pending_tasks_use_case.dart';

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

  final member = HouseholdMember(
    profileId: 'member-1',
    displayName: 'Alice',
    role: 'owner',
  );

  test('загружает все невыполненные задачи', () async {
    final repository = _FakeTaskRepository(tasks: [task]);
    final householdRepository = _FakeHouseholdRepository(members: [member]);

    final cubit = ScheduledTasksCubit(
      getAllPendingTasksUseCase: GetAllPendingTasksUseCase(repository: repository),
      householdRepository: householdRepository,
    );
    addTearDown(cubit.close);

    await cubit.load(householdId: 'household-1');

    expect(cubit.state, ScheduledTasksLoaded(tasks: [task], members: [member]));
    expect(repository.receivedHouseholdId, 'household-1');
  });

  test('показывает ошибку при неудачной загрузке', () async {
    final cubit = ScheduledTasksCubit(
      getAllPendingTasksUseCase: GetAllPendingTasksUseCase(
        repository: _FakeTaskRepository(shouldThrow: true),
      ),
      householdRepository: _FakeHouseholdRepository(),
    );
    addTearDown(cubit.close);

    await cubit.load(householdId: 'household-1');

    expect(
      cubit.state,
      const ScheduledTasksFailure(message: 'Не удалось загрузить запланированные задачи.'),
    );
  });

  test('refresh не заменяет Loaded на Failure при ошибке', () async {
    final repository = _FakeTaskRepository(tasks: [task], shouldThrowOnSecondCall: true);
    final cubit = ScheduledTasksCubit(
      getAllPendingTasksUseCase: GetAllPendingTasksUseCase(repository: repository),
      householdRepository: _FakeHouseholdRepository(members: [member]),
    );
    addTearDown(cubit.close);

    await cubit.load(householdId: 'household-1');
    expect(cubit.state, isA<ScheduledTasksLoaded>());

    await cubit.refresh(householdId: 'household-1');
    expect(cubit.state, isA<ScheduledTasksLoaded>());
  });

  test('replaceTask заменяет задачу в списке', () async {
    final repository = _FakeTaskRepository(tasks: [task]);
    final cubit = ScheduledTasksCubit(
      getAllPendingTasksUseCase: GetAllPendingTasksUseCase(repository: repository),
      householdRepository: _FakeHouseholdRepository(members: [member]),
    );
    addTearDown(cubit.close);

    await cubit.load(householdId: 'household-1');
    cubit.replaceTask(task.copyWith(title: 'Обновлено'));

    final state = cubit.state as ScheduledTasksLoaded;
    expect(state.tasks.first.title, 'Обновлено');
  });

  test('removeTask убирает задачу из списка', () async {
    final repository = _FakeTaskRepository(tasks: [task]);
    final cubit = ScheduledTasksCubit(
      getAllPendingTasksUseCase: GetAllPendingTasksUseCase(repository: repository),
      householdRepository: _FakeHouseholdRepository(members: [member]),
    );
    addTearDown(cubit.close);

    await cubit.load(householdId: 'household-1');
    cubit.removeTask('task-1');

    final state = cubit.state as ScheduledTasksLoaded;
    expect(state.tasks, isEmpty);
  });

  test('confirmDelete не вызывает ошибок', () async {
    final repository = _FakeTaskRepository(tasks: [task]);
    final cubit = ScheduledTasksCubit(
      getAllPendingTasksUseCase: GetAllPendingTasksUseCase(repository: repository),
      householdRepository: _FakeHouseholdRepository(members: [member]),
    );
    addTearDown(cubit.close);

    await cubit.load(householdId: 'household-1');
    cubit.removeTask('task-1');
    cubit.confirmDelete('task-1');
    cubit.cancelDelete('task-1');
  });
}

final class _FakeTaskRepository implements TaskRepository {
  _FakeTaskRepository({
    this.tasks = const [],
    this.shouldThrow = false,
    this.shouldThrowOnSecondCall = false,
  });

  final List<Task> tasks;
  final bool shouldThrow;
  final bool shouldThrowOnSecondCall;
  int _callCount = 0;

  String? receivedHouseholdId;

  @override
  Future<Task> create({required CreateTaskParams params}) => throw UnimplementedError();

  @override
  Future<void> delete({required String taskId}) async {}

  @override
  Future<List<Task>> getForDay({required String householdId, required DateTime day}) => throw UnimplementedError();

  @override
  Future<List<Task>> getScheduledAfter({required String householdId, required DateTime day}) => throw UnimplementedError();

  @override
  Future<List<Task>> getAllPending({required String householdId}) async {
    _callCount++;
    if (shouldThrow || (shouldThrowOnSecondCall && _callCount > 1)) {
      throw Exception('Ошибка сети');
    }
    receivedHouseholdId = householdId;
    return tasks;
  }

  @override
  Future<void> save(Task task) async {}

  @override
  Future<void> addAllowedMember({required String taskId, required String memberId}) async {}

  @override
  Future<void> removeAllowedMember({required String taskId, required String memberId}) async {}

  @override
  Future<void> patchStatus({required String taskId, required String status, String? completedByMemberId, String? completedAt, String? assignedMemberId}) async {}
}

final class _FakeHouseholdRepository implements HouseholdRepository {
  _FakeHouseholdRepository({this.members = const []});

  final List<HouseholdMember> members;

  @override
  Future<List<HouseholdMember>> getMembers({required String householdId}) async => members;

  @override
  Future<List<Household>> getMyHouseholds() => throw UnimplementedError();

  @override
  Future<Household> create({required String name}) => throw UnimplementedError();

  @override
  Future<void> createInvitation({required String householdId, required String email}) async {}

  @override
  Future<List<HouseholdInvitation>> getPendingInvitations() => throw UnimplementedError();

  @override
  Future<String> acceptInvitation({required String invitationId}) => throw UnimplementedError();

  @override
  Future<void> declineInvitation({required String invitationId}) async {}

  @override
  Future<void> leaveHousehold({required String householdId}) async {}

  @override
  Future<void> removeMember({required String householdId, required String profileId}) async {}

  @override
  Future<void> deleteHousehold({required String householdId}) async {}

  @override
  Future<void> updateHousehold({required String householdId, required String name}) async {}
}
