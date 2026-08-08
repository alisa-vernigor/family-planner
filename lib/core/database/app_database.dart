import 'package:drift/drift.dart';

import 'tables/task_occurrences_table.dart';
import 'tables/task_categories_table.dart';
import 'tables/task_subtasks_table.dart';
import 'tables/household_members_table.dart';
import 'tables/sync_queue_table.dart';
import 'daos/task_dao.dart';
import 'daos/sync_queue_dao.dart';
import 'daos/household_members_dao.dart';
import 'daos/task_categories_dao.dart';
import 'daos/task_subtasks_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    TaskOccurrences,
    TaskCategories,
    TaskSubtasks,
    HouseholdMembers,
    SyncQueue,
  ],
  daos: [
    TaskDao,
    TaskCategoriesDao,
    TaskSubtasksDao,
    SyncQueueDao,
    HouseholdMembersDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 6;

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
        if (from < 3) {
          // Reminders: за сколько минут до дедлайна/начала прислать напоминание.
          await migrator.addColumn(
            taskOccurrences,
            taskOccurrences.reminderMinutesBefore,
          );
        }
        if (from < 4) {
          // Категории и подзадачи: локальные кэши справочников.
          await migrator.createTable(taskCategories);
          await migrator.createTable(taskSubtasks);
          // category_id на task_occurrences — ссылка на категорию задачи.
          await migrator.addColumn(
            taskOccurrences,
            taskOccurrences.categoryId,
          );
        }
        if (from < 5) {
          // Время начала задачи (минуты от полуночи) для календарной шкалы.
          await migrator.addColumn(taskOccurrences, taskOccurrences.plannedTime);
        }
        if (from < 6) {
          // Пауза повторяющейся задачи: активна ли серия (task_templates.is_active).
          await migrator.addColumn(
            taskOccurrences,
            taskOccurrences.templateActive,
          );
        }
      },
    );
  }
}
