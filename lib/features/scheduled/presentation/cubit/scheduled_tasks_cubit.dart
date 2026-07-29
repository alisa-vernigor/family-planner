import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:family_planner/core/logging/app_logger.dart';
import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/households/domain/repositories/household_repository.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'dart:async';
import 'package:family_planner/core/mixins/optimistic_task_operations.dart';

import 'scheduled_tasks_state.dart';

final class ScheduledTasksCubit extends Cubit<ScheduledTasksState>
    with OptimisticTaskOperationsMixin<ScheduledTasksState> {
  ScheduledTasksCubit({
    required this.taskRepository,
    required this.householdRepository,
  }) : super(const ScheduledTasksInitial());

  final TaskRepository taskRepository;
  final HouseholdRepository householdRepository;

  Future<void> load({
    required String householdId,
  }) async {
    emit(const ScheduledTasksLoading());

    await _fetch(householdId: householdId);
  }

  /// Тихая перезагрузка — не показывает спиннер, если данные уже есть.
  Future<void> refresh({
    required String householdId,
  }) async {
    final previousState = state;

    await _fetch(
      householdId: householdId,
      onFailure: () {
        if (previousState case ScheduledTasksLoaded()) {
          emit(previousState);
        }
      },
    );
  }

  Future<void> _fetch({
    required String householdId,
    void Function()? onFailure,
  }) async {
    try {
      final tasksFuture = taskRepository.getAllPending(
        householdId: householdId,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Supabase не ответил за 15 секунд.');
        },
      );
      final membersFuture = householdRepository.getMembers(
        householdId: householdId,
      ).timeout(const Duration(seconds: 15));

      final results = await Future.wait([tasksFuture, membersFuture]);
      var tasks = results[0] as List<Task>;
      final members = results[1] as List<HouseholdMember>;

      // Исключаем задачи, которые ещё удаляются
      tasks = filterPendingDeletes(tasks);

      AppLogger.info(
        'Все невыполненные задачи загружены: '
        'householdId=$householdId; '
        'count=${tasks.length}',
      );

      emit(ScheduledTasksLoaded(tasks: tasks, members: members));
    } catch (exception, stackTrace) {
      const message = 'Не удалось загрузить запланированные задачи.';

      AppLogger.error(message, error: exception, stackTrace: stackTrace);

      if (onFailure != null) {
        onFailure();
      } else {
        emit(const ScheduledTasksFailure(message: message));
      }
    }
  }

  /// Оптимистично заменяет задачу в текущем списке без перезагрузки.
  void replaceTask(Task updatedTask) {
    final current = state;
    if (current case ScheduledTasksLoaded(:final tasks, :final members)) {
      optimisticReplace(
        updatedTask,
        tasks,
        members,
        (t, m) => ScheduledTasksLoaded(tasks: t, members: m),
      );
    }
  }

  /// Оптимистично удаляет задачу из текущего списка.
  void removeTask(String taskId) {
    final current = state;
    if (current case ScheduledTasksLoaded(:final tasks, :final members)) {
      optimisticRemove(
        taskId,
        tasks,
        members,
        (t, m) => ScheduledTasksLoaded(tasks: t, members: m),
      );
    }
  }
}
