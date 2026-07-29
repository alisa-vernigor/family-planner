import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/task_occurrences_table.dart';

part 'task_dao.g.dart';

/// DAO for reading/writing tasks in the local SQLite database.
///
/// All reads come from here. Writes also enqueue sync operations
/// via [SyncQueueDao].
@DriftAccessor(tables: [TaskOccurrences])
class TaskDao extends DatabaseAccessor<AppDatabase> with _$TaskDaoMixin {
  TaskDao(super.db);

  // ── Queries ───────────────────────────────────────────────

  /// Stream of tasks for a specific household and day (planned_for date).
  /// Automatically re-emits when underlying data changes.
  Stream<List<TaskOccurrence>> watchTasksForDay(
    String householdId,
    String plannedFor,
  ) {
    return (select(taskOccurrences)
          ..where((t) => t.householdId.equals(householdId))
          ..where((t) => t.plannedFor.equals(plannedFor))
          ..orderBy([(t) => OrderingTerm(expression: t.deadline)]))
        .watch();
  }

  /// Stream of all non-completed tasks for a household (for ScheduledPage).
  Stream<List<TaskOccurrence>> watchAllPending(String householdId) {
    return (select(taskOccurrences)
          ..where((t) => t.householdId.equals(householdId))
          ..where((t) => t.status.equals('pending'))
          ..orderBy([
            (t) => OrderingTerm(expression: t.plannedFor),
            (t) => OrderingTerm(expression: t.deadline),
          ]))
        .watch();
  }

  /// One-shot: get a task by its UUID.
  Future<TaskOccurrence?> getTaskById(String id) {
    return (select(taskOccurrences)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// One-shot: get all pending tasks (non-completed) for a household.
  Future<List<TaskOccurrence>> getAllPending(String householdId) {
    return (select(taskOccurrences)
          ..where((t) => t.householdId.equals(householdId))
          ..where((t) => t.status.equals('pending'))
          ..orderBy([
            (t) => OrderingTerm(expression: t.plannedFor),
            (t) => OrderingTerm(expression: t.deadline),
          ]))
        .get();
  }

  /// One-shot: get all tasks for a specific day.
  Future<List<TaskOccurrence>> getForDay(
    String householdId,
    String plannedFor,
  ) {
    return (select(taskOccurrences)
          ..where((t) => t.householdId.equals(householdId))
          ..where((t) => t.plannedFor.equals(plannedFor)))
        .get();
  }

  /// One-shot: get tasks planned on or after a given date.
  Future<List<TaskOccurrence>> getScheduledAfter(
    String householdId,
    String plannedFor,
  ) {
    return (select(taskOccurrences)
          ..where((t) => t.householdId.equals(householdId))
          ..where((t) => t.plannedFor.isBiggerThanValue(plannedFor))
          ..where((t) => t.status.equals('pending'))
          ..orderBy([
            (t) => OrderingTerm(expression: t.plannedFor),
            (t) => OrderingTerm(expression: t.deadline),
          ]))
        .get();
  }

  /// Check if there are any tasks for this household (for initial sync).
  Future<bool> hasTasksForHousehold(String householdId) {
    return (select(taskOccurrences)
          ..where((t) => t.householdId.equals(householdId))
          ..limit(1))
        .get()
        .then((rows) => rows.isNotEmpty);
  }

  // ── Mutations ─────────────────────────────────────────────

  /// Insert or replace a task occurrence.
  Future<void> upsertTask(TaskOccurrencesCompanion task) {
    return into(taskOccurrences).insertOnConflictUpdate(task);
  }

  /// Batch upsert — used after initial sync or realtime updates.
  Future<void> upsertTasks(List<TaskOccurrencesCompanion> tasks) {
    return batch((batch) {
      batch.insertAllOnConflictUpdate(taskOccurrences, tasks);
    });
  }

  /// Delete a task by id.
  Future<void> deleteTask(String id) {
    return (delete(taskOccurrences)..where((t) => t.id.equals(id))).go();
  }

  /// Remove all task data for a household (used before full re-sync).
  Future<void> clearHousehold(String householdId) {
    return (delete(taskOccurrences)
          ..where((t) => t.householdId.equals(householdId)))
        .go();
  }

  /// Remove all tasks for a household and planned_for date.
  Future<void> clearDay(String householdId, String plannedFor) {
    return (delete(taskOccurrences)
          ..where((t) => t.householdId.equals(householdId))
          ..where((t) => t.plannedFor.equals(plannedFor)))
        .go();
  }
}
