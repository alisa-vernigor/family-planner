import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:family_planner/core/mixins/realtime_tasks_subscription.dart';
import 'package:family_planner/core/logging/app_logger.dart';
import 'package:family_planner/features/tasks/tasks.dart';
import 'package:family_planner/features/households/households.dart';
import 'package:family_planner/features/scheduled/presentation/cubit/scheduled_tasks_cubit.dart';
import 'package:family_planner/features/scheduled/presentation/cubit/scheduled_tasks_state.dart';
import 'package:family_planner/features/scheduled/presentation/widgets/scheduled_task_card.dart';

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
        taskRepository: repository,
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

final class _ScheduledViewState extends State<_ScheduledView>
    with RealtimeTasksSubscriptionMixin<_ScheduledView> {
  String _taskFilter = 'all'; // all, mine, unassigned
  bool _showMatrix = false;
  TaskSortOption _sortOption = TaskSortOption.plannedFor;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    subscribeToTaskChanges(
      householdId: widget.householdId,
      channelPrefix: 'scheduled-tasks',
      onChanged: _silentReload,
    );
    _reloadTasks();
  }

  @override
  void didUpdateWidget(covariant _ScheduledView oldWidget) {
    super.didUpdateWidget(oldWidget);
    reattachTaskSubscription(
      oldHouseholdId: oldWidget.householdId,
      newHouseholdId: widget.householdId,
      channelPrefix: 'scheduled-tasks',
      onChanged: _silentReload,
    );
    if (oldWidget.householdId != widget.householdId) {
      _reloadTasks();
    }
  }

  @override
  void dispose() {
    unsubscribeFromTaskChanges();
    super.dispose();
  }

  void _silentReload() {
    context.read<ScheduledTasksCubit>().refresh(
      householdId: widget.householdId,
    );
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

  Future<void> _openCreateTaskSheet() async {
    final wasCreated = await showCreateTaskSheet(
      context: context,
      householdId: widget.householdId,
      plannedFor: DateTime.now(),
    );

    if (wasCreated == true && mounted) {
      _silentReload();
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
    final useCase = AssignTaskUseCase(repository: repository);

    // Оптимистичное обновление
    tasksCubit.replaceTask(
      task.copyWith(
        assignedMemberId: memberId.isEmpty ? null : memberId,
      ),
    );

    try {
      await useCase(task: task, memberId: memberId.isEmpty ? null : memberId);
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
    final useCase = UnpinTaskUseCase(repository: repository);

    // Оптимистичное обновление
    tasksCubit.replaceTask(task.unpin());

    try {
      await useCase(task: task);
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

  Future<void> _completeTask(
    Task task,
    List<HouseholdMember> members,
    BuildContext context,
  ) async {
    if (task.isCompleted || !mounted) return;

    final useCase = CompleteTaskUseCase(
      repository: context.read<TaskRepository>(),
      now: DateTime.now,
    );
    try {
      final completed = await useCase(task: task, memberId: widget.currentMemberId);
      context.read<ScheduledTasksCubit>().replaceTask(completed);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 6),
            content: const Text('Задача выполнена. Отличная работа!'),
            action: SnackBarAction(
              label: 'Отменить',
              onPressed: () => _uncompleteTask(completed, members, context),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось выполнить задачу.')),
        );
      }
    }
  }

  Future<void> _uncompleteTask(
    Task task,
    List<HouseholdMember> members,
    BuildContext context,
  ) async {
    if (!task.isCompleted || !mounted) return;

    final useCase = UncompleteTaskUseCase(
      repository: context.read<TaskRepository>(),
    );
    try {
      final result = await useCase(task: task);
      context.read<ScheduledTasksCubit>().replaceTask(result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось отменить выполнение.')),
        );
      }
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
    final repository = context.read<TaskRepository>();

    // Оптимистичное удаление
    tasksCubit.removeTask(task.id);

    try {
      await repository.delete(taskId: task.id);
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

  Future<void> _updateTaskPriority(Task task, EisenhowerPriority newPriority) async {
    if (task.priority == newPriority) return;

    final tasksCubit = context.read<ScheduledTasksCubit>();
    final repository = context.read<TaskRepository>();
    final useCase = UpdateTaskPriorityUseCase(repository: repository);

    // Оптимистичное обновление
    tasksCubit.replaceTask(task.withPriority(newPriority));

    try {
      await useCase(task: task, newPriority: newPriority);
    } catch (exception, stackTrace) {
      // Откат
      if (!mounted) return;
      tasksCubit.replaceTask(task);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось изменить приоритет задачи.')),
      );
      AppLogger.error('Ошибка смены приоритета', error: exception, stackTrace: stackTrace);
    }
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
                    onCreate: _openCreateTaskSheet,
                  );
                }

                final grouped = <String, List<Task>>{};
                final sortedTasks = TaskSortOption.apply(filteredTasks, _sortOption, ascending: _sortAscending);
                for (final task in sortedTasks) {
                  final key = _formatDate(task.plannedFor);
                  grouped.putIfAbsent(key, () => []).add(task);
                }
                final dates = grouped.keys.toList();

                return Column(
                  children: [
                    // Фильтр + сортировка + переключатель вида
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Column(
                        children: [
                          Row(children: [
                            FilterChipWidget(
                              label: 'Все', selected: _taskFilter == 'all',
                              onSelected: () => setState(() => _taskFilter = 'all'),
                            ),
                            const SizedBox(width: 8),
                            FilterChipWidget(
                              label: 'Мои', selected: _taskFilter == 'mine',
                              onSelected: () => setState(() => _taskFilter = 'mine'),
                            ),
                            const SizedBox(width: 8),
                            FilterChipWidget(
                              label: 'Без назначения', selected: _taskFilter == 'unassigned',
                              onSelected: () => setState(() => _taskFilter = 'unassigned'),
                            ),
                            const Spacer(),
                            if (!_showMatrix)
                              SortSelector(
                                current: _sortOption,
                                onChanged: (option) {
                                  setState(() => _sortOption = option);
                                },
                                ascending: _sortAscending,
                                onAscendingChanged: (ascending) {
                                  setState(() => _sortAscending = ascending);
                                },
                              ),
                            IconButton(
                              icon: Icon(
                                _showMatrix ? Icons.list_alt : Icons.grid_view_outlined,
                              ),
                              tooltip: _showMatrix ? 'Список' : 'Матрица Эйзенхауэра',
                              onPressed: () => setState(() => _showMatrix = !_showMatrix),
                            ),
                          ]),
                        ],
                      ),
                    ),
                    if (_showMatrix)
                      Expanded(
                        child: EisenhowerMatrixView(
                          tasks: sortedTasks,
                          members: members,
                          currentMemberId: widget.currentMemberId,
                          onEdit: _openEditTaskSheet,
                          onDelete: _deleteTask,
                          onAssign: _assignTask,
                          onTogglePin: _togglePinTask,
                          onComplete: (task) => _completeTask(task, members, context),
                          onUncomplete: (task) => _uncompleteTask(task, members, context),
                          onSwipeComplete: (task) => _completeTask(task, members, context),
                          onSwipeUncomplete: (task) => _uncompleteTask(task, members, context),
                          onSwipeDelete: (task) => _deleteTask(task),
                          onUpdatePriority: _updateTaskPriority,
                        ),
                      )
                    else
                      Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async => _reloadTasks(),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
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
                                  child: ScheduledTaskCard(
                                    key: ValueKey(task.id),
                                    task: task,
                                    members: members,
                                    currentMemberId: widget.currentMemberId,
                                    formatDate: _formatDate,
                                    onEdit: () => _openEditTaskSheet(task),
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
