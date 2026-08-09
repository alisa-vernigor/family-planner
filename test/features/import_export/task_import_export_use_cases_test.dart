import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/households/domain/entities/household.dart';
import 'package:family_planner/features/households/domain/entities/household_invitation.dart';
import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/households/domain/repositories/household_repository.dart';
import 'package:family_planner/features/import_export/domain/entities/task_transfer_file.dart';
import 'package:family_planner/features/import_export/domain/use_cases/task_export_use_case.dart';
import 'package:family_planner/features/import_export/domain/use_cases/task_import_use_case.dart';
import 'package:family_planner/features/tasks/domain/entities/create_task_category_params.dart';
import 'package:family_planner/features/tasks/domain/entities/create_task_params.dart';
import 'package:family_planner/features/tasks/domain/entities/create_task_subtask_params.dart';
import 'package:family_planner/features/tasks/domain/entities/eisenhower_priority.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_category.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:family_planner/features/tasks/domain/entities/task_subtask.dart';
import 'package:family_planner/features/tasks/domain/entities/update_recurring_task_params.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_category_repository.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_subtask_repository.dart';

void main() {
  const householdId = 'household-1';
  final member = HouseholdMember(
    profileId: 'user-1',
    displayName: 'Мама',
    role: 'owner',
  );

  group('TaskImportUseCase', () {
    test('импортирует задачи, категории и подзадачи онлайн', () async {
      final taskRepo = _FakeTaskRepository(
        taskToCreate: _task(id: 'task-1'),
      );
      final categoryRepo = _FakeCategoryRepository();
      final subtaskRepo = _FakeSubtaskRepository();
      final householdRepo = _FakeHouseholdRepository(members: [member]);
      final useCase = TaskImportUseCase(
        taskRepository: taskRepo,
        taskCategoryRepository: categoryRepo,
        taskSubtaskRepository: subtaskRepo,
        householdRepository: householdRepo,
        isOnline: () => true,
      );

      const json = '''
      {
        "version": 1,
        "tasks": [
          {
            "title": "Помыть посуду",
            "date": "2026-08-09",
            "time": "18:00",
            "duration_minutes": 45,
            "priority": 2,
            "assignee": "мама",
            "category": "Кухня",
            "subtasks": ["Мыло", "Губка"]
          }
        ]
      }
      ''';

      final result = await useCase.import(jsonString: json, householdId: householdId);

      expect(result.imported, 1);
      expect(result.skipped, 0);
      expect(result.errors, isEmpty);

      // Категория создана по имени.
      expect(categoryRepo.createdNames, ['Кухня']);

      // Задача создана с полными параметрами.
      final params = taskRepo.receivedParams;
      expect(params!.title, 'Помыть посуду');
      expect(params.plannedFor, DateTime(2026, 8, 9));
      expect(params.plannedTime, const Duration(hours: 18));
      expect(params.estimatedDurationMinutes, 45);
      expect(params.priority, EisenhowerPriority.notUrgentImportant);
      expect(params.assignedMemberId, 'user-1');
      expect(params.categoryId, categoryRepo.created[0].id);

      // Подзадачи созданы с серверным id задачи.
      expect(subtaskRepo.createdTasks, ['task-1', 'task-1']);
      expect(
        subtaskRepo.createdTitles,
        ['Мыло', 'Губка'],
      );
    });

    test('задача без даты → сегодня', () async {
      final taskRepo = _FakeTaskRepository(taskToCreate: _task(id: 'task-1'));
      final useCase = TaskImportUseCase(
        taskRepository: taskRepo,
        taskCategoryRepository: _FakeCategoryRepository(),
        taskSubtaskRepository: _FakeSubtaskRepository(),
        householdRepository: _FakeHouseholdRepository(members: [member]),
        isOnline: () => true,
      );

      final today = DateTime.now();
      final result = await useCase.import(
        jsonString: '{"tasks":[{"title":"Без даты"}]}',
        householdId: householdId,
      );

      expect(result.imported, 1);
      final params = taskRepo.receivedParams!;
      expect(params.plannedFor.year, today.year);
      expect(params.plannedFor.month, today.month);
      expect(params.plannedFor.day, today.day);
    });

    test('существующая категория не создаётся повторно', () async {
      final taskRepo = _FakeTaskRepository(taskToCreate: _task(id: 'task-1'));
      final categoryRepo = _FakeCategoryRepository(
        existing: [
          TaskCategory(
            id: 'cat-1',
            householdId: householdId,
            name: 'Кухня',
          ),
        ],
      );
      final useCase = TaskImportUseCase(
        taskRepository: taskRepo,
        taskCategoryRepository: categoryRepo,
        taskSubtaskRepository: _FakeSubtaskRepository(),
        householdRepository: _FakeHouseholdRepository(members: [member]),
        isOnline: () => true,
      );

      await useCase.import(
        jsonString: '{"tasks":[{"title":"t","category":"кухня"}]}',
        householdId: householdId,
      );

      expect(categoryRepo.createdNames, isEmpty);
      expect(taskRepo.receivedParams!.categoryId, 'cat-1');
    });

    test('неизвестный исполнитель → без назначения', () async {
      final taskRepo = _FakeTaskRepository(taskToCreate: _task(id: 'task-1'));
      final useCase = TaskImportUseCase(
        taskRepository: taskRepo,
        taskCategoryRepository: _FakeCategoryRepository(),
        taskSubtaskRepository: _FakeSubtaskRepository(),
        householdRepository: _FakeHouseholdRepository(members: [member]),
        isOnline: () => true,
      );

      await useCase.import(
        jsonString: '{"tasks":[{"title":"t","assignee":"Незнакомец"}]}',
        householdId: householdId,
      );

      expect(taskRepo.receivedParams!.assignedMemberId, isNull);
    });

    test('офлайн → TaskImportOfflineException', () async {
      final useCase = TaskImportUseCase(
        taskRepository: _FakeTaskRepository(taskToCreate: _task(id: 'task-1')),
        taskCategoryRepository: _FakeCategoryRepository(),
        taskSubtaskRepository: _FakeSubtaskRepository(),
        householdRepository: _FakeHouseholdRepository(members: [member]),
        isOnline: () => false,
      );

      expect(
        () => useCase.import(
          jsonString: '{"tasks":[{"title":"t"}]}',
          householdId: householdId,
        ),
        throwsA(isA<TaskImportOfflineException>()),
      );
    });

    test('некорректный JSON → TaskImportFormatException', () async {
      final useCase = TaskImportUseCase(
        taskRepository: _FakeTaskRepository(taskToCreate: _task(id: 'task-1')),
        taskCategoryRepository: _FakeCategoryRepository(),
        taskSubtaskRepository: _FakeSubtaskRepository(),
        householdRepository: _FakeHouseholdRepository(members: [member]),
        isOnline: () => true,
      );

      expect(
        () => useCase.import(jsonString: 'не-json', householdId: householdId),
        throwsA(isA<TaskImportFormatException>()),
      );
    });

    test('ошибка одной задачи не ломает остальные', () async {
      // Первая задача падает при создании (пустой title после трима),
      // вторая — импортируется.
      final taskRepo = _FakeTaskRepository(
        taskToCreate: _task(id: 'task-2'),
        failTitles: {'   '},
      );
      final useCase = TaskImportUseCase(
        taskRepository: taskRepo,
        taskCategoryRepository: _FakeCategoryRepository(),
        taskSubtaskRepository: _FakeSubtaskRepository(),
        householdRepository: _FakeHouseholdRepository(members: [member]),
        isOnline: () => true,
      );

      final result = await useCase.import(
        jsonString: '''
        {"tasks":[
          {"title":"   "},
          {"title":"Вторая"}
        ]}
        ''',
        householdId: householdId,
      );

      expect(result.imported, 1);
      expect(result.skipped, 1);
      expect(result.errors, hasLength(1));
    });
  });

  group('TaskExportUseCase', () {
    test('экспортирует невыполненные задачи с именами, без id', () async {
      final task = Task(
        id: 'task-1',
        householdId: householdId,
        title: 'Помыть посуду',
        description: 'С горячей водой',
        estimatedDurationMinutes: 45,
        plannedFor: DateTime(2026, 8, 9),
        plannedTime: const Duration(hours: 18),
        deadline: DateTime(2026, 8, 9, 20),
        priority: EisenhowerPriority.notUrgentImportant,
        assignedMemberId: 'user-1',
        categoryId: 'cat-1',
        allowedMemberIds: const [],
        status: TaskStatus.pending,
        createdAt: DateTime(2026, 8, 1),
      );

      final taskRepo = _FakeTaskRepository(pendingTasks: [task]);
      final categoryRepo = _FakeCategoryRepository(
        existing: [
          TaskCategory(
            id: 'cat-1',
            householdId: householdId,
            name: 'Кухня',
          ),
        ],
      );
      final subtaskRepo = _FakeSubtaskRepository(
        subtasks: [
          TaskSubtask(
            id: 's-1',
            taskId: 'task-1',
            title: 'Мыло',
            position: 0,
            isCompleted: false,
            createdAt: DateTime(2026, 8, 1),
          ),
        ],
      );

      final useCase = TaskExportUseCase(
        taskRepository: taskRepo,
        taskCategoryRepository: categoryRepo,
        taskSubtaskRepository: subtaskRepo,
        householdRepository: _FakeHouseholdRepository(members: [member]),
      );

      final jsonString = await useCase.export(householdId: householdId);
      final file = TaskTransferFile.fromJson(
        _decode(jsonString),
      );

      expect(file.tasks, hasLength(1));
      final item = file.tasks.single;
      expect(item.title, 'Помыть посуду');
      expect(item.assignee, 'Мама');
      expect(item.category, 'Кухня');
      expect(item.subtasks, ['Мыло']);
      expect(item.priority, EisenhowerPriority.notUrgentImportant);
      expect(item.time, const Duration(hours: 18));

      // Никаких внутренних id в JSON.
      expect(jsonString, isNot(contains('task-1')));
      expect(jsonString, isNot(contains('user-1')));
      expect(jsonString, isNot(contains('cat-1')));
    });
  });
}

