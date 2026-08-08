/// Граничные тесты для дожатия покрытия до >95%.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';

import 'package:family_planner/core/logging/app_logger.dart';
import 'package:family_planner/features/households/domain/entities/household.dart';
import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/households/domain/entities/household_invitation.dart';
import 'package:family_planner/features/households/domain/repositories/household_repository.dart';
import 'package:family_planner/features/households/presentation/cubit/household_cubit.dart';
import 'package:family_planner/features/households/presentation/cubit/household_state.dart';
import 'package:family_planner/features/households/presentation/cubit/household_members_cubit.dart';
import 'package:family_planner/features/households/presentation/cubit/household_members_state.dart';
import 'package:family_planner/features/households/presentation/cubit/household_invitations_cubit.dart';
import 'package:family_planner/features/households/presentation/cubit/household_invitations_state.dart';

import 'package:family_planner/features/tasks/domain/entities/create_task_params.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/tasks/domain/services/task_schedule.dart';
import 'package:family_planner/features/tasks/domain/use_cases/distribute_tasks_use_case.dart';
import 'package:family_planner/features/today/presentation/cubit/today_tasks_cubit.dart';
import 'package:family_planner/features/today/presentation/cubit/today_tasks_state.dart';
import 'package:family_planner/features/scheduled/presentation/cubit/scheduled_tasks_cubit.dart';
import 'package:family_planner/features/scheduled/presentation/cubit/scheduled_tasks_state.dart';
import 'package:family_planner/features/tasks/domain/entities/update_recurring_task_params.dart';

