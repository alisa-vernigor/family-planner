import 'package:drift/drift.dart';

import 'tables/task_occurrences_table.dart';
import 'tables/household_members_table.dart';
import 'tables/sync_queue_table.dart';
import 'daos/task_dao.dart';
import 'daos/sync_queue_dao.dart';
import 'daos/household_members_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    TaskOccurrences,
    HouseholdMembers,
    SyncQueue,
  ],
  daos: [
    TaskDao,
    SyncQueueDao,
    HouseholdMembersDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onUpgrade: (migrator, from, to) async {
        if (from < 2) {
          // Recurrence editing: кэш повторяющихся задач хранит шаблон серии.
          await migrator.addColumn(taskOccurrences, taskOccurrences.templateId);
          await migrator.addColumn(taskOccurrences, taskOccurrences.recurrenceType);
          await migrator.addColumn(taskOccurrences, taskOccurrences.intervalDays);
          await migrator.addColumn(taskOccurrences, taskOccurrences.weekdays);
          await migrator.addColumn(
            taskOccurrences,
            taskOccurrences.recurrenceStartDate,
          );
          await migrator.addColumn(
            taskOccurrences,
            taskOccurrences.recurrenceEndDate,
          );
        }
      },
    );
  }
}
