import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/task_subtasks_table.dart';

part 'task_subtasks_dao.g.dart';

/// DAO for local cache of task subtasks.
@DriftAccessor(tables: [TaskSubtasks])
class TaskSubtasksDao extends DatabaseAccessor<AppDatabase>
    with _$TaskSubtasksDaoMixin {
  TaskSubtasksDao(super.db);

  /// All subtasks for a task, ordered by position.
  Future<List<TaskSubtask>> getForTask(String taskId) {
    return (select(taskSubtasks)
          ..where((s) => s.taskOccurrenceId.equals(taskId))
          ..orderBy([(s) => OrderingTerm(expression: s.position)]))
        .get();
  }

  /// One subtask by its own id.
  Future<TaskSubtask?> getById(String id) {
    return (select(taskSubtasks)..where((s) => s.id.equals(id)))
        .getSingleOrNull();
  }

  /// Insert or replace a subtask.
  Future<void> upsert(TaskSubtasksCompanion subtask) {
    return into(taskSubtasks).insertOnConflictUpdate(subtask);
  }

  /// Batch upsert subtasks.
  Future<void> upsertAll(List<TaskSubtasksCompanion> subtasks) {
    return batch((batch) {
      batch.insertAllOnConflictUpdate(taskSubtasks, subtasks);
    });
  }

  /// Remove a subtask.
  Future<void> deleteSubtask(String id) {
    return (delete(taskSubtasks)..where((s) => s.id.equals(id))).go();
  }

  /// Remove all subtasks for a task (when task is deleted).
  Future<void> clearForTask(String taskId) {
    return (delete(taskSubtasks)
          ..where((s) => s.taskOccurrenceId.equals(taskId)))
        .go();
  }
}
