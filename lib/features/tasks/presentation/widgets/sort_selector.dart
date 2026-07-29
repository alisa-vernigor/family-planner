import 'package:flutter/material.dart';

import 'package:family_planner/features/tasks/domain/entities/task_sort_option.dart';

/// Виджет выбора сортировки задач выпадающим списком.
final class SortSelector extends StatelessWidget {
  const SortSelector({
    required this.current,
    required this.onChanged,
    super.key,
  });

  final TaskSortOption current;
  final ValueChanged<TaskSortOption> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(Icons.sort_outlined, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            'Сортировка:',
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<TaskSortOption>(
                  value: current,
                  isExpanded: true,
                  isDense: true,
                  items: TaskSortOption.values.map((option) {
                    return DropdownMenuItem(
                      value: option,
                      child: Text(
                        option.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (option) {
                    if (option != null) onChanged(option);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
