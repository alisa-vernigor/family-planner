import 'package:flutter/material.dart';

import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/presentation/widgets/filter_chip.dart';

/// Карточка запланированной задачи в списке.
///
/// Отличается от `TaskCard` — компактнее, без свайпов, с иконкой
/// расписания и чипом даты/времени.
final class ScheduledTaskCard extends StatelessWidget {
  const ScheduledTaskCard({
    required this.task,
    required this.members,
    required this.currentMemberId,
    required this.formatDate,
    required this.onEdit,
    required this.onAssign,
    required this.onTogglePin,
    required this.onDelete,
    super.key,
  });

  final Task task;
  final List<HouseholdMember> members;
  final String currentMemberId;
  final String Function(DateTime) formatDate;
  final VoidCallback onEdit;
  final VoidCallback onAssign;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;

  String? _assigneeName() {
    if (task.assignedMemberId == null) return null;
    final nameMap = {for (final m in members) m.profileId: m.displayName};
    return nameMap[task.assignedMemberId];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.schedule_outlined,
                    size: 22,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    task.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  key: Key('task_menu_${task.id}'),
                  tooltip: 'Действия с задачей',
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        onEdit();
                      case 'assign':
                        onAssign();
                      case 'pin':
                        onTogglePin();
                      case 'delete':
                        onDelete();
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Редактировать'),
                    ),
                    PopupMenuItem(
                      value: 'assign',
                      child: Text(
                        task.isPinned
                            ? 'Изменить ответственного'
                            : 'Назначить',
                      ),
                    ),
                    if (task.isPinned)
                      const PopupMenuItem(
                        value: 'pin',
                        child: Text('Открепить'),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Удалить'),
                    ),
                  ],
                ),
              ],
            ),
            if (task.description != null && task.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                task.description!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                InfoChip(
                  icon: Icons.calendar_today_outlined,
                  label: formatDate(task.plannedFor),
                  color: cs.tertiary,
                ),
                InfoChip(
                  icon: Icons.timer_outlined,
                  label: '${task.estimatedDurationMinutes} мин',
                  color: cs.tertiary,
                ),
                if (task.isPinned)
                  InfoChip(
                    icon: Icons.push_pin,
                    label: 'Закреплено',
                    color: cs.tertiary,
                  ),
                if (task.assignedMemberId != null)
                  InfoChip(
                    icon: Icons.person_outline,
                    label: _assigneeName() ?? 'Участник',
                    color: cs.primary,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
