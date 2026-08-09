import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/core/database/app_database.dart';
import 'package:family_planner/core/database/daos/task_categories_dao.dart';
import 'package:family_planner/core/database/daos/task_subtasks_dao.dart';

AppDatabase _createTestDb() => AppDatabase(NativeDatabase.memory());

TaskCategoriesCompanion _category({
  required String id,
  String householdId = 'household-1',
  required String name,
  String? colorHex,
  String? iconName,
}) {
  return TaskCategoriesCompanion(
    id: Value(id),
    householdId: Value(householdId),
    name: Value(name),
    colorHex: Value(colorHex),
    iconName: Value(iconName),
  );
}

TaskSubtasksCompanion _subtask({
  required String id,
  String taskId = 'task-1',
  required String title,
  int position = 0,
  bool isCompleted = false,
  String? completedAt,
}) {
  return TaskSubtasksCompanion(
    id: Value(id),
    taskOccurrenceId: Value(taskId),
    title: Value(title),
    position: Value(position),
    isCompleted: Value(isCompleted),
    completedAt: Value(completedAt),
    createdAt: const Value('2026-08-09T08:00:00Z'),
  );
}

void main() {
  group('TaskCategoriesDao', () {
    late AppDatabase database;
    late TaskCategoriesDao dao;

    setUp(() {
      database = _createTestDb();
      dao = database.taskCategoriesDao;
    });

    tearDown(() async {
      await database.close();
    });

    test('getForHousehold возвращает категории, отсортированные по имени',
        () async {
      await dao.upsert(_category(id: 'cat-2', name: 'Работа'));
      await dao.upsert(_category(id: 'cat-1', name: 'Дом'));
      await dao.upsert(
        _category(id: 'cat-3', name: 'Дом', householdId: 'household-2'),
      );

      final categories = await dao.getForHousehold('household-1');
      expect(categories.map((c) => c.name).toList(), ['Дом', 'Работа']);
      expect(categories.map((c) => c.householdId).toSet(), {'household-1'});
    });

    test('upsert заменяет существующую категорию (insert on conflict)', () async {
      await dao.upsert(_category(id: 'cat-1', name: 'Дом'));
      await dao.upsert(_category(id: 'cat-1', name: 'Квартира', colorHex: '#111'));

      final categories = await dao.getForHousehold('household-1');
      expect(categories, hasLength(1));
      expect(categories.single.name, 'Квартира');
      expect(categories.single.colorHex, '#111');
    });

    test('upsertAll батчем и сохраняет все колонки', () async {
      await dao.upsertAll([
        _category(id: 'c1', name: 'Дом', colorHex: '#FF0000', iconName: 'home'),
        _category(id: 'c2', name: 'Работа'),
      ]);

      final categories = await dao.getForHousehold('household-1');
      expect(categories, hasLength(2));
      final byId = {for (final c in categories) c.id: c};
      expect(byId['c1']!.colorHex, '#FF0000');
      expect(byId['c1']!.iconName, 'home');
      expect(byId['c2']!.colorHex, isNull);
    });

    test('deleteCategory удаляет одну категорию', () async {
      await dao.upsertAll([
        _category(id: 'c1', name: 'Дом'),
        _category(id: 'c2', name: 'Работа'),
      ]);

      await dao.deleteCategory('c1');

      final categories = await dao.getForHousehold('household-1');
      expect(categories.map((c) => c.id).toList(), ['c2']);
    });

    test('clearHousehold удаляет только категории семьи', () async {
      await dao.upsertAll([
        _category(id: 'c1', name: 'Дом'),
        _category(id: 'c2', name: 'Работа'),
        _category(id: 'c3', name: 'Чужая', householdId: 'household-2'),
      ]);

      await dao.clearHousehold('household-1');

      expect(await dao.getForHousehold('household-1'), isEmpty);
      expect(await dao.getForHousehold('household-2'), hasLength(1));
    });
  });

  group('TaskSubtasksDao', () {
    late AppDatabase database;
    late TaskSubtasksDao dao;

    setUp(() {
      database = _createTestDb();
      dao = database.taskSubtasksDao;
    });

    tearDown(() async {
      await database.close();
    });

    test('getForTask возвращает подзадачи, отсортированные по position',
        () async {
      await dao.upsert(_subtask(id: 's1', title: 'Первый', position: 1));
      await dao.upsert(_subtask(id: 's0', title: 'Нулевой', position: 0));
      await dao.upsert(
        _subtask(id: 's-other', title: 'Чужая', taskId: 'task-2'),
      );

      final subtasks = await dao.getForTask('task-1');
      expect(subtasks.map((s) => s.title).toList(), ['Нулевой', 'Первый']);
    });

    test('getById возвращает подзадачу или null', () async {
      await dao.upsert(_subtask(id: 's1', title: 'Единственная'));

      expect((await dao.getById('s1'))!.title, 'Единственная');
      expect(await dao.getById('missing'), isNull);
    });

    test('upsert заменяет существующую подзадачу', () async {
      await dao.upsert(_subtask(id: 's1', title: 'До'));
      await dao.upsert(
        _subtask(id: 's1', title: 'После', isCompleted: true),
      );

      final subtask = await dao.getById('s1');
      expect(subtask!.title, 'После');
      expect(subtask.isCompleted, isTrue);
    });

    test('upsertAll батчем сохраняет все колонки', () async {
      await dao.upsertAll([
        _subtask(
          id: 's1',
          title: 'Готова',
          position: 0,
          isCompleted: true,
          completedAt: '2026-08-09T12:00:00Z',
        ),
        _subtask(id: 's2', title: 'Не готова', position: 1),
      ]);

      final subtasks = await dao.getForTask('task-1');
      expect(subtasks, hasLength(2));
      final byId = {for (final s in subtasks) s.id: s};
      expect(byId['s1']!.isCompleted, isTrue);
      expect(byId['s1']!.completedAt, '2026-08-09T12:00:00Z');
      expect(byId['s2']!.completedAt, isNull);
    });

    test('deleteSubtask удаляет одну подзадачу', () async {
      await dao.upsertAll([
        _subtask(id: 's1', title: 'Одна'),
        _subtask(id: 's2', title: 'Две'),
      ]);

      await dao.deleteSubtask('s1');

      expect(await dao.getForTask('task-1'), hasLength(1));
      expect((await dao.getForTask('task-1')).single.id, 's2');
    });

    test('clearForTask удаляет подзадачи только указанной задачи', () async {
      await dao.upsertAll([
        _subtask(id: 's1', title: 'Одна'),
        _subtask(id: 's2', title: 'Две'),
        _subtask(id: 's3', title: 'Чужая', taskId: 'task-2'),
      ]);

      await dao.clearForTask('task-1');

      expect(await dao.getForTask('task-1'), isEmpty);
      expect(await dao.getForTask('task-2'), hasLength(1));
    });
  });
}
