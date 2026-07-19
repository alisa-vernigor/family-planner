import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/task.dart';
import '../../domain/use_cases/complete_task_use_case.dart';
import 'task_completion_state.dart';

final class TaskCompletionCubit extends Cubit<TaskCompletionState> {
  TaskCompletionCubit({required this.completeTaskUseCase})
    : super(const TaskCompletionInitial());

  final CompleteTaskUseCase completeTaskUseCase;

  Future<void> completeTask({
    required Task task,
    required String memberId,
  }) async {
    emit(const TaskCompletionInProgress());

    try {
      final completedTask = await completeTaskUseCase(
        task: task,
        memberId: memberId,
      );

      AppLogger.info(
        'Задача выполнена: taskId=${completedTask.id}; '
        'memberId=$memberId',
      );

      emit(TaskCompletionSuccess(task: completedTask));
    } on TaskAlreadyCompletedException {
      const message = 'Эта задача уже была выполнена.';
      AppLogger.warning(message);
      emit(const TaskCompletionFailure(message: message));
    } on TaskCompletionNotAllowedException catch (exception) {
      const message = 'У вас нет права выполнить эту задачу.';
      AppLogger.warning(
        '$message taskId=${exception.taskId}; memberId=${exception.memberId}',
      );
      emit(const TaskCompletionFailure(message: message));
    } catch (exception, stackTrace) {
      const message = 'Не удалось отметить задачу выполненной.';
      AppLogger.error(message, error: exception, stackTrace: stackTrace);
      emit(const TaskCompletionFailure(message: message));
    }
  }
}
