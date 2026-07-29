import 'package:flutter/material.dart';

import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/eisenhower_priority.dart';
import 'package:family_planner/features/tasks/presentation/widgets/task_card.dart';

/// Представление задач в виде матрицы Эйзенхауэра (4 квадранта).
///
/// Поддерживает drag & drop: длинное нажатие на карточку задачи позволяет
/// перетащить её в другой квадрант для смены приоритета.
final class EisenhowerMatrixView extends StatelessWidget {
  const EisenhowerMatrixView({
    required this.tasks,
    required this.members,
    required this.currentMemberId,
    required this.onEdit,
    required this.onDelete,
    required this.onAssign,
    required this.onTogglePin,
    required this.onComplete,
    required this.onUncomplete,
    required this.onSwipeComplete,
    required this.onSwipeUncomplete,
    required this.onSwipeDelete,
    this.onUpdatePriority,
    super.key,
  });

  final List<Task> tasks;
  final List<HouseholdMember> members;
  final String currentMemberId;
  final void Function(Task) onEdit;
  final void Function(Task) onDelete;
  final void Function(Task, List<HouseholdMember>) onAssign;
  final void Function(Task) onTogglePin;
  final void Function(Task) onComplete;
  final void Function(Task) onUncomplete;
  final void Function(Task)? onSwipeComplete;
  final void Function(Task)? onSwipeUncomplete;
  final void Function(Task)? onSwipeDelete;

  /// Вызывается, когда пользователь перетащил задачу в другой квадрант.
  final void Function(Task task, EisenhowerPriority newPriority)? onUpdatePriority;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final urgentImportant = <Task>[];
    final notUrgentImportant = <Task>[];
    final urgentNotImportant = <Task>[];
    final notUrgentNotImportant = <Task>[];

