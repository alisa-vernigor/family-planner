import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show Supabase, PostgresChangeEvent, RealtimeChannel, PostgresChangeFilter,
         PostgresChangeFilterType, RealtimeSubscribeStatus;

import 'package:family_planner/core/logging/app_logger.dart';
import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/households/domain/repositories/household_repository.dart';
import 'package:family_planner/features/tasks/presentation/pages/edit_task_sheet.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/use_cases/get_tasks_for_day_use_case.dart';
import 'package:family_planner/features/tasks/domain/use_cases/complete_task_use_case.dart';
import 'package:family_planner/features/tasks/domain/use_cases/uncomplete_task_use_case.dart';
import 'package:family_planner/features/tasks/domain/use_cases/delete_task_use_case.dart';
import 'package:family_planner/features/tasks/domain/use_cases/distribute_tasks_use_case.dart';
import 'package:family_planner/features/tasks/presentation/cubit/task_completion_cubit.dart';
import 'package:family_planner/features/tasks/presentation/cubit/task_completion_state.dart';
import 'package:family_planner/features/tasks/presentation/cubit/task_actions_cubit.dart';
import 'package:family_planner/features/today/presentation/cubit/today_tasks_cubit.dart';
import 'package:family_planner/features/today/presentation/cubit/today_tasks_state.dart';
import 'package:family_planner/features/tasks/domain/services/task_schedule.dart';
import 'package:family_planner/features/tasks/presentation/widgets/task_card.dart';
import 'package:family_planner/features/tasks/presentation/widgets/assignee_picker.dart';
import 'package:family_planner/features/tasks/presentation/pages/create_task_sheet.dart';

final class TodayPage extends StatelessWidget {
  const TodayPage({
    required this.householdId,
    required this.householdName,
    required this.currentMemberId,
    super.key,
  });

  final String householdId;
  final String householdName;
  final String currentMemberId;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<TaskRepository>();
    final householdRepository = context.read<HouseholdRepository>();

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => TodayTasksCubit(
            getTasksForDayUseCase: GetTasksForDayUseCase(
              repository: repository,
            ),
            householdRepository: householdRepository,
            distributeTasksUseCase: DistributeTasksUseCase(
              taskRepository: repository,
              householdRepository: householdRepository,
            ),
          ),
        ),
        BlocProvider(
          create: (_) => TaskCompletionCubit(
            completeTaskUseCase: CompleteTaskUseCase(
              repository: repository,
              now: DateTime.now,
            ),
          ),
        ),
        BlocProvider(
          create: (_) => TaskActionsCubit(
            uncompleteTaskUseCase: UncompleteTaskUseCase(
              repository: repository,
            ),
            deleteTaskUseCase: DeleteTaskUseCase(
              repository: repository,
            ),
          ),
        ),
      ],
      child: _TodayView(
        householdId: householdId,
        householdName: householdName,
        currentMemberId: currentMemberId,
        day: DateTime.now(),
      ),
    );
  }
}

final class _TodayView extends StatefulWidget {
  const _TodayView({
    required this.householdId,
    required this.householdName,
    required this.currentMemberId,
    required this.day,
  });

  final String householdId;
  final String householdName;
  final String currentMemberId;
  final DateTime day;

  @override
  State<_TodayView> createState() => _TodayViewState();
}

final class _TodayViewState extends State<_TodayView> {
  RealtimeChannel? _realtimeChannel;
  final Set<String> _selectedTaskIds = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();

