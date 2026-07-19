import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:family_planner/core/logging/app_logger.dart';
import 'package:family_planner/features/tasks/domain/use_cases/get_tasks_for_day_use_case.dart';

import 'today_tasks_state.dart';

final class TodayTasksCubit extends Cubit<TodayTasksState> {
  TodayTasksCubit({required this.getTasksForDayUseCase})
    : super(const TodayTasksInitial());

  final GetTasksForDayUseCase getTasksForDayUseCase;

  Future<void> load({
    required String householdId,
    required DateTime day,
  }) async {
    emit(const TodayTasksLoading());

    try {
      final tasks = await getTasksForDayUseCase(
        householdId: householdId,
        day: day,
      );

      AppLogger.info(
        'Задачи на день загружены: '
        'householdId=$householdId; '
        'count=${tasks.length}',
      );

      emit(TodayTasksLoaded(tasks: tasks));
    } catch (exception, stackTrace) {
      const message = 'Не удалось загрузить задачи на сегодня.';

      AppLogger.error(message, error: exception, stackTrace: stackTrace);

      emit(const TodayTasksFailure(message: message));
    }
  }
}
