import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/tasks/domain/entities/create_task_params.dart';
import 'package:family_planner/features/tasks/domain/entities/eisenhower_priority.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_recurrence.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:family_planner/features/tasks/domain/entities/update_recurring_task_params.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/tasks/domain/use_cases/assign_task_use_case.dart';
import 'package:family_planner/features/tasks/domain/use_cases/duplicate_task_use_case.dart';
import 'package:family_planner/features/tasks/domain/use_cases/pause_task_template_use_case.dart';
import 'package:family_planner/features/tasks/domain/use_cases/reschedule_task_use_case.dart';
import 'package:family_planner/features/tasks/domain/use_cases/resume_task_template_use_case.dart';
import 'package:family_planner/features/tasks/domain/use_cases/unpin_task_use_case.dart';
import 'package:family_planner/features/tasks/domain/use_cases/update_task_priority_use_case.dart';

// ── Ручной фейк репозитория: фиксируем вызовы и возвращаемые значения ─────
class _SpyTaskRepository implements TaskRepository {
  Task? savedTask;
  final savedTasks = <Task>[];
  String? addAllowedTaskId;
  String? addAllowedMemberId;
  String? removeAllowedTaskId;
  String? removeAllowedMemberId;
  String? pausedTemplateId;
  String? resumedTemplateId;
  UpdateRecurringTaskParams? updateTemplateParams;
  CreateTaskParams? createdParams;
  Task? createdTask;

