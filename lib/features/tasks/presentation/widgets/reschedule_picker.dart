import 'package:flutter/material.dart';

import 'package:family_planner/features/tasks/domain/entities/task.dart';

/// Показывает диалог переноса задачи на новую дату.
///
/// - Обычная задача → выбирается только новая дата.
/// - Повторяющаяся задача → показывается предупреждение, что серия
///   переносится целиком (как в Google Calendar «переместить событие»),
///   и выбирается новая дата.
///
/// Возвращает `RescheduleResult` с новой датой, либо `null` если отменено.
Future<RescheduleResult?> showReschedulePicker({
  required BuildContext context,
  required Task task,
}) async {
  // Для серии подтверждаем перенос всей серии.
  if (task.isRecurring) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Перенести серию?'),
        content: const Text(
          'Это повторяющаяся задача. Перенос изменит дату всей серии.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Перенести'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return null;
  }

  // Выбираем новую дату.
  final now = DateTime.now();
  final newDate = await showDatePicker(
    context: context,
    initialDate: task.plannedFor.isBefore(now)
        ? now
        : task.plannedFor,
    firstDate: DateTime(now.year - 1),
    lastDate: DateTime(now.year + 5),
    helpText: 'Перенести задачу',
  );

  if (newDate == null || !context.mounted) return null;

  // Дата переноса без времени.
  final newPlannedFor = DateTime(newDate.year, newDate.month, newDate.day);

  return RescheduleResult(
    newPlannedFor: newPlannedFor,
    isSeries: task.isRecurring,
  );
}

/// Результат выбора переноса задачи.
final class RescheduleResult {
  const RescheduleResult({
    required this.newPlannedFor,
    this.isSeries = false,
  });

  /// Новая дата планирования (без времени).
  final DateTime newPlannedFor;

  /// True, если переносится повторяющаяся серия целиком.
  final bool isSeries;
}
