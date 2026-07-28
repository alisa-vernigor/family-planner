import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:family_planner/core/logging/app_logger.dart';
import 'package:family_planner/core/services/home_widget_service.dart';
import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/households/domain/repositories/household_repository.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/use_cases/distribute_tasks_use_case.dart';
import 'package:family_planner/features/tasks/domain/use_cases/get_tasks_for_day_use_case.dart';

import 'today_tasks_state.dart';

final class TodayTasksCubit extends Cubit<TodayTasksState> {
  TodayTasksCubit({
    required this.getTasksForDayUseCase,
    required this.householdRepository,
    required this.currentMemberId,
    required this.householdId,
    this.distributeTasksUseCase,
  }) : super(const TodayTasksInitial());

  final GetTasksForDayUseCase getTasksForDayUseCase;
  final HouseholdRepository householdRepository;
  final DistributeTasksUseCase? distributeTasksUseCase;
  final String currentMemberId;
  final String householdId;

  /// ID задач, которые сейчас удаляются — не возвращать из refresh пока удаление не завершится.
  final Set<String> _pendingDeleteIds = {};

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
      final tasksFuture = getTasksForDayUseCase(
        householdId: householdId,
        day: day,
      ).timeout(const Duration(seconds: 15));
      final membersFuture = householdRepository.getMembers(
        householdId: householdId,
      ).timeout(const Duration(seconds: 15));

      final results = await Future.wait([tasksFuture, membersFuture]);
      var tasks = results[0] as List<Task>;
      final members = results[1] as List<HouseholdMember>;

      // Исключаем задачи, которые ещё удаляются
      if (_pendingDeleteIds.isNotEmpty) {
        tasks = tasks.where((t) => !_pendingDeleteIds.contains(t.id)).toList();
      }

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
      emit(
        TodayTasksLoaded(
          tasks: tasks.map((t) => t.id == updatedTask.id ? updatedTask : t).toList(),
          members: members,
        ),
      );
    }
  }

  /// Оптимистично удаляет задачу из текущего списка.
  void removeTask(String taskId) {
    _pendingDeleteIds.add(taskId);

    final current = state;
    if (current case TodayTasksLoaded(:final tasks, :final members)) {
      emit(
        TodayTasksLoaded(
          tasks: tasks.where((t) => t.id != taskId).toList(),
          members: members,
        ),
      );
    }
  }

  /// Подтверждает удаление — убирает ID из pending-списка.
  void confirmDelete(String taskId) {
    _pendingDeleteIds.remove(taskId);
  }

  /// Отменяет удаление — убирает ID из pending и перезагружает.
  void cancelDelete(String taskId) {
    _pendingDeleteIds.remove(taskId);
  }
}