    _subscribeToRealtime(widget.householdId);
    _loadTasks();
  }

  @override
  void didUpdateWidget(covariant _TodayView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.householdId != widget.householdId) {
      _unsubscribeFromRealtime();
      _subscribeToRealtime(widget.householdId);
      _loadTasks();
    }
  }

  @override
  void dispose() {
    _unsubscribeFromRealtime();
    super.dispose();
  }

  void _subscribeToRealtime(String householdId) {
    _realtimeChannel = Supabase.instance.client
        .channel('task-occurrences-$householdId')
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
            if (mounted) _silentReload();
          },
        )
        .subscribe((status, error) {
          if (error != null) {
            AppLogger.error('Realtime error', error: error);
          }

          if (status == RealtimeSubscribeStatus.subscribed) {
            AppLogger.debug('Realtime канал подключён');
            // При переподключении — полная перезагрузка на случай пропущенных событий
            if (mounted) _reloadTasks();
          }
        });
  }

  void _unsubscribeFromRealtime() {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
  }

  void _loadTasks() {
    context.read<TodayTasksCubit>().load(
      householdId: widget.householdId,
      day: widget.day,
    );
  }

  void _reloadTasks() {
    context.read<TodayTasksCubit>().load(
      householdId: widget.householdId,
      day: widget.day,
    );
  }

  /// Тихая перезагрузка без спиннера — для реалтайм-событий и фоновых обновлений.
  void _silentReload() {
    context.read<TodayTasksCubit>().refresh(
      householdId: widget.householdId,
      day: widget.day,
    );
  }

  Future<void> _openCreateTaskSheet() async {
    final wasCreated = await showCreateTaskSheet(
      context: context,
      householdId: widget.householdId,
      plannedFor: widget.day,
    );

    if (wasCreated == true && mounted) {
      _silentReload();
    }
  }

  Future<void> _openEditTaskSheet(Task task) async {
    final wasEdited = await showEditTaskSheet(context: context, task: task);

    if (wasEdited == true && mounted) {
      _silentReload();
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

    final tasksCubit = context.read<TodayTasksCubit>();
    final actionsCubit = context.read<TaskActionsCubit>();

    // Оптимистичное удаление
    tasksCubit.removeTask(task.id);

    final deleted = await actionsCubit.deleteTask(taskId: task.id);

    if (deleted && mounted) {
      tasksCubit.confirmDelete(task.id);
    } else if (mounted) {
      // Откат — перезагружаем
      tasksCubit.cancelDelete(task.id);
      _reloadTasks();
    }
  }

  Future<void> _distributeTasks() async {
    await context.read<TodayTasksCubit>().distribute(
      householdId: widget.householdId,
      day: widget.day,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Задачи распределены между участниками.')),
      );
    }
  }

  Future<void> _assignTask(Task task, List<HouseholdMember> members) async {
    final memberId = await showAssigneePicker(
      context: context,
      members: members,
      currentAssigneeId: task.assignedMemberId,
    );

    if (memberId == null || !mounted) return;

    final tasksCubit = context.read<TodayTasksCubit>();
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
    final tasksCubit = context.read<TodayTasksCubit>();
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

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) _selectedTaskIds.clear();
    });
  }

  void _toggleTaskSelection(String taskId) {
    setState(() {
      if (_selectedTaskIds.contains(taskId)) {
        _selectedTaskIds.remove(taskId);
        if (_selectedTaskIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedTaskIds.add(taskId);
      }
    });
  }

  void _batchComplete(List<Task> tasks) {
    if (!mounted || _selectedTaskIds.isEmpty) return;

    final toComplete = tasks.where(
      (t) => _selectedTaskIds.contains(t.id) && !t.isCompleted,
    );
    final completionCubit = context.read<TaskCompletionCubit>();

    for (final task in toComplete) {
      completionCubit.completeTask(
        task: task,
        memberId: widget.currentMemberId,
      );
    }

    setState(() {
      _selectedTaskIds.clear();
      _isSelectionMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<TaskCompletionCubit, TaskCompletionState>(
          listener: (context, state) {
            switch (state) {
              case TaskCompletionSuccess(:final task):
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                duration: const Duration(seconds: 6),
                content: const Text('Задача выполнена. Отличная работа!'),
                action: SnackBarAction(
                  label: 'Отменить',
                  onPressed: () {
                    context
                        .read<TaskActionsCubit>()
                        .uncompleteTask(task: task);
                  },
                ),
              ),
            );
            context.read<TodayTasksCubit>().replaceTask(task);
              case TaskCompletionFailure(:final message):
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(message)));
              case TaskCompletionInitial():
              case TaskCompletionInProgress():
                break;
            }
          },
        ),
        BlocListener<TaskActionsCubit, TaskCompletionState>(
          listener: (context, state) {
            if (state case TaskCompletionFailure(:final message)) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(message)));
            }
          },
        ),
      ],
      child: Stack(
        children: [
          BlocBuilder<TodayTasksCubit, TodayTasksState>(
            builder: (context, state) {
              switch (state) {
                case TodayTasksInitial():
                case TodayTasksLoading():
                  return const Center(child: CircularProgressIndicator());

                case TodayTasksFailure(:final message):
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

                case TodayTasksLoaded(:final tasks, :final members):
                  final todayTasks = TaskSchedule.forDay(
                    tasks: tasks,
                    day: widget.day,
                  );

                  if (todayTasks.isEmpty) {
                    return _emptyState(
                      icon: Icons.check_circle_outline,
                      title: 'На сегодня задач нет',
                      subtitle: 'Создайте новую задачу или запланируйте на другой день',
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async => _reloadTasks(),
                    child: _TaskListView(
                      tasks: todayTasks,
                      members: members,
                      currentMemberId: widget.currentMemberId,
                      isSelectionMode: _isSelectionMode,
                      selectedTaskIds: _selectedTaskIds,
                      onEdit: _openEditTaskSheet,
                      onDelete: _deleteTask,
                      onAssign: _assignTask,
                      onTogglePin: _togglePinTask,
                      onComplete: (task) {
                        if (_isSelectionMode) {
                          _toggleTaskSelection(task.id);
                        } else {
                          context
                              .read<TaskCompletionCubit>()
                              .completeTask(
                                task: task,
                                memberId: widget.currentMemberId,
                              );
                        }
                      },
                      onLongPress: (task) {
                        if (!_isSelectionMode) {
                          _toggleSelectionMode();
                          _toggleTaskSelection(task.id);
                        }
                      },
                      onUncomplete: (task) async {
                        final result = await context
                            .read<TaskActionsCubit>()
                            .uncompleteTask(task: task);
                        if (result != null && mounted) {
                          context.read<TodayTasksCubit>().replaceTask(result);
                        }
                      },
                    ),
                  );
              }
            },
          ),
          // ── Selection mode bar ───────────────────────────
          if (_isSelectionMode)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() {
                          _isSelectionMode = false;
                          _selectedTaskIds.clear();
                        }),
                        icon: const Icon(Icons.close),
                        label: const Text('Отменить'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: () {
                          final state = context.read<TodayTasksCubit>().state;
                          if (state case TodayTasksLoaded(:final tasks)) {
                            _batchComplete(tasks);
                          }
                        },
                        icon: const Icon(Icons.checklist),
                        label: Text(
                          'Выполнить (${_selectedTaskIds.length})',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // ── Distribute FAB ──────────────────────────────
          if (!_isSelectionMode)
            Positioned(
              right: 16,
              bottom: 16,
              child: BlocBuilder<TodayTasksCubit, TodayTasksState>(
              builder: (context, state) {
                final isLoading = state is TodayTasksLoading;
                return FloatingActionButton.small(
                  heroTag: 'distribute_tasks_fab',
                  tooltip: 'Автораспределить задачи',
                  onPressed: isLoading ? null : _distributeTasks,
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_outlined),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
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
              onPressed: _openCreateTaskSheet,
              icon: const Icon(Icons.add),
              label: const Text('Создать задачу'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Grouped list view ─────────────────────────────────────────────

final class _TaskListView extends StatelessWidget {
  const _TaskListView({
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
        if (myTasks.isNotEmpty) ...[
          _SectionHeader(title: 'Мои задачи', count: myTasks.length),
          ...myTasks.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TaskCard(
                  key: ValueKey('my-${t.id}'),
                  task: t,
                  members: members,
                  currentMemberId: currentMemberId,
                  isSelected: selectedTaskIds.contains(t.id),
                  onLongPress: onLongPress != null ? () => onLongPress!(t) : null,
                  onComplete: () => onComplete(t),
                  onUncomplete: () => onUncomplete(t),
                  onEdit: () => onEdit(t),
                  onDelete: () => onDelete(t),
                  onAssign: () => onAssign(t, members),
                  onTogglePin: () => onTogglePin(t),
                ),
              )),
          const SizedBox(height: 8),
        ],
        if (othersTasks.isNotEmpty) ...[
          _SectionHeader(title: 'Задачи семьи', count: othersTasks.length),
          ...othersTasks.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TaskCard(
                  key: ValueKey('other-${t.id}'),
                  task: t,
                  members: members,
                  currentMemberId: currentMemberId,
                  isSelected: selectedTaskIds.contains(t.id),
                  onLongPress: onLongPress != null ? () => onLongPress!(t) : null,
                  onComplete: () => onComplete(t),
                  onUncomplete: () => onUncomplete(t),
                  onEdit: () => onEdit(t),
                  onDelete: () => onDelete(t),
                  onAssign: () => onAssign(t, members),
                  onTogglePin: () => onTogglePin(t),
                ),
              )),
          const SizedBox(height: 8),
        ],
        if (unassigned.isNotEmpty) ...[
          _SectionHeader(title: 'Неназначенные', count: unassigned.length),
          ...unassigned.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TaskCard(
                  key: ValueKey('unassigned-${t.id}'),
                  task: t,
                  members: members,
                  currentMemberId: currentMemberId,
                  isSelected: selectedTaskIds.contains(t.id),
                  onLongPress: onLongPress != null ? () => onLongPress!(t) : null,
                  onComplete: () => onComplete(t),
                  onUncomplete: () => onUncomplete(t),
                  onEdit: () => onEdit(t),
                  onDelete: () => onDelete(t),
                  onAssign: () => onAssign(t, members),
                  onTogglePin: () => onTogglePin(t),
                ),
              )),
        ],
      ],
    );
  }
}

final class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8, left: 4),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
