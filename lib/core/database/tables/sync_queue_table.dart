import 'package:drift/drift.dart';

/// Persistent queue of mutations that haven't been synced to Supabase yet.
///
/// Each row represents one atomic operation (CREATE / UPDATE / DELETE / etc.)
/// against one entity. The queue is processed in FIFO order when connectivity
/// is restored.
class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityType => text()(); // 'task_occurrence'
  TextColumn get operation => text()(); // 'CREATE'|'UPDATE'|'DELETE'|'PATCH_STATUS'|'ADD_ALLOWED'|'REMOVE_ALLOWED'
  TextColumn get entityId => text()(); // UUID of the affected entity
  TextColumn get householdId => text()(); // for filtering per household
  TextColumn get payload => text()(); // JSON with operation data
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
}
