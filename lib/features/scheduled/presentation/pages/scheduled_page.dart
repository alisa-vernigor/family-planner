import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show
        Supabase,
        RealtimeChannel,
        PostgresChangeEvent,
        PostgresChangeFilter,
        PostgresChangeFilterType;

import 'package:family_planner/core/logging/app_logger.dart';
import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/households/domain/repositories/household_repository.dart';
import 'package:family_planner/features/scheduled/presentation/cubit/scheduled_tasks_cubit.dart';
import 'package:family_planner/features/scheduled/presentation/cubit/scheduled_tasks_state.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/presentation/pages/create_task_sheet.dart';
import 'package:family_planner/features/tasks/presentation/pages/edit_task_sheet.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/tasks/domain/use_cases/get_all_pending_tasks_use_case.dart';
import 'package:family_planner/features/tasks/domain/use_cases/delete_task_use_case.dart';
import 'package:family_planner/features/tasks/presentation/widgets/assignee_picker.dart';

final class ScheduledPage extends StatelessWidget {
  const ScheduledPage({
    required this.householdId,
    required this.currentMemberId,
    super.key,
  });

  final String householdId;
  final String currentMemberId;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<TaskRepository>();
    final householdRepository = context.read<HouseholdRepository>();

    return BlocProvider(
      create: (_) => ScheduledTasksCubit(
        getAllPendingTasksUseCase: GetAllPendingTasksUseCase(
          repository: repository,
        ),
        householdRepository: householdRepository,
      ),
      child: _ScheduledView(
        householdId: householdId,
        currentMemberId: currentMemberId,
      ),
    );
  }
}

final class _ScheduledView extends StatefulWidget {
  const _ScheduledView({
    required this.householdId,
    required this.currentMemberId,
  });

  final String householdId;
  final String currentMemberId;

  @override
  State<_ScheduledView> createState() => _ScheduledViewState();
}

