import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:family_planner/core/logging/app_logger.dart';
import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/households/domain/repositories/household_repository.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/use_cases/get_all_pending_tasks_use_case.dart';
import 'dart:async';
import 'scheduled_tasks_state.dart';

final class ScheduledTasksCubit extends Cubit<ScheduledTasksState> {
  ScheduledTasksCubit({
    required this.getAllPendingTasksUseCase,
    required this.householdRepository,
  }) : super(const ScheduledTasksInitial());

  final GetAllPendingTasksUseCase getAllPendingTasksUseCase;
  final HouseholdRepository householdRepository;

  Future<void> load({
    required String householdId,
  }) async {
    emit(const ScheduledTasksLoading());

    try {
      final tasksFuture = getAllPendingTasksUseCase(
        householdId: householdId,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Supabase не ответил за 15 секунд.');
        },
      );
      final membersFuture = householdRepository.getMembers(
        householdId: householdId,
      );

      final results = await Future.wait([tasksFuture, membersFuture]);
      final tasks = results[0] as List<Task>;
      final members = results[1] as List<HouseholdMember>;

      AppLogger.info(
        'Все невыполненные задачи загружены: '
        'householdId=$householdId; '
        'count=${tasks.length}',
      );

      emit(ScheduledTasksLoaded(tasks: tasks, members: members));
    } catch (exception, stackTrace) {
      const message = 'Не удалось загрузить запланированные задачи.';

      AppLogger.error(message, error: exception, stackTrace: stackTrace);

      emit(const ScheduledTasksFailure(message: message));
    }
  }
}
