import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:family_planner/core/database/app_database.dart';
import 'package:family_planner/core/database/tables/task_categories_table.dart';
import 'package:family_planner/core/database/tables/task_subtasks_table.dart';
import 'package:family_planner/core/database/tables/task_occurrences_table.dart';

void main() {
  group('AppDatabase миграции', () {
    late Directory dir;
    late String dbPath;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('fp_migrate_test');
      dbPath = '${dir.path}/test.db';
    });

    tearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    /// Создаёт файл БД с заданным user_version (старая схема),
    /// затем открывает [AppDatabase] → срабатывает onUpgrade.
    AppDatabase openDbFromVersion(int version) {
      final db = sqlite.sqlite3.open(dbPath);
      // Схема версии 1: минимальная таблица task_occurrences (без
      // recurring/reminder/category/planned_time/template_active колонок).
      db.execute('''
        CREATE TABLE "task_occurrences" (
          "id" TEXT NOT NULL PRIMARY KEY,
          "household_id" TEXT NOT NULL,
          "title" TEXT NOT NULL,
          "description" TEXT,
          "estimated_duration_minutes" INTEGER NOT NULL,
          "planned_for" TEXT NOT NULL,
          "deadline" TEXT,
          "assigned_member_id" TEXT,
          "pinned_member_id" TEXT,
          "status" TEXT NOT NULL,
          "created_by_member_id" TEXT,
          "created_at" TEXT NOT NULL,
          "completed_at" TEXT,
          "updated_at" TEXT,
          "priority" INTEGER,
          "allowed_member_ids" TEXT NOT NULL
        )
      ''');
      db.execute('PRAGMA user_version = $version');
      db.dispose();

      return AppDatabase(NativeDatabase(File(dbPath)));
    }

    test('миграция 1→6: добавляет recurring-колонки', () async {
      final database = openDbFromVersion(1);
      await database.customStatement('SELECT 1');
      // Проверяем, что recurring-колонки есть в таблице.
      final columns = await database
          .customSelect('PRAGMA table_info(task_occurrences)')
          .get();
      final names = columns.map((r) => r.data['name']).toList();
      expect(names, contains('template_id'));
      expect(names, contains('recurrence_type'));
      expect(names, contains('interval_days'));
      expect(names, contains('weekdays'));
      expect(names, contains('recurrence_start_date'));
      expect(names, contains('recurrence_end_date'));
      await database.close();
    });

    test('миграция 2→6: добавляет reminder_minutes_before', () async {
      final database = openDbFromVersion(2);
      await database.customStatement('SELECT 1');
      final names = await database
          .customSelect('PRAGMA table_info(task_occurrences)')
          .get()
          .then((r) => r.map((c) => c.data['name']).toList());
      expect(names, contains('reminder_minutes_before'));
      await database.close();
    });

    test('миграция 3→6: создаёт таблицы категорий и подзадач + category_id', () async {
      final database = openDbFromVersion(3);
      await database.customStatement('SELECT 1');
      final names = await database
          .customSelect('PRAGMA table_info(task_occurrences)')
          .get()
          .then((r) => r.map((c) => c.data['name']).toList());
      expect(names, contains('category_id'));
      // Таблицы созданы.
      final tables = await database
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table'",
          )
          .get()
          .then((r) => r.map((c) => c.data['name']).toList());
      expect(tables, contains('task_categories'));
      expect(tables, contains('task_subtasks'));
      await database.close();
    });

    test('миграция 4→6: добавляет planned_time', () async {
      final database = openDbFromVersion(4);
      await database.customStatement('SELECT 1');
      final names = await database
          .customSelect('PRAGMA table_info(task_occurrences)')
          .get()
          .then((r) => r.map((c) => c.data['name']).toList());
      expect(names, contains('planned_time'));
      await database.close();
    });

    test('миграция 5→6: добавляет template_active', () async {
      final database = openDbFromVersion(5);
      await database.customStatement('SELECT 1');
      final names = await database
          .customSelect('PRAGMA table_info(task_occurrences)')
          .get()
          .then((r) => r.map((c) => c.data['name']).toList());
      expect(names, contains('template_active'));
      await database.close();
    });

    test('свежая БД (version 0) открывается без onUpgrade', () async {
      final database = AppDatabase(NativeDatabase.memory());
      await database.customStatement('SELECT 1');
      // Таблицы уже созданы из схемы.
      await database.into(database.taskOccurrences).insert(
            TaskOccurrencesCompanion.insert(
              id: 'task-x',
              householdId: 'household-1',
              title: 'T',
              estimatedDurationMinutes: 30,
              plannedFor: '2026-08-09',
              status: 'pending',
              createdAt: '2026-08-09T08:00:00Z',
              allowedMemberIds: '["member-1"]',
            ),
          );
      await database.close();
    });
  });
}
