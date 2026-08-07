import 'package:drift/drift.dart';

/// Local cache of `task_categories` (mirrors Supabase table).
class TaskCategories extends Table {
  TextColumn get id => text()();
  TextColumn get householdId => text()();
  TextColumn get name => text()();
  TextColumn get colorHex => text().nullable()();
  TextColumn get iconName => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
