import 'package:flutter/material.dart';

import 'package:family_planner/features/tasks/domain/entities/eisenhower_priority.dart';

/// Виджет выбора приоритета по матрице Эйзенхауэра.
final class PrioritySelector extends StatelessWidget {
  const PrioritySelector({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final EisenhowerPriority? value;
  final ValueChanged<EisenhowerPriority?> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.flag_outlined, size: 18, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              'Приоритет',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
            ),
            if (value != null) ...[
              const Spacer(),
              GestureDetector(
                onTap: () => onChanged(null),
                child: Text(
                  'Сбросить',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: EisenhowerPriority.values.map((p) {
              final isSelected = value == p;
              final (Color bg, Color fg, IconData icon) = _priorityStyle(p, cs);

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onChanged(isSelected ? null : p),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? bg : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                      border: isSelected
                          ? Border.all(color: fg, width: 1.5)
                          : Border.all(color: Colors.transparent),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 16, color: isSelected ? fg : cs.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text(
                          p.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected ? fg : cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  (Color, Color, IconData) _priorityStyle(EisenhowerPriority p, ColorScheme cs) {
    return switch (p) {
      EisenhowerPriority.urgentImportant =>
        (cs.errorContainer.withAlpha(80), cs.error, Icons.bolt),
      EisenhowerPriority.notUrgentImportant =>
        (cs.primaryContainer.withAlpha(80), cs.primary, Icons.flag_circle_outlined),
      EisenhowerPriority.urgentNotImportant =>
        (cs.tertiaryContainer.withAlpha(80), cs.tertiary, Icons.schedule_outlined),
      EisenhowerPriority.notUrgentNotImportant =>
        (cs.surfaceContainerHighest, cs.onSurfaceVariant, Icons.more_horiz_outlined),
    };
  }
}
