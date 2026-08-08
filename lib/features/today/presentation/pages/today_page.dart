import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:family_planner/core/mixins/realtime_tasks_subscription.dart';
import 'package:family_planner/core/logging/app_logger.dart';
import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/households/domain/repositories/household_repository.dart';
import 'package:family_planner/features/tasks/tasks.dart';
import 'package:family_planner/features/today/presentation/cubit/today_tasks_cubit.dart';
import 'package:family_planner/features/today/presentation/cubit/today_tasks_state.dart';
import 'package:family_planner/features/today/presentation/widgets/task_list_view.dart';

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
            taskRepository: repository,
            householdRepository: householdRepository,
            currentMemberId: currentMemberId,
            householdId: householdId,
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
            skipTaskUseCase: SkipTaskUseCase(repository: repository),
            taskRepository: repository,
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

final class _TodayViewState extends State<_TodayView>
    with RealtimeTasksSubscriptionMixin<_TodayView> {
  final Set<String> _selectedTaskIds = {};
  bool _isSelectionMode = false;
  TaskSortOption _sortOption = TaskSortOption.deadline;
  bool _sortAscending = true;
  Map<String, TaskCategory> _categoriesById = {};

  @override
  void initState() {
    super.initState();

    subscribeToTaskChanges(
      householdId: widget.householdId,
      channelPrefix: 'task-occurrences',
      onChanged: _silentReload,
    );
    _loadTasks();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await context
          .read<TaskCategoryRepository>()
          .getForHousehold(widget.householdId);
      if (mounted) {
        setState(() {
          _categoriesById = {for (final c in categories) c.id: c};
        });
      }
    } catch (_) {
      // Категории не критичны — список задач показываем без них.
    }
  }

  @override
  void didUpdateWidget(covariant _TodayView oldWidget) {
    super.didUpdateWidget(oldWidget);

    reattachTaskSubscription(
      oldHouseholdId: oldWidget.householdId,
      newHouseholdId: widget.householdId,
      channelPrefix: 'task-occurrences',
      onChanged: _silentReload,
    );
    if (oldWidget.householdId != widget.householdId) {
      _loadTasks();
    }
  }

  @override
  void dispose() {
    unsubscribeFromTaskChanges();
    super.dispose();
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

  Future<void> _skipTask(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Пропустить задачу?'),
        content: Text('«${task.title}» будет пропущена и исчезнет из списков.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Пропустить'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final tasksCubit = context.read<TodayTasksCubit>();
    final actionsCubit = context.read<TaskActionsCubit>();

    // Оптимистично убираем задачу из списка (как при удалении).
    tasksCubit.removeTask(task.id);

    final skipped = await actionsCubit.skipTask(task: task);

    if (skipped != null && mounted) {
      tasksCubit.confirmDelete(task.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Задача пропущена.')),
      );
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
    final useCase = AssignTaskUseCase(repository: repository);

    // Оптимистичное обновление
    final optimistic = task.copyWith(
      assignedMemberId: memberId.isEmpty ? null : memberId,
    );
    tasksCubit.replaceTask(optimistic);

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
    final tasksCubit = context.read<TodayTasksCubit>();
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

  Future<void> _rescheduleTask(Task task) async {
    final result = await showReschedulePicker(context: context, task: task);
    if (result == null || !mounted) return;

    final tasksCubit = context.read<TodayTasksCubit>();
    final repository = context.read<TaskRepository>();
    final useCase = RescheduleTaskUseCase(repository: repository);

    // Оптимистичное обновление
    final optimistic = task.copyWith(plannedFor: result.newPlannedFor);
    tasksCubit.replaceTask(optimistic);

    try {
      await useCase.call(
        task: task,
        newDate: result.newPlannedFor,
        scope: result.isSeries ? RecurrenceEditScope.all : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Задача перенесена на ${_formatRescheduleDate(result.newPlannedFor)}')),
        );
      }
    } catch (exception, stackTrace) {
      // Откат — перезагружаем
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось перенести задачу.')),
      );
      AppLogger.error('Ошибка переноса задачи', error: exception, stackTrace: stackTrace);
      _reloadTasks();
    }
  }

  String _formatRescheduleDate(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
  }

  Future<void> _duplicateTask(Task task) async {
    final repository = context.read<TaskRepository>();
    final useCase = DuplicateTaskUseCase(repository: repository);

    try {
      final created = await useCase.call(task: task);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              created.isRecurring
                  ? 'Серия скопирована.'
                  : 'Задача скопирована.',
            ),
          ),
        );
      }
    } catch (exception, stackTrace) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось скопировать задачу.')),
      );
      AppLogger.error('Ошибка дублирования задачи', error: exception, stackTrace: stackTrace);
      _reloadTasks();
    }
  }

  Future<void> _togglePauseTask(Task task) async {
    if (task.templateId == null) return;
    final repository = context.read<TaskRepository>();

    final isPausing = !task.isSeriesPaused;
    try {
      if (isPausing) {
        await PauseTaskTemplateUseCase(repository: repository).call(
          templateId: task.templateId!,
        );
      } else {
        await ResumeTaskTemplateUseCase(repository: repository).call(
          templateId: task.templateId!,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isPausing ? 'Серия поставлена на паузу.' : 'Серия возобновлена.',
            ),
          ),
        );
        // Перезагружаем: пауза удаляет будущие экземпляры на сервере.
        _silentReload();
      }
    } catch (exception, stackTrace) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось изменить состояние серии.')),
      );
      AppLogger.error(
        'Ошибка паузы/возобновления серии',
        error: exception,
        stackTrace: stackTrace,
      );
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

    // Batch-complete — не показываем N снекбаров,
    // один общий снекбар после последнего завершения.
    var count = 0;
    for (final task in toComplete) {
      count++;
      completionCubit.completeTask(
        task: task,
        memberId: widget.currentMemberId,
      );
    }

    setState(() {
      _selectedTaskIds.clear();
      _isSelectionMode = false;
    });

    // Единый снекбар вместо N
    if (count > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          content: Text('Выполнено задач: $count'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<TaskCompletionCubit, TaskCompletionState>(
          listener: (context, state) {
            switch (state) {
              case TaskCompletionSuccess(:final task):
            // В batch-режиме не показываем N индивидуальных снекбаров
            if (!_isSelectionMode) {
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
            }
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
        BlocListener<TaskActionsCubit, TaskActionState>(
          listener: (context, state) {
            if (state case TaskActionFailure(:final message)) {
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
                  final todayTasks = TaskSortOption.apply(
                    TaskSchedule.forDay(
                      tasks: tasks,
                      day: widget.day,
                    ),
                    _sortOption,
                    ascending: _sortAscending,
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
                    child: TaskListView(
                      tasks: todayTasks,
                      members: members,
                      currentMemberId: widget.currentMemberId,
                      isSelectionMode: _isSelectionMode,
                      selectedTaskIds: _selectedTaskIds,
                      categoriesById: _categoriesById,
                      sortOption: _sortOption,
                      onSortChanged: (option) {
                        setState(() => _sortOption = option);
                      },
                      sortAscending: _sortAscending,
                      onSortAscendingChanged: (ascending) {
                        setState(() => _sortAscending = ascending);
                      },
                      onEdit: _openEditTaskSheet,
                            onDelete: _deleteTask,
                            onAssign: _assignTask,
                            onTogglePin: _togglePinTask,
                            onReschedule: _rescheduleTask,
                            onDuplicate: _duplicateTask,
                            onTogglePause: _togglePauseTask,
                            onSkip: _skipTask,
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
                      onSwipeComplete: (task) {
                        if (!task.isCompleted) {
                          context
                              .read<TaskCompletionCubit>()
                              .completeTask(
                                task: task,
                                memberId: widget.currentMemberId,
                              );
                        }
                      },
                      onSwipeUncomplete: (task) async {
                        if (task.isCompleted) {
                          final result = await context
                              .read<TaskActionsCubit>()
                              .uncompleteTask(task: task);
                          if (result != null && mounted) {
                            context.read<TodayTasksCubit>().replaceTask(result);
                          }
                        }
                      },
                      onSwipeDelete: (task) {
                        _deleteTask(task);
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
          // ── Create task + Distribute FABs ───────────────
          if (!_isSelectionMode)
            Positioned(
              right: 16,
              bottom: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'distribute_tasks_fab',
                    tooltip: 'Автораспределить задачи',
                    onPressed: _distributeTasks,
                    child: const Icon(Icons.auto_awesome_outlined, size: 20),
                  ),
                  const SizedBox(height: 12),
                  FloatingActionButton(
                    heroTag: 'create_task_today_fab',
                    tooltip: 'Создать задачу',
                    onPressed: _openCreateTaskSheet,
                    child: const Icon(Icons.add),
                  ),
                ],
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

