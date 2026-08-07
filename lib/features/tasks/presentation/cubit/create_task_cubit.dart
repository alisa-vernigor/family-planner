import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:family_planner/core/logging/app_logger.dart';
import 'package:family_planner/core/services/reminder_service.dart';
import 'package:family_planner/features/tasks/domain/entities/create_task_params.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/use_cases/create_task_use_case.dart';

import 'create_task_state.dart';

final class CreateTaskCubit extends Cubit<CreateTaskState> {
  CreateTaskCubit({required this.createTaskUseCase})
    : super(const CreateTaskInitial());

  final CreateTaskUseCase createTaskUseCase;

  void reset() => emit(const CreateTaskInitial());

  Future<void> create({required CreateTaskParams params}) async {
    emit(const CreateTaskInProgress());

    try {
      final task = await createTaskUseCase(params: params);

      AppLogger.info(
        'Задача создана: '
        'taskId=${task.id}; householdId=${task.householdId}',
      );

      // Напоминание планируем отдельно — его сбой не должен ломать создание.
      await _scheduleReminder(task);

      emit(CreateTaskSuccess(task: task));
    } catch (exception, stackTrace) {
      const message = 'Не удалось создать задачу.';

      AppLogger.error(message, error: exception, stackTrace: stackTrace);

      emit(const CreateTaskFailure(message: message));
    }
  }

  Future<void> _scheduleReminder(Task task) async {
    final minutesBefore = task.reminderMinutesBefore;
    if (minutesBefore == null) return;

    try {
      await ReminderService.instance.schedule(
        taskId: task.id,
        title: task.title,
        scheduledFor: task.deadline ?? task.plannedFor,
        minutesBefore: minutesBefore,
      );
    } catch (e) {
      AppLogger.warning(
        'Не удалось запланировать напоминание: taskId=${task.id}: $e',
      );
    }
  }
}
