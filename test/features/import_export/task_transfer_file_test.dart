import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/import_export/domain/entities/task_transfer_file.dart';
import 'package:family_planner/features/tasks/domain/entities/eisenhower_priority.dart';

void main() {
  group('TaskTransferItem.fromJson', () {
    test('парсит все поля', () {
      final item = TaskTransferItem.fromJson({
        'title': '  Помыть посуду  ',
        'description': '  С горячей водой  ',
        'date': '2026-08-09',
        'time': '18:00',
        'deadline': '2026-08-09T20:00',
        'duration_minutes': 45,
        'priority': 2,
        'assignee': '  Мама  ',
        'category': '  Кухня  ',
        'subtasks': ['Мыло', '  Губка  ', ''],
      });

      expect(item.title, 'Помыть посуду');
      expect(item.description, 'С горячей водой');
      expect(item.date, DateTime(2026, 8, 9));
      expect(item.time, const Duration(hours: 18));
      expect(item.deadline, DateTime(2026, 8, 9, 20));
      expect(item.durationMinutes, 45);
      expect(item.priority, EisenhowerPriority.notUrgentImportant);
      expect(item.assignee, 'Мама');
      expect(item.category, 'Кухня');
      expect(item.subtasks, ['Мыло', 'Губка']);
    });

    test('без даты — дата null (сегодня обрабатывает use case)', () {
      final item = TaskTransferItem.fromJson({'title': 'Задача'});
      expect(item.date, isNull);
      expect(item.title, 'Задача');
    });

    test('длительность ≤ 0 → дефолт 30; большая — зажимается до 1440', () {
      expect(
        TaskTransferItem.fromJson({'title': 't', 'duration_minutes': 0}).durationMinutes,
        30,
      );
      expect(
        TaskTransferItem.fromJson({'title': 't', 'duration_minutes': -5}).durationMinutes,
        30,
      );
      expect(
        TaskTransferItem.fromJson({'title': 't', 'duration_minutes': 5000})
            .durationMinutes,
        1440,
      );
    });

    test('приоритет принимает строки и числа', () {
      expect(
        TaskTransferItem.fromJson({'title': 't', 'priority': 1}).priority,
        EisenhowerPriority.urgentImportant,
      );
      expect(
        TaskTransferItem.fromJson({'title': 't', 'priority': 'high'}).priority,
        EisenhowerPriority.urgentImportant,
      );
      expect(
        TaskTransferItem.fromJson({'title': 't', 'priority': 'medium'}).priority,
        EisenhowerPriority.notUrgentImportant,
      );
      expect(
        TaskTransferItem.fromJson({'title': 't', 'priority': 'low'}).priority,
        EisenhowerPriority.urgentNotImportant,
      );
      expect(
        TaskTransferItem.fromJson({'title': 't', 'priority': 'none'}).priority,
        isNull,
      );
      // Неверный приоритет → null (без падения).
      expect(
        TaskTransferItem.fromJson({'title': 't', 'priority': 'whatever'}).priority,
        isNull,
      );
    });

    test('кривой формат даты/времени → null, а не падение', () {
      final item = TaskTransferItem.fromJson({
        'title': 't',
        'date': 'не-дата',
        'time': 'abc',
        'deadline': 'не-дедлайн',
      });
      expect(item.date, isNull);
      expect(item.time, isNull);
      expect(item.deadline, isNull);
    });
  });

  group('TaskTransferItem.toJson / round-trip', () {
    test('круговая сериализация сохраняет поля', () {
      final item = TaskTransferItem(
        title: 'Помыть посуду',
        description: 'С горячей водой',
        date: DateTime(2026, 8, 9),
        time: const Duration(hours: 18),
        deadline: DateTime(2026, 8, 9, 20),
        durationMinutes: 45,
        priority: EisenhowerPriority.urgentImportant,
        assignee: 'Мама',
        category: 'Кухня',
        subtasks: ['Мыло', 'Губка'],
      );

      final reparsed = TaskTransferItem.fromJson(item.toJson());

      expect(reparsed, item);
    });

    test('пустые поля не попадают в JSON', () {
      final json = TaskTransferItem(title: 't', durationMinutes: 30).toJson();
      expect(json.containsKey('description'), isFalse);
      expect(json.containsKey('date'), isFalse);
      expect(json.containsKey('time'), isFalse);
      expect(json.containsKey('deadline'), isFalse);
      expect(json.containsKey('priority'), isFalse);
      expect(json.containsKey('assignee'), isFalse);
      expect(json.containsKey('category'), isFalse);
      expect(json.containsKey('subtasks'), isFalse);
    });
  });

  group('TaskTransferFile', () {
    test('fromJson/toJson round-trip', () {
      final json = {
        'version': 1,
        'tasks': [
          {'title': 'Задача 1', 'duration_minutes': 30},
          {'title': 'Задача 2', 'duration_minutes': 60},
        ],
      };

      final file = TaskTransferFile.fromJson(json);
      expect(file.version, 1);
      expect(file.tasks, hasLength(2));

      final reparsed = TaskTransferFile.fromJson(file.toJson());
      expect(reparsed, file);
    });

    test('отсутствующий version → 1', () {
      final file = TaskTransferFile.fromJson({'tasks': []});
      expect(file.version, 1);
    });

    test('toJsonString — валидный JSON', () {
      final file = TaskTransferFile(
        tasks: [TaskTransferItem(title: 'Задача', durationMinutes: 30)],
      );
      final string = file.toJsonString();
      expect(string, contains('"Задача"'));
      expect(string, contains('"version"'));
      final decoded = jsonDecode(string) as Map<String, dynamic>;
      expect(decoded['version'], 1);
      expect((decoded['tasks'] as List<dynamic>), hasLength(1));
    });
  });
}
