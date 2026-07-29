import 'package:drift/drift.dart';

/// Mirrors the `task_occurrences` Supabase table locally.
///
/// `allowedMemberIds` is stored as a JSON array string `["id1","id2"]`
/// to avoid a separate join table in the local cache.
class TaskOccurrences extends Table {
  TextColumn get id => text()();
  TextColumn get householdId => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  IntColumn get estimatedDurationMinutes => integer()();
  TextColumn get plannedFor => text()(); // ISO date YYYY-MM-DD
  TextColumn get deadline => text().nullable()(); // ISO datetime
  TextColumn get assignedMemberId => text().nullable()();
  TextColumn get pinnedMemberId => text().nullable()();
  TextColumn get status => text()(); // 'pending' | 'completed' | 'skipped'
  TextColumn get createdAt => text()(); // ISO datetime
  TextColumn get completedAt => text().nullable()(); // ISO datetime
  TextColumn get updatedAt => text().nullable()(); // ISO datetime
  IntColumn get priority => integer().nullable()();
  TextColumn get allowedMemberIds => text()(); // JSON array: '["id1","id2"]'

  @override
  Set<Column> get primaryKey => {id};
}
