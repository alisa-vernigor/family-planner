import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:family_planner/core/mixins/realtime_tasks_subscription.dart';
import 'package:family_planner/core/logging/app_logger.dart';
import 'package:family_planner/features/tasks/tasks.dart';
import 'package:family_planner/features/households/households.dart';
import 'package:family_planner/features/scheduled/presentation/cubit/scheduled_tasks_cubit.dart';
import 'package:family_planner/features/scheduled/presentation/cubit/scheduled_tasks_state.dart';
import 'package:family_planner/features/scheduled/presentation/widgets/calendar_view.dart';
import 'package:family_planner/features/scheduled/presentation/widgets/scheduled_task_card.dart';

final class ScheduledPage extends StatelessWidget {
  const ScheduledPage({
    required this.householdId,
    required this.currentMemberId,
    super.key,
  });

  final String householdId;
  final String currentMemberId;

  /// Case-insensitive поиск по названию и описанию задачи.
  /// Статический — для тестируемости без рендера страницы.
  static bool matchesSearchQuery(Task task, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final titleMatches = task.title.toLowerCase().contains(q);
    final descriptionMatches =
        task.description != null &&
        task.description!.toLowerCase().contains(q);
    return titleMatches || descriptionMatches;
  }

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
  String _searchQuery = '';
  final _searchController = TextEditingController();
  _ViewMode _viewMode = _ViewMode.list;
  TaskSortOption _sortOption = TaskSortOption.plannedFor;
  bool _sortAscending = true;
  Map<String, TaskCategory> _categoriesById = {};

