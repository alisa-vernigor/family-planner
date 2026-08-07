import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/task_categories_table.dart';

part 'task_categories_dao.g.dart';

/// DAO for local cache of task categories.
@DriftAccessor(tables: [TaskCategories])
class TaskCategoriesDao extends DatabaseAccessor<AppDatabase>
    with _$TaskCategoriesDaoMixin {
  TaskCategoriesDao(super.db);

  /// All cached categories for a household.
  Future<List<TaskCategory>> getForHousehold(String householdId) {
    return (select(taskCategories)
          ..where((c) => c.householdId.equals(householdId))
          ..orderBy([(c) => OrderingTerm(expression: c.name)]))
        .get();
  }

  /// Insert or replace a category.
  Future<void> upsert(TaskCategoriesCompanion category) {
    return into(taskCategories).insertOnConflictUpdate(category);
  }

  /// Batch upsert categories.
  Future<void> upsertAll(List<TaskCategoriesCompanion> categories) {
    return batch((batch) {
      batch.insertAllOnConflictUpdate(taskCategories, categories);
    });
  }

  /// Remove a category.
  Future<void> deleteCategory(String id) {
    return (delete(taskCategories)..where((c) => c.id.equals(id))).go();
  }

  /// Remove all categories for a household.
  Future<void> clearHousehold(String householdId) {
    return (delete(taskCategories)
          ..where((c) => c.householdId.equals(householdId)))
        .go();
  }
}
