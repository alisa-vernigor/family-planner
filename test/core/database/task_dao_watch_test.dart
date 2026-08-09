import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/core/database/app_database.dart';

AppDatabase _createTestDb() => AppDatabase(NativeDatabase.memory());

TaskOccurrencesCompanion _task(
  String id, {
  String householdId = 'household-1',
  String plannedFor = '2026-08-09',
  String status = 'pending',
}) {
  return TaskOccurrencesCompanion.insert(
    id: id,
    householdId: householdId,
    title: 'Задача $id',
    estimatedDurationMinutes: 30,
    plannedFor: plannedFor,
    status: status,
    createdAt: '2026-08-09T08:00:00Z',
    allowedMemberIds: '["member-1"]',
  );
}

void main() {
  late AppDatabase database;

  setUp(() => database = _createTestDb());
  tearDown(() => database.close());

  group('TaskDao watchTasksForDay', () {
    test('эмитит задачи для указанного дня', () async {
      await database.into(database.taskOccurrences).insert(
            _task('task-1', plannedFor: '2026-08-09'),
          );
      await database.into(database.taskOccurrences).insert(
            _task('task-2', plannedFor: '2026-08-09'),
          );
      await database.into(database.taskOccurrences).insert(
            _task('task-tomorrow', plannedFor: '2026-08-10'),
          );

      final stream = database.taskDao.watchTasksForDay(
        'household-1',
        '2026-08-09',
      );
      final first = await stream.first;
      expect(first.map((t) => t.id).toList(), containsAll(['task-1', 'task-2']));
      expect(first.map((t) => t.id), isNot(contains('task-tomorrow')));
    });

    test('переэмитит при изменении данных (watch)', () async {
      await database.into(database.taskOccurrences).insert(
            _task('task-1'),
          );

      final stream = database.taskDao.watchTasksForDay(
        'household-1',
        '2026-08-09',
      );
      // Собираем первые две эмиссии: первая после вставки task-1,
      // вторая после вставки task-2.
      final emissions = stream.take(2).toList();

      // Дождёмся первой эмиссии, затем вставим вторую задачу.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await database.into(database.taskOccurrences).insert(
            _task('task-2'),
          );

      final results = await emissions.timeout(const Duration(seconds: 3));
      expect(results[0].map((t) => t.id).toList(), contains('task-1'));
      expect(results[1].map((t) => t.id).toList(), containsAll(['task-1', 'task-2']));
    });

    test('порядок по deadline', () async {
      await database.into(database.taskOccurrences).insert(
            _task('later', plannedFor: '2026-08-09')
                .copyWith(deadline: const Value('2026-08-09T18:00:00Z')),
          );
      await database.into(database.taskOccurrences).insert(
            _task('earlier', plannedFor: '2026-08-09')
                .copyWith(deadline: const Value('2026-08-09T09:00:00Z')),
          );

      final stream = database.taskDao.watchTasksForDay(
        'household-1',
        '2026-08-09',
      );
      final tasks = await stream.first;
      expect(tasks.first.id, 'earlier');
    });
  });

  group('TaskDao watchAllPending', () {
    test('возвращает только pending задачи', () async {
      await database.into(database.taskOccurrences).insert(
            _task('pending-1', status: 'pending'),
          );
      await database.into(database.taskOccurrences).insert(
            _task('pending-2', status: 'pending'),
          );
      await database.into(database.taskOccurrences).insert(
            _task('completed', status: 'completed'),
          );

      final stream = database.taskDao.watchAllPending('household-1');
      final tasks = await stream.first;
      expect(tasks.map((t) => t.id).toList(), ['pending-1', 'pending-2']);
    });

    test('сортирует по planned_for затем deadline', () async {
      await database.into(database.taskOccurrences).insert(
            _task('later', plannedFor: '2026-08-10'),
          );
      await database.into(database.taskOccurrences).insert(
            _task('earlier', plannedFor: '2026-08-09')
                .copyWith(deadline: const Value('2026-08-09T12:00:00Z')),
          );
      await database.into(database.taskOccurrences).insert(
            _task('mid', plannedFor: '2026-08-09')
                .copyWith(deadline: const Value('2026-08-09T09:00:00Z')),
          );

      final tasks = await database.taskDao.watchAllPending('household-1').first;
      expect(tasks.map((t) => t.id).toList(), ['mid', 'earlier', 'later']);
    });
  });

  group('TaskDao clearDay', () {
    test('удаляет задачи только за указанный день', () async {
      await database.into(database.taskOccurrences).insert(
            _task('day-task', plannedFor: '2026-08-09'),
          );
      await database.into(database.taskOccurrences).insert(
            _task('other-day', plannedFor: '2026-08-10'),
          );

      await database.taskDao.clearDay('household-1', '2026-08-09');

      final remaining = await database
          .select(database.taskOccurrences)
          .get();
      expect(remaining.map((t) => t.id).toList(), ['other-day']);
    });
  });

  group('TaskDao getHouseholdIdByTemplate', () {
    test('возвращает household_id по template_id', () async {
      await database.into(database.taskOccurrences).insert(
            _task('task-1').copyWith(templateId: const Value('template-1')),
          );
      await database.into(database.taskOccurrences).insert(
            _task('task-2').copyWith(templateId: const Value('template-2')),
          );

      final hh = await database.taskDao.getHouseholdIdByTemplate('template-2');
      expect(hh, 'household-1');
    });

    test('возвращает null для несуществующего шаблона', () async {
      final hh = await database.taskDao.getHouseholdIdByTemplate('missing');
      expect(hh, isNull);
    });
  });

  group('TaskDao getScheduledAfter', () {
    test('возвращает только pending задачи строго после даты, сортируя по дате', () async {
      await database.into(database.taskOccurrences).insert(
            _task('later', plannedFor: '2026-08-15'),
          );
      await database.into(database.taskOccurrences).insert(
            _task('day-after', plannedFor: '2026-08-11')
                .copyWith(deadline: const Value('2026-08-11T18:00:00Z')),
          );
      await database.into(database.taskOccurrences).insert(
            _task('same-day', plannedFor: '2026-08-10'),
          );
      await database.into(database.taskOccurrences).insert(
            _task('before', plannedFor: '2026-08-08'),
          );
      await database.into(database.taskOccurrences).insert(
            _task('completed', plannedFor: '2026-08-20', status: 'completed'),
          );

      final tasks = await database.taskDao.getScheduledAfter(
        'household-1',
        '2026-08-10',
      );
      expect(tasks.map((t) => t.id).toList(), ['day-after', 'later']);
    });
  });

  group('TaskDao updateAllowedMembers / пауза серии', () {
    test('updateAllowedMembers обновляет только allowed_member_ids', () async {
      await database.into(database.taskOccurrences).insert(
            _task('task-1'),
          );

      await database.taskDao.updateAllowedMembers('task-1', '["m1","m2"]');

      final row = await database.taskDao.getTaskById('task-1');
      expect(row?.allowedMemberIds, '["m1","m2"]');
      expect(row?.title, 'Задача task-1'); // другие поля не тронуты
    });

    test('pauseTemplateLocally/resumeTemplateLocally переключают template_active',
        () async {
      await database.into(database.taskOccurrences).insert(
            _task('task-1').copyWith(templateId: const Value('template-1')),
          );
      await database.into(database.taskOccurrences).insert(
            _task('task-2').copyWith(templateId: const Value('template-1')),
          );

      await database.taskDao.pauseTemplateLocally('template-1');
      final paused = await database.taskDao.getAllPending('household-1');
      for (final t in paused) {
        expect(t.templateActive, isFalse);
      }

      await database.taskDao.resumeTemplateLocally('template-1');
      final resumed = await database.taskDao.getAllPending('household-1');
      for (final t in resumed) {
        expect(t.templateActive, isTrue);
      }
    });
  });
}
