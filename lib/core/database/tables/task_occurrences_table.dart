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
  IntColumn get plannedTime => integer().nullable()(); // minutes from midnight; null = whole day
  TextColumn get deadline => text().nullable()(); // ISO datetime
  TextColumn get assignedMemberId => text().nullable()();
  TextColumn get pinnedMemberId => text().nullable()();
  TextColumn get status => text()(); // 'pending' | 'completed' | 'skipped'
  TextColumn get createdAt => text()(); // ISO datetime
  TextColumn get completedAt => text().nullable()(); // ISO datetime
  TextColumn get updatedAt => text().nullable()(); // ISO datetime
  IntColumn get priority => integer().nullable()();
  TextColumn get allowedMemberIds => text()(); // JSON array: '["id1","id2"]'
  TextColumn get templateId => text().nullable()(); // task_templates.id (series)
  TextColumn get recurrenceType => text().nullable()(); // 'daily'|'weekly'|'interval_days'
  IntColumn get intervalDays => integer().nullable()();
  TextColumn get weekdays => text().nullable()(); // JSON array: '[1,3,5]'
  TextColumn get recurrenceStartDate => text().nullable()(); // ISO date
  TextColumn get recurrenceEndDate => text().nullable()(); // ISO date
  IntColumn get reminderMinutesBefore => integer().nullable()(); // minutes before deadline/start
  TextColumn get categoryId => text().nullable()(); // task_categories.id
  BoolColumn get templateActive => boolean().nullable()(); // task_templates.is_active; false = серия на паузе

  @override
  Set<Column> get primaryKey => {id};
}