  @override
  Future<List<Task>> getForDay({
    required String householdId,
    required DateTime day,
  }) async => [];
  @override
  Future<List<Task>> getScheduledAfter({
    required String householdId,
    required DateTime day,
  }) async => [];
  @override
  Future<List<Task>> getAllPending({required String householdId}) async => [];
  @override
  Future<Task> create({required CreateTaskParams params}) async {
    createdParams = params;
    return createdTask ?? Task(
      id: 'created-id',
      householdId: params.householdId,
      title: params.title,
      estimatedDurationMinutes: params.estimatedDurationMinutes,
      plannedFor: params.plannedFor,
      allowedMemberIds: const [],
      status: TaskStatus.pending,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> save(Task task) async {
    savedTask = task;
    savedTasks.add(task);
  }

  @override
  Future<void> updateTemplate({required UpdateRecurringTaskParams params}) async {
    updateTemplateParams = params;
  }

  @override
  Future<void> pauseTemplate({required String templateId}) async {
    pausedTemplateId = templateId;
  }

  @override
  Future<void> resumeTemplate({required String templateId}) async {
    resumedTemplateId = templateId;
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
  Future<void> delete({required String taskId}) async {}

  @override
  Future<void> addAllowedMember({
    required String taskId,
    required String memberId,
  }) async {
    addAllowedTaskId = taskId;
    addAllowedMemberId = memberId;
  }

  @override
  Future<void> removeAllowedMember({
    required String taskId,
    required String memberId,
  }) async {
    removeAllowedTaskId = taskId;
    removeAllowedMemberId = memberId;
  }
}

Task _task({
  String id = 'task-1',
  String? assignedMemberId,
  String? pinnedMemberId,
  EisenhowerPriority? priority,
  String? templateId,
  TaskStatus status = TaskStatus.pending,
}) {
  return Task(
    id: id,
    householdId: 'household-1',
    title: 'Задача',
    estimatedDurationMinutes: 30,
    plannedFor: DateTime.utc(2026, 8, 10),
    allowedMemberIds: const ['alice'],
    assignedMemberId: assignedMemberId,
    pinnedMemberId: pinnedMemberId,
    priority: priority,
    templateId: templateId,
    status: status,
    createdAt: DateTime.utc(2026, 8, 1),
  );
}

void main() {
  group('AssignTaskUseCase', () {
    test('назначает ответственного и добавляет в allowed если отсутствует', () async {
      final repo = _SpyTaskRepository();
      final uc = AssignTaskUseCase(repository: repo);

      final result = await uc.call(task: _task(), memberId: 'bob');

      expect(repo.addAllowedTaskId, 'task-1');
      expect(repo.addAllowedMemberId, 'bob');
      expect(result.assignedMemberId, 'bob');
      expect(repo.savedTask!.assignedMemberId, 'bob');
    });

    test('не добавляет в allowed если уже там', () async {
      final repo = _SpyTaskRepository();
      final uc = AssignTaskUseCase(repository: repo);

      await uc.call(task: _task(), memberId: 'alice');

      expect(repo.addAllowedTaskId, isNull);
      expect(repo.savedTask!.assignedMemberId, 'alice');
    });

    test('снимает назначение при пустом/нулевом memberId', () async {
      final repo = _SpyTaskRepository();
      final uc = AssignTaskUseCase(repository: repo);

      final result = await uc.call(
        task: _task(assignedMemberId: 'bob'),
        memberId: null,
      );

      expect(result.assignedMemberId, isNull);
      expect(repo.savedTask!.assignedMemberId, isNull);
    });
  });

  group('UnpinTaskUseCase', () {
    test('снимает закрепление и сохраняет', () async {
      final repo = _SpyTaskRepository();
      final uc = UnpinTaskUseCase(repository: repo);

      final result = await uc.call(task: _task(pinnedMemberId: 'alice'));

      expect(result.pinnedMemberId, isNull);
      expect(repo.savedTask!.pinnedMemberId, isNull);
    });
  });

  group('UpdateTaskPriorityUseCase', () {
    test('меняет приоритет и сохраняет', () async {
      final repo = _SpyTaskRepository();
      final uc = UpdateTaskPriorityUseCase(repository: repo);

      final result = await uc.call(
        task: _task(priority: EisenhowerPriority.notUrgentNotImportant),
        newPriority: EisenhowerPriority.urgentImportant,
      );

      expect(result.priority, EisenhowerPriority.urgentImportant);
      expect(repo.savedTask!.priority, EisenhowerPriority.urgentImportant);
    });

    test('возвращает задачу без сохранения если приоритет не изменился', () async {
      final repo = _SpyTaskRepository();
      final uc = UpdateTaskPriorityUseCase(repository: repo);

      final result = await uc.call(
        task: _task(priority: EisenhowerPriority.urgentImportant),
        newPriority: EisenhowerPriority.urgentImportant,
      );

      expect(repo.savedTask, isNull);
      expect(result, same(result));
    });
  });

  group('Pause/ResumeTaskTemplateUseCase', () {
    test('pause вызывает repository.pauseTemplate', () async {
      final repo = _SpyTaskRepository();
      final uc = PauseTaskTemplateUseCase(repository: repo);

      await uc.call(templateId: 'tmpl-1');

      expect(repo.pausedTemplateId, 'tmpl-1');
    });

    test('resume вызывает repository.resumeTemplate', () async {
      final repo = _SpyTaskRepository();
      final uc = ResumeTaskTemplateUseCase(repository: repo);

      await uc.call(templateId: 'tmpl-1');

      expect(repo.resumedTemplateId, 'tmpl-1');
    });
  });

  group('DuplicateTaskUseCase', () {
    test('дублирует обычную задачу на следующий день', () async {
      final repo = _SpyTaskRepository();
      final uc = DuplicateTaskUseCase(repository: repo);

      await uc.call(task: _task());

      final p = repo.createdParams!;
      expect(p.title, 'Задача');
      expect(p.plannedFor, isNot(_task().plannedFor)); // следующий день
      expect(p.recurrence, isNull);
      expect(p.recurrenceStartDate, isNull);
      expect(p.priority, isNull);
    });

    test('дублирует серию с сохранением расписания и стартовой даты', () async {
      final repo = _SpyTaskRepository();
      final uc = DuplicateTaskUseCase(repository: repo);

      final recurring = Task(
        id: 'task-1',
        householdId: 'household-1',
        title: 'Задача',
        estimatedDurationMinutes: 30,
        plannedFor: DateTime.utc(2026, 8, 10),
        allowedMemberIds: const ['alice'],
        status: TaskStatus.pending,
        templateId: 'tmpl-1',
        recurrence: const TaskRecurrence.daily(),
        recurrenceStartDate: DateTime.utc(2026, 8, 1),
        recurrenceEndDate: DateTime.utc(2026, 9, 1),
        createdAt: DateTime.utc(2026, 8, 1),
      );

      await uc.call(task: recurring);

      final p = repo.createdParams!;
      expect(p.recurrence, const TaskRecurrence.daily());
      expect(p.recurrenceStartDate, DateTime.utc(2026, 8, 1));
      expect(p.recurrenceEndDate, DateTime.utc(2026, 9, 1));
      // plannedFor сохраняется у серии
      expect(p.plannedFor, DateTime.utc(2026, 8, 10));
    });

    test('серия без recurrenceStartDate использует plannedFor', () async {
      final repo = _SpyTaskRepository();
      final uc = DuplicateTaskUseCase(repository: repo);

      final recurring = Task(
        id: 'task-1',
        householdId: 'household-1',
        title: 'Задача',
        estimatedDurationMinutes: 30,
        plannedFor: DateTime.utc(2026, 8, 10),
        allowedMemberIds: const ['alice'],
        status: TaskStatus.pending,
        templateId: 'tmpl-1',
        recurrence: const TaskRecurrence.daily(),
        createdAt: DateTime.utc(2026, 8, 1),
      );

      await uc.call(task: recurring);

      final p = repo.createdParams!;
      expect(p.recurrenceStartDate, DateTime.utc(2026, 8, 10));
    });
  });

  group('RescheduleTaskUseCase', () {
    test('обычная задача — save с новой датой', () async {
      final repo = _SpyTaskRepository();
      final uc = RescheduleTaskUseCase(repository: repo);

      final result = await uc.call(
        task: _task(),
        newDate: DateTime(2026, 9, 1),
      );

      expect(result.plannedFor, DateTime(2026, 9, 1));
      expect(repo.savedTask!.plannedFor, DateTime(2026, 9, 1));
      expect(repo.updateTemplateParams, isNull);
    });

    test('серия с scope только этот экземпляр — save', () async {
      final repo = _SpyTaskRepository();
      final uc = RescheduleTaskUseCase(repository: repo);

      final result = await uc.call(
        task: _task(templateId: 'tmpl-1'),
        newDate: DateTime(2026, 9, 1),
        scope: RecurrenceEditScope.onlyThis,
      );

      expect(repo.savedTask, isNotNull);
      expect(repo.updateTemplateParams, isNull);
      expect(result.plannedFor, DateTime(2026, 9, 1));
    });

    test('серия с scope all — updateTemplate с newStartDate', () async {
      final repo = _SpyTaskRepository();
      final uc = RescheduleTaskUseCase(repository: repo);

      // Нужен recurring с recurrence. Создаём через Task с templateId +
      // recurrenceStartDate, но recurrence обязателен для isRecurring.
      final recurringTask = Task(
        id: 'task-1',
        householdId: 'household-1',
        title: 'Задача',
        estimatedDurationMinutes: 30,
        plannedFor: DateTime.utc(2026, 8, 10),
        allowedMemberIds: const ['alice'],
        status: TaskStatus.pending,
        templateId: 'tmpl-1',
        recurrence: const TaskRecurrence.daily(),
        recurrenceStartDate: DateTime.utc(2026, 8, 1),
        createdAt: DateTime.utc(2026, 8, 1),
      );

      final result = await uc.call(
        task: recurringTask,
        newDate: DateTime(2026, 9, 1),
        scope: RecurrenceEditScope.all,
      );

      expect(repo.updateTemplateParams, isNotNull);
      expect(repo.updateTemplateParams!.scope, RecurrenceEditScope.all);
      expect(repo.updateTemplateParams!.newStartDate, DateTime(2026, 9, 1));
      expect(repo.savedTask, isNull);
      expect(result.plannedFor, DateTime(2026, 9, 1));
    });
  });
}
