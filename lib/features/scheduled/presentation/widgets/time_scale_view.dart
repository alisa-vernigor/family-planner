import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:family_planner/features/tasks/tasks.dart';

/// Временная шкала задач (неделя/день) с часами — как события в Google Calendar.
///
/// Задачи с [Task.plannedTime] рисуются блоками в сетке часов: вертикальная
/// позиция блока = время начала, высота = `estimatedDurationMinutes`.
/// Задачи без времени — полоски в ряду «Весь день» над шкалой.
/// В «сегодня» показывается красная линия текущего времени.
///
/// В недельном режиме колонки дней растягиваются на всю ширину (минимум —
/// [kMinWeekColumnWidth]). В шапке — дни недели с датами. Шапка дней, ряд
/// «Весь день» и шкала прокручиваются по горизонтали синхронно (три связанных
/// [ScrollController]).
final class TimeScaleView extends StatefulWidget {
  const TimeScaleView({
    required this.tasks,
    required this.categoriesById,
    required this.currentMemberId,
    required this.weekMode,
    required this.focusedDay,
    required this.onFocusedDayChanged,
    required this.onEdit,
    required this.onComplete,
    required this.onUncomplete,
    super.key,
  });

  /// Высота одного часа в пикселях.
  static const double hourHeight = 52;

  /// Ширина колонки с подписями часов.
  static const double hourGutterWidth = 44;

  /// Минимальная ширина колонки дня в недельном режиме. Пока 7 колонок
  /// влезают — они растягиваются на всю ширину; уже — горизонтальный скролл.
  static const double kMinWeekColumnWidth = 48;

  final List<Task> tasks;
  final Map<String, TaskCategory> categoriesById;
  final String currentMemberId;
  final bool weekMode;
  final DateTime focusedDay;
  final void Function(DateTime) onFocusedDayChanged;
  final void Function(Task) onEdit;
  final void Function(Task) onComplete;
  final void Function(Task) onUncomplete;

  @override
  State<TimeScaleView> createState() => _TimeScaleViewState();
}

final class _TimeScaleViewState extends State<TimeScaleView> {
  /// Горизонтальные скролл-контроллеры шапки дней, ряда «Весь день» и шкалы.
  /// Связаны слушателями, чтобы прокручиваться синхронно.
  final ScrollController _headerController = ScrollController();
  final ScrollController _allDayController = ScrollController();
  final ScrollController _timelineController = ScrollController();

  @override
  void initState() {
    super.initState();
    _link(_timelineController, _headerController);
    _link(_timelineController, _allDayController);
  }

  @override
  void dispose() {
    _headerController.dispose();
    _allDayController.dispose();
    _timelineController.dispose();
    super.dispose();
  }

  /// Связывает два горизонтальных скролла: при прокрутке одного второй
  /// догоняет его (`jumpTo`). Защита `> 0.5` от бесконечной петли обратной
  /// связи после синхронизации.
  void _link(ScrollController a, ScrollController b) {
    void sync(ScrollController from, ScrollController to) {
      from.addListener(() {
        if (!to.hasClients) return;
        if ((from.offset - to.offset).abs() > 0.5) {
          to.jumpTo(from.offset);
        }
      });
    }

    sync(a, b);
    sync(b, a);
  }

