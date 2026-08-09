import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/core/database/app_database.dart';
import 'package:family_planner/core/database/tables/household_members_table.dart';
import 'package:family_planner/core/database/tables/sync_queue_table.dart';
import 'package:family_planner/core/database/tables/task_categories_table.dart';
import 'package:family_planner/core/database/tables/task_occurrences_table.dart';
import 'package:family_planner/core/database/tables/task_subtasks_table.dart';

AppDatabase _createTestDb() => AppDatabase(NativeDatabase.memory());

void main() {
  group('SyncQueue table', () {
    late AppDatabase database;

    setUp(() => database = _createTestDb());
    tearDown(() => database.close());

    test('вставляются и читаются все колонки', () async {
      final createdAt = DateTime.utc(2026, 8, 9, 10, 0, 0);
      await database.into(database.syncQueue).insert(
            SyncQueueCompanion.insert(
              entityType: 'task_occurrence',
              operation: 'CREATE',
              entityId: 'task-1',
              householdId: 'household-1',
              payload: '{"title":"Купить молоко"}',
              createdAt: createdAt,
            ),
          );

      final rows = await database.select(database.syncQueue).get();
      expect(rows, hasLength(1));

      final row = rows.single;
      expect(row.id, greaterThan(0));
      expect(row.entityType, 'task_occurrence');
      expect(row.operation, 'CREATE');
      expect(row.entityId, 'task-1');
      expect(row.householdId, 'household-1');
      expect(row.payload, '{"title":"Купить молоко"}');
      expect(row.retryCount, 0, reason: 'retryCount имеет DEFAULT 0');
      expect(row.lastError, isNull);
      expect(row.createdAt.millisecondsSinceEpoch,
          createdAt.millisecondsSinceEpoch);
      expect(row.lastAttemptAt, isNull);
    });

    test('nullable lastError/lastAttemptAt и retryCount записываются', () async {
      final createdAt = DateTime.utc(2026, 8, 9);
      final lastAttempt = DateTime.utc(2026, 8, 9, 12);
      await database.into(database.syncQueue).insert(
            SyncQueueCompanion.insert(
              entityType: 'task_occurrence',
              operation: 'PATCH_STATUS',
              entityId: 'task-2',
              householdId: 'household-1',
              payload: '{}',
              createdAt: createdAt,
            ).copyWith(
              retryCount: const Value(3),
              lastError: const Value('boom'),
              lastAttemptAt: Value(lastAttempt),
            ),
          );

      final row = await database.select(database.syncQueue).getSingle();
      expect(row.retryCount, 3);
      expect(row.lastError, 'boom');
      expect(row.lastAttemptAt!.millisecondsSinceEpoch,
          lastAttempt.millisecondsSinceEpoch);
    });

    test('id autoincrement растёт', () async {
      final createdAt = DateTime.utc(2026, 8, 9);
      await database.into(database.syncQueue).insert(
            SyncQueueCompanion.insert(
              entityType: 'task_occurrence',
              operation: 'CREATE',
              entityId: 'task-1',
              householdId: 'household-1',
              payload: '{}',
              createdAt: createdAt,
            ),
          );
      await database.into(database.syncQueue).insert(
            SyncQueueCompanion.insert(
              entityType: 'task_occurrence',
              operation: 'DELETE',
              entityId: 'task-1',
              householdId: 'household-1',
              payload: '{}',
              createdAt: createdAt,
            ),
          );

      final rows = await database.select(database.syncQueue).get();
      expect(rows.last.id, rows.first.id + 1);
    });

    test('удаление записи', () async {
      final createdAt = DateTime.utc(2026, 8, 9);
      await database.into(database.syncQueue).insert(
            SyncQueueCompanion.insert(
              entityType: 'task_occurrence',
              operation: 'CREATE',
              entityId: 'task-1',
              householdId: 'household-1',
              payload: '{}',
              createdAt: createdAt,
            ),
          );
      final row = await database.select(database.syncQueue).getSingle();
      await database.delete(database.syncQueue).go();
      expect(await database.select(database.syncQueue).get(), isEmpty);
      expect(row.operation, 'CREATE');
    });
  });

  group('TaskOccurrences table', () {
    late AppDatabase database;

    setUp(() => database = _createTestDb());
    tearDown(() => database.close());

    test('вставляются и читаются все колонки', () async {
      await database.into(database.taskOccurrences).insert(
            TaskOccurrencesCompanion.insert(
              id: 'task-full',
              householdId: 'household-1',
              title: 'Полная задача',
              description: const Value('описание'),
              estimatedDurationMinutes: 45,
              plannedFor: '2026-08-09',
              plannedTime: const Value(9 * 60 + 30),
              deadline: const Value('2026-08-09T18:00:00Z'),
              assignedMemberId: const Value('member-1'),
              pinnedMemberId: const Value('member-2'),
              status: 'pending',
              createdAt: '2026-08-09T08:00:00Z',
              completedAt: const Value(null),
              updatedAt: const Value('2026-08-09T08:00:00Z'),
              priority: const Value(2),
              allowedMemberIds: '["member-1","member-2"]',
              templateId: const Value('template-1'),
              recurrenceType: const Value('weekly'),
              intervalDays: const Value(null),
              weekdays: const Value('[1,3,5]'),
              recurrenceStartDate: const Value('2026-08-09'),
              recurrenceEndDate: const Value('2026-09-09'),
              reminderMinutesBefore: const Value(30),
              categoryId: const Value('category-1'),
              templateActive: const Value(true),
            ),
          );

      final row = await database
          .select(database.taskOccurrences)
          .getSingle();

      expect(row.id, 'task-full');
      expect(row.householdId, 'household-1');
      expect(row.title, 'Полная задача');
      expect(row.description, 'описание');
      expect(row.estimatedDurationMinutes, 45);
      expect(row.plannedFor, '2026-08-09');
      expect(row.plannedTime, 9 * 60 + 30);
      expect(row.deadline, '2026-08-09T18:00:00Z');
      expect(row.assignedMemberId, 'member-1');
      expect(row.pinnedMemberId, 'member-2');
      expect(row.status, 'pending');
      expect(row.createdAt, '2026-08-09T08:00:00Z');
      expect(row.completedAt, isNull);
      expect(row.updatedAt, '2026-08-09T08:00:00Z');
      expect(row.priority, 2);
      expect(row.allowedMemberIds, '["member-1","member-2"]');
      expect(row.templateId, 'template-1');
      expect(row.recurrenceType, 'weekly');
      expect(row.intervalDays, isNull);
      expect(row.weekdays, '[1,3,5]');
      expect(row.recurrenceStartDate, '2026-08-09');
      expect(row.recurrenceEndDate, '2026-09-09');
      expect(row.reminderMinutesBefore, 30);
      expect(row.categoryId, 'category-1');
      expect(row.templateActive, isTrue);
    });

    test('nullable колонки остаются null', () async {
      await database.into(database.taskOccurrences).insert(
            TaskOccurrencesCompanion.insert(
              id: 'task-min',
              householdId: 'household-1',
              title: 'Минимальная',
              estimatedDurationMinutes: 5,
              plannedFor: '2026-08-09',
              status: 'pending',
              createdAt: '2026-08-09T08:00:00Z',
              allowedMemberIds: '[]',
            ),
          );

      final row = await database
          .select(database.taskOccurrences)
          .getSingle();

      expect(row.description, isNull);
      expect(row.plannedTime, isNull);
      expect(row.deadline, isNull);
      expect(row.assignedMemberId, isNull);
      expect(row.pinnedMemberId, isNull);
      expect(row.completedAt, isNull);
      expect(row.updatedAt, isNull);
      expect(row.priority, isNull);
      expect(row.templateId, isNull);
      expect(row.recurrenceType, isNull);
      expect(row.intervalDays, isNull);
      expect(row.weekdays, isNull);
      expect(row.recurrenceStartDate, isNull);
      expect(row.recurrenceEndDate, isNull);
      expect(row.reminderMinutesBefore, isNull);
      expect(row.categoryId, isNull);
      expect(row.templateActive, isNull);
    });

    test('primary key id уникален — повторный insert конфликтует', () async {
      await database.into(database.taskOccurrences).insert(
            TaskOccurrencesCompanion.insert(
              id: 'dup',
              householdId: 'household-1',
              title: 'Первый',
              estimatedDurationMinutes: 5,
              plannedFor: '2026-08-09',
              status: 'pending',
              createdAt: '2026-08-09T08:00:00Z',
              allowedMemberIds: '[]',
            ),
          );

      expect(
        () => database.into(database.taskOccurrences).insert(
              TaskOccurrencesCompanion.insert(
                id: 'dup',
                householdId: 'household-1',
                title: 'Второй',
                estimatedDurationMinutes: 5,
                plannedFor: '2026-08-09',
                status: 'pending',
                createdAt: '2026-08-09T08:00:00Z',
                allowedMemberIds: '[]',
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('update обновляет поля', () async {
      await database.into(database.taskOccurrences).insert(
            TaskOccurrencesCompanion.insert(
              id: 'task-1',
              householdId: 'household-1',
              title: 'Старое название',
              estimatedDurationMinutes: 5,
              plannedFor: '2026-08-09',
              status: 'pending',
              createdAt: '2026-08-09T08:00:00Z',
              allowedMemberIds: '[]',
            ),
          );

      await (database.update(database.taskOccurrences)
            ..where((t) => t.id.equals('task-1')))
          .write(const TaskOccurrencesCompanion(status: Value('completed')));

      final row = await database.select(database.taskOccurrences).getSingle();
      expect(row.status, 'completed');
      expect(row.title, 'Старое название');
    });
  });

  group('HouseholdMembers table', () {
    late AppDatabase database;

    setUp(() => database = _createTestDb());
    tearDown(() => database.close());

    test('вставляются и читаются все колонки', () async {
      await database.into(database.householdMembers).insert(
            HouseholdMembersCompanion.insert(
              profileId: 'profile-1',
              householdId: 'household-1',
              displayName: 'Алиса',
              avatarUrl: const Value('https://example.com/a.png'),
              role: 'owner',
            ),
          );

      final row = await database.select(database.householdMembers).getSingle();
      expect(row.profileId, 'profile-1');
      expect(row.householdId, 'household-1');
      expect(row.displayName, 'Алиса');
      expect(row.avatarUrl, 'https://example.com/a.png');
      expect(row.role, 'owner');
    });

    test('avatarUrl nullable', () async {
      await database.into(database.householdMembers).insert(
            HouseholdMembersCompanion.insert(
              profileId: 'profile-1',
              householdId: 'household-1',
              displayName: 'Боб',
              role: 'member',
            ),
          );

      final row = await database.select(database.householdMembers).getSingle();
      expect(row.avatarUrl, isNull);
    });

    test('composite PK (profileId, householdId) — повторный insert конфликтует',
        () async {
      await database.into(database.householdMembers).insert(
            HouseholdMembersCompanion.insert(
              profileId: 'profile-1',
              householdId: 'household-1',
              displayName: 'Алиса',
              role: 'owner',
            ),
          );

      expect(
        () => database.into(database.householdMembers).insert(
              HouseholdMembersCompanion.insert(
                profileId: 'profile-1',
                householdId: 'household-1',
                displayName: 'Дубликат',
                role: 'member',
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    });
  });

  group('TaskCategories table', () {
    late AppDatabase database;

    setUp(() => database = _createTestDb());
    tearDown(() => database.close());

    test('вставляются и читаются все колонки', () async {
      await database.into(database.taskCategories).insert(
            TaskCategoriesCompanion.insert(
              id: 'cat-1',
              householdId: 'household-1',
              name: 'Дом',
              colorHex: const Value('#FF0000'),
              iconName: const Value('home'),
            ),
          );

      final row = await database.select(database.taskCategories).getSingle();
      expect(row.id, 'cat-1');
      expect(row.householdId, 'household-1');
      expect(row.name, 'Дом');
      expect(row.colorHex, '#FF0000');
      expect(row.iconName, 'home');
    });

    test('colorHex/iconName nullable', () async {
      await database.into(database.taskCategories).insert(
            TaskCategoriesCompanion.insert(
              id: 'cat-2',
              householdId: 'household-1',
              name: 'Без цвета',
            ),
          );

      final row = await database.select(database.taskCategories).getSingle();
      expect(row.colorHex, isNull);
      expect(row.iconName, isNull);
    });
  });

  group('TaskSubtasks table', () {
    late AppDatabase database;

    setUp(() => database = _createTestDb());
    tearDown(() => database.close());

    test('вставляются и читаются все колонки', () async {
      await database.into(database.taskSubtasks).insert(
            TaskSubtasksCompanion.insert(
              id: 'subtask-1',
              taskOccurrenceId: 'task-1',
              title: 'Подзадача',
              position: 0,
              isCompleted: true,
              completedAt: const Value('2026-08-09T12:00:00Z'),
              createdAt: '2026-08-09T08:00:00Z',
            ),
          );

      final row = await database.select(database.taskSubtasks).getSingle();
      expect(row.id, 'subtask-1');
      expect(row.taskOccurrenceId, 'task-1');
      expect(row.title, 'Подзадача');
      expect(row.position, 0);
      expect(row.isCompleted, isTrue);
      expect(row.completedAt, '2026-08-09T12:00:00Z');
      expect(row.createdAt, '2026-08-09T08:00:00Z');
    });

    test('completedAt nullable и isCompleted false', () async {
      await database.into(database.taskSubtasks).insert(
            TaskSubtasksCompanion.insert(
              id: 'subtask-2',
              taskOccurrenceId: 'task-1',
              title: 'Не готова',
              position: 1,
              isCompleted: false,
              createdAt: '2026-08-09T08:00:00Z',
            ),
          );

      final row = await database.select(database.taskSubtasks).getSingle();
      expect(row.isCompleted, isFalse);
      expect(row.completedAt, isNull);
    });
  });

  // Базовые классы таблиц (lib/core/database/tables/*.dart) — это build-time
  // DSL для генератора. В runtime колоночные геттеры (например `text()()`
  // внутри `get id => ...`) бросают UnsupportedError — их тело переписано
  // кодогенерацией в сгенерированном `$Table`-подклассе. Эти тесты фиксируют
  // guard-поведение и покрывают базовые классы, до которых иначе не добраться.
  group('Base table DSL classes (build-time only)', () {
    test('SyncQueue: геттеры колонок не вызываются в runtime', () {
      final table = SyncQueue();
      expect(() => table.id, throwsUnsupportedError);
      expect(() => table.entityType, throwsUnsupportedError);
      expect(() => table.operation, throwsUnsupportedError);
      expect(() => table.entityId, throwsUnsupportedError);
      expect(() => table.householdId, throwsUnsupportedError);
      expect(() => table.payload, throwsUnsupportedError);
      expect(() => table.retryCount, throwsUnsupportedError);
      expect(() => table.lastError, throwsUnsupportedError);
      expect(() => table.createdAt, throwsUnsupportedError);
      expect(() => table.lastAttemptAt, throwsUnsupportedError);
    });
    test('TaskOccurrences: primaryKey недоступен в runtime (генератор override)', () {
      expect(() => TaskOccurrences().primaryKey, throwsUnsupportedError);
    });

    test('TaskOccurrences: геттеры колонок не вызываются в runtime', () {
      final table = TaskOccurrences();
      expect(() => table.id, throwsUnsupportedError);
      expect(() => table.householdId, throwsUnsupportedError);
      expect(() => table.title, throwsUnsupportedError);
      expect(() => table.description, throwsUnsupportedError);
      expect(() => table.estimatedDurationMinutes, throwsUnsupportedError);
      expect(() => table.plannedFor, throwsUnsupportedError);
      expect(() => table.plannedTime, throwsUnsupportedError);
      expect(() => table.deadline, throwsUnsupportedError);
      expect(() => table.assignedMemberId, throwsUnsupportedError);
      expect(() => table.pinnedMemberId, throwsUnsupportedError);
      expect(() => table.status, throwsUnsupportedError);
      expect(() => table.createdAt, throwsUnsupportedError);
      expect(() => table.completedAt, throwsUnsupportedError);
      expect(() => table.updatedAt, throwsUnsupportedError);
      expect(() => table.priority, throwsUnsupportedError);
      expect(() => table.allowedMemberIds, throwsUnsupportedError);
      expect(() => table.templateId, throwsUnsupportedError);
      expect(() => table.recurrenceType, throwsUnsupportedError);
      expect(() => table.intervalDays, throwsUnsupportedError);
      expect(() => table.weekdays, throwsUnsupportedError);
      expect(() => table.recurrenceStartDate, throwsUnsupportedError);
      expect(() => table.recurrenceEndDate, throwsUnsupportedError);
      expect(() => table.reminderMinutesBefore, throwsUnsupportedError);
      expect(() => table.categoryId, throwsUnsupportedError);
      expect(() => table.templateActive, throwsUnsupportedError);
    });

    test('HouseholdMembers: геттеры колонок не вызываются в runtime', () {
      final table = HouseholdMembers();
      expect(() => table.profileId, throwsUnsupportedError);
      expect(() => table.householdId, throwsUnsupportedError);
      expect(() => table.displayName, throwsUnsupportedError);
      expect(() => table.avatarUrl, throwsUnsupportedError);
      expect(() => table.role, throwsUnsupportedError);
    });

    test('HouseholdMembers: primaryKey недоступен в runtime', () {
      expect(() => HouseholdMembers().primaryKey, throwsUnsupportedError);
    });

    test('TaskCategories: геттеры колонок не вызываются в runtime', () {
      final table = TaskCategories();
      expect(() => table.id, throwsUnsupportedError);
      expect(() => table.householdId, throwsUnsupportedError);
      expect(() => table.name, throwsUnsupportedError);
      expect(() => table.colorHex, throwsUnsupportedError);
      expect(() => table.iconName, throwsUnsupportedError);
    });

    test('TaskCategories: primaryKey недоступен в runtime', () {
      expect(() => TaskCategories().primaryKey, throwsUnsupportedError);
    });

    test('TaskSubtasks: геттеры колонок не вызываются в runtime', () {
      final table = TaskSubtasks();
      expect(() => table.id, throwsUnsupportedError);
      expect(() => table.taskOccurrenceId, throwsUnsupportedError);
      expect(() => table.title, throwsUnsupportedError);
      expect(() => table.position, throwsUnsupportedError);
      expect(() => table.isCompleted, throwsUnsupportedError);
      expect(() => table.completedAt, throwsUnsupportedError);
      expect(() => table.createdAt, throwsUnsupportedError);
    });

    test('TaskSubtasks: primaryKey недоступен в runtime', () {
      expect(() => TaskSubtasks().primaryKey, throwsUnsupportedError);
    });
  });
}
