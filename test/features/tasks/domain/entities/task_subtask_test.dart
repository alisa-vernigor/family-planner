import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/tasks/domain/entities/create_task_category_params.dart';
import 'package:family_planner/features/tasks/domain/entities/create_task_subtask_params.dart';
import 'package:family_planner/features/tasks/domain/entities/task_subtask.dart';

void main() {
  group('TaskSubtask', () {
    final createdAt = DateTime(2026, 8, 1, 10);

    TaskSubtask base() => TaskSubtask(
      id: 'st-1',
      taskId: 'task-1',
      title: 'Помыть посуду',
      position: 0,
      isCompleted: false,
      createdAt: createdAt,
    );

    test('создаётся со всеми полями', () {
      final s = base();

      expect(s.id, 'st-1');
      expect(s.taskId, 'task-1');
      expect(s.title, 'Помыть посуду');
      expect(s.position, 0);
      expect(s.isCompleted, isFalse);
      expect(s.createdAt, createdAt);
      expect(s.completedAt, isNull);
    });

    test('equals по полям', () {
      expect(base(), equals(base()));
      expect(base().copyWith(title: 'Другая'), isNot(equals(base())));
    });

    test('copyWith сохраняет значения не переданных полей', () {
      final updated = base().copyWith(title: 'Новое название');

      expect(updated.title, 'Новое название');
      expect(updated.id, 'st-1');
      expect(updated.position, 0);
    });

    test('copyWith сбрасывает completedAt при передаче null', () {
      final done = base().copyWith(isCompleted: true, completedAt: DateTime(2026, 8, 2));
      expect(done.completedAt, DateTime(2026, 8, 2));

      final reset = done.copyWith(completedAt: null);
      expect(reset.completedAt, isNull);
    });

    test('copyWith оставляет completedAt, если не передан', () {
      final done = base().copyWith(completedAt: DateTime(2026, 8, 2));
      final same = done.copyWith(title: 'x');

      expect(same.completedAt, DateTime(2026, 8, 2));
    });

    test('toggle меняет isCompleted и ставит completedAt', () {
      final toggled = base().toggle();

      expect(toggled.isCompleted, isTrue);
      expect(toggled.completedAt, isNotNull);
    });

    test('toggle обратно снимает completedAt', () {
      final done = base().toggle();
      final undone = done.toggle();

      expect(undone.isCompleted, isFalse);
      expect(undone.completedAt, isNull);
    });

    test('props содержат все поля', () {
      expect(base().props, [
        'st-1',
        'task-1',
        'Помыть посуду',
        0,
        false,
        createdAt,
        null,
      ]);
    });
  });

  group('CreateTaskSubtaskParams', () {
    test('создаётся и равняется по полям', () {
      const a = CreateTaskSubtaskParams(taskId: 't1', title: 'Подзадача');
      const b = CreateTaskSubtaskParams(taskId: 't1', title: 'Подзадача');
      const c = CreateTaskSubtaskParams(taskId: 't2', title: 'Подзадача');

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.props, ['t1', 'Подзадача']);
    });
  });

  group('CreateTaskCategoryParams', () {
    test('создаётся и равняется по полям', () {
      const a = CreateTaskCategoryParams(
        householdId: 'h1',
        name: 'Работа',
        colorHex: '#FF0000',
        iconName: 'work',
      );
      const b = CreateTaskCategoryParams(
        householdId: 'h1',
        name: 'Работа',
        colorHex: '#FF0000',
        iconName: 'work',
      );
      const c = CreateTaskCategoryParams(
        householdId: 'h1',
        name: 'Дом',
        colorHex: '#00FF00',
        iconName: 'home',
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.props, ['h1', 'Работа', '#FF0000', 'work']);
    });
  });
}
