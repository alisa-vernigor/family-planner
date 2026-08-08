import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/tasks/tasks.dart';

import 'time_scale_view.dart';

/// Календарный режим экрана «Запланированные».
///
/// Месячная/недельная сетка [TableCalendar] с маркерами задач на днях и
/// списком задач выбранного дня под сеткой. Задачи за пределами видимого
/// месяца не фильтруются — календарь показывает маркеры всех переданных задач.
///
/// Перенос задачи: длинное нажатие на карточку в списке дня → перетащить на
/// день в сетке → [onRescheduleToDay].
final class CalendarView extends StatefulWidget {
  const CalendarView({
    required this.tasks,
    required this.members,
    required this.currentMemberId,
    required this.categoriesById,
    required this.onEdit,
    required this.onDelete,
    required this.onAssign,
    required this.onTogglePin,
    required this.onReschedule,
    required this.onRescheduleToDay,
    required this.onDuplicate,
    required this.onComplete,
    required this.onUncomplete,
    required this.onCreate,
    this.onTogglePause,
    this.onSkip,
    super.key,
  });

  final List<Task> tasks;
  final List<HouseholdMember> members;
  final String currentMemberId;
  final Map<String, TaskCategory> categoriesById;

  final void Function(Task task) onEdit;
  final void Function(Task task) onDelete;
  final void Function(Task task, List<HouseholdMember> members) onAssign;
  final void Function(Task task) onTogglePin;
  final void Function(Task task) onReschedule;

  /// Перенос задачи на конкретную дату (drag & drop).
  final void Function(Task task, DateTime day) onRescheduleToDay;
  final void Function(Task task) onDuplicate;
  final void Function(Task task) onComplete;
  final void Function(Task task) onUncomplete;
  final VoidCallback onCreate;

  /// Пауза/возобновление серии повторяющейся задачи.
  final void Function(Task task)? onTogglePause;

  /// Пропустить задачу (статус `skipped`).
  final void Function(Task task)? onSkip;

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

final class _CalendarViewState extends State<CalendarView> {
  static const String _localeTag = 'ru_RU';

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  /// Режим отображения: месяц (сетка с полосками), неделя/день (временная
  /// шкала с часами, как в Google Calendar).
  _CalendarMode _mode = _CalendarMode.month;