Map<String, dynamic> _decode(String jsonString) {
  return jsonDecode(jsonString) as Map<String, dynamic>;
}

Task _task({
  required String id,
}) {
  return Task(
    id: id,
    householdId: 'household-1',
    title: 'Задача',
    estimatedDurationMinutes: 30,
    plannedFor: DateTime(2026, 8, 9),
    allowedMemberIds: const [],
    status: TaskStatus.pending,
    createdAt: DateTime(2026, 8, 1),
  );
}

final class _FakeTaskRepository implements TaskRepository {
  _FakeTaskRepository({
    this.taskToCreate,
    this.pendingTasks = const [],
    this.failTitles = const {},
  });

  final Task? taskToCreate;
  final List<Task> pendingTasks;
  final Set<String> failTitles;

  CreateTaskParams? receivedParams;

  @override
  Future<Task> create({required CreateTaskParams params}) async {
    if (failTitles.contains(params.title.trim())) {
      throw StateError('Пустое название');
    }
    receivedParams = params;
    return taskToCreate!;
  }

  @override
  Future<List<Task>> getAllPending({required String householdId}) async {
    return pendingTasks;
  }

  @override
  Future<void> save(Task task) async {}

  @override
  Future<List<Task>> getForDay({
    required String householdId,
    required DateTime day,
  }) async {
    return const [];
  }

