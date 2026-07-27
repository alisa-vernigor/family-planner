import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:family_planner/core/logging/app_logger.dart';
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
    this.distributeTasksUseCase,
  }) : super(const TodayTasksInitial());

  final GetTasksForDayUseCase getTasksForDayUseCase;
  final HouseholdRepository householdRepository;
  final DistributeTasksUseCase? distributeTasksUseCase;

  Future<void> load({
    required String householdId,
    required DateTime day,
  }) async {
    emit(const TodayTasksLoading());

    try {
      final tasksFuture = getTasksForDayUseCase(
        householdId: householdId,
        day: day,
      );
      final membersFuture = householdRepository.getMembers(
        householdId: householdId,
      );

      final results = await Future.wait([tasksFuture, membersFuture]);
      final tasks = results[0] as List<Task>;
      final members = results[1] as List<HouseholdMember>;

      AppLogger.info(
        'Задачи на день загружены: '
        'householdId=$householdId; '
        'count=${tasks.length}',
      );

      emit(TodayTasksLoaded(tasks: tasks, members: members));
    } catch (exception, stackTrace) {
      const message = 'Не удалось загрузить задачи на сегодня.';

      AppLogger.error(message, error: exception, stackTrace: stackTrace);

      emit(const TodayTasksFailure(message: message));
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
}