  PageController? _pageController;
  Timer? _autoScrollTimer;

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tasks != widget.tasks) {
      // При обновлении задач (realtime/оптимистичные правки) пересчитываем
      // список выбранного дня, чтобы не показывать устаревшие данные.
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final headerStyle = HeaderStyle(
      titleCentered: true,
      formatButtonVisible: false,
      formatButtonShowsNext: false,
      titleTextStyle: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: cs.onSurface,
      ),
      titleTextFormatter: (date, locale) => _formatHeaderTitle(date),
      leftChevronIcon: Icon(Icons.chevron_left, color: cs.primary),
      rightChevronIcon: Icon(Icons.chevron_right, color: cs.primary),
      formatButtonTextStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: cs.primary,
      ),
      formatButtonDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      formatButtonPadding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
    );

    final daysOfWeekStyle = DaysOfWeekStyle(
      dowTextFormatter: (date, locale) =>
          DateFormat.E(locale.toString()).format(date),
      weekdayStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: cs.onSurfaceVariant,
      ),
      weekendStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: cs.primary,
      ),
    );

    final calendarStyle = CalendarStyle(
      outsideDaysVisible: true,
      markersMaxCount: 3,
      markerDecoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
      todayDecoration: BoxDecoration(
        color: cs.primaryContainer,
        shape: BoxShape.circle,
      ),
      todayTextStyle: TextStyle(
        fontWeight: FontWeight.w700,
        color: cs.onPrimaryContainer,
      ),
      selectedDecoration: BoxDecoration(
        color: cs.primary,
        shape: BoxShape.circle,
      ),
      selectedTextStyle: TextStyle(
        fontWeight: FontWeight.w700,
        color: cs.onPrimary,
      ),
      defaultTextStyle: TextStyle(fontSize: 14, color: cs.onSurface),
      weekendTextStyle: TextStyle(
        fontSize: 14,
        color: cs.onSurfaceVariant,
      ),
      outsideTextStyle: TextStyle(fontSize: 14, color: cs.outlineVariant),
      rowDecoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
      ),
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SegmentedButton<_CalendarMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: _CalendarMode.month,
                    label: Text('Месяц'),
                  ),
                  ButtonSegment(
                    value: _CalendarMode.week,
                    label: Text('Неделя'),
                  ),
                  ButtonSegment(
                    value: _CalendarMode.day,
                    label: Text('День'),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (selection) {
                  setState(() => _mode = selection.first);
                },
              ),
            ],
          ),
        ),
        if (_mode == _CalendarMode.month) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TableCalendar<Task>(
            locale: _localeTag,
            firstDay: DateTime(DateTime.now().year - 1),
            lastDay: DateTime(DateTime.now().year + 1),
            focusedDay: _focusedDay,
            currentDay: DateTime.now(),
            startingDayOfWeek: StartingDayOfWeek.monday,
            calendarFormat: CalendarFormat.month,
            availableCalendarFormats: const {
              CalendarFormat.month: 'Месяц',
            },
            onFormatChanged: (format) {
              setState(() {});
            },
            onCalendarCreated: (controller) {
              _pageController = controller;
            },
            rowHeight: 64,
            eventLoader: _tasksForDay,
            selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            headerStyle: headerStyle,
            daysOfWeekStyle: daysOfWeekStyle,
            calendarStyle: calendarStyle,
            calendarBuilders: CalendarBuilders<Task>(
              defaultBuilder: (context, day, focused) => _buildDayCell(
                day,
                focused,
                isToday: false,
                isSelected: false,
                isOutside: false,
                style: calendarStyle,
              ),
              todayBuilder: (context, day, focused) => _buildDayCell(
                day,
                focused,
                isToday: true,
                isSelected: false,
                isOutside: false,
                style: calendarStyle,
              ),
              selectedBuilder: (context, day, focused) => _buildDayCell(
                day,
                focused,
                isToday: false,
                isSelected: true,
                isOutside: false,
                style: calendarStyle,
              ),
              outsideBuilder: (context, day, focused) => _buildDayCell(
                day,
                focused,
                isToday: false,
                isSelected: false,
                isOutside: true,
                style: calendarStyle,
              ),
              markerBuilder: (context, day, tasks) {
                // Полоски задач уже нарисованы внутри ячейки (_buildDayCell),
                // поэтому отдельные точки-маркеры не нужны.
                if (tasks.isEmpty) return null;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        ],
        if (_mode == _CalendarMode.month) ...[
          const SizedBox(height: 8),
          _DayTasksHeader(
            day: _selectedDay,
            count: _tasksForDay(_selectedDay).length,
          ),
          Expanded(
            child: _tasksForDay(_selectedDay).isEmpty
                ? SingleChildScrollView(
                    child: SizedBox(
                      height: MediaQuery.sizeOf(context).height * 0.4,
                      child: _emptyDay(cs),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    children: [
                      for (final task in _tasksForDay(_selectedDay))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: LongPressDraggable<Task>(
                            key: Key('draggable_task_${task.id}'),
                            data: task,
                            onDragStarted: () {
                              _stopAutoScroll();
                            },
                            onDragUpdate: (details) {
                              final direction = _edgeDirection(details);
                              if (direction != null) {
                                _startAutoScroll(direction);
                              } else {
                                _stopAutoScroll();
                              }
                            },
                            onDragEnd: (details) {
                              _stopAutoScroll();
                            },
                            onDraggableCanceled: (_, _) {
                              _stopAutoScroll();
                            },
                            feedback: Material(
                              elevation: 4,
                              borderRadius: BorderRadius.circular(12),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 260),
                                child: _CalendarDayTaskCard(
                                  task: task,
                                  members: widget.members,
                                  currentMemberId: widget.currentMemberId,
                                  category:
                                      widget.categoriesById[task.categoryId],
                                  formatDate: _formatDate,
                                  onEdit: () => widget.onEdit(task),
                                  onDelete: () => widget.onDelete(task),
                                  onAssign: () =>
                                      widget.onAssign(task, widget.members),
                                  onTogglePin: () => widget.onTogglePin(task),
                                  onReschedule: () => widget.onReschedule(task),
                                  onDuplicate: () => widget.onDuplicate(task),
                                  onTogglePause:
                                      widget.onTogglePause == null
                                      ? null
                                      : () => widget.onTogglePause!(task),
                                  onSkip:
                                      widget.onSkip == null
                                      ? null
                                      : () => widget.onSkip!(task),
                                  onComplete: () => widget.onComplete(task),
                                  onUncomplete: () => widget.onUncomplete(task),
                                ),
                              ),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.35,
                              child: _CalendarDayTaskCard(
                                task: task,
                                members: widget.members,
                                currentMemberId: widget.currentMemberId,
                                category:
                                    widget.categoriesById[task.categoryId],
                                formatDate: _formatDate,
                                onEdit: () => widget.onEdit(task),
                                onDelete: () => widget.onDelete(task),
                                onAssign: () =>
                                    widget.onAssign(task, widget.members),
                                onTogglePin: () => widget.onTogglePin(task),
                                onReschedule: () => widget.onReschedule(task),
                                onDuplicate: () => widget.onDuplicate(task),
                                onTogglePause:
                                    widget.onTogglePause == null
                                    ? null
                                    : () => widget.onTogglePause!(task),
                                onSkip:
                                    widget.onSkip == null
                                    ? null
                                    : () => widget.onSkip!(task),
                                onComplete: () => widget.onComplete(task),
                                onUncomplete: () => widget.onUncomplete(task),
                              ),
                            ),
                            child: _CalendarDayTaskCard(
                              task: task,
                              members: widget.members,
                              currentMemberId: widget.currentMemberId,
                              category: widget.categoriesById[task.categoryId],
                              formatDate: _formatDate,
                              onEdit: () => widget.onEdit(task),
                              onDelete: () => widget.onDelete(task),
                              onAssign: () =>
                                  widget.onAssign(task, widget.members),
                              onTogglePin: () => widget.onTogglePin(task),
                              onReschedule: () => widget.onReschedule(task),
                              onDuplicate: () => widget.onDuplicate(task),
                              onTogglePause:
                                  widget.onTogglePause == null
                                  ? null
                                  : () => widget.onTogglePause!(task),
                              onSkip:
                                  widget.onSkip == null
                                  ? null
                                  : () => widget.onSkip!(task),
                              onComplete: () => widget.onComplete(task),
                              onUncomplete: () => widget.onUncomplete(task),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
        if (_mode != _CalendarMode.month)
          Expanded(
            child: TimeScaleView(
              tasks: widget.tasks,
              categoriesById: widget.categoriesById,
              currentMemberId: widget.currentMemberId,
              weekMode: _mode == _CalendarMode.week,
              focusedDay: _focusedDay,
              onFocusedDayChanged: (day) {
                setState(() => _focusedDay = day);
              },
              onEdit: widget.onEdit,
              onComplete: widget.onComplete,
              onUncomplete: widget.onUncomplete,
            ),
          ),
      ],
    );
  }

  /// Ячейка дня — номер + [DragTarget] для переноса задачи перетаскиванием
  /// и цветные полоски задач (как события в Google Calendar).
  Widget _buildDayCell(
    DateTime day,
    DateTime focusedDay, {
    required bool isToday,
    required bool isSelected,
    required bool isOutside,
    required CalendarStyle style,
  }) {
    final cs = Theme.of(context).colorScheme;

    Decoration decoration;
    TextStyle textStyle;
    if (isSelected) {
      decoration = style.selectedDecoration;
      textStyle = style.selectedTextStyle;
    } else if (isToday) {
      decoration = style.todayDecoration;
      textStyle = style.todayTextStyle;
    } else if (isOutside) {
      decoration = style.outsideDecoration;
      textStyle = style.outsideTextStyle;
    } else {
      final isWeekend =
          day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
      decoration =
          isWeekend ? style.weekendDecoration : style.defaultDecoration;
      textStyle = isWeekend ? style.weekendTextStyle : style.defaultTextStyle;
    }

    final label = '${day.day}';
    final dayTasks = _tasksForDay(day);

    return DragTarget<Task>(
      key: Key('calendar_day_${day.year}_${day.month}_${day.day}'),
      onWillAcceptWithDetails: (details) => !details.data.isCompleted,
      onAcceptWithDetails: (details) {
        final task = details.data;
        final target = DateTime(day.year, day.month, day.day);
        setState(() {
          _selectedDay = target;
          _focusedDay = target;
        });
        widget.onRescheduleToDay(task, target);
      },
      builder: (context, candidates, _) {
        final isTarget = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: style.cellMargin,
          alignment: style.cellAlignment,
          decoration: isTarget
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.primaryContainer,
                  border: Border.all(color: cs.primary, width: 2),
                )
              : decoration,
          // Внутри ячейки: номер дня + полоски задач.
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(label, style: textStyle),
              ),
              // В ячейке месяца (высота ~52px): номер + до 2 полосок задач.
              for (final task in dayTasks.take(1))
                _DayTaskBar(task: task, color: _markerColor(task)),
              if (dayTasks.length > 1)
                _DayTaskBar.more(count: dayTasks.length - 1),
            ],
          ),
        );
      },
    );
  }

  /// Цветной маркер категории для полоски задачи.
  Color _markerColor(Task task) {
    final category = widget.categoriesById[task.categoryId];
    if (category != null) {
      return colorFromHex(category.colorHex, fallback: cs.primary);
    }
    return cs.primary;
  }

  ColorScheme get cs => Theme.of(context).colorScheme;

  /// Задачи на указанный день (включая выполненные — чтобы видеть прогресс).
  List<Task> _tasksForDay(DateTime day) {
    return widget.tasks
        .where((t) => DateUtils.isSameDay(t.plannedFor, day))
        .toList(growable: false);
  }

  // ── Авто-листание при перетаскивании к краю ────────────

  /// Запускает периодическое листание в [direction], пока курсор у края.
  void _startAutoScroll(_ScrollDirection direction) {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      final controller = _pageController;
      if (controller == null || !controller.hasClients) return;
      final position = controller.position;

      if (direction == _ScrollDirection.next) {
        if (position.pixels < position.maxScrollExtent) {
          controller.nextPage(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      } else {
        if (position.pixels > position.minScrollExtent) {
          controller.previousPage(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  /// Возвращает направление, если [details] перетаскивания находится
  /// достаточно близко к левому/правому краю календаря.
  _ScrollDirection? _edgeDirection(DragUpdateDetails details) {
    final box = context.findRenderObject();
    if (box is! RenderBox) return null;
    final width = box.size.width;
    const edge = 64.0;
    final dx = details.globalPosition.dx - box.localToGlobal(Offset.zero).dx;

    if (dx < edge) return _ScrollDirection.previous;
    if (dx > width - edge) return _ScrollDirection.next;
    return null;
  }

  Widget _emptyDay(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_available_outlined,
              size: 48,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Нет задач на этот день',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Создайте задачу или выберите другой день',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: widget.onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Создать задачу'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatHeaderTitle(DateTime date) {
    return DateFormat.yMMMM(_localeTag).format(date);
  }

  String _formatDate(DateTime value) {
    final date = DateTime(value.year, value.month, value.day);
    return DateFormat('d MMMM yyyy', _localeTag).format(date);
  }
}

/// Заголовок «9 августа 2026 — N задач».
final class _DayTasksHeader extends StatelessWidget {
  const _DayTasksHeader({required this.day, required this.count});

  final DateTime day;
  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = DateFormat('d MMMM yyyy', 'ru_RU').format(day);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          Icon(Icons.today_outlined, size: 18, color: cs.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            _pluralTasks(count),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _pluralTasks(int n) {
    final n10 = n % 10;
    final n100 = n % 100;
    if (n10 == 1 && n100 != 11) return '$n задача';
    if (n10 >= 2 && n10 <= 4 && (n100 < 12 || n100 > 14)) return '$n задачи';
    return '$n задач';
  }
}

/// Компактная карточка задачи в календаре (аналог `ScheduledTaskCard`,
/// но без дублирования чипа даты — дата уже в заголовке дня).
final class _CalendarDayTaskCard extends StatelessWidget {
  const _CalendarDayTaskCard({
    required this.task,
    required this.members,
    required this.currentMemberId,
    required this.formatDate,
    required this.onEdit,
    required this.onDelete,
    required this.onAssign,
    required this.onTogglePin,
    required this.onReschedule,
    required this.onDuplicate,
    required this.onComplete,
    required this.onUncomplete,
    this.onTogglePause,
    this.onSkip,
    this.category,
  });

  final Task task;
  final List<HouseholdMember> members;
  final String currentMemberId;
  final String Function(DateTime) formatDate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAssign;
  final VoidCallback onTogglePin;
  final VoidCallback onReschedule;
  final VoidCallback onDuplicate;
  final VoidCallback onComplete;
  final VoidCallback onUncomplete;
  final VoidCallback? onTogglePause;
  final VoidCallback? onSkip;
  final TaskCategory? category;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final assigneeName = _assigneeName();
    final canComplete = task.canBeCompletedBy(currentMemberId);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Tooltip(
                message: task.isCompleted
                    ? 'Отменить выполнение'
                    : canComplete
                    ? 'Отметить выполненной'
                    : 'Вы не назначены исполнителем',
                child: GestureDetector(
                  onTap: task.isCompleted
                      ? onUncomplete
                      : canComplete
                      ? onComplete
                      : () {},
                  child: Icon(
                    task.isCompleted
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 22,
                    color: task.isCompleted
                        ? cs.primary
                        : canComplete
                        ? cs.onSurfaceVariant
                        : cs.onSurfaceVariant.withValues(alpha: 0.38),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        decoration:
                            task.isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (task.isCompleted && task.completedAt != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Выполнено ${formatDate(task.completedAt!)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        CategoryChip(category: category),
                        InfoChip(
                          icon: Icons.timer_outlined,
                          label: '${task.estimatedDurationMinutes} мин',
                          color: cs.tertiary,
                        ),
                        if (task.plannedTimeLabel != null)
                          InfoChip(
                            icon: Icons.schedule_outlined,
                            label: task.plannedTimeLabel!,
                            color: cs.tertiary,
                          ),
                        if (task.isRecurring)
                          InfoChip(
                            icon: Icons.repeat_outlined,
                            label: 'Повтор',
                            color: cs.tertiary,
                          ),
                        if (task.isSeriesPaused)
                          InfoChip(
                            icon: Icons.pause_circle_outline,
                            label: 'Серия на паузе',
                            color: cs.error,
                          ),
                        if (task.isPinned)
                          InfoChip(
                            icon: Icons.push_pin,
                            label: 'Закреплено',
                            color: cs.tertiary,
                          ),
                        if (assigneeName != null)
                          InfoChip(
                            icon: Icons.person_outline,
                            label: assigneeName,
                            color: cs.primary,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                key: Key('calendar_task_menu_${task.id}'),
                tooltip: 'Действия с задачей',
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit();
                    case 'assign':
                      onAssign();
                    case 'pin':
                      onTogglePin();
                    case 'delete':
                      onDelete();
                    case 'reschedule':
                      onReschedule();
                    case 'duplicate':
                      onDuplicate();
                    case 'togglePause':
                      onTogglePause?.call();
                    case 'skip':
                      onSkip?.call();
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Редактировать'),
                  ),
                  const PopupMenuItem(
                    value: 'reschedule',
                    child: Text('Перенести'),
                  ),
                  const PopupMenuItem(
                    value: 'duplicate',
                    child: Text('Дублировать'),
                  ),
                  if (onTogglePause != null)
                    PopupMenuItem(
                      value: 'togglePause',
                      child: Text(
                        task.isSeriesPaused
                            ? 'Возобновить серию'
                            : 'Поставить на паузу',
                      ),
                    ),
                  if (onSkip != null)
                    const PopupMenuItem(
                      value: 'skip',
                      child: Text('Пропустить'),
                    ),
                  PopupMenuItem(
                    value: 'assign',
                    child: Text(
                      task.isPinned
                          ? 'Изменить ответственного'
                          : 'Назначить',
                    ),
                  ),
                  if (task.isPinned)
                    const PopupMenuItem(
                      value: 'pin',
                      child: Text('Открепить'),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Удалить'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _assigneeName() {
    if (task.assignedMemberId == null) return null;
    final nameMap = {for (final m in members) m.profileId: m.displayName};
    return nameMap[task.assignedMemberId];
  }
}

/// Цветная полоска задачи в ячейке месяца (как событие Google Calendar).
final class _DayTaskBar extends StatelessWidget {
  const _DayTaskBar({required this.task, required this.color})
      : _count = null;

  const _DayTaskBar.more({required int this._count})
      : task = null,
        color = null;

  final Task? task;
  final Color? color;
  final int? _count;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isMore = _count != null;
    final Color bg;
    final Color borderColor;
    final String label;
    final Color textColor;
    if (isMore) {
      bg = cs.surfaceContainerHighest;
      borderColor = cs.outlineVariant;
      label = '+$_count ещё';
      textColor = cs.onSurfaceVariant;
    } else {
      final task = this.task!;
      final color = this.color!;
      bg = color.withValues(alpha: 0.25);
      borderColor = color;
      label = task.title;
      textColor = cs.onSurface;
    }

    return Container(
      width: double.infinity,
      height: 13,
      margin: const EdgeInsets.only(left: 2, right: 2, top: 1),
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(3),
        border: Border(left: BorderSide(color: borderColor, width: 2)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 9,
          height: 1.0,
          color: textColor,
        ),
      ),
    );
  }
}

/// Направление авто-листания календаря при перетаскивании к краю.
enum _ScrollDirection { previous, next }

/// Режим отображения календаря.
enum _CalendarMode { month, week, day }
