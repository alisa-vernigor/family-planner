import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/tasks/domain/entities/create_task_params.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/tasks/domain/use_cases/delete_task_use_case.dart';
import 'package:family_planner/features/tasks/domain/use_cases/get_all_pending_tasks_use_case.dart';
import 'package:family_planner/features/tasks/domain/use_cases/get_scheduled_tasks_use_case.dart';
import 'package:family_planner/features/tasks/domain/use_cases/uncomplete_task_use_case.dart';
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

    test('очищает description и устанавливает null, если он пустой после обрезки', () async {
      final editedTask = task.copyWith(description: '   ');

      await UpdateTaskUseCase(repository: repository)(task: editedTask);

      expect(repository.savedTask!.description, isNull);
    });

    test('оставляет непустой description после обрезки', () async {
      final editedTask = task.copyWith(description: '  Купить ещё и сыр  ');

      await UpdateTaskUseCase(repository: repository)(task: editedTask);

      expect(repository.savedTask!.description, 'Купить ещё и сыр');
    });
  });

  group('DeleteTaskUseCase', () {
    test('удаляет только задачу с переданным идентификатором', () async {
      await DeleteTaskUseCase(repository: repository)(taskId: task.id);

      expect(repository.deletedTaskId, 'task-1');
    });
  });

  group('UncompleteTaskUseCase', () {
    test('сбрасывает выполненную задачу в состояние "ожидает"', () async {
      final completedTask = task.copyWith(
        assignedMemberId: 'member-1',
        status: TaskStatus.completed,
        completedAt: DateTime(2026, 7, 22, 10),
      );

      final pendingTask = await UncompleteTaskUseCase(
        repository: repository,
      )(task: completedTask);

      expect(pendingTask.status, TaskStatus.pending);
      expect(pendingTask.assignedMemberId, isNull);
      expect(pendingTask.completedAt, isNull);
      expect(repository.savedTask, isNotNull);
      expect(repository.savedTask!.status, TaskStatus.pending);
    });

    test('выбрасывает исключение для задачи, которая ещё не выполнена',
        () async {
      await expectLater(
        UncompleteTaskUseCase(repository: repository)(task: task),
        throwsA(isA<TaskNotCompletedException>()),
      );

      expect(repository.savedTask, isNull);
    });
  });

  group('GetAllPendingTasksUseCase', () {
    test('запрашивает все невыполненные задачи у репозитория', () async {
      repository.pendingTasks = [task];

      final result = await GetAllPendingTasksUseCase(
        repository: repository,
      )(householdId: 'household-1');

      expect(result, [task]);
      expect(repository.receivedPendingHouseholdId, 'household-1');
    });
  });
}

final class _FakeTaskRepository implements TaskRepository {
  List<Task> scheduledTasks = const [];
  List<Task> pendingTasks = const [];
  String? receivedHouseholdId;
  String? receivedPendingHouseholdId;
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

  @override
  Future<List<Task>> getAllPending({
    required String householdId,
  }) async {
    receivedPendingHouseholdId = householdId;
    return pendingTasks;
  }

  @override
  Future<void> addAllowedMember({
    required String taskId,
    required String memberId,
  }) async {}

  @override
  Future<void> removeAllowedMember({required String taskId, required String memberId}) async {}

  @override
  Future<void> patchStatus({required String taskId, required String status, String? completedByMemberId, String? completedAt, String? assignedMemberId}) async {
    // UncompleteTaskUseCase вызывает patchStatus, а не save
    savedTask = Task(
      id: taskId,
      householdId: '',
      title: '',
      estimatedDurationMinutes: 0,
      plannedFor: DateTime.now(),
      allowedMemberIds: const [],
      status: status == 'completed' ? TaskStatus.completed : TaskStatus.pending,
      assignedMemberId: assignedMemberId,
      createdAt: DateTime.now(),
    );
  }
}