  @override
  Future<List<Task>> getScheduledAfter({
    required String householdId,
    required DateTime day,
  }) async {
    return const [];
  }

  @override
  Future<void> patchStatus({
    required String taskId,
    required String status,
    String? completedByMemberId,
    String? completedAt,
    String? assignedMemberId,
  }) async {}

  @override
  Future<void> addAllowedMember({
    required String taskId,
    required String memberId,
  }) async {}

  @override
  Future<void> removeAllowedMember({
    required String taskId,
    required String memberId,
  }) async {}

  @override
  Future<void> delete({required String taskId}) async {}

  @override
  Future<void> updateTemplate({required UpdateRecurringTaskParams params}) async {}

  @override
  Future<void> pauseTemplate({required String templateId}) async {}

  @override
  Future<void> resumeTemplate({required String templateId}) async {}
}

final class _FakeCategoryRepository implements TaskCategoryRepository {
  _FakeCategoryRepository({this.existing = const []});

  final List<TaskCategory> existing;
  final List<TaskCategory> created = [];
  List<String> get createdNames => created.map((c) => c.name).toList();

  @override
  Future<List<TaskCategory>> getForHousehold(String householdId) async {
    return existing;
  }

  @override
  Future<TaskCategory> create(CreateTaskCategoryParams params) async {
    final category = TaskCategory(
      id: 'cat-${created.length + 1}',
      householdId: params.householdId,
      name: params.name,
    );
    created.add(category);
    return category;
  }

