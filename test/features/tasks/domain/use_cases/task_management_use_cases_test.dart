import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/tasks/domain/entities/create_task_params.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/tasks/domain/use_cases/delete_task_use_case.dart';
import 'package:family_planner/features/tasks/domain/use_cases/get_scheduled_tasks_use_case.dart';
import 'package:family_planner/features/tasks/domain/use_cases/update_task_use_case.dart';

void main() {
  late _FakeTaskRepository repository;

  final task = Task(
    id: 'task-1',
    householdId: 'household-1',
    title: 'Купить продукты',
    description: 'Молоко и хлеб',
    estimatedDurationMinutes: 30,
    plannedFor: DateTime(2026, 7, 22),
    deadline: DateTime(2026, 7, 22, 18),
    allowedMemberIds: const ['member-1'],
    status: TaskStatus.pending,
    createdAt: DateTime(2026, 7, 19),
  );

  setUp(() {
    repository = _FakeTaskRepository();
  });

  group('GetScheduledTasksUseCase', () {
    test('запрашивает будущие задачи у репозитория', () async {
      repository.scheduledTasks = [task];

      final result = await GetScheduledTasksUseCase(repository: repository)(
        householdId: 'household-1',
        day: DateTime(2026, 7, 19),
      );

      expect(result, [task]);
      expect(repository.receivedHouseholdId, 'household-1');
      expect(repository.receivedDay, DateTime(2026, 7, 19));
    });
  });

  group('UpdateTaskUseCase', () {
    test('сохраняет отредактированную задачу с очищенным названием', () async {
      final editedTask = task.copyWith(
        title: '  Купить продукты для ужина  ',
        estimatedDurationMinutes: 45,
      );

      await UpdateTaskUseCase(repository: repository)(task: editedTask);

      expect(repository.savedTask, isNotNull);
      expect(repository.savedTask!.title, 'Купить продукты для ужина');
      expect(repository.savedTask!.estimatedDurationMinutes, 45);
    });

    test('не сохраняет задачу с пустым названием', () async {
      final editedTask = task.copyWith(title: '   ');

      await expectLater(
        UpdateTaskUseCase(repository: repository)(task: editedTask),
        throwsArgumentError,
      );

      expect(repository.savedTask, isNull);
    });

    test('не сохраняет задачу с нулевой длительностью', () async {
      final editedTask = task.copyWith(estimatedDurationMinutes: 0);

      await expectLater(
        UpdateTaskUseCase(repository: repository)(task: editedTask),
        throwsArgumentError,
      );

      expect(repository.savedTask, isNull);
    });
  });

  group('DeleteTaskUseCase', () {
    test('удаляет только задачу с переданным идентификатором', () async {
      await DeleteTaskUseCase(repository: repository)(taskId: task.id);

      expect(repository.deletedTaskId, 'task-1');
    });
  });
}

final class _FakeTaskRepository implements TaskRepository {
  List<Task> scheduledTasks = const [];
  String? receivedHouseholdId;
  DateTime? receivedDay;
  Task? savedTask;
  String? deletedTaskId;

  @override
  Future<Task> create({required CreateTaskParams params}) {
    throw UnimplementedError();
  }

  @override
  Future<void> delete({required String taskId}) async {
    deletedTaskId = taskId;
  }

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
    receivedHouseholdId = householdId;
    receivedDay = day;

    return scheduledTasks;
  }

  @override
  Future<void> save(Task task) async {
    savedTask = task;
  }
}
