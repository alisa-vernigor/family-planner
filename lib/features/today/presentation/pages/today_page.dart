import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgresChangeEvent, RealtimeChannel, PostgresChangeFilter, PostgresChangeFilterType;

import 'package:family_planner/features/tasks/presentation/pages/create_task_sheet.dart';
import 'package:family_planner/features/tasks/presentation/pages/edit_task_sheet.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/use_cases/complete_task_use_case.dart';
import 'package:family_planner/features/tasks/domain/use_cases/delete_task_use_case.dart';
import 'package:family_planner/features/tasks/domain/use_cases/get_tasks_for_day_use_case.dart';
import 'package:family_planner/features/tasks/domain/use_cases/uncomplete_task_use_case.dart';
import 'package:family_planner/features/tasks/presentation/cubit/task_completion_cubit.dart';
import 'package:family_planner/features/tasks/presentation/cubit/task_completion_state.dart';
import 'package:family_planner/features/tasks/presentation/cubit/task_actions_cubit.dart';
import 'package:family_planner/features/today/presentation/cubit/today_tasks_cubit.dart';
import 'package:family_planner/features/today/presentation/cubit/today_tasks_state.dart';
import 'package:family_planner/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:family_planner/features/auth/presentation/widgets/sign_out_button.dart';
import 'package:family_planner/features/tasks/domain/services/task_schedule.dart';
import 'package:family_planner/features/scheduled/presentation/pages/scheduled_page.dart';

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

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => TodayTasksCubit(
            getTasksForDayUseCase: GetTasksForDayUseCase(
              repository: repository,
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
            if (mounted) _reloadTasks();
          },
        )
        .subscribe();
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

  Future<void> _openCreateTaskSheet() async {
    final wasCreated = await showCreateTaskSheet(
      context: context,
      householdId: widget.householdId,
      plannedFor: widget.day,
    );

    if (wasCreated == true && mounted) {
      _reloadTasks();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Задача создана.')));
    }
  }

  Future<void> _openEditTaskSheet(Task task) async {
    final wasEdited = await showEditTaskSheet(context: context, task: task);

    if (wasEdited == true && mounted) {
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

    final actionsCubit = context.read<TaskActionsCubit>();
    final deleted = await actionsCubit.deleteTask(taskId: task.id);

    if (deleted && mounted) {
      _reloadTasks();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<TaskCompletionCubit, TaskCompletionState>(
          listener: (context, state) {
            switch (state) {
              case TaskCompletionSuccess():
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Задача выполнена. Отличная работа!'),
                  ),
                );
                _reloadTasks();
              case TaskCompletionFailure(:final message):
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(message)));
              case TaskCompletionInitial():
              case TaskCompletionInProgress():
                break;
            }
          },
        ),
        BlocListener<TaskActionsCubit, TaskCompletionState>(
          listener: (context, state) {
            if (state case TaskCompletionFailure(:final message)) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(message)));
            }
          },
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.householdName),
          actions: [
            IconButton(
              tooltip: 'Запланированные задачи',
              onPressed: () async {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        ScheduledPage(householdId: widget.householdId),
                  ),
                );

                if (mounted) {
                  _reloadTasks();
                }
              },
              icon: const Icon(Icons.calendar_month_outlined),
            ),
            SignOutButton(
              onPressed: () {
                context.read<AuthCubit>().signOut();
              },
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _openCreateTaskSheet,
          tooltip: 'Создать задачу',
          child: const Icon(Icons.add),
        ),
        body: BlocBuilder<TodayTasksCubit, TodayTasksState>(
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
                        const Icon(Icons.cloud_off_outlined, size: 48),
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

              case TodayTasksLoaded(:final tasks):
                final todayTasks = TaskSchedule.forDay(
                  tasks: tasks,
                  day: widget.day,
                );

                if (todayTasks.isEmpty) {
                  return const Center(
                    child: Text(
                      'На сегодня задач нет',
                      key: Key('today_empty_state'),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: todayTasks.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, index) {
                    return _TodayTaskCard(
                      task: todayTasks[index],
                      memberId: widget.currentMemberId,
                      onEdit: () => _openEditTaskSheet(todayTasks[index]),
                      onDelete: () => _deleteTask(todayTasks[index]),
                      onUncomplete: () async {
                        final actionsCubit =
                            context.read<TaskActionsCubit>();
                        final result = await actionsCubit.uncompleteTask(
                          task: todayTasks[index],
                        );
                        if (result != null && mounted) {
                          _reloadTasks();
                        }
                      },
                    );
                  },
                );
            }
          },
        ),
      ),
    );
  }
}

final class _TodayTaskCard extends StatelessWidget {
  const _TodayTaskCard({
    required this.task,
    required this.memberId,
    required this.onEdit,
    required this.onDelete,
    required this.onUncomplete,
  });

  final Task task;
  final String memberId;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onUncomplete;

  @override
  Widget build(BuildContext context) {
    final isCompleted = task.isCompleted;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      decoration: isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
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
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Редактировать'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline),
                        title: Text('Удалить'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (task.description != null) ...[
              const SizedBox(height: 8),
              Text(
                task.description!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  decoration: isCompleted
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text('Примерно ${task.estimatedDurationMinutes} минут'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: BlocBuilder<TaskCompletionCubit, TaskCompletionState>(
                    builder: (context, completionState) {
                      final isThisTaskInProgress =
                          completionState is TaskCompletionInProgress;

                      if (isCompleted) {
                        return OutlinedButton.icon(
                          onPressed: isThisTaskInProgress ? null : onUncomplete,
                          icon: const Icon(Icons.undo),
                          label: const Text('Отменить'),
                        );
                      }

                      return FilledButton.icon(
                        key: Key('complete_task_button_${task.id}'),
                        onPressed: task.canBeCompletedBy(memberId) &&
                                !isThisTaskInProgress
                            ? () {
                                context
                                    .read<TaskCompletionCubit>()
                                    .completeTask(
                                      task: task,
                                      memberId: memberId,
                                    );
                              }
                            : null,
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Выполнить'),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
