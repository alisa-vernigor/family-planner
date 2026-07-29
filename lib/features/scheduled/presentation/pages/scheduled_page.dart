import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show
        Supabase,
        RealtimeChannel,
        PostgresChangeEvent,
        PostgresChangeFilter,
        PostgresChangeFilterType,
        RealtimeSubscribeStatus;

import 'package:family_planner/core/logging/app_logger.dart';
import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/households/domain/repositories/household_repository.dart';
import 'package:family_planner/features/scheduled/presentation/cubit/scheduled_tasks_cubit.dart';
import 'package:family_planner/features/scheduled/presentation/cubit/scheduled_tasks_state.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/create_task_params.dart';
import 'package:family_planner/features/tasks/presentation/pages/create_task_sheet.dart';
import 'package:family_planner/features/tasks/presentation/pages/edit_task_sheet.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/tasks/domain/use_cases/get_all_pending_tasks_use_case.dart';
import 'package:family_planner/features/tasks/domain/use_cases/delete_task_use_case.dart';
import 'package:family_planner/features/tasks/presentation/widgets/assignee_picker.dart';
import 'package:family_planner/features/tasks/domain/services/ai_task_service.dart';

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
  String _taskFilter = 'all'; // all, mine, unassigned
  Timer? _realtimeDebounce;

  @override
  void initState() {
    super.initState();
    _subscribeToRealtime(widget.householdId);
    _reloadTasks();
  }

  @override
  void didUpdateWidget(covariant _ScheduledView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.householdId != widget.householdId) {
      _unsubscribeFromRealtime();
      _subscribeToRealtime(widget.householdId);
      _reloadTasks();
    }
  }

  @override
  void dispose() {
    _realtimeDebounce?.cancel();
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
            if (!mounted) return;

            // Debounce — пачка realtime-событий схлопывается в один релоад
            _realtimeDebounce?.cancel();
            _realtimeDebounce = Timer(const Duration(milliseconds: 1500), () {
              if (mounted) _silentReload();
            });
          },
        )
        .subscribe((status, error) {
          if (error != null) {
            AppLogger.error('Realtime error', error: error);
          }

          if (status == RealtimeSubscribeStatus.subscribed) {
            AppLogger.debug('Realtime канал подключён');
          }
        });
  }

  void _silentReload() {
    context.read<ScheduledTasksCubit>().refresh(
      householdId: widget.householdId,
    );
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
      _silentReload();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Изменения сохранены.')),
      );
    }
  }

  Future<void> _openCreateTaskSheet({AITaskResult? aiResult}) async {
    final wasCreated = await showCreateTaskSheet(
      context: context,
      householdId: widget.householdId,
      plannedFor: DateTime.now(),
      aiInitialData: aiResult,
    );

    if (wasCreated == true && mounted) {
      _silentReload();
    }
  }

  Future<void> _decomposeTask(Task task) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('ИИ разбивает задачу...')),
          ],
        ),
      ),
    );

    try {
      final aiService = AITaskService();
      final subtasks = await aiService.decomposeTask(task.title, task.description);

      final repository = context.read<TaskRepository>();
      final count = subtasks.isNotEmpty ? subtasks.length : 1;

      for (final subtask in subtasks) {
        final duration = subtask.durationMinutes ?? (task.estimatedDurationMinutes ~/ count);
        await repository.create(
          params: CreateTaskParams(
            householdId: task.householdId,
            title: subtask.title,
            description: subtask.description,
            estimatedDurationMinutes: duration > 0 ? duration : 10,
            plannedFor: task.plannedFor,
            deadline: task.deadline,
            assignedMemberId: task.assignedMemberId,
            pinnedMemberId: task.pinnedMemberId,
          ),
        );
      }

      await repository.delete(taskId: task.id);

      if (mounted) {
        Navigator.of(context).pop(); // Закрываем диалог
        _silentReload();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Задача разбита на подзадачи!')),
        );
      }
    } catch (e, st) {
      AppLogger.error('Ошибка декомпозиции', error: e, stackTrace: st);
      if (mounted) {
        Navigator.of(context).pop(); // Закрываем диалог
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось разбить задачу.')),
        );
      }
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

    final tasksCubit = context.read<ScheduledTasksCubit>();

    // Оптимистичное удаление
    tasksCubit.removeTask(task.id);

    final deleteUseCase = DeleteTaskUseCase(repository: context.read<TaskRepository>());
    try {
      await deleteUseCase(taskId: task.id);
      tasksCubit.confirmDelete(task.id);
    } catch (exception, stackTrace) {
      // Откат — перезагружаем
      tasksCubit.cancelDelete(task.id);
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
                    onCreate: () => _openCreateTaskSheet(),
                  );
                }

                // Группируем по дате
                final filteredTasks = switch (_taskFilter) {
                  'mine' => tasks.where((t) => t.assignedMemberId == widget.currentMemberId).toList(),
                  'unassigned' => tasks.where((t) => t.assignedMemberId == null).toList(),
                  _ => tasks,
                };

                if (filteredTasks.isEmpty) {
                  return _emptyState(
                    icon: Icons.calendar_month_outlined,
                    title: 'Нет задач по выбранному фильтру',
                    subtitle: 'Попробуйте другой фильтр',
                    onCreate: () => _openCreateTaskSheet(),
                  );
                }

                final grouped = <String, List<Task>>{};
                for (final task in filteredTasks) {
                  final key = _formatDate(task.plannedFor);
                  grouped.putIfAbsent(key, () => []).add(task);
                }
                final dates = grouped.keys.toList();

                return Column(
                  children: [
                    // Фильтр
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Row(children: [
                        _FilterChip(
                          label: 'Все', selected: _taskFilter == 'all',
                          onSelected: () => setState(() => _taskFilter = 'all'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Мои', selected: _taskFilter == 'mine',
                          onSelected: () => setState(() => _taskFilter = 'mine'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Без назначения', selected: _taskFilter == 'unassigned',
                          onSelected: () => setState(() => _taskFilter = 'unassigned'),
                        ),
                      ]),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async => _reloadTasks(),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                          children: [
                            for (final date in dates) ...[
                              Padding(
                                padding: const EdgeInsets.only(top: 12, bottom: 4, left: 4),
                                child: Text(
                                  date,
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              for (final task in grouped[date]!)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _ScheduledTaskCard(
                                    key: ValueKey(task.id),
                                    task: task,
                                    members: members,
                                    currentMemberId: widget.currentMemberId,
                                    formatDate: _formatDate,
                                    onEdit: () => _openEditTaskSheet(task),
                                    onDecompose: () => _decomposeTask(task),
                                    onAssign: () => _assignTask(task, members),
                                    onTogglePin: () => _togglePinTask(task),
                                    onDelete: () => _deleteTask(task),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                );
            }
          },
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'create_task_scheduled_fab',
            onPressed: () => _openCreateTaskSheet(),
            tooltip: 'Создать задачу вручную',
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
    super.key,
    required this.task,
    required this.members,
    required this.currentMemberId,
    required this.formatDate,
    required this.onEdit,
    required this.onDecompose,
    required this.onAssign,
    required this.onTogglePin,
    required this.onDelete,
  });

  final Task task;
  final List<HouseholdMember> members;
  final String currentMemberId;
  final String Function(DateTime) formatDate;
  final VoidCallback onEdit;
  final VoidCallback onDecompose;
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
                      case 'decompose':
                        onDecompose();
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
                    const PopupMenuItem(
                      value: 'decompose',
                      child: Text('Разбить (ИИ)'),
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

final class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
          ),
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