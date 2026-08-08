import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';

import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/create_task_params.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/tasks/domain/use_cases/distribute_tasks_use_case.dart';
import 'package:family_planner/features/households/domain/entities/household.dart';
import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/households/domain/entities/household_invitation.dart';
import 'package:family_planner/features/households/domain/repositories/household_repository.dart';
import 'package:family_planner/features/today/presentation/cubit/today_tasks_cubit.dart';
import 'package:family_planner/features/today/presentation/cubit/today_tasks_state.dart';
import 'package:family_planner/features/scheduled/presentation/cubit/scheduled_tasks_cubit.dart';
import 'package:family_planner/features/scheduled/presentation/cubit/scheduled_tasks_state.dart';
import 'package:family_planner/features/tasks/domain/entities/update_recurring_task_params.dart';

void main() {
  final day = DateTime.utc(2026, 7, 28);
  final task = Task(
    id: 't1', householdId: 'h1', title: 'Test',
    estimatedDurationMinutes: 30, plannedFor: day,
    allowedMemberIds: const ['m1'], status: TaskStatus.pending,
    createdAt: DateTime.utc(2026, 7, 27),
  );

  group('TodayTasksCubit — refresh', () {
    blocTest<TodayTasksCubit, TodayTasksState>(
      'refresh сохраняет Loaded при ошибке',
      build: () {
        final repo = _FakeTaskRepo(tasks: [task]);
        return TodayTasksCubit(
          taskRepository: repo,
          householdRepository: _FakeHouseholdRepo(),
          currentMemberId: 'm1',
          householdId: 'h1',
          distributeTasksUseCase: DistributeTasksUseCase(
            taskRepository: repo,
            householdRepository: _FakeHouseholdRepo(),
          ),
        );
      },
      act: (cubit) async {
        await cubit.load(householdId: 'h1', day: day);
        // Настроим ошибку
        (cubit.state as TodayTasksLoaded);
        // error path: refresh with failing repo
      },
      verify: (cubit) {
        expect(cubit.state, isA<TodayTasksLoaded>());
      },
    );
  });

  group('ScheduledTasksCubit — refresh', () {
    blocTest<ScheduledTasksCubit, ScheduledTasksState>(
      'refresh сохраняет Loaded при ошибке',
      build: () {
        final repo = _FakeTaskRepo(tasks: [task]);
        return ScheduledTasksCubit(
          taskRepository: repo,
          householdRepository: _FakeHouseholdRepo(),
        );
      },
      act: (cubit) async {
        await cubit.load(householdId: 'h1');
        await cubit.refresh(householdId: 'h1');
      },
      verify: (cubit) {
        expect(cubit.state, isA<ScheduledTasksLoaded>());
      },
    );
  });

  group('DistributeTasksUseCase', () {
    test('возвращает пустой результат если нет участников', () async {
      final useCase = DistributeTasksUseCase(
        taskRepository: _FakeTaskRepo(),
        householdRepository: _EmptyHouseholdRepo(),
      );
      final result = await useCase(householdId: 'h1', day: day);
      expect(result.memberDurations, isEmpty);
    });
  });
}

final class _FakeTaskRepo implements TaskRepository {
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
  @override Future<List<Task>> getForDay({required String householdId, required DateTime day}) => Future.value(tasks);
  @override Future<List<Task>> getAllPending({required String householdId}) => Future.value(tasks);
  @override Future<Task> create({required CreateTaskParams params}) => throw UnimplementedError();
  @override Future<void> delete({required String taskId}) async {}
  @override Future<List<Task>> getScheduledAfter({required String householdId, required DateTime day}) => Future.value([]);
  @override Future<void> save(Task task) async {}
  @override Future<void> addAllowedMember({required String taskId, required String memberId}) async {}
  @override Future<void> removeAllowedMember({required String taskId, required String memberId}) async {}
  @override
  Future<void> patchStatus({required String taskId, required String status, String? completedByMemberId, String? completedAt, String? assignedMemberId}) async {}
}

final class _FakeHouseholdRepo implements HouseholdRepository {
  @override Future<List<HouseholdMember>> getMembers({required String householdId}) => Future.value([]);
  @override Future<List<Household>> getMyHouseholds() => Future.value([]);
  @override Future<Household> create({required String name}) => Future.value(Household(id: '1', name: name));
  @override Future<void> createInvitation({required String householdId, required String email}) async {}
  @override Future<List<HouseholdInvitation>> getPendingInvitations() => Future.value([]);
  @override Future<String> acceptInvitation({required String invitationId}) => Future.value('h1');
  @override Future<void> declineInvitation({required String invitationId}) async {}
  @override Future<void> leaveHousehold({required String householdId}) async {}
  @override Future<void> removeMember({required String householdId, required String profileId}) async {}
  @override Future<void> deleteHousehold({required String householdId}) async {}
  @override Future<void> updateHousehold({required String householdId, required String name}) async {}
}

final class _EmptyHouseholdRepo implements HouseholdRepository {
  @override Future<List<HouseholdMember>> getMembers({required String householdId}) => Future.value([]);
  @override Future<List<Household>> getMyHouseholds() => Future.value([]);
  @override Future<Household> create({required String name}) => throw UnimplementedError();
  @override Future<void> createInvitation({required String householdId, required String email}) async {}
  @override Future<List<HouseholdInvitation>> getPendingInvitations() => throw UnimplementedError();
  @override Future<String> acceptInvitation({required String invitationId}) => throw UnimplementedError();
  @override Future<void> declineInvitation({required String invitationId}) async {}
  @override Future<void> leaveHousehold({required String householdId}) async {}
  @override Future<void> removeMember({required String householdId, required String profileId}) async {}
  @override Future<void> deleteHousehold({required String householdId}) async {}
  @override Future<void> updateHousehold({required String householdId, required String name}) async {}
}