    for (final task in tasks) {
      if (task.isCompleted) continue;
      switch (task.effectivePriority) {
        case EisenhowerPriority.urgentImportant:
          urgentImportant.add(task);
        case EisenhowerPriority.notUrgentImportant:
          notUrgentImportant.add(task);
        case EisenhowerPriority.urgentNotImportant:
          urgentNotImportant.add(task);
        case EisenhowerPriority.notUrgentNotImportant:
          notUrgentNotImportant.add(task);
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;

        if (isWide) {
          return _QuadGrid(
            cs: cs,
            urgentImportant: urgentImportant,
            notUrgentImportant: notUrgentImportant,
            urgentNotImportant: urgentNotImportant,
            notUrgentNotImportant: notUrgentNotImportant,
            members: members,
            currentMemberId: currentMemberId,
            onEdit: onEdit,
            onDelete: onDelete,
            onAssign: onAssign,
            onTogglePin: onTogglePin,
            onComplete: onComplete,
            onUncomplete: onUncomplete,
            onSwipeComplete: onSwipeComplete,
            onSwipeUncomplete: onSwipeUncomplete,
            onSwipeDelete: onSwipeDelete,
            onUpdatePriority: onUpdatePriority,
          );
        }

        // На узких экранах — вертикальный список квадрантов
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
          child: Column(
            children: [
              _QuadrantSection(
                title: 'Срочно и важно',
                subtitle: 'Делать в первую очередь',
                icon: Icons.bolt,
                color: cs.error,
                bgColor: cs.errorContainer.withValues(alpha: 0.2),
                priority: EisenhowerPriority.urgentImportant,
                tasks: urgentImportant,
                members: members,
                currentMemberId: currentMemberId,
                onEdit: onEdit,
                onDelete: onDelete,
                onAssign: onAssign,
                onTogglePin: onTogglePin,
                onComplete: onComplete,
                onUncomplete: onUncomplete,
                onSwipeComplete: onSwipeComplete,
                onSwipeUncomplete: onSwipeUncomplete,
                onSwipeDelete: onSwipeDelete,
                onUpdatePriority: onUpdatePriority,
              ),
              const SizedBox(height: 12),
              _QuadrantSection(
                title: 'Не срочно, но важно',
                subtitle: 'Запланировать',
                icon: Icons.flag_circle_outlined,
                color: cs.primary,
                bgColor: cs.primaryContainer.withValues(alpha: 0.2),
                priority: EisenhowerPriority.notUrgentImportant,
                tasks: notUrgentImportant,
                members: members,
                currentMemberId: currentMemberId,
                onEdit: onEdit,
                onDelete: onDelete,
                onAssign: onAssign,
                onTogglePin: onTogglePin,
                onComplete: onComplete,
                onUncomplete: onUncomplete,
                onSwipeComplete: onSwipeComplete,
                onSwipeUncomplete: onSwipeUncomplete,
                onSwipeDelete: onSwipeDelete,
                onUpdatePriority: onUpdatePriority,
              ),
              const SizedBox(height: 12),
              _QuadrantSection(
                title: 'Срочно, но не важно',
                subtitle: 'Делегировать',
                icon: Icons.schedule_outlined,
                color: cs.tertiary,
                bgColor: cs.tertiaryContainer.withValues(alpha: 0.2),
                priority: EisenhowerPriority.urgentNotImportant,
                tasks: urgentNotImportant,
                members: members,
                currentMemberId: currentMemberId,
                onEdit: onEdit,
                onDelete: onDelete,
                onAssign: onAssign,
                onTogglePin: onTogglePin,
                onComplete: onComplete,
                onUncomplete: onUncomplete,
                onSwipeComplete: onSwipeComplete,
                onSwipeUncomplete: onSwipeUncomplete,
                onSwipeDelete: onSwipeDelete,
                onUpdatePriority: onUpdatePriority,
              ),
              const SizedBox(height: 12),
              _QuadrantSection(
                title: 'Не срочно и не важно',
                subtitle: 'По возможности',
                icon: Icons.more_horiz_outlined,
                color: cs.outlineVariant,
                bgColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                priority: EisenhowerPriority.notUrgentNotImportant,
                tasks: notUrgentNotImportant,
                members: members,
                currentMemberId: currentMemberId,
                onEdit: onEdit,
                onDelete: onDelete,
                onAssign: onAssign,
                onTogglePin: onTogglePin,
                onComplete: onComplete,
                onUncomplete: onUncomplete,
                onSwipeComplete: onSwipeComplete,
                onSwipeUncomplete: onSwipeUncomplete,
                onSwipeDelete: onSwipeDelete,
                onUpdatePriority: onUpdatePriority,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Wide screen: grid 2×2 ────────────────────────────────────────

final class _QuadGrid extends StatelessWidget {
  const _QuadGrid({
    required this.cs,
    required this.urgentImportant,
    required this.notUrgentImportant,
    required this.urgentNotImportant,
    required this.notUrgentNotImportant,
    required this.members,
    required this.currentMemberId,
    required this.onEdit,
    required this.onDelete,
    required this.onAssign,
    required this.onTogglePin,
    required this.onComplete,
    required this.onUncomplete,
    required this.onSwipeComplete,
    required this.onSwipeUncomplete,
    required this.onSwipeDelete,
    required this.onUpdatePriority,
  });

  final ColorScheme cs;
  final List<Task> urgentImportant;
  final List<Task> notUrgentImportant;
  final List<Task> urgentNotImportant;
  final List<Task> notUrgentNotImportant;
  final List<HouseholdMember> members;
  final String currentMemberId;
  final void Function(Task) onEdit;
  final void Function(Task) onDelete;
  final void Function(Task, List<HouseholdMember>) onAssign;
  final void Function(Task) onTogglePin;
  final void Function(Task) onComplete;
  final void Function(Task) onUncomplete;
  final void Function(Task)? onSwipeComplete;
  final void Function(Task)? onSwipeUncomplete;
  final void Function(Task)? onSwipeDelete;
  final void Function(Task task, EisenhowerPriority newPriority)? onUpdatePriority;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _QuadrantGridCell(
                    title: 'Срочно и важно',
                    icon: Icons.bolt,
                    color: cs.error,
                    accent: cs.errorContainer,
                    priority: EisenhowerPriority.urgentImportant,
                    tasks: urgentImportant,
                    members: members,
                    currentMemberId: currentMemberId,
                    onEdit: onEdit,
                    onDelete: onDelete,
                    onAssign: onAssign,
                    onTogglePin: onTogglePin,
                    onComplete: onComplete,
                    onUncomplete: onUncomplete,
                    onSwipeComplete: onSwipeComplete,
                    onSwipeUncomplete: onSwipeUncomplete,
                    onSwipeDelete: onSwipeDelete,
                    onUpdatePriority: onUpdatePriority,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuadrantGridCell(
                    title: 'Не срочно, но важно',
                    icon: Icons.flag_circle_outlined,
                    color: cs.primary,
                    accent: cs.primaryContainer,
                    priority: EisenhowerPriority.notUrgentImportant,
                    tasks: notUrgentImportant,
                    members: members,
                    currentMemberId: currentMemberId,
                    onEdit: onEdit,
                    onDelete: onDelete,
                    onAssign: onAssign,
                    onTogglePin: onTogglePin,
                    onComplete: onComplete,
                    onUncomplete: onUncomplete,
                    onSwipeComplete: onSwipeComplete,
                    onSwipeUncomplete: onSwipeUncomplete,
                    onSwipeDelete: onSwipeDelete,
                    onUpdatePriority: onUpdatePriority,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _QuadrantGridCell(
                    title: 'Срочно, но не важно',
                    icon: Icons.schedule_outlined,
                    color: cs.tertiary,
                    accent: cs.tertiaryContainer,
                    priority: EisenhowerPriority.urgentNotImportant,
                    tasks: urgentNotImportant,
                    members: members,
                    currentMemberId: currentMemberId,
                    onEdit: onEdit,
                    onDelete: onDelete,
                    onAssign: onAssign,
                    onTogglePin: onTogglePin,
                    onComplete: onComplete,
                    onUncomplete: onUncomplete,
                    onSwipeComplete: onSwipeComplete,
                    onSwipeUncomplete: onSwipeUncomplete,
                    onSwipeDelete: onSwipeDelete,
                    onUpdatePriority: onUpdatePriority,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuadrantGridCell(
                    title: 'Не срочно и не важно',
                    icon: Icons.more_horiz_outlined,
                    color: cs.outlineVariant,
                    accent: cs.surfaceContainerHighest,
                    priority: EisenhowerPriority.notUrgentNotImportant,
                    tasks: notUrgentNotImportant,
                    members: members,
                    currentMemberId: currentMemberId,
                    onEdit: onEdit,
                    onDelete: onDelete,
                    onAssign: onAssign,
                    onTogglePin: onTogglePin,
                    onComplete: onComplete,
                    onUncomplete: onUncomplete,
                    onSwipeComplete: onSwipeComplete,
                    onSwipeUncomplete: onSwipeUncomplete,
                    onSwipeDelete: onSwipeDelete,
                    onUpdatePriority: onUpdatePriority,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Grid cell (wide) ─────────────────────────────────────────────

final class _QuadrantGridCell extends StatelessWidget {
  const _QuadrantGridCell({
    required this.title,
    required this.icon,
    required this.color,
    required this.accent,
    required this.priority,
    required this.tasks,
    required this.members,
    required this.currentMemberId,
    required this.onEdit,
    required this.onDelete,
    required this.onAssign,
    required this.onTogglePin,
    required this.onComplete,
    required this.onUncomplete,
    required this.onSwipeComplete,
    required this.onSwipeUncomplete,
    required this.onSwipeDelete,
    required this.onUpdatePriority,
  });

  final String title;
  final IconData icon;
  final Color color;
  final Color accent;
  final EisenhowerPriority priority;
  final List<Task> tasks;
  final List<HouseholdMember> members;
  final String currentMemberId;
  final void Function(Task) onEdit;
  final void Function(Task) onDelete;
  final void Function(Task, List<HouseholdMember>) onAssign;
  final void Function(Task) onTogglePin;
  final void Function(Task) onComplete;
  final void Function(Task) onUncomplete;
  final void Function(Task)? onSwipeComplete;
  final void Function(Task)? onSwipeUncomplete;
  final void Function(Task)? onSwipeDelete;
  final void Function(Task task, EisenhowerPriority newPriority)? onUpdatePriority;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDropTarget = onUpdatePriority != null;

    final child = Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${tasks.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Task list
          Expanded(
            child: tasks.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        'Нет задач',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(4),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      final card = _MiniTaskCard(
                        task: task,
                        onComplete: () => onComplete(task),
                        onUncomplete: () => onUncomplete(task),
                        onEdit: () => onEdit(task),
                      );
                      if (!isDropTarget) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: card,
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: LongPressDraggable<Task>(
                          data: task,
                          feedback: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 160,
                              child: _MiniTaskCard(
                                task: task,
                                onComplete: () {},
                                onUncomplete: () {},
                                onEdit: () {},
                              ),
                            ),
                          ),
                          childWhenDragging: Opacity(
                            opacity: 0.3,
                            child: card,
                          ),
                          child: card,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );

    if (!isDropTarget) return child;

    return DragTarget<Task>(
      onAcceptWithDetails: (details) {
        onUpdatePriority?.call(details.data, priority);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isHovering ? color : accent.withValues(alpha: 0.5),
              width: isHovering ? 2 : 1,
            ),
            color: isHovering
                ? color.withValues(alpha: 0.08)
                : cs.surface,
          ),
          child: child,
        );
      },
    );
  }
}

// ── Section (narrow vertical) ────────────────────────────────────

final class _QuadrantSection extends StatelessWidget {
  const _QuadrantSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.priority,
    required this.tasks,
    required this.members,
    required this.currentMemberId,
    required this.onEdit,
    required this.onDelete,
    required this.onAssign,
    required this.onTogglePin,
    required this.onComplete,
    required this.onUncomplete,
    required this.onSwipeComplete,
    required this.onSwipeUncomplete,
    required this.onSwipeDelete,
    required this.onUpdatePriority,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final EisenhowerPriority priority;
  final List<Task> tasks;
  final List<HouseholdMember> members;
  final String currentMemberId;
  final void Function(Task) onEdit;
  final void Function(Task) onDelete;
  final void Function(Task, List<HouseholdMember>) onAssign;
  final void Function(Task) onTogglePin;
  final void Function(Task) onComplete;
  final void Function(Task) onUncomplete;
  final void Function(Task)? onSwipeComplete;
  final void Function(Task)? onSwipeUncomplete;
  final void Function(Task)? onSwipeDelete;
  final void Function(Task task, EisenhowerPriority newPriority)? onUpdatePriority;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDropTarget = onUpdatePriority != null;

    final child = Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${tasks.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Нет задач',
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
              ),
            )
          else
            ...tasks.map(
              (task) {
                final card = Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: TaskCard(
                    key: ValueKey('matrix-${task.id}'),
                    task: task,
                    members: members,
                    currentMemberId: currentMemberId,
                    onComplete: () => onComplete(task),
                    onUncomplete: () => onUncomplete(task),
                    onEdit: () => onEdit(task),
                    onDelete: () => onDelete(task),
                    onAssign: () => onAssign(task, members),
                    onTogglePin: () => onTogglePin(task),
                    onSwipeComplete: onSwipeComplete != null ? () => onSwipeComplete!(task) : null,
                    onSwipeUncomplete: onSwipeUncomplete != null ? () => onSwipeUncomplete!(task) : null,
                    onSwipeDelete: onSwipeDelete != null ? () => onSwipeDelete!(task) : null,
                  ),
                );
                if (!isDropTarget) return card;
                return LongPressDraggable<Task>(
                  data: task,
                  feedback: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 280,
                      child: TaskCard(
                        task: task,
                        members: members,
                        currentMemberId: currentMemberId,
                        onComplete: () {},
                        onUncomplete: () {},
                        onEdit: () {},
                        onDelete: () {},
                        onAssign: () {},
                      ),
                    ),
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.3,
                    child: card,
                  ),
                  child: card,
                );
              },
            ),
        ],
      ),
    );

    if (!isDropTarget) return child;

    return DragTarget<Task>(
      onAcceptWithDetails: (details) {
        onUpdatePriority?.call(details.data, priority);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: isHovering ? color.withValues(alpha: 0.06) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isHovering ? color : color.withValues(alpha: 0.3),
              width: isHovering ? 2 : 1,
            ),
          ),
          child: child,
        );
      },
    );
  }
}

// ── Mini compact task card for grid cells ────────────────────────

final class _MiniTaskCard extends StatelessWidget {
  const _MiniTaskCard({
    required this.task,
    required this.onComplete,
    required this.onUncomplete,
    required this.onEdit,
  });

  final Task task;
  final VoidCallback onComplete;
  final VoidCallback onUncomplete;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCompleted = task.isCompleted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onEdit,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: isCompleted ? onUncomplete : onComplete,
                child: Icon(
                  isCompleted ? Icons.check_circle : Icons.radio_button_unchecked_outlined,
                  size: 18,
                  color: isCompleted ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                    color: isCompleted ? cs.onSurfaceVariant : cs.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (task.estimatedDurationMinutes > 0)
                Text(
                  '${task.estimatedDurationMinutes}м',
                  style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
