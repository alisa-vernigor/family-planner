import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/scheduled/presentation/widgets/calendar_view.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_category.dart';
import 'package:family_planner/features/tasks/domain/entities/task_recurrence.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru_RU');
  });

  final today = DateTime.now();
  final taskOnToday = Task(
    id: 'task-today',
    householdId: 'household-1',
    title: 'Сегодняшняя задача',
    estimatedDurationMinutes: 30,
    plannedFor: today,
    allowedMemberIds: const ['member-1'],
    status: TaskStatus.pending,
    createdAt: today,
  );
  Widget buildSubject({
    List<Task> tasks = const [],
    List<HouseholdMember> members = const [],
    Map<String, TaskCategory> categoriesById = const {},
    void Function(Task, DateTime)? onRescheduleToDay,
    void Function(Task)? onTogglePause,
    void Function(Task)? onSkip,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: CalendarView(
          tasks: tasks,
          members: members,
          currentMemberId: 'member-1',
          categoriesById: categoriesById,
          onEdit: (_) {},
          onDelete: (_) {},
          onAssign: (_, _) {},
          onTogglePin: (_) {},
          onReschedule: (_) {},
          onRescheduleToDay: onRescheduleToDay ?? (_, _) {},
          onDuplicate: (_) {},
          onTogglePause: onTogglePause,
          onSkip: onSkip,
          onComplete: (_) {},
          onUncomplete: (_) {},
          onCreate: () {},
        ),
      ),
    );
  }

  testWidgets('показывает календарь с полоской задачи на дне', (tester) async {
    await tester.pumpWidget(buildSubject(tasks: [taskOnToday]));

    // TableCalendar отображает заголовок месяца и сетку
    expect(find.byType(CalendarView), findsOneWidget);

    // Задача видна и в ячейке месяца (полоска), и в списке выбранного дня.
    expect(find.text('Сегодняшняя задача'), findsNWidgets(2));
  });

  testWidgets('показывает бейдж «Серия на паузе» для приостановленной серии', (
    tester,
  ) async {
    final pausedSeries = taskOnToday.copyWith(
      templateId: 'template-1',
      recurrence: const TaskRecurrence.daily(),
      templateActive: false,
    );
    await tester.pumpWidget(
      buildSubject(
        tasks: [pausedSeries],
        onTogglePause: (_) {},
      ),
    );

    // Бейдж виден в карточке дня (и в меню — пункт «Возобновить серию»).
    expect(find.text('Серия на паузе'), findsOneWidget);

    // Меню позволяет возобновить серию. Увеличиваем окно и подскролливаем
    // к карточке, чтобы её меню оказалось в зоне тапа.
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      buildSubject(
        tasks: [pausedSeries],
        onTogglePause: (_) {},
      ),
    );
    await tester.ensureVisible(find.byKey(const Key('calendar_task_menu_task-today')));
    await tester.tap(find.byKey(const Key('calendar_task_menu_task-today')));
    await tester.pumpAndSettle();
    expect(find.text('Возобновить серию'), findsOneWidget);
  });

  testWidgets('меню позволяет пропустить задачу (статус skipped)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      buildSubject(tasks: [taskOnToday], onSkip: (_) {}),
    );

    await tester.ensureVisible(
      find.byKey(const Key('calendar_task_menu_task-today')),
    );
    await tester.tap(find.byKey(const Key('calendar_task_menu_task-today')));
    await tester.pumpAndSettle();
    expect(find.text('Пропустить'), findsOneWidget);
  });

  testWidgets('показывает пустое состояние, если на день нет задач', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    expect(find.text('Нет задач на этот день'), findsOneWidget);
    expect(find.text('Создать задачу'), findsOneWidget);
  });

  testWidgets('показывает заголовок дня с количеством задач', (tester) async {
    await tester.pumpWidget(buildSubject(tasks: [taskOnToday]));

    // Заголовок дня с числом задач
    expect(find.textContaining('задача'), findsWidgets);
  });

  testWidgets('выполненная задача показывается с зачёркиванием', (
    tester,
  ) async {
    final completed = taskOnToday.copyWith(
      status: TaskStatus.completed,
      completedAt: today,
    );

    await tester.pumpWidget(buildSubject(tasks: [completed]));

    // В ячейке месяца полоска (compact, без зачёркивания) и в списке дня —
    // карточка с зачёркнутым заголовком.
    expect(find.text('Сегодняшняя задача'), findsNWidgets(2));

    final listText = tester.widget<Text>(
      find.text('Сегодняшняя задача').last,
    );
    expect(listText.style?.decoration, TextDecoration.lineThrough);
  });

  testWidgets('переключатель режима: Месяц/Неделя/День', (tester) async {
    await tester.pumpWidget(buildSubject());

    // SegmentedButton с тремя режимами
    expect(find.text('Месяц'), findsOneWidget);
    expect(find.text('Неделя'), findsOneWidget);
    expect(find.text('День'), findsOneWidget);

    // Переключаемся на «День» → появляется временная шкала (TimeScaleView)
    await tester.tap(find.text('День'));
    await tester.pumpAndSettle();

    expect(find.text('00:00'), findsOneWidget); // подпись часа на шкале
  });

  testWidgets('перетаскивание задачи вызывает onRescheduleToDay с датой', (
    tester,
  ) async {
    // Увеличиваем окно — задача в списке дня должна быть видима.
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Задача на сегодня видна в списке выбранного дня.
    final tomorrow = today.add(const Duration(days: 1));

    Task? draggedTask;
    DateTime? draggedDay;
    await tester.pumpWidget(
      buildSubject(
        tasks: [taskOnToday],
        onRescheduleToDay: (task, day) {
          draggedTask = task;
          draggedDay = day;
        },
      ),
    );

    // Находим перетаскиваемую карточку
    final draggable = find.byKey(Key('draggable_task_task-today'));
    expect(draggable, findsOneWidget);

    // Целевой день — завтрашний (всегда в сетке текущего месяца).
    final target = find.byKey(
      Key(
        'calendar_day_${tomorrow.year}_${tomorrow.month}_${tomorrow.day}',
      ),
    );
    expect(target, findsOneWidget);

    final source = tester.getCenter(draggable);
    final destination = tester.getCenter(target);

    // Long-press drag: зажимаем, ждём long-press, перемещаем к целевому дню.
    final gesture = await tester.startGesture(source);
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(destination);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(draggedTask?.id, 'task-today');
    expect(draggedDay, isNotNull);
    expect(DateUtils.isSameDay(draggedDay!, tomorrow), isTrue);
  });

  testWidgets('полоска задачи окрашена в цвет категории', (tester) async {
    final category = TaskCategory(
      id: 'cat-red',
      householdId: 'household-1',
      name: 'Покупки',
      colorHex: 'E53935', // красный
    );
    final taskWithCategory = taskOnToday.copyWith(categoryId: 'cat-red');

    await tester.pumpWidget(
      buildSubject(
        tasks: [taskWithCategory],
        categoriesById: {'cat-red': category},
      ),
    );

    // В ячейке месяца — полоска (Container) с фоном в цвет категории
    // (альфа 0.25) и левой рамкой того же цвета.
    final barColor = const Color(0xFFE53935);
    final barFinder = find.byWidgetPredicate(
      (widget) {
        if (widget is! Container) return false;
        final decoration = widget.decoration;
        if (decoration is! BoxDecoration) return false;
        final hasBg = decoration.color == barColor.withValues(alpha: 0.25);
        final border = decoration.border;
        final hasLeftBorder =
            border is Border && border.left.color == barColor;
        return hasBg && hasLeftBorder;
      },
    );

    expect(barFinder, findsWidgets);
  });

  testWidgets('при многих задачах на день показывается «+N ещё»', (
    tester,
  ) async {
    // 3 задачи на сегодня — в ячейке 1 полоска + «+2 ещё».
    final tasks = [
      for (var i = 0; i < 3; i++)
        taskOnToday.copyWith(
          id: 'task-$i',
          title: 'Задача $i',
        ),
    ];

    await tester.pumpWidget(buildSubject(tasks: tasks));

    expect(find.text('+2 ещё'), findsOneWidget);
  });

  testWidgets('перетаскивание к краю листает календарь на другой месяц', (
    tester,
  ) async {
    // Увеличиваем окно — задача в списке дня должна быть видима.
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final nextMonth = DateTime(today.year, today.month + 1);
    final nextMonthHeader = DateFormat.yMMMM('ru_RU').format(nextMonth);

    await tester.pumpWidget(buildSubject(tasks: [taskOnToday]));

    // Находим перетаскиваемую карточку и правый край календаря.
    final draggable = find.byKey(Key('draggable_task_task-today'));
    expect(draggable, findsOneWidget);

    final source = tester.getCenter(draggable);
    // Край календаря — правый край его рамки (в логических координатах).
    final calendarRect = tester.getRect(find.byType(CalendarView));
    final edge = Offset(calendarRect.right - 2, source.dy);
    final center = calendarRect.center;

    final gesture = await tester.startGesture(source);
    await tester.pump(const Duration(milliseconds: 600)); // long-press
    await gesture.moveTo(edge);
    await tester.pump(); // начать перетаскивание

    // Ждём таймер авто-листания (300мс период) → одна страница вперёд.
    await tester.pump(const Duration(milliseconds: 350));

    // Возвращаем курсор в центр, чтобы остановить авто-листание.
    await gesture.moveTo(center);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    // Заголовок календаря сменился на следующий месяц.
    expect(find.text(nextMonthHeader), findsOneWidget);
  });
}
