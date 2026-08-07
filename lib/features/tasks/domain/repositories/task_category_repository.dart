import '../entities/create_task_category_params.dart';
import '../entities/task_category.dart';

/// Абстрактный контракт работы с категориями задач.
abstract interface class TaskCategoryRepository {
  /// Все категории семьи.
  Future<List<TaskCategory>> getForHousehold(String householdId);

  /// Создать категорию. Возвращает созданную категорию.
  Future<TaskCategory> create(CreateTaskCategoryParams params);

  /// Переименовать/перекрасить категорию.
  Future<void> update(TaskCategory category);

  /// Удалить категорию (задачи получат category_id = null).
  Future<void> delete(String categoryId);
}