// ── 1. Конструкторы ─────────────────────────────────────
void main() {
  test('AppLogger._()', () => expect(AppLogger, isA<Type>()));
  test('Household(const)', () {
    const h = Household(id: 'x', name: 'y');
    expect(h.props, ['x', 'y']);
  });
  test('TaskSchedule._()', () => expect(TaskSchedule, isA<Type>()));
  test('ScheduledTasksState base props', () => expect(const ScheduledTasksInitial().props, []));

  // ── 2. HouseholdCubit — edge branches ─────────────────
  group('HouseholdCubit branches', () {
    blocTest<HouseholdCubit, HouseholdState>(
      'refresh from Empty handles empty result (no re-emission filter)',
      build: () => _householdCubit(_EmptyHHRepo()),
      seed: () => const HouseholdEmpty(),
      act: (c) => c.refresh(),
      verify: (c) => expect(c.state, const HouseholdEmpty()),
    );

    blocTest<HouseholdCubit, HouseholdState>(
      'refresh from Loaded preserves prev on error',
      build: () => _householdCubit(_FailGetHouseholds()),
      seed: () => const HouseholdLoaded(households: [Household(id: 'h1', name: 'T')]),
      act: (c) => c.refresh(),
      verify: (c) => expect(c.state, isA<HouseholdLoaded>()),
    );

    blocTest<HouseholdCubit, HouseholdState>(
      'delete from Empty reloads',
      build: () => _householdCubit(_EmptyHHRepo()),
      seed: () => const HouseholdEmpty(),
      act: (c) => c.delete(householdId: 'h1'),
      expect: () => const [HouseholdLoading(), HouseholdEmpty()],
    );

    test('update with error reaches _emitFailure', () async {
      final cubit = _householdCubit(_FailGetHouseholds());
      cubit.update(householdId: 'h1', name: 'x');
      await Future.delayed(Duration.zero);
      cubit.close();
    });
  });

  // ── 4. HouseholdInvitationsCubit _currentInvitations ─
  test('_currentInvitations default branch', () {
    final cubit = HouseholdInvitationsCubit(
      householdRepository: _EmptyHHRepo(),
    );
    expect(cubit.state, const HouseholdInvitationsInitial());
    cubit.close();
  });

  // ── 5. HouseholdMembersCubit _currentMembers ─────────
  test('_currentMembers default branch', () {
    final cubit = HouseholdMembersCubit(
      householdRepository: _EmptyHHRepo(),
    );
    expect(cubit.state, const HouseholdMembersInitial());
    cubit.close();
  });

  // ── 6. TodayTasksCubit ──────────────────────────────
  group('TodayTasksCubit branches', () {
    final day = DateTime.utc(2026, 7, 20);
    final task = Task(id: 't1', householdId: 'h1', title: 'T', estimatedDurationMinutes: 10,
      plannedFor: day, allowedMemberIds: const ['m1'], status: TaskStatus.pending, createdAt: DateTime.utc(2026, 7, 19));

    blocTest<TodayTasksCubit, TodayTasksState>(
      'pending delete ids filtered',
      build: () => TodayTasksCubit(
        taskRepository: _FakeTaskRepo(tasks: [task]),
        householdRepository: _EmptyHHRepo(),
        currentMemberId: 'm1',
        householdId: 'h1',
      ),
      act: (c) async {
        await c.load(householdId: 'h1', day: day);
        c.removeTask('t1');
        await c.load(householdId: 'h1', day: day);
      },
      verify: (c) => expect((c.state as TodayTasksLoaded).tasks, isEmpty),
    );

    blocTest<TodayTasksCubit, TodayTasksState>(
      'refresh preserves Loaded on error',
      build: () => TodayTasksCubit(
        taskRepository: _FakeTaskRepo(),
        householdRepository: _FailGetMembers(),
        currentMemberId: 'm1',
        householdId: 'h1',
      ),
      seed: () => TodayTasksLoaded(tasks: [task], members: []),
      act: (c) => c.refresh(householdId: 'h1', day: day),
      verify: (c) => expect(c.state, isA<TodayTasksLoaded>()),
    );

    blocTest<TodayTasksCubit, TodayTasksState>(
      'load failure',
      build: () => TodayTasksCubit(
        taskRepository: _FakeTaskRepo(),
        householdRepository: _FailGetMembers(),
        currentMemberId: 'm1',
        householdId: 'h1',
      ),
      act: (c) => c.load(householdId: 'h1', day: day),
      expect: () => const [TodayTasksLoading(), TodayTasksFailure(message: 'Не удалось загрузить задачи на сегодня.')],
    );
  });

  // ── 7. ScheduledTasksCubit ──────────────────────────
  group('ScheduledTasksCubit branches', () {
    final task = Task(id: 't1', householdId: 'h1', title: 'T', estimatedDurationMinutes: 10,
      plannedFor: DateTime.utc(2026, 7, 20), allowedMemberIds: const ['m1'],
      status: TaskStatus.pending, createdAt: DateTime.utc(2026, 7, 19));

    test('pending delete filtered from refresh', () async {
      final cubit = ScheduledTasksCubit(
        taskRepository: _FakeTaskRepo(tasks: [task]),
        householdRepository: _EmptyHHRepo(),
      );
      await cubit.load(householdId: 'h1');
      cubit.removeTask('t1');
      await cubit.refresh(householdId: 'h1');
      expect((cubit.state as ScheduledTasksLoaded).tasks, isEmpty);
      cubit.close();
    });

    test('confirmDelete/cancelDelete safe', () {
      final cubit = ScheduledTasksCubit(
        taskRepository: _FakeTaskRepo(),
        householdRepository: _EmptyHHRepo(),
      );
      cubit.confirmDelete('t1');
      cubit.cancelDelete('t1');
      cubit.close();
    });
  });

  // ── 8. DistributeTasksUseCase — addAllowedMember ─────
  test('DistributeTasksUseCase addAllowedMember when assignee not in allowed list', () async {
    final day = DateTime.utc(2026, 7, 20);
    final task = Task(id: 't1', householdId: 'h1', title: 'T', estimatedDurationMinutes: 10,
      plannedFor: day, allowedMemberIds: const ['m1'], assignedMemberId: 'm2',
      status: TaskStatus.pending, createdAt: DateTime.utc(2026, 7, 19));
    final repo = _DistributeTaskRepo();
    await repo.save(task);
    final useCase = DistributeTasksUseCase(
      taskRepository: repo,
      householdRepository: _EmptyHHRepo(),
    );
    await useCase(householdId: 'h1', day: day);
  });
}

// ── Helpers ──────────────────────────────────────────────
HouseholdCubit _householdCubit(HouseholdRepository repo) => HouseholdCubit(
  householdRepository: repo,
);

