import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:family_planner/features/tasks/presentation/pages/create_task_sheet.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/use_cases/complete_task_use_case.dart';
import 'package:family_planner/features/tasks/domain/use_cases/get_tasks_for_day_use_case.dart';
import 'package:family_planner/features/tasks/presentation/cubit/task_completion_cubit.dart';
import 'package:family_planner/features/tasks/presentation/cubit/task_completion_state.dart';
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
  @override
  void initState() {
    super.initState();

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

  @override
  Widget build(BuildContext context) {
    return BlocListener<TaskCompletionCubit, TaskCompletionState>(
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
  const _TodayTaskCard({required this.task, required this.memberId});

  final Task task;
  final String memberId;

  @override
  Widget build(BuildContext context) {
    final isCompleted = task.isCompleted;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(task.title, style: Theme.of(context).textTheme.titleLarge),
            if (task.description != null) ...[
              const SizedBox(height: 8),
              Text(
                task.description!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 16),
            Text('Примерно ${task.estimatedDurationMinutes} минут'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: BlocBuilder<TaskCompletionCubit, TaskCompletionState>(
                builder: (context, completionState) {
                  final isThisTaskInProgress =
                      completionState is TaskCompletionInProgress;

                  return FilledButton.icon(
                    key: Key('complete_task_button_${task.id}'),
                    onPressed: isCompleted || isThisTaskInProgress
                        ? null
                        : () {
                            context.read<TaskCompletionCubit>().completeTask(
                              task: task,
                              memberId: memberId,
                            );
                          },
                    icon: Icon(
                      isCompleted
                          ? Icons.check_circle
                          : Icons.check_circle_outline,
                    ),
                    label: Text(isCompleted ? 'Выполнено' : 'Выполнить'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
