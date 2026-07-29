import 'package:flutter/material.dart';

import 'package:family_planner/features/tasks/domain/entities/task_recurrence.dart';

/// Человекочитаемая сводка настроек повторения задачи.
///
/// Показывает тип повторения, даты начала/окончания, количество итераций
/// и предпросмотр первых 5 дат.
final class RecurrenceSummary extends StatelessWidget {
  const RecurrenceSummary({
    required this.type,
    required this.intervalDays,
    required this.weekdayCount,
    this.weekdays = const [],
    this.startDate,
    this.endDate,
    super.key,
  });

  final TaskRecurrenceType type;
  final int intervalDays;
  final int weekdayCount;
  final List<int> weekdays;
  final DateTime? startDate;
  final DateTime? endDate;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    String summary;
    switch (type) {
      case TaskRecurrenceType.daily:
        summary = 'Каждый день';
      case TaskRecurrenceType.weekly:
        if (weekdays.isEmpty) {
          summary = 'Каждую неделю';
        } else {
          const labels = ['', 'пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];
          summary = 'По ${weekdays.map((d) => labels[d]).join(', ')}';
        }
      case TaskRecurrenceType.intervalDays:
        summary = 'Каждые $intervalDays дн.';
    }

    // Считаем количество итераций
    int? count;
    final start = startDate;
    final end = endDate;
    if (start != null && end != null) {
      final days = end.difference(start).inDays + 1;
      switch (type) {
        case TaskRecurrenceType.daily:
          count = days;
        case TaskRecurrenceType.weekly:
          if (weekdays.isNotEmpty) {
            count = 0;
            for (var d = 0; d < days; d++) {
              final date = start.add(Duration(days: d));
              if (weekdays.contains(date.weekday)) count = count! + 1;
            }
          }
        case TaskRecurrenceType.intervalDays:
          count = days ~/ intervalDays + 1;
      }
    }
    if (end == null) {
      count = null;
    }

    // Генерируем первые 5 дат для предпросмотра
    final previewDates = <DateTime>[];
    if (start != null) {
      final previewEnd = end ?? start.add(const Duration(days: 60));
      final totalDays = previewEnd.difference(start).inDays + 1;
      for (var d = 0; d < totalDays && previewDates.length < 5; d++) {
        final date = start.add(Duration(days: d));
        bool matches;
        switch (type) {
          case TaskRecurrenceType.daily:
            matches = true;
          case TaskRecurrenceType.weekly:
            matches = weekdays.contains(date.weekday);
          case TaskRecurrenceType.intervalDays:
            matches = d % intervalDays == 0;
        }
        if (matches) previewDates.add(date);
      }
    }

    if (start != null) {
      final startStr = '${start.day}.${start.month}.${start.year}';
      if (end != null) {
        final endStr = '${end.day}.${end.month}.${end.year}';
        summary += ', с $startStr по $endStr';
      } else {
        summary += ', с $startStr';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.tertiaryContainer.withAlpha(76),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.repeat, size: 16, color: cs.tertiary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  summary,
                  style: TextStyle(
                    color: cs.tertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (count != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: cs.tertiary.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: cs.tertiary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (previewDates.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withAlpha(60),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...previewDates.map(
                  (date) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      children: [
                        Icon(
                          Icons.checklist,
                          size: 14,
                          color: cs.tertiary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${date.day.toString().padLeft(2, '0')}.'
                          '${date.month.toString().padLeft(2, '0')}.'
                          '${date.year}',
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (count != null && count > previewDates.length)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '…и ещё ${count - previewDates.length}',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