  @override
  Widget build(BuildContext context) {
    final days = _daysForRange(widget.focusedDay, widget.weekMode);
    return Column(
      children: [
        _header(context),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Ширина области колонок (без гуттера часов) — одинаковая для
              // шапки, ряда «Весь день» и шкалы, чтобы столбцы совпадали.
              final viewportWidth = math.max(
                0.0,
                constraints.maxWidth - TimeScaleView.hourGutterWidth,
              );
              final colWidth = _colWidth(viewportWidth);
              final contentWidth = math.max(
                viewportWidth,
                colWidth * days.length,
              );
              return Column(
                children: [
                  _dayHeaderRow(
                    context,
                    days,
                    viewportWidth,
                    colWidth,
                    contentWidth,
                  ),
                  _allDayRow(
                    context,
                    days,
                    viewportWidth,
                    colWidth,
                    contentWidth,
                  ),
                  Expanded(
                    child: _timeline(
                      context,
                      days,
                      viewportWidth,
                      colWidth,
                      contentWidth,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  /// Дни для отображения: 1 (день) или 7 (неделя, старт с понедельника).
  List<DateTime> _daysForRange(DateTime day, bool weekMode) {
    if (!weekMode) return [DateTime(day.year, day.month, day.day)];
    final start = _startOfWeek(day);
    return List.generate(
      7,
      (i) => DateTime(start.year, start.month, start.day + i),
    );
  }

  DateTime _startOfWeek(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final daysFromMonday = (day.weekday - DateTime.monday) % 7;
    return DateTime(day.year, day.month, day.day - daysFromMonday);
  }

  /// Ширина колонки дня: в режиме «День» — вся область; в недельном —
  /// равномерно на 7 колонок, но не уже [kMinWeekColumnWidth].
  double _colWidth(double viewportWidth) {
    if (!widget.weekMode) return viewportWidth;
    return math.max(viewportWidth / 7, TimeScaleView.kMinWeekColumnWidth);
  }

  // ── Header (навигация) ────────────────────────────────────

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Назад',
            icon: const Icon(Icons.chevron_left),
            onPressed: () => widget.onFocusedDayChanged(_shift(-1)),
          ),
          Expanded(
            child: Center(
              child: Text(
                _title(),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Вперёд',
            icon: const Icon(Icons.chevron_right),
            onPressed: () => widget.onFocusedDayChanged(_shift(1)),
          ),
        ],
      ),
    );
  }

  /// Назад/вперёд: на день или на неделю в зависимости от режима.
  DateTime _shift(int direction) {
    return widget.weekMode
        ? DateTime(
            widget.focusedDay.year,
            widget.focusedDay.month,
            widget.focusedDay.day + 7 * direction,
          )
        : DateTime(
            widget.focusedDay.year,
            widget.focusedDay.month,
            widget.focusedDay.day + direction,
          );
  }

  String _title() {
    if (widget.weekMode) {
      final start = _startOfWeek(widget.focusedDay);
      final end = DateTime(start.year, start.month, start.day + 6);
      if (start.year == end.year && start.month == end.month) {
        return '${start.day} – ${end.day} '
            '${DateFormat('MMMM yyyy', 'ru_RU').format(end)}';
      }
      return '${DateFormat('d MMM', 'ru_RU').format(start)} – '
          '${DateFormat('d MMM yyyy', 'ru_RU').format(end)}';
    }
    return DateFormat('d MMMM yyyy', 'ru_RU').format(widget.focusedDay);
  }

  // ── Шапка дней недели ────────────────────────────────────

  Widget _dayHeaderRow(
    BuildContext context,
    List<DateTime> days,
    double viewportWidth,
    double colWidth,
    double contentWidth,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Угол над гуттером часов — пустой, как в Google Calendar.
          SizedBox(width: TimeScaleView.hourGutterWidth),
          SizedBox(
            width: viewportWidth,
            child: SingleChildScrollView(
              controller: _headerController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: contentWidth,
                child: Row(
                  children: [
                    for (final day in days)
                      _dayHeaderCell(context, day, colWidth),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayHeaderCell(BuildContext context, DateTime day, double width) {
    final cs = Theme.of(context).colorScheme;
    final isToday = DateUtils.isSameDay(day, DateTime.now());
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isToday
            ? cs.primaryContainer.withValues(alpha: 0.10)
            : Colors.transparent,
      ),
      child: Column(
        children: [
          Text(
            DateFormat.E('ru_RU').format(day),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isToday ? cs.primary : cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: isToday
                ? BoxDecoration(
                    color: cs.primary,
                    shape: BoxShape.circle,
                  )
                : null,
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isToday ? cs.onPrimary : cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Ряд «Весь день» ───────────────────────────────────────

  Widget _allDayRow(
    BuildContext context,
    List<DateTime> days,
    double viewportWidth,
    double colWidth,
    double contentWidth,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: TimeScaleView.hourGutterWidth,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 0, 0),
              child: Text(
                'Весь день',
                style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
              ),
            ),
          ),
          SizedBox(
            width: viewportWidth,
            child: SingleChildScrollView(
              controller: _allDayController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: contentWidth,
                child: Row(
                  children: [
                    for (final day in days)
                      _allDayCell(context, day, colWidth),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _allDayCell(BuildContext context, DateTime day, double width) {
    final cs = Theme.of(context).colorScheme;
    final allDay = widget.tasks
        .where(
          (t) =>
              DateUtils.isSameDay(t.plannedFor, day) &&
              t.plannedTime == null,
        )
        .toList();

    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: allDay.isEmpty
            ? const SizedBox(height: 22)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final task in allDay)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: _AllDayChip(
                        task: task,
                        color: _markerColor(task, cs),
                        onEdit: () => widget.onEdit(task),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  // ── Временная шкала ───────────────────────────────────────

  Widget _timeline(
    BuildContext context,
    List<DateTime> days,
    double viewportWidth,
    double colWidth,
    double contentWidth,
  ) {
    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: TimeScaleView.hourGutterWidth,
            height: 24 * TimeScaleView.hourHeight,
            child: _hourGutter(context),
          ),
          SizedBox(
            width: viewportWidth,
            child: SingleChildScrollView(
              controller: _timelineController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: contentWidth,
                child: Row(
                  children: [
                    for (final day in days)
                      _dayColumn(context, day, colWidth),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Колонка с подписями часов (0:00 … 23:00).
  Widget _hourGutter(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      children: [
        for (var h = 0; h < 24; h++)
          Positioned(
            top: h * TimeScaleView.hourHeight,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${h.toString().padLeft(2, '0')}:00',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 10,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          child: Container(
            width: 1,
            color: cs.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }

  Widget _dayColumn(BuildContext context, DateTime day, double width) {
    final cs = Theme.of(context).colorScheme;
    final dayTasks = widget.tasks
        .where((t) => DateUtils.isSameDay(t.plannedFor, day))
        .toList();
    final timed = dayTasks.where((t) => t.plannedTime != null).toList();
    final blocks = _layoutDayBlocks(timed);
    final isToday = DateUtils.isSameDay(day, DateTime.now());

    return SizedBox(
      width: width,
      height: 24 * TimeScaleView.hourHeight,
      child: Stack(
        children: [
          if (isToday)
            Positioned.fill(
              child: ColoredBox(
                color: cs.primaryContainer.withValues(alpha: 0.08),
              ),
            ),
          for (var h = 0; h < 24; h++)
            Positioned(
              top: h * TimeScaleView.hourHeight,
              left: 0,
              right: 0,
              child: Container(
                height: 1,
                color: cs.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
          if (isToday) _nowIndicator(cs),
          for (final block in blocks)
            Positioned(
              top: (block.startMinutes / 60) * TimeScaleView.hourHeight,
              left: block.left * width,
              width: block.width * width,
              child: SizedBox(
                height: _blockHeight(block),
                child: _TimelineTaskBlock(
                  task: block.task,
                  color: _markerColor(block.task, cs),
                  currentMemberId: widget.currentMemberId,
                  titleMaxLines: _blockHeight(block) >= 44 ? 2 : 1,
                  onEdit: () => widget.onEdit(block.task),
                  onComplete: () => widget.onComplete(block.task),
                  onUncomplete: () => widget.onUncomplete(block.task),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Красная линия текущего времени в колонке сегодня.
  Widget _nowIndicator(ColorScheme cs) {
    final now = DateTime.now();
    final minutes = now.hour * 60 + now.minute;
    return Positioned(
      top: (minutes / 60) * TimeScaleView.hourHeight,
      left: 0,
      right: 0,
      child: Container(
        height: 2,
        color: cs.error,
      ),
    );
  }

  /// Высота блока по длительности (мин. 36px, чтобы текст был читаемым).
  double _blockHeight(_PlacedBlock block) {
    final minutes = block.endMinutes - block.startMinutes;
    return (minutes / 60) * TimeScaleView.hourHeight < 36
        ? 36
        : (minutes / 60) * TimeScaleView.hourHeight;
  }

  /// Раскладывает задачи с временем по колонкам (алгоритм разбиения
  /// интервалов): пересекающиеся по времени блоки встают рядом, как в
  /// Google Calendar.
  List<_PlacedBlock> _layoutDayBlocks(List<Task> timedTasks) {
    final sorted = [...timedTasks]
      ..sort(
        (a, b) =>
            a.plannedTime!.inMinutes.compareTo(b.plannedTime!.inMinutes),
      );

    final columnEnds = <int>[];
    final columnOf = <String, int>{};

    for (final task in sorted) {
      final start = task.plannedTime!.inMinutes;
      final end = _endMinutes(task);
      var col = -1;
      for (var i = 0; i < columnEnds.length; i++) {
        if (columnEnds[i] <= start) {
          col = i;
          break;
        }
      }
      if (col == -1) {
        col = columnEnds.length;
        columnEnds.add(end);
      } else {
        columnEnds[col] = end;
      }
      columnOf[task.id] = col;
    }

    final n = columnEnds.length;
    return [
      for (final task in sorted)
        _PlacedBlock(
          task: task,
          left: columnOf[task.id]! / n,
          width: 1 / n,
          startMinutes: task.plannedTime!.inMinutes,
          endMinutes: _endMinutes(task),
        ),
    ];
  }

  /// Конец блока: начало + длительность (мин. 30 мин).
  int _endMinutes(Task task) {
    final duration = task.estimatedDurationMinutes <= 0
        ? 30
        : task.estimatedDurationMinutes;
    return task.plannedTime!.inMinutes + duration;
  }

  /// Цвет маркера: категория или акцент темы.
  Color _markerColor(Task task, ColorScheme cs) {
    final category = widget.categoriesById[task.categoryId];
    if (category != null) {
      return colorFromHex(category.colorHex, fallback: cs.primary);
    }
    return cs.primary;
  }
}

/// Размещённый блок задачи на шкале.
final class _PlacedBlock {
  const _PlacedBlock({
    required this.task,
    required this.left,
    required this.width,
    required this.startMinutes,
    required this.endMinutes,
  });

  final Task task;

  /// Доля ширины колонки от левого края (для блоков, стоящих рядом).
  final double left;
  final double width;
  final int startMinutes;
  final int endMinutes;
}

/// Блок задачи на временной шкале.
final class _TimelineTaskBlock extends StatelessWidget {
  const _TimelineTaskBlock({
    required this.task,
    required this.color,
    required this.currentMemberId,
    required this.onEdit,
    required this.onComplete,
    required this.onUncomplete,
    this.titleMaxLines = 2,
  });

  final Task task;
  final Color color;
  final String currentMemberId;
  final VoidCallback onEdit;
  final VoidCallback onComplete;
  final VoidCallback onUncomplete;

  /// Сколько строк заголовка помещается в блок (1 — в низких блоках,
  /// 2 — в блоках выше 44px). Как в Google Calendar: чем ниже блок, тем
  /// меньше деталей.
  final int titleMaxLines;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCompleted = task.isCompleted;
    final canComplete = task.canBeCompletedBy(currentMemberId);
    final accent = isCompleted ? cs.onSurfaceVariant : color;

    return GestureDetector(
      onTap: onEdit,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: isCompleted ? 0.06 : 0.18),
          borderRadius: BorderRadius.circular(4),
          border: Border(left: BorderSide(color: accent, width: 3)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tooltip(
              message: isCompleted
                  ? 'Отменить выполнение'
                  : canComplete
                  ? 'Отметить выполненной'
                  : 'Вы не назначены исполнителем',
              child: GestureDetector(
                onTap: isCompleted
                    ? onUncomplete
                    : canComplete
                    ? onComplete
                    : () {},
                child: Icon(
                  isCompleted
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 12,
                  color: isCompleted
                      ? accent
                      : canComplete
                      ? cs.onSurfaceVariant
                      : cs.onSurfaceVariant.withValues(alpha: 0.38),
                ),
              ),
            ),
            const SizedBox(width: 3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _timeLabel(task.plannedTime!),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                  Text(
                    task.title,
                    maxLines: titleMaxLines,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.15,
                      color: cs.onSurface,
                      decoration: isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeLabel(Duration time) {
    final h = time.inHours.toString().padLeft(2, '0');
    final m = (time.inMinutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }
}

/// Полоска задачи без времени в ряду «Весь день».
final class _AllDayChip extends StatelessWidget {
  const _AllDayChip({
    required this.task,
    required this.color,
    required this.onEdit,
  });

  final Task task;
  final Color color;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCompleted = task.isCompleted;

    return GestureDetector(
      onTap: onEdit,
      child: Container(
        width: double.infinity,
        height: 20,
        padding: const EdgeInsets.symmetric(horizontal: 3),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(3),
          border: Border(left: BorderSide(color: color, width: 2)),
        ),
        child: Text(
          task.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 9,
            height: 1.0,
            color: cs.onSurface,
            decoration: isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
      ),
    );
  }
}
