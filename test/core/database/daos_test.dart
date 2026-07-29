import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/core/database/app_database.dart';
import 'package:family_planner/core/database/daos/task_dao.dart';
import 'package:family_planner/core/database/daos/sync_queue_dao.dart';
import 'package:family_planner/core/database/daos/household_members_dao.dart';

AppDatabase _createTestDb() => AppDatabase(NativeDatabase.memory());

void main() {
  group('TaskDao', () {
    late AppDatabase database;
    late TaskDao dao;

    setUp(() {
      database = _createTestDb();
      dao = database.taskDao;
    });

    tearDown(() async {
      await database.close();
    });

    test('upsertTask and getTaskById', () async {
      await dao.upsertTask(TaskOccurrencesCompanion(
        id: const Value('task-1'),
        householdId: const Value('household-1'),
        title: const Value('Test Task'),
        description: const Value('Test Description'),
        estimatedDurationMinutes: const Value(30),
        plannedFor: const Value('2026-07-29'),
        deadline: const Value(null),
        assignedMemberId: const Value(null),
        pinnedMemberId: const Value(null),
        status: const Value('pending'),
        createdAt: const Value('2026-07-29T10:00:00.000Z'),
        completedAt: const Value(null),
        updatedAt: const Value('2026-07-29T10:00:00.000Z'),
        priority: const Value(null),
        allowedMemberIds: const Value('["member-1"]'),
      ));

      final task = await dao.getTaskById('task-1');
      expect(task, isNot(isNull));
      expect(task!.title, 'Test Task');
      expect(task.status, 'pending');
    });

    test('getForDay возвращает задачи для указанного дня', () async {
      await dao.upsertTask(TaskOccurrencesCompanion(
        id: const Value('task-1'),
        householdId: const Value('household-1'),
        title: const Value('Test Task'),
        estimatedDurationMinutes: const Value(30),
        plannedFor: const Value('2026-07-29'),
        status: const Value('pending'),
        createdAt: const Value('2026-07-29T10:00:00.000Z'),
        allowedMemberIds: const Value('[]'),
      ));
      await dao.upsertTask(TaskOccurrencesCompanion(
        id: const Value('task-2'),
        householdId: const Value('household-1'),
        title: const Value('Another'),
        estimatedDurationMinutes: const Value(15),
        plannedFor: const Value('2026-07-30'),
        status: const Value('pending'),
        createdAt: const Value('2026-07-29T10:00:00.000Z'),
        allowedMemberIds: const Value('[]'),
      ));

      final dayTasks = await dao.getForDay('household-1', '2026-07-29');
      expect(dayTasks.length, 1);
      expect(dayTasks.first.id, 'task-1');
    });

    test('getAllPending не возвращает completed', () async {
      await dao.upsertTask(TaskOccurrencesCompanion(
        id: const Value('task-1'),
        householdId: const Value('household-1'),
        title: const Value('Pending'),
        estimatedDurationMinutes: const Value(10),
        plannedFor: const Value('2026-07-29'),
        status: const Value('pending'),
        createdAt: const Value('2026-07-29T10:00:00.000Z'),
        allowedMemberIds: const Value('[]'),
      ));
      await dao.upsertTask(TaskOccurrencesCompanion(
        id: const Value('task-done'),
        householdId: const Value('household-1'),
        title: const Value('Completed'),
        estimatedDurationMinutes: const Value(10),
        plannedFor: const Value('2026-07-29'),
        status: const Value('completed'),
        createdAt: const Value('2026-07-29T10:00:00.000Z'),
        completedAt: const Value('2026-07-29T12:00:00.000Z'),
        allowedMemberIds: const Value('[]'),
      ));

      final pending = await dao.getAllPending('household-1');
      expect(pending.length, 1);
      expect(pending.first.id, 'task-1');
    });

    test('deleteTask удаляет задачу', () async {
      await dao.upsertTask(TaskOccurrencesCompanion(
        id: const Value('task-1'),
        householdId: const Value('household-1'),
        title: const Value('To Delete'),
        estimatedDurationMinutes: const Value(5),
        plannedFor: const Value('2026-07-29'),
        status: const Value('pending'),
        createdAt: const Value('2026-07-29T10:00:00.000Z'),
        allowedMemberIds: const Value('[]'),
      ));
      await dao.deleteTask('task-1');

      expect(await dao.getTaskById('task-1'), isNull);
    });

    test('clearHousehold изолирована по householdId', () async {
      await dao.upsertTask(TaskOccurrencesCompanion(
        id: const Value('task-1'),
        householdId: const Value('household-1'),
        title: const Value('H1'),
        estimatedDurationMinutes: const Value(5),
        plannedFor: const Value('2026-07-29'),
        status: const Value('pending'),
        createdAt: const Value('2026-07-29T10:00:00.000Z'),
        allowedMemberIds: const Value('[]'),
      ));
      await dao.upsertTask(TaskOccurrencesCompanion(
        id: const Value('task-2'),
        householdId: const Value('household-2'),
        title: const Value('H2'),
        estimatedDurationMinutes: const Value(5),
        plannedFor: const Value('2026-07-29'),
        status: const Value('pending'),
        createdAt: const Value('2026-07-29T10:00:00.000Z'),
        allowedMemberIds: const Value('[]'),
      ));

      await dao.clearHousehold('household-1');

      expect(await dao.getAllPending('household-1'), isEmpty);
      expect(await dao.getAllPending('household-2'), isNot(isEmpty));
    });

    test('upsertTasks batch', () async {
      final tasks = List.generate(10, (i) => TaskOccurrencesCompanion(
        id: Value('task-$i'),
        householdId: const Value('household-1'),
        title: Value('Task $i'),
        estimatedDurationMinutes: const Value(10),
        plannedFor: const Value('2026-07-29'),
        status: const Value('pending'),
        createdAt: const Value('2026-07-29T10:00:00.000Z'),
        allowedMemberIds: const Value('[]'),
      ));
      await dao.upsertTasks(tasks);

      expect(await dao.getAllPending('household-1'), hasLength(10));
    });

    test('hasTasksForHousehold', () async {
      expect(await dao.hasTasksForHousehold('household-1'), isFalse);

      await dao.upsertTask(TaskOccurrencesCompanion(
        id: const Value('task-1'),
        householdId: const Value('household-1'),
        title: const Value('First'),
        estimatedDurationMinutes: const Value(5),
        plannedFor: const Value('2026-07-29'),
        status: const Value('pending'),
        createdAt: const Value('2026-07-29T10:00:00.000Z'),
        allowedMemberIds: const Value('[]'),
      ));

      expect(await dao.hasTasksForHousehold('household-1'), isTrue);
    });
  });

  group('SyncQueueDao', () {
    late AppDatabase database;
    late SyncQueueDao syncDao;

    setUp(() {
      database = _createTestDb();
      syncDao = database.syncQueueDao;
    });

    tearDown(() async {
      await database.close();
    });

    test('enqueue добавляет запись', () async {
      await syncDao.enqueue(
        entityType: 'task_occurrence',
        operation: 'CREATE',
        entityId: 'task-1',
        householdId: 'household-1',
        payload: {'test': true},
      );
      expect(await syncDao.hasPendingOperations(), isTrue);
    });

    test('getPending в порядке создания', () async {
      await syncDao.enqueue(
        entityType: 'task_occurrence',
        operation: 'CREATE',
        entityId: 'task-1',
        householdId: 'household-1',
        payload: {},
      );
      await Future.delayed(const Duration(milliseconds: 5));
      await syncDao.enqueue(
        entityType: 'task_occurrence',
        operation: 'DELETE',
        entityId: 'task-1',
        householdId: 'household-1',
        payload: {},
      );

      final entries = await syncDao.getPending();
      expect(entries, hasLength(2));
      expect(entries.first.operation, 'CREATE');
      expect(entries.last.operation, 'DELETE');
    });

    test('getPendingIds', () async {
      await syncDao.enqueue(
        entityType: 'task_occurrence',
        operation: 'UPDATE',
        entityId: 'task-abc',
        householdId: 'household-1',
        payload: {},
      );
      final ids = await syncDao.getPendingIds('household-1');
      expect(ids, contains('task-abc'));
    });

    test('deleteProcessed', () async {
      await syncDao.enqueue(
        entityType: 'task_occurrence',
        operation: 'CREATE',
        entityId: 'task-1',
        householdId: 'household-1',
        payload: {},
      );
      final entry = (await syncDao.getPending()).first;
      await syncDao.deleteProcessed(entry.id);

      expect(await syncDao.hasPendingOperations(), isFalse);
    });

    test('markFailed увеличивает retryCount', () async {
      await syncDao.enqueue(
        entityType: 'task_occurrence',
        operation: 'CREATE',
        entityId: 'task-1',
        householdId: 'household-1',
        payload: {},
      );
      final entry = (await syncDao.getPending()).first;
      await syncDao.markFailed(entry.id, 'error!');

      final updated = await syncDao.getPending();
      expect(updated.first.retryCount, 1);
      expect(updated.first.lastError, 'error!');
    });

    test('clearHousehold', () async {
      await syncDao.enqueue(
        entityType: 'task_occurrence',
        operation: 'CREATE',
        entityId: 't1',
        householdId: 'household-1',
        payload: {},
      );
      await syncDao.enqueue(
        entityType: 'task_occurrence',
        operation: 'CREATE',
        entityId: 't2',
        householdId: 'household-2',
        payload: {},
      );
      await syncDao.clearHousehold('household-1');

      expect(await syncDao.getPendingIds('household-1'), isEmpty);
      expect(await syncDao.getPendingIds('household-2'), isNot(isEmpty));
    });

    test('getPendingCount', () async {
      await syncDao.enqueue(
        entityType: 'task_occurrence',
        operation: 'UPDATE',
        entityId: 'task-count',
        householdId: 'household-1',
        payload: {},
      );
      expect(await syncDao.getPendingCount('household-1'), 1);
    });
  });

  group('HouseholdMembersDao', () {
    late AppDatabase database;
    late HouseholdMembersDao membersDao;

    setUp(() {
      database = _createTestDb();
      membersDao = database.householdMembersDao;
    });

    tearDown(() async {
      await database.close();
    });

    test('upsert и getMembers', () async {
      await membersDao.upsertMember(HouseholdMembersCompanion(
        profileId: const Value('member-1'),
        householdId: const Value('household-1'),
        displayName: const Value('Alice'),
        role: const Value('owner'),
      ));
      final members = await membersDao.getMembers('household-1');
      expect(members, hasLength(1));
      expect(members.first.displayName, 'Alice');
    });

    test('getMembers изолирована по household', () async {
      await membersDao.upsertMember(HouseholdMembersCompanion(
        profileId: const Value('m1'),
        householdId: const Value('household-1'),
        displayName: const Value('Alice'),
        role: const Value('owner'),
      ));
      expect(await membersDao.getMembers('household-2'), isEmpty);
    });

    test('upsertMembers batch', () async {
      final members = List.generate(5, (i) => HouseholdMembersCompanion(
        profileId: Value('m-$i'),
        householdId: const Value('household-1'),
        displayName: Value('M $i'),
        role: const Value('member'),
      ));
      await membersDao.upsertMembers(members);

      expect(await membersDao.getMembers('household-1'), hasLength(5));
    });

    test('clearHousehold', () async {
      await membersDao.upsertMember(HouseholdMembersCompanion(
        profileId: const Value('m1'),
        householdId: const Value('household-1'),
        displayName: const Value('Alice'),
        role: const Value('owner'),
      ));
      await membersDao.clearHousehold('household-1');

      expect(await membersDao.getMembers('household-1'), isEmpty);
    });
  });
}
