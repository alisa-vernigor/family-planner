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
  AppDatabase(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 1;
}
