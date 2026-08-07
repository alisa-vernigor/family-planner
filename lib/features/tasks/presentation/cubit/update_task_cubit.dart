import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:family_planner/core/logging/app_logger.dart';
import 'package:family_planner/core/services/reminder_service.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/update_recurring_task_params.dart';
import 'package:family_planner/features/tasks/domain/use_cases/update_task_use_case.dart';

import 'update_task_state.dart';

final class UpdateTaskCubit extends Cubit<UpdateTaskState> {
  UpdateTaskCubit({required this.updateTaskUseCase})
    : super(const UpdateTaskInitial());

  final UpdateTaskUseCase updateTaskUseCase;

  Future<void> update({required Task task}) async {
    emit(const UpdateTaskInProgress());

    try {
      await updateTaskUseCase(task: task);

      AppLogger.info(
        'Задача отредактирована: '
        'taskId=${task.id}; householdId=${task.householdId}',
      );

      await _syncReminder(task);

      emit(UpdateTaskSuccess(task: task));
    } catch (exception, stackTrace) {
      const message = 'Не удалось сохранить изменения задачи.';

      AppLogger.error(message, error: exception, stackTrace: stackTrace);

      emit(const UpdateTaskFailure(message: message));
    }
  }

  /// Обновляет повторяющуюся задачу с выбранной областью применения.
  Future<void> updateTemplate({
    required UpdateRecurringTaskParams params,
  }) async {
    emit(const UpdateTaskInProgress());

    try {
      await updateTaskUseCase.updateRecurring(params: params);

      AppLogger.info(
        'Повторяющаяся задача обновлена: '
        'taskId=${params.task.id}; scope=${params.scope.databaseValue}',
      );

      // При редактировании серии напоминание переустанавливаем на экземпляр,
      // который редактировали (остальные экземпляры серии напоминаний не несут).
      await _syncReminder(params.task);

      emit(UpdateTaskSuccess(task: params.task));
    } catch (exception, stackTrace) {
      const message = 'Не удалось сохранить изменения повторяющейся задачи.';

      AppLogger.error(message, error: exception, stackTrace: stackTrace);

      emit(const UpdateTaskFailure(message: message));
    }
  }

  void reset() {
    emit(const UpdateTaskInitial());
  }

  /// Перенастраивает локальное напоминание под новое значение задачи.
  /// Сбой напоминания не должен ломать сохранение задачи.
  Future<void> _syncReminder(Task task) async {
    try {
      await ReminderService.instance.cancel(task.id);

      final minutesBefore = task.reminderMinutesBefore;
      if (minutesBefore != null) {
        await ReminderService.instance.schedule(
          taskId: task.id,
          title: task.title,
          scheduledFor: task.deadline ?? task.plannedFor,
          minutesBefore: minutesBefore,
        );
      }
    } catch (e) {
      AppLogger.warning(
        'Не удалось обновить напоминание: taskId=${task.id}: $e',
      );
    }
  }
}
