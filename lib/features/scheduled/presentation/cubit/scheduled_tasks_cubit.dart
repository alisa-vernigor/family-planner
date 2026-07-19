import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:family_planner/core/logging/app_logger.dart';
import 'package:family_planner/features/tasks/domain/use_cases/get_scheduled_tasks_use_case.dart';
import 'dart:async';
import 'scheduled_tasks_state.dart';

final class ScheduledTasksCubit extends Cubit<ScheduledTasksState> {
  ScheduledTasksCubit({required this.getScheduledTasksUseCase})
    : super(const ScheduledTasksInitial());

  final GetScheduledTasksUseCase getScheduledTasksUseCase;

  Future<void> load({
    required String householdId,
    required DateTime day,
  }) async {
    emit(const ScheduledTasksLoading());

    try {
      final tasks =
          await getScheduledTasksUseCase(
            householdId: householdId,
            day: day,
          ).timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException('Supabase не ответил за 15 секунд.');
            },
          );

      AppLogger.info(
        'Запланированные задачи загружены: '
        'householdId=$householdId; '
        'count=${tasks.length}',
      );

      emit(ScheduledTasksLoaded(tasks: tasks));
    } catch (exception, stackTrace) {
      const message = 'Не удалось загрузить запланированные задачи.';

      AppLogger.error(message, error: exception, stackTrace: stackTrace);

      emit(const ScheduledTasksFailure(message: message));
    }
  }
}
