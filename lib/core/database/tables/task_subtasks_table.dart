import 'package:drift/drift.dart';

/// Local cache of `task_subtasks` (mirrors Supabase table).
class TaskSubtasks extends Table {
  TextColumn get id => text()();
  TextColumn get taskOccurrenceId => text()();
  TextColumn get title => text()();
  IntColumn get position => integer()();
  BoolColumn get isCompleted => boolean()();
  TextColumn get completedAt => text().nullable()(); // ISO datetime
  TextColumn get createdAt => text()(); // ISO datetime

  @override
  Set<Column> get primaryKey => {id};
}
