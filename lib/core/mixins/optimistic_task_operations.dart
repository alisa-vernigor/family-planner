import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/households/domain/entities/household_member.dart';
import '../../features/tasks/domain/entities/task.dart';

/// Mixin for cubits managing a list of tasks with optimistic updates.
///
/// Provides [optimisticReplace], [optimisticRemove], [filterPendingDeletes],
/// [confirmDelete], and [cancelDelete] — the pattern that both
/// [TodayTasksCubit] and [ScheduledTasksCubit] previously duplicated.
///
/// Упрощение для нейронок: один source of truth для оптимистичных операций.
mixin OptimisticTaskOperationsMixin<S> on Cubit<S> {
  /// ID задач, которые сейчас удаляются — не возвращать из refresh
  /// пока удаление не завершится.
  final Set<String> _pendingDeleteIds = {};

  /// Оптимистично заменяет задачу в текущем списке без перезагрузки.
  void optimisticReplace(
    Task updatedTask,
    List<Task> currentTasks,
    List<HouseholdMember> currentMembers,
    S Function(List<Task>, List<HouseholdMember>) buildLoaded,
  ) {
    emit(buildLoaded(
      currentTasks
          .map((t) => t.id == updatedTask.id ? updatedTask : t)
          .toList(),
      currentMembers,
    ));
  }

  /// Оптимистично удаляет задачу из текущего списка.
  void optimisticRemove(
    String taskId,
    List<Task> currentTasks,
    List<HouseholdMember> currentMembers,
    S Function(List<Task>, List<HouseholdMember>) buildLoaded,
  ) {
    _pendingDeleteIds.add(taskId);
    emit(buildLoaded(
      currentTasks.where((t) => t.id != taskId).toList(),
      currentMembers,
    ));
  }

  /// Подтверждает удаление — убирает ID из pending-списка.
  void confirmDelete(String taskId) {
    _pendingDeleteIds.remove(taskId);
  }

  /// Отменяет удаление — убирает ID из pending.
  void cancelDelete(String taskId) {
    _pendingDeleteIds.remove(taskId);
  }

  /// Удаляет из списка задачи, которые ещё в процессе удаления.
  List<Task> filterPendingDeletes(List<Task> tasks) {
    if (_pendingDeleteIds.isEmpty) return tasks;
    return tasks.where((t) => !_pendingDeleteIds.contains(t.id)).toList();
  }
}
