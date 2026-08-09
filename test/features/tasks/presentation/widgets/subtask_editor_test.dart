import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/tasks/domain/entities/task_subtask.dart';
import 'package:family_planner/features/tasks/presentation/widgets/subtask_editor.dart';

void main() {
  final subtasks = [
    TaskSubtask(
      id: 'sub-1',
      taskId: 'task-1',
      title: 'Купить молоко',
      position: 0,
      isCompleted: false,
      createdAt: DateTime(2026, 8, 1),
    ),
    TaskSubtask(
      id: 'sub-2',
      taskId: 'task-1',
      title: 'Купить хлеб',
      position: 1,
      isCompleted: true,
      createdAt: DateTime(2026, 8, 1),
      completedAt: DateTime(2026, 8, 2),
    ),
  ];

  Widget buildSubject({
    List<TaskSubtask>? list,
    Future<void> Function(String title)? onAdd,
    Future<void> Function(TaskSubtask subtask)? onToggle,
    Future<void> Function(String subtaskId)? onDelete,
    Future<void> Function(String taskId, List<String> orderedIds)? onReorder,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SubtaskEditor(
          subtasks: list ?? subtasks,
          onAdd: onAdd ?? (_) async {},
          onToggle: onToggle ?? (_) async {},
          onDelete: onDelete ?? (_) async {},
          // ReorderableListView в этой версии Flutter требует не-null
          // onReorder/onReorderItem, поэтому в тестах со списком
          // подзадач всегда передаём onReorder.
          onReorder: onReorder ?? (_, _) async {},
        ),
      ),
    );
  }

  testWidgets('показывает заголовок и счётчик выполнения', (tester) async {
    await tester.pumpWidget(buildSubject());

    expect(find.text('Подзадачи'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
  });

  testWidgets('без onReorder с непустым списком — не падает (ListView)', (tester) async {
    // Регрессионный тест: раньше при onReorder == null и непустом списке
    // ReorderableListView падал с assertion
    // 'The onReorder callback is obsolete and is replaced by onReorderItem.'
    // Теперь рендерится обычный ListView без drag&drop.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SubtaskEditor(
            subtasks: subtasks,
            onAdd: (_) async {},
            onToggle: (_) async {},
            onDelete: (_) async {},
            onReorder: null,
          ),
        ),
      ),
    );

    // Не упало — рендер прошёл, подзадачи на месте.
    expect(find.text('Купить молоко'), findsOneWidget);
    expect(find.text('Купить хлеб'), findsOneWidget);
    // Drag-иконка отключена (enabled: onReorder != null).
    final drag = tester.widget<ReorderableDragStartListener>(
      find.byType(ReorderableDragStartListener).first,
    );
    expect(drag.enabled, isFalse);
  });

  testWidgets('показывает подзадачи с чекбоксами', (tester) async {
    await tester.pumpWidget(buildSubject());

    expect(find.text('Купить молоко'), findsOneWidget);
    expect(find.text('Купить хлеб'), findsOneWidget);
    // Один выполненный (check_circle) и один нет.
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked_outlined), findsOneWidget);
  });

  testWidgets('выполненная подзадача зачёркнута', (tester) async {
    await tester.pumpWidget(buildSubject());

    final text = tester.widget<Text>(find.text('Купить хлеб'));
    expect(text.style?.decoration, TextDecoration.lineThrough);
  });

  testWidgets('пустой список — только поле добавления', (tester) async {
    // С пустым списком ReorderableListView не строится — можно передать null.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SubtaskEditor(
            subtasks: const [],
            onAdd: (_) async {},
            onToggle: (_) async {},
            onDelete: (_) async {},
          ),
        ),
      ),
    );

    expect(find.text('Подзадачи'), findsOneWidget);
    expect(find.text('Купить молоко'), findsNothing);
    expect(find.text('Добавить подзадачу…'), findsOneWidget);
    // Счётчик не показывается для пустого списка.
    expect(find.text('0/0'), findsNothing);
  });

  testWidgets('добавление подзадачи через submit вызывает onAdd', (
    tester,
  ) async {
    String? added;
    await tester.pumpWidget(
      buildSubject(onAdd: (title) async => added = title),
    );

    await tester.enterText(find.byType(TextField), 'Купить сыр');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(added, 'Купить сыр');
    // Поле очищено после добавления.
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets('пустое название не вызывает onAdd', (tester) async {
    var calls = 0;
    await tester.pumpWidget(buildSubject(onAdd: (_) async => calls++));

    await tester.enterText(find.byType(TextField), '   ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(calls, 0);
  });

  testWidgets('кнопка «плюс» добавляет подзадачу', (tester) async {
    String? added;
    await tester.pumpWidget(
      buildSubject(onAdd: (title) async => added = title),
    );

    await tester.enterText(find.byType(TextField), 'Помыть окна');
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pumpAndSettle();

    expect(added, 'Помыть окна');
  });

  testWidgets('тап по чекбоксу вызывает onToggle', (tester) async {
    TaskSubtask? toggled;
    await tester.pumpWidget(
      buildSubject(onToggle: (s) async => toggled = s),
    );

    await tester.tap(find.byIcon(Icons.radio_button_unchecked_outlined));
    await tester.pump();

    expect(toggled?.id, 'sub-1');
  });

  testWidgets('свайп удаляет подзадачу', (tester) async {
    String? deleted;
    await tester.pumpWidget(
      buildSubject(onDelete: (id) async => deleted = id),
    );

    await tester.drag(find.text('Купить молоко'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(deleted, 'sub-1');
  });

  testWidgets('показывает drag-иконку при onReorder != null', (tester) async {
    await tester.pumpWidget(buildSubject());

    expect(find.byIcon(Icons.drag_indicator), findsNWidgets(2));
  });

  testWidgets('перетаскивание вызывает onReorder с новым порядком', (
    tester,
  ) async {
    String? reorderedTaskId;
    List<String>? orderedIds;
    await tester.pumpWidget(
      buildSubject(
        onReorder: (taskId, ids) async {
          reorderedTaskId = taskId;
          orderedIds = ids;
        },
      ),
    );

    // Перетаскиваем первую подзадачу вниз.
    await tester.drag(
      find.byIcon(Icons.drag_indicator).first,
      const Offset(0, 100),
    );
    await tester.pumpAndSettle();

    expect(reorderedTaskId, 'task-1');
    expect(orderedIds, ['sub-2', 'sub-1']);
  });
}
