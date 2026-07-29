import 'package:flutter/material.dart';

import 'package:family_planner/features/tasks/domain/entities/task_sort_option.dart';

/// Два компактных выпадающих списка — поле сортировки + порядок.
/// Никаких диалогов, всё на месте.
final class SortSelector extends StatelessWidget {
  const SortSelector({
    required this.current,
    required this.onChanged,
    this.ascending = true,
    this.onAscendingChanged,
    this.iconColor,
    super.key,
  });

  final TaskSortOption current;
  final ValueChanged<TaskSortOption> onChanged;
  final bool ascending;
  final ValueChanged<bool>? onAscendingChanged;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fgColor = iconColor ?? cs.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Dropdown: поле сортировки
        _CompactDropdown<TaskSortOption>(
          value: current,
          icon: Icons.sort_outlined,
          iconColor: fgColor,
          items: TaskSortOption.values,
          itemBuilder: (option, cs, isSelected) {
            return Row(
              children: [
                Icon(_iconForOption(option), size: 16, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  option.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? cs.primary : cs.onSurface,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.check, size: 16, color: cs.primary),
                ],
              ],
            );
          },
          onChanged: onChanged,
        ),
        const SizedBox(width: 4),
        // Dropdown: направление
        if (onAscendingChanged != null)
          _CompactDropdown<bool>(
            value: ascending,
            icon: ascending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            iconColor: fgColor,
            items: const [true, false],
            itemBuilder: (v, cs, isSelected) {
              return Text(
                v ? 'По возрастанию' : 'По убыванию',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? cs.primary : cs.onSurface,
                ),
              );
            },
            onChanged: onAscendingChanged!,
          ),
      ],
    );
  }

  IconData _iconForOption(TaskSortOption option) {
    return switch (option) {
      TaskSortOption.deadline => Icons.schedule_outlined,
      TaskSortOption.priority => Icons.flag_outlined,
      TaskSortOption.duration => Icons.timer_outlined,
      TaskSortOption.title => Icons.text_fields,
      TaskSortOption.createdAt => Icons.add_circle_outline,
      TaskSortOption.plannedFor => Icons.calendar_today_outlined,
    };
  }
}

/// Миниатюрная кнопка с popup-меню. Выглядит как иконка + стрелка вниз.
final class _CompactDropdown<T> extends StatelessWidget {
  const _CompactDropdown({
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.items,
    required this.itemBuilder,
    required this.onChanged,
  });

  final T value;
  final IconData icon;
  final Color iconColor;
  final List<T> items;
  final Widget Function(T value, ColorScheme cs, bool isSelected) itemBuilder;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return PopupMenuButton<T>(
      initialValue: value,
      onSelected: onChanged,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      position: PopupMenuPosition.under,
      itemBuilder: (ctx) => items.map((item) {
        final isSelected = item == value;
        return PopupMenuItem<T>(
          value: item,
          child: itemBuilder(item, cs, isSelected),
        );
      }).toList(),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down_rounded, size: 16, color: iconColor),
          ],
        ),
      ),
    );
  }
}