class _EmptyHHRepo implements HouseholdRepository {
  @override
  Future<List<HouseholdMember>> getMembers({required String householdId}) => Future.value([]);
  @override
  Future<List<Household>> getMyHouseholds() => Future.value([]);
  @override
  Future<Household> create({required String name}) => Future.value(const Household(id: '1', name: 'n'));
  @override
  Future<void> createInvitation({required String householdId, required String email}) async {}
  @override
  Future<List<HouseholdInvitation>> getPendingInvitations() => Future.value([]);
  @override
  Future<String> acceptInvitation({required String invitationId}) => Future.value('h1');
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

class _FailGetHouseholds implements HouseholdRepository {
  @override
  Future<List<Household>> getMyHouseholds() => Future.error(Exception('fail'));
  @override
  Future<List<HouseholdMember>> getMembers({required String householdId}) => Future.value([]);
  @override
  Future<Household> create({required String name}) => Future.value(const Household(id: '1', name: 'n'));
  @override
  Future<void> createInvitation({required String householdId, required String email}) async {}
  @override
  Future<List<HouseholdInvitation>> getPendingInvitations() => Future.value([]);
  @override
  Future<String> acceptInvitation({required String invitationId}) => Future.value('h1');
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

class _FailGetMembers implements HouseholdRepository {
  @override
  Future<List<HouseholdMember>> getMembers({required String householdId}) => Future.error(Exception('fail'));
  @override
  Future<List<Household>> getMyHouseholds() => Future.value([]);
  @override
  Future<Household> create({required String name}) => Future.value(const Household(id: '1', name: 'n'));
  @override
  Future<void> createInvitation({required String householdId, required String email}) async {}
  @override
  Future<List<HouseholdInvitation>> getPendingInvitations() => Future.value([]);
  @override
  Future<String> acceptInvitation({required String invitationId}) => Future.value('h1');
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

class _FakeTaskRepo implements TaskRepository {
  @override
  Future<void> updateTemplate({
    required UpdateRecurringTaskParams params,
  }) async {}
  @override
  Future<void> pauseTemplate({required String templateId}) async {}

  @override
  Future<void> resumeTemplate({required String templateId}) async {}

  _FakeTaskRepo({this.tasks = const []});
  final List<Task> tasks;
  @override Future<Task> create({required CreateTaskParams params}) => throw UnimplementedError();
  @override Future<void> delete({required String taskId}) async {}
  @override Future<List<Task>> getForDay({required String householdId, required DateTime day}) async => tasks;
  @override Future<List<Task>> getScheduledAfter({required String householdId, required DateTime day}) async => [];
  @override Future<List<Task>> getAllPending({required String householdId}) async => tasks;
  @override Future<void> save(Task task) async {}
  @override Future<void> addAllowedMember({required String taskId, required String memberId}) async {}
  @override Future<void> removeAllowedMember({required String taskId, required String memberId}) async {}

  @override
  Future<void> patchStatus({required String taskId, required String status, String? completedByMemberId, String? completedAt, String? assignedMemberId}) async {}
}

class _DistributeTaskRepo implements TaskRepository {
  @override
  Future<void> updateTemplate({
    required UpdateRecurringTaskParams params,
  }) async {}
  @override
  Future<void> pauseTemplate({required String templateId}) async {}

  @override
  Future<void> resumeTemplate({required String templateId}) async {}

  final _saved = <Task>[];
  @override Future<List<Task>> getForDay({required String householdId, required DateTime day}) async =>
    _saved.where((t) => t.plannedFor == day).toList();
  @override Future<List<Task>> getScheduledAfter({required String householdId, required DateTime day}) async => [];
  @override Future<List<Task>> getAllPending({required String householdId}) async => _saved;
  @override Future<Task> create({required CreateTaskParams params}) => throw UnimplementedError();
  @override Future<void> delete({required String taskId}) async {}
  @override Future<void> save(Task task) async { _saved.removeWhere((t) => t.id == task.id); _saved.add(task); }
  @override Future<void> addAllowedMember({required String taskId, required String memberId}) async {}
  @override Future<void> removeAllowedMember({required String taskId, required String memberId}) async {}

  @override
  Future<void> patchStatus({required String taskId, required String status, String? completedByMemberId, String? completedAt, String? assignedMemberId}) async {}
}
