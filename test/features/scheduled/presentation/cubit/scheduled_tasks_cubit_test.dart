import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/scheduled/presentation/cubit/scheduled_tasks_cubit.dart';
import 'package:family_planner/features/scheduled/presentation/cubit/scheduled_tasks_state.dart';
import 'package:family_planner/features/tasks/domain/entities/create_task_params.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/tasks/domain/use_cases/get_scheduled_tasks_use_case.dart';

void main() {
  final task = Task(
    id: 'task-1',
    householdId: 'household-1',
    title: 'Купить продукты',
    estimatedDurationMinutes: 30,
    plannedFor: DateTime(2026, 7, 22),
    deadline: DateTime(2026, 7, 22, 18),
    allowedMemberIds: const ['member-1'],
    status: TaskStatus.pending,
    createdAt: DateTime(2026, 7, 19),
  );

  test('загружает будущие задачи', () async {
    final repository = _FakeTaskRepository(tasks: [task]);

    final cubit = ScheduledTasksCubit(
      getScheduledTasksUseCase: GetScheduledTasksUseCase(
        repository: repository,
      ),
    );
    addTearDown(cubit.close);

    await cubit.load(householdId: 'household-1', day: DateTime(2026, 7, 19));

    expect(cubit.state, ScheduledTasksLoaded(tasks: [task]));
    expect(repository.receivedHouseholdId, 'household-1');
    expect(repository.receivedDay, DateTime(2026, 7, 19));
  });

  test('показывает ошибку, если загрузка завершилась неудачно', () async {
    final cubit = ScheduledTasksCubit(
      getScheduledTasksUseCase: GetScheduledTasksUseCase(
        repository: _FakeTaskRepository(shouldThrow: true),
      ),
    );
    addTearDown(cubit.close);

    await cubit.load(householdId: 'household-1', day: DateTime(2026, 7, 19));

    expect(
      cubit.state,
      const ScheduledTasksFailure(
        message: 'Не удалось загрузить запланированные задачи.',
      ),
    );
  });
}

final class _FakeTaskRepository implements TaskRepository {
  _FakeTaskRepository({
 this.tasks = const [],
  this.shouldThrow = false,
  });

  final List<Task> tasks;
  final bool shouldThrow;

  String? receivedHouseholdId;
  DateTime? receivedDay;

  @override
  Future<Task> create({required CreateTaskParams params}) {
    throw UnimplementedError();
  }

  @override
  Future<void> delete({required String taskId}) async {}

  @override
  Future<List<Task>> getForDay({
    required String householdId,
    required DateTime day,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<Task>> getScheduledAfter({
    required String householdId,
    required DateTime day,
  }) async {
    if (shouldThrow) {
      throw Exception('Ошибка сети');
    }

    receivedHouseholdId = householdId;
    receivedDay = day;

    return tasks;
  }

  @override
  Future<void> save(Task task) async {}
}
