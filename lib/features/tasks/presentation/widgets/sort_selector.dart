import 'package:flutter/material.dart';

import 'package:family_planner/features/tasks/domain/entities/task_sort_option.dart';

/// Премиальный выбор сортировки.
///
/// Выглядит как капсула с текущим полем сортировки и стрелкой направления.
/// При тапе открывает красивый bottom sheet с выбором поля и
/// переключателем «по возрастанию / по убыванию».
final class SortSelector extends StatelessWidget {
  const SortSelector({
    required this.current,
    required this.onChanged,
    this.ascending = true,
    this.onAscendingChanged,
    super.key,
  });

  final TaskSortOption current;
  final ValueChanged<TaskSortOption> onChanged;
  final bool ascending;
  final ValueChanged<bool>? onAscendingChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          // Иконка сортировки
          Icon(Icons.sort_outlined, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          // Капсула-кнопка
          Expanded(
            child: GestureDetector(
              onTap: () => _showSortSheet(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _iconForOption(current),
                      size: 16,
                      color: cs.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        current.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Кнопка направления сортировки
          if (onAscendingChanged != null)
            Material(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onAscendingChanged!(!ascending),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Icon(
                    ascending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                    size: 18,
                    color: cs.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
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

  void _showSortSheet(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Локальная копия для реактивности внутри StatefulBuilder
    var localAscending = ascending;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ручка
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Заголовок
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Icon(Icons.sort_outlined, size: 20, color: cs.onSurface),
                        const SizedBox(width: 10),
                        Text(
                          'Сортировка',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Список опций
                  ...TaskSortOption.values.map((option) {
                    final isSelected = current == option;
                    return ListTile(
                      leading: Icon(
                        _iconForOption(option),
                        color: isSelected ? cs.primary : cs.onSurfaceVariant,
                      ),
                      title: Text(
                        option.label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? cs.primary : cs.onSurface,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_circle, color: cs.primary, size: 22)
                          : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onTap: () {
                        onChanged(option);
                        setSheetState(() {});
                      },
                    );
                  }),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  // Переключатель направления
                  if (onAscendingChanged != null)
                    SwitchListTile(
                      value: localAscending,
                      onChanged: (value) {
                        onAscendingChanged!(value);
                        setSheetState(() => localAscending = value);
                      },
                      secondary: Icon(
                        localAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                        color: cs.primary,
                      ),
                      title: Text(
                        localAscending ? 'По возрастанию' : 'По убыванию',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
