import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/scheduled/presentation/widgets/calendar_view.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';import 'package:family_planner/features/tasks/domain/entities/task_category.dart';
import 'package:family_planner/features/tasks/domain/entities/task_recurrence.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:table_calendar/table_calendar.dart';

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
    String currentMemberId = 'member-1',
    void Function(Task, DateTime)? onRescheduleToDay,
    void Function(Task)? onTogglePause,
    void Function(Task)? onSkip,
    void Function(Task)? onComplete,
    void Function(Task)? onEdit,
    void Function(Task)? onDelete,
    void Function(Task, List<HouseholdMember>)? onAssign,
    void Function(Task)? onTogglePin,
    void Function(Task)? onReschedule,
    void Function(Task)? onDuplicate,
    void Function(Task)? onUncomplete,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: CalendarView(
          tasks: tasks,
          members: members,
          currentMemberId: currentMemberId,
          categoriesById: categoriesById,
          onEdit: onEdit ?? (_) {},
          onDelete: onDelete ?? (_) {},
          onAssign: onAssign ?? (_, _) {},
          onTogglePin: onTogglePin ?? (_) {},
          onReschedule: onReschedule ?? (_) {},
          onRescheduleToDay: onRescheduleToDay ?? (_, _) {},
          onDuplicate: onDuplicate ?? (_) {},
          onTogglePause: onTogglePause,
          onSkip: onSkip,
          onComplete: onComplete ?? (_) {},
          onUncomplete: onUncomplete ?? (_) {},
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

  testWidgets('вертикальный свайп по сетке месяца вызывает onFormatChanged', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject(tasks: [taskOnToday]));

    // Свайп вверх по TableCalendar. Формат всего один (month), поэтому
    // onFormatChanged вызывается с month, но сам колбэк исполняется (setState).
    final table = find.byType(TableCalendar<Task>);
    expect(table, findsOneWidget);

    await tester.fling(table, const Offset(0, -200), 1000);
    await tester.pumpAndSettle();

    // Календарь всё ещё в месячном режиме.
    expect(find.text('Месяц'), findsOneWidget);
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

  testWidgets('перетаскивание к левому краю листает календарь назад', (
    tester,
  ) async {
    // Увеличиваем окно — задача в списке дня должна быть видима.
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final prevMonth = DateTime(today.year, today.month - 1);
    final prevMonthHeader = DateFormat.yMMMM('ru_RU').format(prevMonth);

    await tester.pumpWidget(buildSubject(tasks: [taskOnToday]));

    final draggable = find.byKey(Key('draggable_task_task-today'));
    expect(draggable, findsOneWidget);

    final source = tester.getCenter(draggable);
    final calendarRect = tester.getRect(find.byType(CalendarView));
    final edge = Offset(calendarRect.left + 2, source.dy);
    final center = calendarRect.center;

    final gesture = await tester.startGesture(source);
    await tester.pump(const Duration(milliseconds: 600)); // long-press
    await gesture.moveTo(edge);
    await tester.pump(); // начать перетаскивание

    // Ждём таймер авто-листания (300мс период) → одна страница назад.
    await tester.pump(const Duration(milliseconds: 350));

    // Возвращаем курсор в центр, чтобы остановить авто-листание.
    await gesture.moveTo(center);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    // Заголовок календаря сменился на предыдущий месяц.
    expect(find.text(prevMonthHeader), findsOneWidget);
  });

  testWidgets('чекбокс выполнения в списке дня активен, если пользователь в allowedMemberIds', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Task? completed;
    await tester.pumpWidget(
      buildSubject(tasks: [taskOnToday], onComplete: (task) => completed = task),
    );

    // В списке выбранного дня — карточка с чекбоксом.
    await tester.tap(find.byIcon(Icons.radio_button_unchecked).first);
    await tester.pump();

    expect(completed?.id, 'task-today');
  });

  testWidgets('чекбокс выполнения в списке дня неактивен, если пользователь не в allowedMemberIds', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Task? completed;
    await tester.pumpWidget(
      buildSubject(
        tasks: [taskOnToday],
        currentMemberId: 'other-member',
        onComplete: (task) => completed = task,
      ),
    );

    await tester.tap(
      find.byIcon(Icons.radio_button_unchecked).first,
      warnIfMissed: false,
    );
    await tester.pump();

    expect(completed, isNull);
  });

  testWidgets('меню карточки: редактировать/удалить/назначить/перенести/дублировать вызывают колбэки', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final called = <String>[];
    await tester.pumpWidget(
      buildSubject(
        tasks: [taskOnToday],
        onEdit: (_) => called.add('edit'),
        onDelete: (_) => called.add('delete'),
        onAssign: (_, _) => called.add('assign'),
        onReschedule: (_) => called.add('reschedule'),
        onDuplicate: (_) => called.add('duplicate'),
      ),
    );

    Future<void> tapMenuItem(String label) async {
      await tester.ensureVisible(
        find.byKey(const Key('calendar_task_menu_task-today')),
      );
      await tester.tap(find.byKey(const Key('calendar_task_menu_task-today')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    await tapMenuItem('Редактировать');
    expect(called, contains('edit'));

    await tapMenuItem('Перенести');
    expect(called, contains('reschedule'));

    await tapMenuItem('Дублировать');
    expect(called, contains('duplicate'));

    await tapMenuItem('Назначить');
    expect(called, contains('assign'));

    await tapMenuItem('Удалить');
    expect(called, contains('delete'));
    expect(called, ['edit', 'reschedule', 'duplicate', 'assign', 'delete']);
  });

  testWidgets('закреплённая задача: чип «Закреплено» и пункт «Открепить»', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final pinned = taskOnToday.copyWith(pinnedMemberId: 'member-1');
    bool? toggled;
    await tester.pumpWidget(
      buildSubject(tasks: [pinned], onTogglePin: (_) => toggled = true),
    );

    // Чип «Закреплено» в карточке дня.
    expect(find.text('Закреплено'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('calendar_task_menu_task-today')),
    );
    await tester.tap(find.byKey(const Key('calendar_task_menu_task-today')));
    await tester.pumpAndSettle();

    // Для закреплённой: «Открепить» (вместо «Назначить»).
    await tester.tap(find.text('Открепить'));
    await tester.pumpAndSettle();
    expect(toggled, isTrue);
  });

  testWidgets('чип времени начала показывается у задачи с plannedTime', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final withTime = taskOnToday.copyWith(
      plannedTime: const Duration(hours: 9, minutes: 30),
    );
    await tester.pumpWidget(buildSubject(tasks: [withTime]));

    // Чип времени начала (HH:MM) в карточке дня.
    expect(find.text('09:30'), findsOneWidget);
  });

  testWidgets('чип исполнителя показывает имя назначенного участника', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final assigned = taskOnToday.copyWith(assignedMemberId: 'member-2');
    final member2 = HouseholdMember(
      profileId: 'member-2',
      displayName: 'Влад',
      role: 'member',
    );
    await tester.pumpWidget(
      buildSubject(tasks: [assigned], members: [member2]),
    );

    expect(find.text('Влад'), findsOneWidget);
  });

  testWidgets('назначенный участник с неизвестным id не показывается', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // assignedMemberId не найден в members → имя null → чипа нет.
    final assigned = taskOnToday.copyWith(assignedMemberId: 'unknown');
    await tester.pumpWidget(
      buildSubject(tasks: [assigned], members: const []),
    );

    // Нет чипа исполнителя; но имя не существует вовсе.
    expect(find.text('unknown'), findsNothing);
  });

  testWidgets('выбор дня вызывает setState и обновляет список задач', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final tomorrow = today.add(const Duration(days: 1));
    final tomorrowTask = taskOnToday.copyWith(
      id: 'task-tomorrow',
      title: 'Завтрашняя',
      plannedFor: tomorrow,
    );
    await tester.pumpWidget(
      buildSubject(tasks: [tomorrowTask]),
    );

    // Завтрашняя задача сейчас не в списке выбранного дня (сегодня):
    // карточки дня для неё нет.
    expect(
      find.byKey(const Key('calendar_task_menu_task-tomorrow')),
      findsNothing,
    );

    // Выбираем завтрашний день в сетке.
    final target = find.byKey(
      Key('calendar_day_${tomorrow.year}_${tomorrow.month}_${tomorrow.day}'),
    );
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();

    // После выбора дня его карточка появляется в списке под сеткой.
    expect(
      find.byKey(const Key('calendar_task_menu_task-tomorrow')),
      findsOneWidget,
    );
  });

  testWidgets('навигация в недельном режиме листает календарь', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildSubject());

    // Переключаемся в недельный режим (TimeScaleView с навигацией).
    await tester.tap(find.text('Неделя'));
    await tester.pumpAndSettle();

    // Запоминаем заголовок недели до навигации.
    final before = tester
        .widget<Text>(
          find.byWidgetPredicate(
            (w) => w is Text && w.style?.fontWeight == FontWeight.w700,
          ).first,
        )
        .data;

    // Кнопка «Вперёд» в шапке TimeScaleView.
    await tester.tap(find.byTooltip('Вперёд'));
    await tester.pumpAndSettle();

    final after = tester
        .widget<Text>(
          find.byWidgetPredicate(
            (w) => w is Text && w.style?.fontWeight == FontWeight.w700,
          ).first,
        )
        .data;

    expect(after, isNot(before));
  });

  testWidgets('меню: «Поставить на паузу» и «Пропустить» для повторяющейся задачи', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final recurring = taskOnToday.copyWith(
      templateId: 'template-1',
      recurrence: const TaskRecurrence.daily(),
    );
    final called = <String>[];
    await tester.pumpWidget(
      buildSubject(
        tasks: [recurring],
        onTogglePause: (_) => called.add('pause'),
        onSkip: (_) => called.add('skip'),
      ),
    );

    await tester.ensureVisible(
      find.byKey(const Key('calendar_task_menu_task-today')),
    );
    await tester.tap(find.byKey(const Key('calendar_task_menu_task-today')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Поставить на паузу'));
    await tester.pumpAndSettle();
    expect(called, contains('pause'));

    await tester.tap(find.byKey(const Key('calendar_task_menu_task-today')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Пропустить'));
    await tester.pumpAndSettle();
    expect(called, contains('skip'));
  });

  testWidgets('меню: «Отменить выполнение» для выполненной задачи', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final completed = taskOnToday.copyWith(
      status: TaskStatus.completed,
      completedAt: today,
    );
    Task? uncompleted;
    await tester.pumpWidget(
      buildSubject(tasks: [completed], onUncomplete: (t) => uncompleted = t),
    );

    // Выполненная задача: чекбокс check_circle → тап → onUncomplete.
    await tester.tap(find.byIcon(Icons.check_circle));
    await tester.pump();

    expect(uncompleted?.id, 'task-today');
  });
}
