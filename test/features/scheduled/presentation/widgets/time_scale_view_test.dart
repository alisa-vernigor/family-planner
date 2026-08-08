import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:family_planner/features/scheduled/presentation/widgets/time_scale_view.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_category.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru_RU');
  });

  final today = DateTime.now();
  // Задача на ранний час — блок виден без прокрутки.
  final earlyTask = Task(
    id: 'task-early',
    householdId: 'household-1',
    title: 'Ранняя задача',
    estimatedDurationMinutes: 30,
    plannedFor: today,
    plannedTime: const Duration(hours: 8),
    allowedMemberIds: const ['member-1'],
    status: TaskStatus.pending,
    createdAt: today,
  );
  final allDayTask = Task(
    id: 'task-allday',
    householdId: 'household-1',
    title: 'Весь день',
    estimatedDurationMinutes: 30,
    plannedFor: today,
    allowedMemberIds: const ['member-1'],
    status: TaskStatus.pending,
    createdAt: today,
  );

  Widget buildSubject({
    List<Task> tasks = const [],
    Map<String, TaskCategory> categoriesById = const {},
    bool weekMode = false,
    DateTime? focusedDay,
    void Function(Task)? onEdit,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: TimeScaleView(
          tasks: tasks,
          categoriesById: categoriesById,
          weekMode: weekMode,
          focusedDay: focusedDay ?? today,
          onFocusedDayChanged: (_) {},
          onEdit: onEdit ?? (_) {},
          onComplete: (_) {},
          onUncomplete: (_) {},
        ),
      ),
    );
  }

  testWidgets('показывает шкалу часов от 00:00 до 23:00', (tester) async {
    await tester.pumpWidget(buildSubject());

    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('12:00'), findsOneWidget);
    expect(find.text('23:00'), findsOneWidget);
  });

  testWidgets('задача с временем показывается на шкале', (tester) async {
    await tester.pumpWidget(buildSubject(tasks: [earlyTask]));

    expect(find.text('Ранняя задача'), findsOneWidget);
    // Метка времени в блоке (в гуттере тоже есть «08:00», поэтому 2 совпадения).
    expect(find.text('08:00'), findsNWidgets(2));
  });

  testWidgets('задача без времени — в ряду «Весь день»', (tester) async {
    await tester.pumpWidget(buildSubject(tasks: [allDayTask]));

    // Label ряда + чип с заголовком задачи (оба текста «Весь день»).
    expect(find.text('Весь день'), findsNWidgets(2));
  });

  testWidgets('выполненная задача на шкале зачёркнута', (tester) async {
    final completed = earlyTask.copyWith(
      status: TaskStatus.completed,
      completedAt: today,
    );

    await tester.pumpWidget(buildSubject(tasks: [completed]));

    final text = tester.widget<Text>(find.text('Ранняя задача'));
    expect(text.style?.decoration, TextDecoration.lineThrough);
  });

  testWidgets('блок задачи окрашен в цвет категории', (tester) async {
    final category = TaskCategory(
      id: 'cat-red',
      householdId: 'household-1',
      name: 'Покупки',
      colorHex: 'E53935', // красный
    );
    final taskWithCategory = earlyTask.copyWith(categoryId: 'cat-red');

    await tester.pumpWidget(
      buildSubject(
        tasks: [taskWithCategory],
        categoriesById: {'cat-red': category},
      ),
    );

    final barColor = const Color(0xFFE53935);
    final barFinder = find.byWidgetPredicate(
      (widget) {
        if (widget is! Container) return false;
        final decoration = widget.decoration;
        if (decoration is! BoxDecoration) return false;
        final border = decoration.border;
        return border is Border && border.left.color == barColor;
      },
    );

    expect(barFinder, findsWidgets);
  });

  testWidgets('недельный режим показывает несколько колонок', (tester) async {
    await tester.pumpWidget(buildSubject(weekMode: true));

    // В недельном режиме есть подписи дней недели (пн … вс).
    expect(find.text('00:00'), findsOneWidget);
  });

  testWidgets('тап по задаче открывает редактирование', (tester) async {
    // Увеличиваем окно — блок задачи в 8:00 виден без прокрутки.
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Task? edited;
    await tester.pumpWidget(
      buildSubject(
        tasks: [earlyTask],
        onEdit: (task) => edited = task,
      ),
    );

    await tester.tap(find.text('Ранняя задача'));
    await tester.pump();

    expect(edited?.id, 'task-early');
  });

  testWidgets('недельный режим показывает шапку дней с датами', (tester) async {
    await tester.pumpWidget(buildSubject(weekMode: true));

    // В шапке недели — подписи дней недели (пн … вс) и числа дат.
    expect(find.text('пн'), findsOneWidget);
    expect(find.text('вс'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^[а-я]{2}$')), findsWidgets);
  });

  testWidgets('в недельном режиме колонки растягиваются на всю ширину', (
    tester,
  ) async {
    // Широкое окно: 7 колонок должны заполнить всю область без пустоты справа.
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildSubject(weekMode: true));

    final view = tester.getRect(find.byType(TimeScaleView));
    final viewportWidth = view.width - TimeScaleView.hourGutterWidth;
    // Колонка дня ≈ ширина области / 7 (а не фиксированные 56px).
    expect(viewportWidth / 7, greaterThan(TimeScaleView.kMinWeekColumnWidth));
  });

  testWidgets('в режиме дня колонка занимает всю ширину', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildSubject());

    final view = tester.getRect(find.byType(TimeScaleView));
    final viewportWidth = view.width - TimeScaleView.hourGutterWidth;
    expect(viewportWidth, greaterThan(TimeScaleView.kMinWeekColumnWidth));
  });

  testWidgets('задача на конкретный день встаёт в колонку этого дня', (
    tester,
  ) async {
    final monday = today.subtract(
      Duration(days: today.weekday - DateTime.monday),
    );
    final mondayTask = Task(
      id: 'task-monday',
      householdId: 'household-1',
      title: 'Понедельничная',
      estimatedDurationMinutes: 30,
      plannedFor: monday,
      plannedTime: const Duration(hours: 8),
      allowedMemberIds: const ['member-1'],
      status: TaskStatus.pending,
      createdAt: today,
    );

    await tester.pumpWidget(
      buildSubject(weekMode: true, tasks: [mondayTask]),
    );

    // Задача на понедельник — в первой колонке, под шапкой «пн».
    expect(find.text('Понедельничная'), findsOneWidget);
  });
}
