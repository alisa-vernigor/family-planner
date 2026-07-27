import 'package:flutter/material.dart';

import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';

final class TaskCard extends StatelessWidget {
  const TaskCard({
    required this.task,
    required this.members,
    required this.currentMemberId,
    required this.onComplete,
    required this.onUncomplete,
    required this.onEdit,
    required this.onDelete,
    required this.onAssign,
    this.onTogglePin,
    this.isSelected = false,
    this.onLongPress,
    super.key,
  });

  final Task task;
  final List<HouseholdMember> members;
  final String currentMemberId;
  final VoidCallback onComplete;
  final VoidCallback onUncomplete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAssign;
  final VoidCallback? onTogglePin;
  final bool isSelected;
  final VoidCallback? onLongPress;

  /// Map memberId → displayName для быстрого поиска
  Map<String, String> get _memberNameMap {
    return {for (final m in members) m.profileId: m.displayName};
  }

  String? _assigneeName() {
    if (task.assignedMemberId == null) return null;
    return _memberNameMap[task.assignedMemberId];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCompleted = task.isCompleted;

    return GestureDetector(
      onLongPress: onLongPress,
      onTap: isSelected
          ? () {} // handled by parent
          : null,
      child: Card(
        color: isSelected
            ? cs.primaryContainer.withAlpha(60)
            : isCompleted
                ? cs.surfaceContainerLowest
                : cs.surface,
        child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title row ─────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    isCompleted
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked_outlined,
                    size: 22,
                    color: isCompleted ? cs.primary : cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          decoration:
                              isCompleted ? TextDecoration.lineThrough : null,
                          color: isCompleted
                              ? cs.onSurfaceVariant
                              : cs.onSurface,
                        ),
                      ),
                      if (task.description != null &&
                          task.description!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            task.description!,
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              decoration:
                                  isCompleted ? TextDecoration.lineThrough : null,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Действия',
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        onEdit();
                      case 'delete':
                        onDelete();
                      case 'assign':
                        onAssign();
                      case 'pin':
                        onTogglePin?.call();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: _MenuRow(
                        icon: Icons.edit_outlined,
                        label: 'Редактировать',
                      ),
                    ),
                    PopupMenuItem(
                      value: 'assign',
                      child: _MenuRow(
                        icon: task.isPinned
                            ? Icons.person_pin
                            : Icons.person_add_outlined,
                        label: task.isPinned
                            ? 'Изменить ответственного'
                            : 'Назначить',
                      ),
                    ),
                    if (task.isPinned)
                      const PopupMenuItem(
                        value: 'pin',
                        child: _MenuRow(
                          icon: Icons.push_pin_outlined,
                          label: 'Открепить',
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: _MenuRow(
                        icon: Icons.delete_outline,
                        label: 'Удалить',
                        isDestructive: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // ── Metadata chips ──────────────────────────────
            Padding(
              padding: const EdgeInsets.only(left: 34, top: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _InfoChip(
                    icon: Icons.timer_outlined,
                    label: '${task.estimatedDurationMinutes} мин',
                    color: cs.tertiary,
                  ),
                  if (task.isPinned)
                    _InfoChip(
                      icon: Icons.push_pin,
                      label: 'Закреплено',
                      color: cs.tertiary,
                    ),
                  if (task.deadline != null)
                    DeadlineChip(deadline: task.deadline!, cs: cs),
                  if (task.assignedMemberId != null)
                    _AssigneeChip(
                      name: _assigneeName() ?? 'Участник',
                      isMine: task.assignedMemberId == currentMemberId,
                      cs: cs,
                    ),
                ],
              ),
            ),
            // ── Action button ───────────────────────────────
            Padding(
              padding: const EdgeInsets.only(left: 34, top: 14),
              child: isCompleted
                  ? SizedBox(
                      height: 36,
                      child: OutlinedButton.icon(
                        key: Key('uncomplete_task_button_${task.id}'),
                        onPressed: onUncomplete,
                        icon: const Icon(Icons.undo, size: 18),
                        label: const Text(
                          'Отменить',
                          style: TextStyle(fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    )
                  : SizedBox(
                      height: 36,
                      child: task.canBeCompletedBy(currentMemberId)
                          ? FilledButton.icon(
                              key: Key('complete_task_button_${task.id}'),
                              onPressed: onComplete,
                              icon: const Icon(Icons.check_circle_outline, size: 18),
                              label: const Text(
                                'Выполнить',
                                style: TextStyle(fontSize: 13),
                              ),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                visualDensity: VisualDensity.compact,
                              ),
                            )
                          : Tooltip(
                              message: 'Вы не назначены исполнителем',
                              child: FilledButton.icon(
                                key: Key('complete_task_button_${task.id}'),
                                onPressed: null,
                                icon: const Icon(Icons.check_circle_outline, size: 18),
                                label: const Text(
                                  'Выполнить',
                                  style: TextStyle(fontSize: 13),
                                ),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ),
                    ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

// ── Small helper widgets ──────────────────────────────────────────

final class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isDestructive
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: isDestructive
                ? Theme.of(context).colorScheme.error
                : null,
          ),
        ),
      ],
    );
  }
}

final class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

final class DeadlineChip extends StatelessWidget {
  const DeadlineChip({required this.deadline, required this.cs, super.key});

  final DateTime deadline;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final isUrgent = deadline.difference(DateTime.now()).inHours < 24;
    final isToday = deadline.day == DateTime.now().day &&
        deadline.month == DateTime.now().month &&
        deadline.year == DateTime.now().year;

    final label = isToday
        ? 'до ${deadline.hour.toString().padLeft(2, '0')}:${deadline.minute.toString().padLeft(2, '0')}'
        : 'до ${deadline.day.toString().padLeft(2, '0')}.${deadline.month.toString().padLeft(2, '0')} ${deadline.hour.toString().padLeft(2, '0')}:${deadline.minute.toString().padLeft(2, '0')}';
    return Container(
      decoration: BoxDecoration(
        color: (isUrgent ? cs.error : cs.secondary).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUrgent ? Icons.warning_amber_rounded : Icons.schedule_outlined,
            size: 14,
            color: isUrgent ? cs.error : cs.secondary,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isUrgent ? cs.error : cs.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

final class _AssigneeChip extends StatelessWidget {
  const _AssigneeChip({
    required this.name,
    required this.isMine,
    required this.cs,
  });

  final String name;
  final bool isMine;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: (isMine ? cs.primary : cs.outlineVariant).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMine ? Icons.person : Icons.person_outline,
            size: 14,
            color: isMine ? cs.primary : cs.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            isMine ? 'Я' : name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isMine ? cs.primary : cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