final class _ScheduledViewState extends State<_ScheduledView> {
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _subscribeToRealtime(widget.householdId);
    _reloadTasks();
  }

  @override
  void dispose() {
    _unsubscribeFromRealtime();
    super.dispose();
  }

  void _subscribeToRealtime(String householdId) {
    _realtimeChannel = Supabase.instance.client
        .channel('scheduled-tasks-$householdId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'task_occurrences',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'household_id',
            value: householdId,
          ),
          callback: (_) {
            if (mounted) _reloadTasks();
          },
        )
        .subscribe();
  }

  void _unsubscribeFromRealtime() {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
  }

  void _reloadTasks() {
    context.read<ScheduledTasksCubit>().load(
      householdId: widget.householdId,
    );
  }

  Future<void> _openEditTaskSheet(Task task) async {
    final wasUpdated = await showEditTaskSheet(context: context, task: task);

    if (wasUpdated == true && mounted) {
      _reloadTasks();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Изменения сохранены.')),
      );
    }
  }

  Future<void> _openCreateTaskSheet() async {
    final wasCreated = await showCreateTaskSheet(
      context: context,
      householdId: widget.householdId,
      plannedFor: DateTime.now(),
    );

    if (wasCreated == true && mounted) {
      _reloadTasks();
    }
  }

  Future<void> _assignTask(Task task, List<HouseholdMember> members) async {
    final memberId = await showAssigneePicker(
      context: context,
      members: members,
      currentAssigneeId: task.assignedMemberId,
    );

    if (memberId == null || !mounted) return;

    final tasksCubit = context.read<ScheduledTasksCubit>();
    final repository = context.read<TaskRepository>();

    // Оптимистичное обновление
    final updatedTask = task.copyWith(
      assignedMemberId: memberId.isEmpty ? null : memberId,
    );
    tasksCubit.replaceTask(updatedTask);

    try {
      if (memberId.isEmpty) {
        await repository.save(task.copyWith(assignedMemberId: null));
      } else {
        if (!task.allowedMemberIds.contains(memberId)) {
          await repository.addAllowedMember(
            taskId: task.id,
            memberId: memberId,
          );
        }
        await repository.save(task.copyWith(assignedMemberId: memberId));
      }
    } catch (exception, stackTrace) {
      // Откат — перезагружаем
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось назначить ответственного.')),
      );
      AppLogger.error('Ошибка назначения задачи', error: exception, stackTrace: stackTrace);
      _reloadTasks();
    }
  }

  Future<void> _togglePinTask(Task task) async {
    final tasksCubit = context.read<ScheduledTasksCubit>();
    final repository = context.read<TaskRepository>();

    // Оптимистичное обновление
    tasksCubit.replaceTask(task.copyWith(pinnedMemberId: null));

    try {
      await repository.save(task.copyWith(pinnedMemberId: null));
    } catch (exception, stackTrace) {
      // Откат
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открепить задачу.')),
      );
      AppLogger.error('Ошибка открепления задачи', error: exception, stackTrace: stackTrace);
      _reloadTasks();
    }
  }

  Future<void> _deleteTask(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить задачу?'),
        content: Text('Вы уверены, что хотите удалить задачу «${task.title}»?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Оптимистичное удаление
    context.read<ScheduledTasksCubit>().removeTask(task.id);

    final deleteUseCase = DeleteTaskUseCase(repository: context.read<TaskRepository>());
    try {
      await deleteUseCase(taskId: task.id);
    } catch (exception, stackTrace) {
      // Откат — перезагружаем
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось удалить задачу.')),
      );
      AppLogger.error('Ошибка удаления задачи', error: exception, stackTrace: stackTrace);
      _reloadTasks();
    }
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');

    return '$day.$month.$year, $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        BlocBuilder<ScheduledTasksCubit, ScheduledTasksState>(
          builder: (context, state) {
            switch (state) {
              case ScheduledTasksInitial():
              case ScheduledTasksLoading():
                return const Center(child: CircularProgressIndicator());

              case ScheduledTasksFailure(:final message):
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cloud_off_outlined,
                          size: 48,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(message, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _reloadTasks,
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  ),
                );

              case ScheduledTasksLoaded(:final tasks, :final members):
                if (tasks.isEmpty) {
                  return _emptyState(
                    icon: Icons.calendar_month_outlined,
                    title: 'Запланированных задач нет',
                    subtitle:
                        'Создайте повторяющуюся задачу или запланируйте на другой день',
                    onCreate: _openCreateTaskSheet,
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _reloadTasks(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    children: tasks.map((task) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ScheduledTaskCard(
                          task: task,
                          members: members,
                          currentMemberId: widget.currentMemberId,
                          formatDate: _formatDate,
                          onEdit: () => _openEditTaskSheet(task),
                          onAssign: () => _assignTask(task, members),
                          onTogglePin: () => _togglePinTask(task),
                          onDelete: () => _deleteTask(task),
                        ),
                      );
                    }).toList(),
                  ),
                );
            }
          },
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'create_task_scheduled_fab',
            onPressed: _openCreateTaskSheet,
            tooltip: 'Создать задачу',
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onCreate,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Создать задачу'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Scheduled task card ───────────────────────────────────────────

final class _ScheduledTaskCard extends StatelessWidget {
  const _ScheduledTaskCard({
    required this.task,
    required this.members,
    required this.currentMemberId,
    required this.formatDate,
    required this.onEdit,
    required this.onAssign,
    required this.onTogglePin,
    required this.onDelete,
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
    final member = members.where(
      (m) => m.profileId == task.assignedMemberId,
    );
    return member.isNotEmpty ? member.first.displayName : null;
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
                _ScheduledInfoChip(
                  icon: Icons.calendar_today_outlined,
                  label: formatDate(task.plannedFor),
                  color: cs.tertiary,
                ),
                _ScheduledInfoChip(
                  icon: Icons.timer_outlined,
                  label: '${task.estimatedDurationMinutes} мин',
                  color: cs.tertiary,
                ),
                if (task.isPinned)
                  _ScheduledInfoChip(
                    icon: Icons.push_pin,
                    label: 'Закреплено',
                    color: cs.tertiary,
                  ),
                if (task.assignedMemberId != null)
                  _ScheduledInfoChip(
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

final class _ScheduledInfoChip extends StatelessWidget {
  const _ScheduledInfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

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
