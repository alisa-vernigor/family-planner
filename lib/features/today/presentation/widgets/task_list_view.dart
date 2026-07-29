import 'package:flutter/material.dart';

import 'package:family_planner/features/households/households.dart';
import 'package:family_planner/features/tasks/tasks.dart';

/// Группированный список задач на сегодняшнем экране.
///
/// Разделяет задачи на секции: «Мои задачи», «Задачи семьи»,
/// «Неназначенные». В каждой секции — список TaskCard.
final class TaskListView extends StatelessWidget {
  const TaskListView({
    required this.tasks,
    required this.members,
    required this.currentMemberId,
    required this.onEdit,
    required this.onDelete,
    required this.onAssign,
    required this.onTogglePin,
    required this.onComplete,
    required this.onUncomplete,
    this.isSelectionMode = false,
    this.selectedTaskIds = const {},
    this.onLongPress,
    this.onSwipeComplete,
    this.onSwipeUncomplete,
    this.onSwipeDelete,
    this.sortOption,
    this.onSortChanged,
    this.sortAscending = true,
    this.onSortAscendingChanged,
    super.key,
  });

  final List<Task> tasks;
  final List<HouseholdMember> members;
  final String currentMemberId;
  final bool isSelectionMode;
  final Set<String> selectedTaskIds;
  final void Function(Task) onEdit;
  final void Function(Task) onDelete;
  final void Function(Task, List<HouseholdMember>) onAssign;
  final void Function(Task) onTogglePin;
  final void Function(Task) onComplete;
  final void Function(Task) onUncomplete;
  final void Function(Task)? onLongPress;
  final void Function(Task)? onSwipeComplete;
  final void Function(Task)? onSwipeUncomplete;
  final void Function(Task)? onSwipeDelete;
  final TaskSortOption? sortOption;
  final ValueChanged<TaskSortOption>? onSortChanged;
  final bool sortAscending;
  final ValueChanged<bool>? onSortAscendingChanged;

  @override
  Widget build(BuildContext context) {
    final myTasks =
        tasks
            .where((t) => t.assignedMemberId == currentMemberId)
            .toList(growable: false);
    final othersTasks =
        tasks
            .where(
              (t) =>
                  t.assignedMemberId != null &&
                  t.assignedMemberId != currentMemberId,
            )
            .toList(growable: false);
    final unassigned =
        tasks
            .where((t) => t.assignedMemberId == null)
            .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      children: [
        if (sortOption != null && onSortChanged != null)
          SortSelector(
            current: sortOption!,
            onChanged: onSortChanged!,
            ascending: sortAscending,
            onAscendingChanged: onSortAscendingChanged,
          ),
        if (myTasks.isNotEmpty) ...[
          SectionHeader(title: 'Мои задачи', count: myTasks.length),
          ...myTasks.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TaskCard(
                key: ValueKey('my-${t.id}'),
                task: t,
                members: members,
                currentMemberId: currentMemberId,
                isSelected: selectedTaskIds.contains(t.id),
                onLongPress:
                    onLongPress != null ? () => onLongPress!(t) : null,
                onSwipeComplete: onSwipeComplete != null
                    ? () => onSwipeComplete!(t)
                    : null,
                onSwipeUncomplete: onSwipeUncomplete != null
                    ? () => onSwipeUncomplete!(t)
                    : null,
                onSwipeDelete:
                    onSwipeDelete != null ? () => onSwipeDelete!(t) : null,
                onComplete: () => onComplete(t),
                onUncomplete: () => onUncomplete(t),
                onEdit: () => onEdit(t),
                onDelete: () => onDelete(t),
                onAssign: () => onAssign(t, members),
                onTogglePin: () => onTogglePin(t),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (othersTasks.isNotEmpty) ...[
          SectionHeader(title: 'Задачи семьи', count: othersTasks.length),
          ...othersTasks.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TaskCard(
                key: ValueKey('other-${t.id}'),
                task: t,
                members: members,
                currentMemberId: currentMemberId,
                isSelected: selectedTaskIds.contains(t.id),
                onLongPress:
                    onLongPress != null ? () => onLongPress!(t) : null,
                onSwipeComplete: onSwipeComplete != null
                    ? () => onSwipeComplete!(t)
                    : null,
                onSwipeUncomplete: onSwipeUncomplete != null
                    ? () => onSwipeUncomplete!(t)
                    : null,
                onSwipeDelete:
                    onSwipeDelete != null ? () => onSwipeDelete!(t) : null,
                onComplete: () => onComplete(t),
                onUncomplete: () => onUncomplete(t),
                onEdit: () => onEdit(t),
                onDelete: () => onDelete(t),
                onAssign: () => onAssign(t, members),
                onTogglePin: () => onTogglePin(t),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (unassigned.isNotEmpty) ...[
          SectionHeader(title: 'Неназначенные', count: unassigned.length),
          ...unassigned.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TaskCard(
                key: ValueKey('unassigned-${t.id}'),
                task: t,
                members: members,
                currentMemberId: currentMemberId,
                isSelected: selectedTaskIds.contains(t.id),
                onLongPress:
                    onLongPress != null ? () => onLongPress!(t) : null,
                onSwipeComplete: onSwipeComplete != null
                    ? () => onSwipeComplete!(t)
                    : null,
                onSwipeUncomplete: onSwipeUncomplete != null
                    ? () => onSwipeUncomplete!(t)
                    : null,
                onSwipeDelete:
                    onSwipeDelete != null ? () => onSwipeDelete!(t) : null,
                onComplete: () => onComplete(t),
                onUncomplete: () => onUncomplete(t),
                onEdit: () => onEdit(t),
                onDelete: () => onDelete(t),
                onAssign: () => onAssign(t, members),
                onTogglePin: () => onTogglePin(t),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Заголовок секции в списке задач с отображением количества.
final class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.title, required this.count, super.key});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8, left: 4),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
