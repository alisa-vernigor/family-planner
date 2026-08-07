import 'package:flutter/material.dart';

import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/update_recurring_task_params.dart';

/// Диалог выбора области применения изменений для повторяющейся задачи —
/// как в Google Calendar: «Только эту», «Эту и последующие», «Все задачи в серии».
///
/// Возвращает выбранный [RecurrenceEditScope] или `null` (отмена).
Future<RecurrenceEditScope?> showRecurrenceEditScopeDialog({
  required BuildContext context,
  required Task task,
}) async {
  final options = <({RecurrenceEditScope scope, String title, String subtitle})>[
    (
      scope: RecurrenceEditScope.onlyThis,
      title: 'Только эту задачу',
      subtitle: 'Изменить только текущий экземпляр. Серия не затрагивается.',
    ),
    (
      scope: RecurrenceEditScope.thisAndFollowing,
      title: 'Эту и последующие',
      subtitle: 'Изменить эту задачу и все будущие экземпляры серии.',
    ),
    (
      scope: RecurrenceEditScope.all,
      title: 'Все задачи в серии',
      subtitle: 'Изменить шаблон и все экземпляры (включая прошедшие).',
    ),
  ];

  return showDialog<RecurrenceEditScope>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text('Изменить «${task.title}»?'),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Это повторяющаяся задача. Что нужно изменить?',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            for (final option in options)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  switch (option.scope) {
                    RecurrenceEditScope.onlyThis => Icons.touch_app_outlined,
                    RecurrenceEditScope.thisAndFollowing =>
                      Icons.event_repeat_outlined,
                    RecurrenceEditScope.all => Icons.linear_scale_outlined,
                  },
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(option.title),
                subtitle: Text(option.subtitle),
                onTap: () => Navigator.of(dialogContext).pop(option.scope),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Отмена'),
          ),
        ],
      );
    },
  );
}
