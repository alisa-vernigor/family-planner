import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:family_planner/core/logging/app_logger.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/tasks/domain/use_cases/uncomplete_task_use_case.dart';

import 'task_completion_state.dart';

final class TaskActionsCubit extends Cubit<TaskCompletionState> {
  TaskActionsCubit({
    required this.uncompleteTaskUseCase,
    required this.taskRepository,
  }) : super(const TaskCompletionInitial());

  final UncompleteTaskUseCase uncompleteTaskUseCase;
  final TaskRepository taskRepository;

  Future<Task?> uncompleteTask({required Task task}) async {
    emit(const TaskCompletionInProgress());

    try {
      final pendingTask = await uncompleteTaskUseCase(task: task);

      AppLogger.info('Выполнение задачи отменено: taskId=${task.id}');

      emit(const TaskCompletionInitial());

      return pendingTask;
    } catch (exception, stackTrace) {
      const message = 'Не удалось отменить выполнение.';

      AppLogger.error(message, error: exception, stackTrace: stackTrace);

      emit(TaskCompletionFailure(message: message));

      return null;
    }
  }

  Future<bool> deleteTask({required String taskId}) async {
    emit(const TaskCompletionInProgress());

    try {
      await taskRepository.delete(taskId: taskId);

      AppLogger.info('Задача удалена: taskId=$taskId');

      emit(const TaskCompletionInitial());

      return true;
    } catch (exception, stackTrace) {
      const message = 'Не удалось удалить задачу.';

      AppLogger.error(message, error: exception, stackTrace: stackTrace);

      emit(TaskCompletionFailure(message: message));

      return false;
    }
  }
}
