import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:family_planner/features/tasks/domain/entities/create_task_params.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/tasks/domain/use_cases/get_tasks_for_day_use_case.dart';
import 'package:family_planner/features/today/presentation/cubit/today_tasks_cubit.dart';
import 'package:family_planner/features/today/presentation/cubit/today_tasks_state.dart';

void main() {
  final day = DateTime.utc(2026, 7, 20);

  final task = Task(
    id: 'task-1',
    householdId: 'household-1',
    title: 'Разобрать посудомойку',
    estimatedDurationMinutes: 10,
    plannedFor: day,
    allowedMemberIds: const ['member-1'],
    status: TaskStatus.pending,
    createdAt: DateTime.utc(2026, 7, 19, 12),
  );

  blocTest<TodayTasksCubit, TodayTasksState>(
    'выдаёт Loading и Loaded со списком задач при успешной загрузке',
    build: () {
      final repository = FakeTaskRepository(tasksToReturn: [task]);

      return TodayTasksCubit(
        getTasksForDayUseCase: GetTasksForDayUseCase(repository: repository),
      );
    },
    act: (cubit) => cubit.load(householdId: 'household-1', day: day),
    expect: () => [
      const TodayTasksLoading(),
      TodayTasksLoaded(tasks: [task]),
    ],
  );

  blocTest<TodayTasksCubit, TodayTasksState>(
    'выдаёт Loading и Loaded с пустым списком, когда задач нет',
    build: () {
      final repository = FakeTaskRepository();

      return TodayTasksCubit(
        getTasksForDayUseCase: GetTasksForDayUseCase(repository: repository),
      );
    },
    act: (cubit) => cubit.load(householdId: 'household-1', day: day),
    expect: () => const [TodayTasksLoading(), TodayTasksLoaded(tasks: [])],
  );

  blocTest<TodayTasksCubit, TodayTasksState>(
    'выдаёт Loading и Failure при ошибке репозитория',
    build: () {
      final repository = FakeTaskRepository(
        exceptionToThrow: Exception('Нет подключения'),
      );

      return TodayTasksCubit(
        getTasksForDayUseCase: GetTasksForDayUseCase(repository: repository),
      );
    },
    act: (cubit) => cubit.load(householdId: 'household-1', day: day),
    expect: () => const [
      TodayTasksLoading(),
      TodayTasksFailure(message: 'Не удалось загрузить задачи на сегодня.'),
    ],
  );
}

final class FakeTaskRepository implements TaskRepository {
  FakeTaskRepository({this.tasksToReturn = const [], this.exceptionToThrow});

  final List<Task> tasksToReturn;
  final Object? exceptionToThrow;

  @override
  Future<void> delete({required String taskId}) async {}

  @override
  Future<List<Task>> getScheduledAfter({
    required String householdId,
    required DateTime day,
  }) async {
    return const [];
  }

  @override
  Future<List<Task>> getForDay({
    required String householdId,
    required DateTime day,
  }) async {
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }

    return tasksToReturn;
  }

  @override
  Future<Task> create({required CreateTaskParams params}) {
    throw UnimplementedError();
  }

  @override
  Future<void> save(Task task) async {}
}
