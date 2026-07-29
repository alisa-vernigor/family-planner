import 'dart:convert';

import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/sync_queue_table.dart';

part 'sync_queue_dao.g.dart';

/// DAO for the sync queue — persistent mutation queue for offline-first support.
///
/// Every write operation (create, update, delete, etc.) enqueues a record here
/// so the [SyncProcessor] can replay it against Supabase when connectivity resumes.
@DriftAccessor(tables: [SyncQueue])
class SyncQueueDao extends DatabaseAccessor<AppDatabase> with _$SyncQueueDaoMixin {
  SyncQueueDao(super.db);

  // ── Enqueue ───────────────────────────────────────────────

  /// Add a mutation to the sync queue.
  Future<void> enqueue({
    required String entityType,
    required String operation,
    required String entityId,
    required String householdId,
    required Map<String, dynamic> payload,
  }) async {
    await into(syncQueue).insert(SyncQueueCompanion(
      entityType: Value(entityType),
      operation: Value(operation),
      entityId: Value(entityId),
      householdId: Value(householdId),
      payload: Value(jsonEncode(payload)),
      createdAt: Value(DateTime.now()),
    ));
  }

  // ── Read ──────────────────────────────────────────────────

  /// All pending (unprocessed) queue entries, in FIFO order.
  Future<List<SyncQueueData>> getPending() {
    return (select(syncQueue)..orderBy([(q) => OrderingTerm(expression: q.createdAt)]))
        .get();
  }

  /// Count of pending entries for a specific household.
  Future<int> getPendingCount(String householdId) {
    return (select(syncQueue)
          ..where((q) => q.householdId.equals(householdId)))
        .get()
        .then((rows) => rows.length);
  }

  /// Whether there are any pending operations at all.
  Future<bool> hasPendingOperations() {
    return (select(syncQueue)..limit(1))
        .get()
        .then((rows) => rows.isNotEmpty);
  }

  /// Get all entity IDs with pending operations for a household.
  Future<Set<String>> getPendingIds(String householdId) {
    return (select(syncQueue)
          ..where((q) => q.householdId.equals(householdId)))
        .get()
        .then((rows) => rows.map((r) => r.entityId).toSet());
  }

  // ── Update / Delete ───────────────────────────────────────

  /// Mark a queue entry as failed — increment retry count, record error.
  Future<void> markFailed(int id, String error) async {
    final entry = await (select(syncQueue)..where((q) => q.id.equals(id)))
        .getSingleOrNull();
    if (entry == null) return;
    await (update(syncQueue)..where((q) => q.id.equals(id))).write(
      SyncQueueCompanion(
        retryCount: Value(entry.retryCount + 1),
        lastError: Value(error),
        lastAttemptAt: Value(DateTime.now()),
      ),
    );
  }

  /// Remove a processed entry from the queue.
  Future<void> deleteProcessed(int id) {
    return (delete(syncQueue)..where((q) => q.id.equals(id))).go();
  }

  /// Clear all queue entries for a household (used when leaving a household).
  Future<void> clearHousehold(String householdId) {
    return (delete(syncQueue)..where((q) => q.householdId.equals(householdId)))
        .go();
  }

  /// Clear all queue entries.
  Future<void> clearAll() {
    return delete(syncQueue).go();
  }
}
