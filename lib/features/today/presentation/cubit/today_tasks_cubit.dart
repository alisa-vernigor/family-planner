import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:family_planner/core/logging/app_logger.dart';
import 'package:family_planner/core/services/home_widget_service.dart';
import 'package:family_planner/features/households/households.dart';
import 'package:family_planner/features/tasks/tasks.dart';

import 'package:family_planner/core/mixins/optimistic_task_operations.dart';

import 'today_tasks_state.dart';

final class TodayTasksCubit extends Cubit<TodayTasksState>
    with OptimisticTaskOperationsMixin<TodayTasksState> {
  TodayTasksCubit({
    required this.taskRepository,
    required this.householdRepository,
    required this.currentMemberId,
    required this.householdId,
    this.distributeTasksUseCase,
  }) : super(const TodayTasksInitial());

  final TaskRepository taskRepository;
  final HouseholdRepository householdRepository;
  final DistributeTasksUseCase? distributeTasksUseCase;
  final String currentMemberId;
  final String householdId;

  Future<void> load({
    required String householdId,
    required DateTime day,
  }) async {
    emit(const TodayTasksLoading());

    await _fetch(householdId: householdId, day: day);
  }

  /// Тихая перезагрузка — не показывает спиннер, если данные уже есть.
  Future<void> refresh({
    required String householdId,
    required DateTime day,
  }) async {
    final previousState = state;

    await _fetch(
      householdId: householdId,
      day: day,
      onFailure: () {
        if (previousState case TodayTasksLoaded()) {
          emit(previousState);
        }
      },
    );
  }

  Future<void> _fetch({
    required String householdId,
    required DateTime day,
    void Function()? onFailure,
  }) async {
    try {
      final tasksFuture = taskRepository.getForDay(
        householdId: householdId,
        day: day,
      );
      final membersFuture = householdRepository.getMembers(
        householdId: householdId,
      );

      final results = await Future.wait([tasksFuture, membersFuture]);
      var tasks = results[0] as List<Task>;
      final members = results[1] as List<HouseholdMember>;

      // Исключаем задачи, которые ещё удаляются
      tasks = filterPendingDeletes(tasks);

      AppLogger.info(
        'Задачи на день загружены: '
        'householdId=$householdId; '
        'count=${tasks.length}',
      );

      emit(TodayTasksLoaded(tasks: tasks, members: members));

      // Синхронизируем виджет ТОЛЬКО при реальной загрузке с сервера
      try {
        unawaited(HomeWidgetService.syncTasks(
          tasks,
          currentMemberId,
          householdId,
        ));
      } catch (_) {
        // Виджет — не критично
      }
    } catch (exception, stackTrace) {
      const message = 'Не удалось загрузить задачи на сегодня.';

      AppLogger.error(message, error: exception, stackTrace: stackTrace);

      if (onFailure != null) {
        onFailure();
      } else {
        emit(const TodayTasksFailure(message: message));
      }
    }
  }

  Future<void> distribute({
    required String householdId,
    required DateTime day,
  }) async {
    final useCase = distributeTasksUseCase;
    if (useCase == null) return;

    try {
      await useCase(
        householdId: householdId,
        day: day,
      );

      AppLogger.info(
        'Задачи распределены: householdId=$householdId',
      );

      await load(householdId: householdId, day: day);
    } catch (exception, stackTrace) {
      const message = 'Не удалось распределить задачи.';

      AppLogger.error(message, error: exception, stackTrace: stackTrace);

      emit(const TodayTasksFailure(message: message));
    }
  }

  /// Оптимистично заменяет задачу в текущем списке без перезагрузки.
  void replaceTask(Task updatedTask) {
    final current = state;
    if (current case TodayTasksLoaded(:final tasks, :final members)) {
      optimisticReplace(
        updatedTask,
        tasks,
        members,
        (t, m) => TodayTasksLoaded(tasks: t, members: m),
      );
    }
  }

  /// Оптимистично удаляет задачу из текущего списка.
  void removeTask(String taskId) {
    final current = state;
    if (current case TodayTasksLoaded(:final tasks, :final members)) {
      optimisticRemove(
        taskId,
        tasks,
        members,
        (t, m) => TodayTasksLoaded(tasks: t, members: m),
      );
    }
  }
}