  @override
  Future<void> update(TaskCategory category) async {}

  @override
  Future<void> delete(String categoryId) async {}
}

final class _FakeSubtaskRepository implements TaskSubtaskRepository {
  _FakeSubtaskRepository({this.subtasks = const []});

  final List<TaskSubtask> subtasks;
  final List<String> createdTasks = [];
  final List<String> createdTitles = [];

  @override
  Future<List<TaskSubtask>> getForTask(String taskId) async {
    return subtasks.where((s) => s.taskId == taskId).toList();
  }

  @override
  Future<TaskSubtask> create(CreateTaskSubtaskParams params) async {
    createdTasks.add(params.taskId);
    createdTitles.add(params.title);
    return TaskSubtask(
      id: 's-${createdTitles.length}',
      taskId: params.taskId,
      title: params.title,
      position: createdTitles.length - 1,
      isCompleted: false,
      createdAt: DateTime(2026, 8, 1),
    );
  }

  @override
  Future<TaskSubtask> toggle(String subtaskId, bool isCompleted) async {
    throw UnimplementedError();
  }

  @override
  Future<TaskSubtask> updateTitle(String subtaskId, String title) async {
    throw UnimplementedError();
  }

  @override
  Future<void> reorder(String taskId, List<String> orderedIds) async {}

  @override
  Future<void> delete(String subtaskId) async {}
}

final class _FakeHouseholdRepository implements HouseholdRepository {
  _FakeHouseholdRepository({this.members = const []});

  final List<HouseholdMember> members;

  @override
  Future<List<HouseholdMember>> getMembers({required String householdId}) async {
    return members;
  }

  @override
  Future<List<Household>> getMyHouseholds() async => const [];

  @override
  Future<Household> create({required String name}) async {
    throw UnimplementedError();
  }

  @override
  Future<void> createInvitation({
    required String householdId,
    required String email,
  }) async {}

  @override
  Future<List<HouseholdInvitation>> getPendingInvitations() async => const [];

  @override
  Future<String> acceptInvitation({required String invitationId}) async {
    throw UnimplementedError();
  }

  @override
  Future<void> declineInvitation({required String invitationId}) async {}

  @override
  Future<void> leaveHousehold({required String householdId}) async {}

  @override
  Future<void> removeMember({
    required String householdId,
    required String profileId,
  }) async {}

  @override
  Future<void> deleteHousehold({required String householdId}) async {}

  @override
  Future<void> updateHousehold({
    required String householdId,
    required String name,
  }) async {}
}
