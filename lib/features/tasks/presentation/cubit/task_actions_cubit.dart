import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:family_planner/core/logging/app_logger.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/tasks/domain/use_cases/uncomplete_task_use_case.dart';

import 'task_action_state.dart';

final class TaskActionsCubit extends Cubit<TaskActionState> {
  TaskActionsCubit({
    required this.uncompleteTaskUseCase,
    required this.taskRepository,
  }) : super(const TaskActionInitial());

  final UncompleteTaskUseCase uncompleteTaskUseCase;
  final TaskRepository taskRepository;

  Future<Task?> uncompleteTask({required Task task}) async {
    emit(const TaskActionInProgress());

    try {
      final pendingTask = await uncompleteTaskUseCase(task: task);

      AppLogger.info('Выполнение задачи отменено: taskId=${task.id}');

      emit(const TaskActionInitial());

      return pendingTask;
    } catch (exception, stackTrace) {
      const message = 'Не удалось отменить выполнение.';

      AppLogger.error(message, error: exception, stackTrace: stackTrace);

      emit(TaskActionFailure(message: message));

      return null;
    }
  }

  Future<bool> deleteTask({required String taskId}) async {
    emit(const TaskActionInProgress());

    try {
      await taskRepository.delete(taskId: taskId);

      AppLogger.info('Задача удалена: taskId=$taskId');

      emit(const TaskActionInitial());

      return true;
    } catch (exception, stackTrace) {
      const message = 'Не удалось удалить задачу.';

      AppLogger.error(message, error: exception, stackTrace: stackTrace);

      emit(TaskActionFailure(message: message));

      return false;
    }
  }
}