  @override
  void initState() {
    super.initState();
    subscribeToTaskChanges(
      householdId: widget.householdId,
      channelPrefix: 'scheduled-tasks',
      onChanged: _silentReload,
    );
    _reloadTasks();
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
    _searchController.dispose();
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

  Future<void> _rescheduleTask(Task task) async {
    final result = await showReschedulePicker(context: context, task: task);
    if (result == null || !mounted) return;

    final tasksCubit = context.read<ScheduledTasksCubit>();
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
          SnackBar(content: Text('Задача перенесена на ${_formatDate(result.newPlannedFor)}')),
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

  /// Перенос задачи на конкретную дату (drag & drop в календаре).
  ///
  /// Без диалога: серия переносится целиком, обычная — только этот экземпляр.
  Future<void> _rescheduleTaskToDay(Task task, DateTime day) async {
    final tasksCubit = context.read<ScheduledTasksCubit>();
    final repository = context.read<TaskRepository>();
    final useCase = RescheduleTaskUseCase(repository: repository);

    // Оптимистичное обновление
    final optimistic = task.copyWith(plannedFor: day);
    tasksCubit.replaceTask(optimistic);

    try {
      await useCase.call(
        task: task,
        newDate: day,
        scope: task.isRecurring ? RecurrenceEditScope.all : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Задача перенесена на ${_formatDate(day)}')),
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

    final tasksCubit = context.read<ScheduledTasksCubit>();
    final repository = context.read<TaskRepository>();
    final useCase = SkipTaskUseCase(repository: repository);

    // Оптимистично убираем задачу из списка (как при удалении).
    tasksCubit.removeTask(task.id);

    try {
      await useCase(task: task);
      tasksCubit.confirmDelete(task.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Задача пропущена.')),
        );
      }
    } catch (exception, stackTrace) {
      // Откат — перезагружаем
      tasksCubit.cancelDelete(task.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось пропустить задачу.')),
      );
      AppLogger.error('Ошибка пропуска задачи', error: exception, stackTrace: stackTrace);
      _reloadTasks();
    }
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

  /// Case-insensitive поиск по названию и описанию задачи.
  bool _matchesSearch(Task task) => ScheduledPage.matchesSearchQuery(
    task,
    _searchQuery,
  );

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
                }
                    .where((t) => _matchesSearch(t))
                    .toList();

                if (filteredTasks.isEmpty) {
                  return _emptyState(
                    icon: _searchQuery.isNotEmpty
                        ? Icons.search_off
                        : Icons.calendar_month_outlined,
                    title: _searchQuery.isNotEmpty
                        ? 'Ничего не найдено'
                        : 'Нет задач по выбранному фильтру',
                    subtitle: _searchQuery.isNotEmpty
                        ? 'Попробуйте изменить поисковый запрос'
                        : 'Попробуйте другой фильтр',
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
                            if (_viewMode == _ViewMode.list)
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
                            if (_viewMode == _ViewMode.list)
                              IconButton(
                                icon: const Icon(Icons.grid_view_outlined),
                                tooltip: 'Матрица Эйзенхауэра',
                                onPressed: () =>
                                    setState(() => _viewMode = _ViewMode.matrix),
                              ),
                            if (_viewMode == _ViewMode.list)
                              IconButton(
                                icon: const Icon(Icons.calendar_month_outlined),
                                tooltip: 'Календарь',
                                onPressed: () =>
                                    setState(() => _viewMode = _ViewMode.calendar),
                              ),
                            if (_viewMode == _ViewMode.matrix) ...[
                              IconButton(
                                icon: const Icon(Icons.calendar_month_outlined),
                                tooltip: 'Календарь',
                                onPressed: () =>
                                    setState(() => _viewMode = _ViewMode.calendar),
                              ),
                              IconButton(
                                icon: const Icon(Icons.list_alt),
                                tooltip: 'Список',
                                onPressed: () =>
                                    setState(() => _viewMode = _ViewMode.list),
                              ),
                            ],
                            if (_viewMode == _ViewMode.calendar) ...[
                              IconButton(
                                icon: const Icon(Icons.list_alt),
                                tooltip: 'Список',
                                onPressed: () =>
                                    setState(() => _viewMode = _ViewMode.list),
                              ),
                              IconButton(
                                icon: const Icon(Icons.grid_view_outlined),
                                tooltip: 'Матрица Эйзенхауэра',
                                onPressed: () =>
                                    setState(() => _viewMode = _ViewMode.matrix),
                              ),
                            ],
                          ]),
                          const SizedBox(height: 8),
                          // Поиск по названию/описанию
                          TextField(
                            key: const Key('task_search_field'),
                            controller: _searchController,
                            onChanged: (value) =>
                                setState(() => _searchQuery = value),
                            decoration: InputDecoration(
                              hintText: 'Поиск задач…',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      tooltip: 'Очистить',
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    switch (_viewMode) {
                      _ViewMode.matrix => Expanded(
                        child: EisenhowerMatrixView(
                          tasks: sortedTasks,
                          members: members,
                          currentMemberId: widget.currentMemberId,
                          onEdit: _openEditTaskSheet,
                          onDelete: _deleteTask,
                          onAssign: _assignTask,
                          onTogglePin: _togglePinTask,
                          onComplete: (task) => _completeTask(task, members, context),
                          onSwipeComplete: (task) => _completeTask(task, members, context),
                          onSwipeDelete: (task) => _deleteTask(task),
                          onReschedule: _rescheduleTask,
                          onDuplicate: _duplicateTask,
                          onUpdatePriority: _updateTaskPriority,
                        ),
                      ),
                      _ViewMode.calendar => Expanded(
                        child: CalendarView(
                          tasks: filteredTasks,
                          members: members,
                          currentMemberId: widget.currentMemberId,
                          categoriesById: _categoriesById,
                          onEdit: _openEditTaskSheet,
                          onDelete: _deleteTask,
                          onAssign: _assignTask,
                          onTogglePin: _togglePinTask,
                          onReschedule: _rescheduleTask,
                          onRescheduleToDay: _rescheduleTaskToDay,
                          onDuplicate: _duplicateTask,
                          onTogglePause: _togglePauseTask,
                          onSkip: _skipTask,
                          onComplete: (task) => _completeTask(task, members, context),
                          onUncomplete: (task) => _uncompleteTask(task, members, context),
                          onCreate: _openCreateTaskSheet,
                        ),
                      ),
                      _ViewMode.list => Expanded(
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
                                    onReschedule: () => _rescheduleTask(task),
                                    onDuplicate: () => _duplicateTask(task),
                                    onTogglePause: () => _togglePauseTask(task),
                                    onSkip: () => _skipTask(task),
                                    category: _categoriesById[task.categoryId],
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    },
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

/// Режим отображения задач на экране «Запланированные».
enum _ViewMode { list, matrix, calendar }
