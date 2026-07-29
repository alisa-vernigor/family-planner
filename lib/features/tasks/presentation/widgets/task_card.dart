import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/profile/presentation/pages/profile_page.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/eisenhower_priority.dart';

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
    this.onSwipeComplete,
    this.onSwipeUncomplete,
    this.onSwipeDelete,
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
  final VoidCallback? onSwipeComplete;
  final VoidCallback? onSwipeUncomplete;
  final VoidCallback? onSwipeDelete;

  /// Map memberId → member details for quick lookup
  Map<String, ({String displayName, String? avatarUrl})> get _memberMap {
    return {
      for (final m in members)
        m.profileId: (displayName: m.displayName, avatarUrl: m.avatarUrl)
    };
  }

  ({String name, String? avatarUrl})? _assigneeInfo() {
    if (task.assignedMemberId == null) return null;
    final info = _memberMap[task.assignedMemberId];
    if (info == null) return null;
    return (name: info.displayName, avatarUrl: info.avatarUrl);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCompleted = task.isCompleted;
    final canComplete = task.canBeCompletedBy(currentMemberId);
    final isOverdue = !isCompleted &&
        task.deadline != null &&
        task.deadline!.isBefore(DateTime.now());

    final card = Card(
      color: isSelected
          ? cs.primaryContainer.withAlpha(60)
          : isOverdue
              ? cs.errorContainer.withAlpha(30)
              : task.isPinned && !isCompleted
                  ? cs.tertiaryContainer.withAlpha(40)
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
                IconButton(
                  key: isCompleted
                      ? Key('uncomplete_task_button_${task.id}')
                      : Key('complete_task_button_${task.id}'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  visualDensity: VisualDensity.compact,
                  tooltip: isCompleted
                      ? 'Отменить выполнение'
                      : canComplete
                          ? 'Отметить выполненной'
                          : 'Вы не назначены исполнителем',
                  onPressed: isCompleted
                      ? onUncomplete
                      : canComplete
                          ? onComplete
                          : null,
                  icon: Icon(
                    isCompleted
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked_outlined,
                    size: 32,
                    color: isCompleted
                        ? cs.primary
                        : canComplete
                            ? cs.onSurfaceVariant
                            : cs.onSurfaceVariant.withValues(alpha: 0.38),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          fontSize: 20,
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
              padding: const EdgeInsets.only(left: 36, top: 10),
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
                  if (task.priority != null)
                    _PriorityChip(priority: task.priority!, cs: cs),
                  if (task.assignedMemberId != null)
                    _AssigneeChip(
                      info: _assigneeInfo(),
                      profileId: task.assignedMemberId!,
                      isMine: task.assignedMemberId == currentMemberId,
                      cs: cs,
                    ),
                  _InfoChip(
                    icon: Icons.calendar_today_outlined,
                    label: '${task.createdAt.day.toString().padLeft(2, '0')}.${task.createdAt.month.toString().padLeft(2, '0')}',
                    color: cs.outlineVariant,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // Логика разрешения свайпа (свайп для изменения статуса слева направо, удаление справа налево)
    final canSwipeStatus = (!isCompleted && onSwipeComplete != null) ||
        (isCompleted && onSwipeUncomplete != null);
    final canSwipeDelete = onSwipeDelete != null;

    return Dismissible(
      key: ValueKey('swipe-${task.id}'),
      direction: (canSwipeStatus || canSwipeDelete)
          ? DismissDirection.horizontal
          : DismissDirection.none,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd && canSwipeStatus) {
          // Легкая вибрация, подтверждающая, что свайп сработал
          HapticFeedback.mediumImpact();

          // Переключаем статус задачи
          if (isCompleted) {
            onSwipeUncomplete?.call();
          } else {
            onSwipeComplete?.call();
          }
          // Возвращаем false, чтобы карточка "спружинила" обратно
          // вместо того, чтобы исчезнуть (так как она остается в списке, просто меняя вид)
          return false;
        }
        if (direction == DismissDirection.endToStart && canSwipeDelete) {
          HapticFeedback.mediumImpact();
          onSwipeDelete!();
          return false; // Откат карточки, само удаление происходит оптимистично в BLoC
        }
        return false;
      },
      // Фон слева (изменение статуса)
      background: Container(
        color: isCompleted ? cs.secondary : cs.primary,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        child: Icon(
          isCompleted ? Icons.undo_outlined : Icons.check_circle_outline,
          color: Colors.white,
          size: 28,
        ),
      ),
      // Фон справа (удаление)
      secondaryBackground: Container(
        color: cs.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      child: GestureDetector(
        onLongPress: onLongPress,
        onTap: isSelected ? () {} : null,
        child: card,
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
    required this.info,
    required this.profileId,
    required this.isMine,
    required this.cs,
  });

  final ({String name, String? avatarUrl})? info;
  final String profileId;
  final bool isMine;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final name = info?.name ?? 'Участник';
    final avatarUrl = info?.avatarUrl;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProfilePage(
              profileId: profileId,
              displayName: name,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: (isMine ? cs.primary : cs.outlineVariant).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 8,
              backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                  ? NetworkImage(avatarUrl)
                  : null,
              child: (avatarUrl == null || avatarUrl.isEmpty)
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: cs.onPrimaryContainer,
                      ),
                    )
                  : null,
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
      ),
    );
  }
}

// ── Priority chip ────────────────────────────────────────────────

final class _PriorityChip extends StatelessWidget {
  const _PriorityChip({required this.priority, required this.cs});

  final EisenhowerPriority priority;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, IconData icon) = switch (priority) {
      EisenhowerPriority.urgentImportant =>
        (cs.error.withValues(alpha: 0.15), cs.error, Icons.bolt),
      EisenhowerPriority.notUrgentImportant =>
        (cs.primary.withValues(alpha: 0.15), cs.primary, Icons.flag_circle_outlined),
      EisenhowerPriority.urgentNotImportant =>
        (cs.tertiary.withValues(alpha: 0.15), cs.tertiary, Icons.schedule_outlined),
      EisenhowerPriority.notUrgentNotImportant =>
        (cs.outlineVariant.withValues(alpha: 0.15), cs.onSurfaceVariant, Icons.more_horiz_outlined),
    };

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            priority.label,
            style: TextStyle(
              fontSize: 12,
              color: fg,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}