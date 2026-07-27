import 'package:bloc_test/bloc_test.dart';
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
import 'package:family_planner/features/tasks/domain/use_cases/get_tasks_for_day_use_case.dart';
import 'package:family_planner/features/today/presentation/cubit/today_tasks_cubit.dart';
import 'package:family_planner/features/today/presentation/cubit/today_tasks_state.dart';

void main() {
  final day = DateTime.utc(2026, 7, 20);

  final task = Task(
    id: 'task-1',
    householdId: 'household-1',
    title: 'Разобрать посудомойку',
    estimatedDurationMinutes: 10,
    plannedFor: day,
    allowedMemberIds: const ['member-1'],
    status: TaskStatus.pending,
    createdAt: DateTime.utc(2026, 7, 19, 12),
  );

  blocTest<TodayTasksCubit, TodayTasksState>(
    'выдаёт Loading и Loaded со списком задач при успешной загрузке',
    build: () {
      final repository = _FakeTaskRepository(tasksToReturn: [task]);

      return TodayTasksCubit(
        getTasksForDayUseCase: GetTasksForDayUseCase(repository: repository),
        householdRepository: _FakeHouseholdRepository(),
      );
    },
    act: (cubit) => cubit.load(householdId: 'household-1', day: day),
    expect: () => [
      const TodayTasksLoading(),
      TodayTasksLoaded(tasks: [task], members: []),
    ],
  );

  blocTest<TodayTasksCubit, TodayTasksState>(
    'выдаёт Loading и Loaded с пустым списком, когда задач нет',
    build: () {
      final repository = _FakeTaskRepository();

      return TodayTasksCubit(
        getTasksForDayUseCase: GetTasksForDayUseCase(repository: repository),
        householdRepository: _FakeHouseholdRepository(),
      );
    },
    act: (cubit) => cubit.load(householdId: 'household-1', day: day),
    expect: () => const [
      TodayTasksLoading(),
      TodayTasksLoaded(tasks: [], members: []),
    ],
  );

  blocTest<TodayTasksCubit, TodayTasksState>(
    'выдаёт Loading и Failure при ошибке репозитория',
    build: () {
      final repository = _FakeTaskRepository(
        exceptionToThrow: Exception('Нет подключения'),
      );

      return TodayTasksCubit(
        getTasksForDayUseCase: GetTasksForDayUseCase(repository: repository),
        householdRepository: _FakeHouseholdRepository(),
      );
    },
    act: (cubit) => cubit.load(householdId: 'household-1', day: day),
    expect: () => const [
      TodayTasksLoading(),
      TodayTasksFailure(message: 'Не удалось загрузить задачи на сегодня.'),
    ],
  );

  blocTest<TodayTasksCubit, TodayTasksState>(
    'distribute перезагружает задачи после успешного распределения',
    build: () {
      final repository = _FakeTaskRepository(tasksToReturn: [task]);
      const members = [
        HouseholdMember(
          profileId: 'member-1',
          displayName: 'Alice',
          role: 'owner',
        ),
      ];

      return TodayTasksCubit(
        getTasksForDayUseCase: GetTasksForDayUseCase(repository: repository),
        householdRepository: _FakeHouseholdRepository(members: members),
        distributeTasksUseCase: DistributeTasksUseCase(
          taskRepository: repository,
          householdRepository: _FakeHouseholdRepository(members: members),
        ),
      );
    },
    act: (cubit) => cubit.distribute(householdId: 'household-1', day: day),
    expect: () => [
      const TodayTasksLoading(),
      TodayTasksLoaded(tasks: [task], members: [
        HouseholdMember(
          profileId: 'member-1',
          displayName: 'Alice',
          role: 'owner',
        ),
      ]),
    ],
  );

  blocTest<TodayTasksCubit, TodayTasksState>(
    'distribute выдаёт Failure при ошибке распределения',
    build: () {
      final repository = _FakeTaskRepository(
        exceptionToThrow: Exception('Ошибка БД'),
      );

      return TodayTasksCubit(
        getTasksForDayUseCase: GetTasksForDayUseCase(repository: repository),
        householdRepository: _FakeHouseholdRepository(),
        distributeTasksUseCase: DistributeTasksUseCase(
          taskRepository: repository,
          householdRepository: _FakeHouseholdRepository(),
        ),
      );
    },
    act: (cubit) => cubit.distribute(householdId: 'household-1', day: day),
    expect: () => const [
      TodayTasksFailure(message: 'Не удалось распределить задачи.'),
    ],
  );
}

final class _FakeTaskRepository implements TaskRepository {
  _FakeTaskRepository({this.tasksToReturn = const [], this.exceptionToThrow});

  final List<Task> tasksToReturn;
  final Object? exceptionToThrow;

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
  Future<List<Task>> getForDay({
    required String householdId,
    required DateTime day,
  }) async {
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }

    return tasksToReturn;
  }

  @override
  Future<Task> create({required CreateTaskParams params}) {
    throw UnimplementedError();
  }

  @override
  Future<void> save(Task task) async {}

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
}

final class _FakeHouseholdRepository implements HouseholdRepository {
  _FakeHouseholdRepository({this.members = const []});

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
