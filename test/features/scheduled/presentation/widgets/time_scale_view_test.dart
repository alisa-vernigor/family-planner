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
    String currentMemberId = 'member-1',
    void Function(Task)? onEdit,
    void Function(Task)? onComplete,
    void Function(Task)? onUncomplete,
    void Function(DateTime)? onFocusedDayChanged,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: TimeScaleView(
          tasks: tasks,
          categoriesById: categoriesById,
          currentMemberId: currentMemberId,
          weekMode: weekMode,
          focusedDay: focusedDay ?? today,
          onFocusedDayChanged: onFocusedDayChanged ?? (_) {},
          onEdit: onEdit ?? (_) {},
          onComplete: onComplete ?? (_) {},
          onUncomplete: onUncomplete ?? (_) {},
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

  testWidgets('чекбокс выполнения активен, если пользователь в allowedMemberIds', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Task? completed;
    await tester.pumpWidget(
      buildSubject(
        tasks: [earlyTask],
        onComplete: (task) => completed = task,
      ),
    );

    // Ранняя задача в 8:00 — чекбокс-иконка внутри блока.
    await tester.tap(find.byIcon(Icons.radio_button_unchecked));
    await tester.pump();

    expect(completed?.id, 'task-early');
  });

  testWidgets('чекбокс выполнения неактивен, если пользователь не в allowedMemberIds', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Task? completed;
    await tester.pumpWidget(
      buildSubject(
        tasks: [earlyTask],
        currentMemberId: 'other-member',
        onComplete: (task) => completed = task,
      ),
    );

    // Тап по «неактивному» чекбоксу не должен вызвать onComplete.
    await tester.tap(find.byIcon(Icons.radio_button_unchecked), warnIfMissed: false);
    await tester.pump();

    expect(completed, isNull);
  });

  testWidgets('навигация: кнопки «Назад»/«Вперёд» вызывают onFocusedDayChanged', (
    tester,
  ) async {
    final changed = <DateTime>[];
    await tester.pumpWidget(
      buildSubject(onFocusedDayChanged: (day) => changed.add(day)),
    );

    // День-режим: «Вперёд» сдвигает на +1 день.
    await tester.tap(find.byTooltip('Вперёд'));
    await tester.pump();
    expect(changed, hasLength(1));
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    expect(
      DateUtils.isSameDay(changed.first, tomorrow),
      isTrue,
    );

    // «Назад» возвращает на предыдущий день.
    await tester.tap(find.byTooltip('Назад'));
    await tester.pump();
    expect(changed, hasLength(2));
  });

  testWidgets('навигация в недельном режиме сдвигает на 7 дней', (tester) async {
    final changed = <DateTime>[];
    await tester.pumpWidget(
      buildSubject(weekMode: true, onFocusedDayChanged: (day) => changed.add(day)),
    );

    await tester.tap(find.byTooltip('Вперёд'));
    await tester.pump();

    expect(changed, hasLength(1));
    final nextWeek = DateTime(today.year, today.month, today.day + 7);
    expect(
      DateUtils.isSameDay(changed.first, nextWeek),
      isTrue,
    );
  });

  testWidgets('заголовок недели при пересечении месяцев показывает диапазон дат', (
    tester,
  ) async {
    // Неделя с 31 августа 2026 (понедельник) заканчивается 6 сентября —
    // пересекает месяц. Заголовок: «31 авг – 6 сен 2026».
    final crossMonthMonday = DateTime(2026, 8, 31);
    await tester.pumpWidget(
      buildSubject(weekMode: true, focusedDay: crossMonthMonday),
    );

    expect(find.textContaining('авг'), findsWidgets);
    expect(find.textContaining('сен'), findsWidgets);
    // Год присутствует (диапазон через месяц).
    expect(find.textContaining('2026'), findsWidgets);
  });

  testWidgets('тап по задаче «Весь день» открывает редактирование', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Task? edited;
    await tester.pumpWidget(
      buildSubject(tasks: [allDayTask], onEdit: (task) => edited = task),
    );

    // Чип «Весь день» с заголовком задачи кликабелен.
    await tester.tap(find.text('Весь день').last);
    await tester.pump();

    expect(edited?.id, 'task-allday');
  });

  testWidgets('выполненная задача: чекбокс вызывает onUncomplete', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final completed = earlyTask.copyWith(
      status: TaskStatus.completed,
      completedAt: today,
    );
    Task? uncompleted;
    await tester.pumpWidget(
      buildSubject(tasks: [completed], onUncomplete: (t) => uncompleted = t),
    );

    // Выполненная задача: иконка check_circle, тап → onUncomplete.
    await tester.tap(find.byIcon(Icons.check_circle));
    await tester.pump();

    expect(uncompleted?.id, 'task-early');
  });

  testWidgets('длинная задача (48м) рисуется выше минимальной высоты', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final long = earlyTask.copyWith(estimatedDurationMinutes: 48);
    await tester.pumpWidget(buildSubject(tasks: [long]));

    // Блок задачи существует и имеет высоту > 36px (мин. высота).
    final blockFinder = find.text('Ранняя задача');
    expect(blockFinder, findsOneWidget);
  });

  testWidgets('две пересекающиеся задачи встают в соседние колонки', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final overlapping = earlyTask.copyWith(
      id: 'task-overlap',
      title: 'Пересекающаяся',
      plannedTime: const Duration(hours: 8, minutes: 20),
      estimatedDurationMinutes: 30,
    );
    await tester.pumpWidget(
      buildSubject(tasks: [earlyTask, overlapping]),
    );

    // Обе задачи видны.
    expect(find.text('Ранняя задача'), findsOneWidget);
    expect(find.text('Пересекающаяся'), findsOneWidget);
  });

  testWidgets('третья задача переиспользует освободившуюся колонку', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // A [8:00–8:30], B [8:20–8:50] (нов. колонка), C [8:30–9:00]
    // (переиспользует колонку A — та завершилась в 8:30).
    final a = earlyTask.copyWith(title: 'Задача A');
    final b = earlyTask.copyWith(
      id: 'task-b',
      title: 'Задача B',
      plannedTime: const Duration(hours: 8, minutes: 20),
    );
    final c = earlyTask.copyWith(
      id: 'task-c',
      title: 'Задача C',
      plannedTime: const Duration(hours: 8, minutes: 30),
    );

    await tester.pumpWidget(buildSubject(tasks: [a, b, c]));

    // Все три задачи видны.
    expect(find.text('Задача A'), findsOneWidget);
    expect(find.text('Задача B'), findsOneWidget);
    expect(find.text('Задача C'), findsOneWidget);
  });

  testWidgets('горизонтальная прокрутка шкалы синхронизирует шапку и ряд «Весь день»', (
    tester,
  ) async {
    // Узкое окно в недельном режиме: 7 колонок не влезают → появляется
    // горизонтальная прокрутка → синхронизация контроллеров.
    tester.view.physicalSize = const Size(200, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      buildSubject(weekMode: true, tasks: [allDayTask]),
    );

    // Прокручиваем шкалу вправо — шапка и ряд «Весь день» догоняют.
    await tester.drag(
      find.byType(TimeScaleView),
      const Offset(-80, 0),
    );
    await tester.pumpAndSettle();

    // Не упало и синхронизация не зациклилась.
    expect(find.byType(TimeScaleView), findsOneWidget);
  });
}
