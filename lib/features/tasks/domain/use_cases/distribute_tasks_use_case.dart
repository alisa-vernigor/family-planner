import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/households/domain/repositories/household_repository.dart';

final class DistributeTasksResult {
  const DistributeTasksResult({
    required this.updatedTasks,
    required this.memberDurations,
  });

  final List<Task> updatedTasks;

  /// memberId -> total allocated minutes
  final Map<String, int> memberDurations;
}

final class DistributeTasksUseCase {
  const DistributeTasksUseCase({
    required this.taskRepository,
    required this.householdRepository,
  });

  final TaskRepository taskRepository;
  final HouseholdRepository householdRepository;

  /// Распределяет нераспределённые задачи на сегодня между членами семьи.
  ///
  /// - Уже назначенные задачи (assignedMemberId != null) не трогает,
  ///   но учитывает их время в нагрузке.
  /// - Закреплённые задачи (isPinned) никогда не перераспределяются.
  /// - Новые задачи назначаются жадным алгоритмом наименее загруженному.
  Future<DistributeTasksResult> call({
    required String householdId,
    required DateTime day,
  }) async {
    final tasks = await taskRepository.getForDay(
      householdId: householdId,
      day: day,
    );

    final members = await householdRepository.getMembers(
      householdId: householdId,
    );

    final pendingTasks =
        tasks.where((t) => !t.isCompleted).toList(growable: false);

    final result = _distribute(pendingTasks, members);

    // Persist only changed tasks + add to allowed members
    for (final task in result.updatedTasks) {
      final original = tasks.firstWhere((t) => t.id == task.id);
      if (task.assignedMemberId != original.assignedMemberId) {
        await taskRepository.save(task);

        // Add assigned member to allowed members list if needed
        final assignedId = task.assignedMemberId;
        if (assignedId != null &&
            !original.allowedMemberIds.contains(assignedId)) {
          await taskRepository.addAllowedMember(
            taskId: task.id,
            memberId: assignedId,
          );
        }
      }
    }

    return result;
  }

  DistributeTasksResult _distribute(
    List<Task> tasks,
    List<HouseholdMember> members,
  ) {
    if (members.isEmpty) {
      return DistributeTasksResult(
        updatedTasks: tasks,
        memberDurations: {},
      );
    }

    // Build workload map: memberId -> total minutes from already-assigned tasks
    final workloads = <String, int>{
      for (final m in members) m.profileId: 0,
    };

    final toAssign = <Task>[];

    for (final task in tasks) {
      if (task.isPinned && workloads.containsKey(task.pinnedMemberId!)) {
        // Pinned task — count duration at pinned member, never reassign
        workloads[task.pinnedMemberId!] =
            workloads[task.pinnedMemberId!]! + task.estimatedDurationMinutes;
      } else if (task.assignedMemberId != null &&
          workloads.containsKey(task.assignedMemberId)) {
        // Already assigned — count duration, don't reassign
        workloads[task.assignedMemberId!] =
            workloads[task.assignedMemberId!]! + task.estimatedDurationMinutes;
      } else {
        // Unassigned and not pinned — needs distribution
        toAssign.add(task);
      }
    }

    // Sort by duration descending (largest first — better greedy packing)
    toAssign.sort(
      (a, b) =>
          b.estimatedDurationMinutes.compareTo(a.estimatedDurationMinutes),
    );

    // Greedy: assign each task to the least loaded member
    final assignments = <String, String>{};

    for (final task in toAssign) {
      final bestMemberId = workloads.entries
          .reduce((a, b) => a.value <= b.value ? a : b)
          .key;

      assignments[task.id] = bestMemberId;
      workloads[bestMemberId] =
          workloads[bestMemberId]! + task.estimatedDurationMinutes;
    }

    // Build updated task list preserving original order
    final updatedTasks = tasks.map((task) {
      final assignedMemberId = assignments[task.id];
      if (assignedMemberId != null) {
        return task.copyWith(assignedMemberId: assignedMemberId);
      }
      return task;
    }).toList(growable: false);

    return DistributeTasksResult(
      updatedTasks: updatedTasks,
      memberDurations: workloads,
    );
  }
}
