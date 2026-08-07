import '../entities/create_task_subtask_params.dart';
import '../entities/task_subtask.dart';

/// Абстрактный контракт работы с подзадачами.
///
/// Подзадачи привязаны к конкретной задаче (`task_occurrence`).
abstract interface class TaskSubtaskRepository {
  /// Все подзадачи задачи, отсортированные по позиции.
  Future<List<TaskSubtask>> getForTask(String taskId);

  /// Создать подзадачу (в конец списка).
  Future<TaskSubtask> create(CreateTaskSubtaskParams params);

  /// Переключить выполнение подзадачи (complete/uncomplete).
  Future<TaskSubtask> toggle(String subtaskId, bool isCompleted);

  /// Изменить название.
  Future<TaskSubtask> updateTitle(String subtaskId, String title);

  /// Переставить подзадачи (новый порядок по id).
  Future<void> reorder(String taskId, List<String> orderedIds);

  /// Удалить подзадачу.
  Future<void> delete(String subtaskId);
}
