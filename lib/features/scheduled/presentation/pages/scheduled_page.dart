import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:family_planner/features/scheduled/presentation/cubit/scheduled_tasks_cubit.dart';
import 'package:family_planner/features/scheduled/presentation/cubit/scheduled_tasks_state.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/presentation/pages/edit_task_sheet.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/tasks/domain/use_cases/get_scheduled_tasks_use_case.dart';

final class ScheduledPage extends StatelessWidget {
  const ScheduledPage({required this.householdId, super.key});

  final String householdId;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<TaskRepository>();

    return BlocProvider(
      create: (_) => ScheduledTasksCubit(
        getScheduledTasksUseCase: GetScheduledTasksUseCase(
          repository: repository,
        ),
      ),
      child: _ScheduledView(householdId: householdId, day: DateTime.now()),
    );
  }
}

final class _ScheduledView extends StatefulWidget {
  const _ScheduledView({required this.householdId, required this.day});

  final String householdId;
  final DateTime day;

  @override
  State<_ScheduledView> createState() => _ScheduledViewState();
}

final class _ScheduledViewState extends State<_ScheduledView> {
  @override
  void initState() {
    super.initState();
    _reloadTasks();
  }

  void _reloadTasks() {
    context.read<ScheduledTasksCubit>().load(
      householdId: widget.householdId,
      day: widget.day,
    );
  }

  Future<void> _openEditTaskSheet(Task task) async {
    final wasUpdated = await showEditTaskSheet(context: context, task: task);

    if (wasUpdated == true && mounted) {
      _reloadTasks();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Изменения сохранены.')));
    }
  }

  String _formatPlannedFor(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();

    return '$day.$month.$year';
  }

  String _formatDeadline(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');

    return '$day.$month.$year, $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Запланировано')),
      body: BlocBuilder<ScheduledTasksCubit, ScheduledTasksState>(
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

            case ScheduledTasksLoaded(:final tasks):
              if (tasks.isEmpty) {
                return const Center(
                  child: Text(
                    'Запланированных задач нет',
                    key: Key('scheduled_empty_state'),
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async => _reloadTasks(),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: tasks.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, index) {
                    final task = tasks[index];

                    return Card(
                      key: Key('scheduled_task_${task.id}'),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    task.title,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  key: Key('task_menu_${task.id}'),
                                  tooltip: 'Действия с задачей',
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _openEditTaskSheet(task);
                                    }
                                  },
                                  itemBuilder: (_) {
                                    return const [
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Text('Редактировать'),
                                      ),
                                    ];
                                  },
                                ),
                              ],
                            ),
                            if (task.description != null &&
                                task.description!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(task.description!),
                            ],
                            const SizedBox(height: 12),
                            Text(
                              'Запланировано: '
                              '${_formatPlannedFor(task.plannedFor)}',
                            ),
                            if (task.deadline != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Дедлайн: ${_formatDeadline(task.deadline!)}',
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              'Примерно ${task.estimatedDurationMinutes} минут',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
          }
        },
      ),
    );
  }
}
