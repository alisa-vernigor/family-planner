import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/tasks/domain/entities/eisenhower_priority.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_recurrence.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';

void main() {
  group('Task', () {
    final createdAt = DateTime.utc(2026, 7, 19, 12);
    final plannedFor = DateTime.utc(2026, 7, 20);

    Task createTask({
      String? assignedMemberId,
      String? pinnedMemberId,
      TaskStatus status = TaskStatus.pending,
      DateTime? completedAt,
      Duration? plannedTime,
      EisenhowerPriority? priority,
      String? templateId,
      TaskRecurrence? recurrence,
      bool? templateActive,
      String? categoryId,
      String? description,
      DateTime? deadline,
    }) {
      return Task(
        id: 'task-1',
        householdId: 'household-1',
        title: 'Вынести мусор',
        description: description ?? 'Пакеты стоят у входной двери',
        estimatedDurationMinutes: 10,
        plannedFor: plannedFor,
        deadline: deadline,
        allowedMemberIds: const ['member-1', 'member-2'],
        assignedMemberId: assignedMemberId,
        pinnedMemberId: pinnedMemberId,
        status: status,
        createdAt: createdAt,
        completedAt: completedAt,
        priority: priority,
        templateId: templateId,
        recurrence: recurrence,
        plannedTime: plannedTime,
        templateActive: templateActive,
        categoryId: categoryId,
      );
    }

    test('создаётся с обязательными полями', () {
      final task = createTask();

      expect(task.id, 'task-1');
      expect(task.householdId, 'household-1');
      expect(task.title, 'Вынести мусор');
      expect(task.estimatedDurationMinutes, 10);
      expect(task.plannedFor, plannedFor);
      expect(task.status, TaskStatus.pending);
      expect(task.isCompleted, isFalse);
    });

    test('считает задачу завершённой только при статусе completed', () {
      final pendingTask = createTask();
      final completedTask = createTask(
        assignedMemberId: 'member-1',
        status: TaskStatus.completed,
        completedAt: DateTime.utc(2026, 7, 20, 9, 15),
      );

      expect(pendingTask.isCompleted, isFalse);
      expect(completedTask.isCompleted, isTrue);
    });

    test('isSkipped — true только при статусе skipped', () {
      expect(createTask().isSkipped, isFalse);
      expect(createTask(status: TaskStatus.skipped).isSkipped, isTrue);
    });

    test('считает участника допустимым исполнителем', () {
      final task = createTask();

      expect(task.canBeCompletedBy('member-1'), isTrue);
      expect(task.canBeCompletedBy('member-2'), isTrue);
      expect(task.canBeCompletedBy('member-3'), isFalse);
    });

    test('создаёт изменённую копию и не меняет исходную задачу', () {
      final originalTask = createTask();
      final updatedTask = originalTask.copyWith(assignedMemberId: 'member-2');

      expect(originalTask.assignedMemberId, isNull);
      expect(updatedTask.assignedMemberId, 'member-2');
      expect(updatedTask.id, originalTask.id);
      expect(updatedTask.title, originalTask.title);
    });

    test('одинаковые задачи равны по значениям', () {
      final firstTask = createTask();
      final secondTask = createTask();

      expect(firstTask, secondTask);
    });

    test('isRecurring — true только когда есть и templateId, и recurrence', () {
      final plain = createTask();
      final onlyTemplate = createTask(templateId: 'tmpl-1');
      final onlyRecurrence = createTask(recurrence: const TaskRecurrence.daily());
      final full = createTask(
        templateId: 'tmpl-1',
        recurrence: const TaskRecurrence.daily(),
      );

      expect(plain.isRecurring, isFalse);
      expect(onlyTemplate.isRecurring, isFalse);
      expect(onlyRecurrence.isRecurring, isFalse);
      expect(full.isRecurring, isTrue);
    });

    test('isSeriesPaused — true только при templateActive == false', () {
      expect(createTask().isSeriesPaused, isFalse);
      expect(createTask(templateActive: true).isSeriesPaused, isFalse);
      expect(createTask(templateActive: false).isSeriesPaused, isTrue);
    });

    test('isPinned — true при наличии pinnedMemberId', () {
      expect(createTask().isPinned, isFalse);
      expect(createTask(pinnedMemberId: 'member-1').isPinned, isTrue);
    });

    group('plannedTimeLabel', () {
      test('null при отсутствии времени', () {
        expect(createTask(plannedTime: null).plannedTimeLabel, isNull);
      });

      test('форматирует HH:MM с нулями', () {
        expect(
          createTask(plannedTime: const Duration(hours: 9, minutes: 30))
              .plannedTimeLabel,
          '09:30',
        );
        expect(
          createTask(plannedTime: const Duration(hours: 9, minutes: 5))
              .plannedTimeLabel,
          '09:05',
        );
        expect(
          createTask(plannedTime: const Duration(minutes: 7))
              .plannedTimeLabel,
          '00:07',
        );
        expect(
          createTask(plannedTime: const Duration(hours: 23, minutes: 59))
              .plannedTimeLabel,
          '23:59',
        );
      });
    });

    test('effectivePriority — дефолтный приоритет, когда priority == null', () {
      expect(createTask().effectivePriority, EisenhowerPriority.notUrgentNotImportant);
      expect(
        createTask(priority: EisenhowerPriority.urgentImportant).effectivePriority,
        EisenhowerPriority.urgentImportant,
      );
    });

    test('unpin снимает закрепление', () {
      final task = createTask(pinnedMemberId: 'member-1');
      final unpinned = task.unpin();

      expect(unpinned.pinnedMemberId, isNull);
      expect(unpinned.id, task.id);
    });

    test('withPriority меняет приоритет', () {
      final task = createTask();
      final updated = task.withPriority(EisenhowerPriority.urgentNotImportant);

      expect(updated.priority, EisenhowerPriority.urgentNotImportant);
    });

    test('assignTo назначает ответственного', () {
      final task = createTask();
      final updated = task.assignTo('member-2');

      expect(updated.assignedMemberId, 'member-2');
      expect(task.assignedMemberId, isNull);
    });

    test('patchStatus меняет 3 самых частых поля', () {
      final completedAt = DateTime.utc(2026, 7, 20, 9);
      final task = createTask();
      final patched = task.patchStatus(
        status: TaskStatus.completed,
        completedAt: completedAt,
        assignedMemberId: 'member-1',
      );

      expect(patched.status, TaskStatus.completed);
      expect(patched.completedAt, completedAt);
      expect(patched.assignedMemberId, 'member-1');
      expect(patched.title, task.title);
    });

    group('copyWith sentinel-поведение', () {
      test('обнуляет nullable-поля при передаче null', () {
        final task = createTask(
          description: 'Описание',
          deadline: DateTime.utc(2026, 7, 25),
          assignedMemberId: 'member-1',
          pinnedMemberId: 'member-1',
          completedAt: DateTime.utc(2026, 7, 20, 9),
          priority: EisenhowerPriority.urgentImportant,
          templateId: 'tmpl-1',
          recurrence: const TaskRecurrence.daily(),
          categoryId: 'cat-1',
          plannedTime: const Duration(hours: 8),
          templateActive: false,
        );

        final cleared = task.copyWith(
          description: null,
          deadline: null,
          assignedMemberId: null,
          pinnedMemberId: null,
          completedAt: null,
          priority: null,
          templateId: null,
          recurrence: null,
          categoryId: null,
          plannedTime: null,
          templateActive: null,
        );

        expect(cleared.description, isNull);
        expect(cleared.deadline, isNull);
        expect(cleared.assignedMemberId, isNull);
        expect(cleared.pinnedMemberId, isNull);
        expect(cleared.completedAt, isNull);
        expect(cleared.priority, isNull);
        expect(cleared.templateId, isNull);
        expect(cleared.recurrence, isNull);
        expect(cleared.categoryId, isNull);
        expect(cleared.plannedTime, isNull);
        expect(cleared.templateActive, isNull);
      });

      test('сохраняет nullable-поля, если они не переданы', () {
        final recurrenceStart = DateTime.utc(2026, 7, 1);
        final recurrenceEnd = DateTime.utc(2026, 8, 1);
        final task = createTask(
          description: 'Описание',
          deadline: DateTime.utc(2026, 7, 25),
          priority: EisenhowerPriority.urgentImportant,
          templateId: 'tmpl-1',
          recurrence: const TaskRecurrence.daily(),
          templateActive: false,
        );
        final full = task.copyWith(
          recurrenceStartDate: recurrenceStart,
          recurrenceEndDate: recurrenceEnd,
          reminderMinutesBefore: 30,
        );

        expect(full.recurrenceStartDate, recurrenceStart);
        expect(full.recurrenceEndDate, recurrenceEnd);
        expect(full.reminderMinutesBefore, 30);

        final kept = full.copyWith(title: 'Новое название');
        expect(kept.description, 'Описание');
        expect(kept.deadline, DateTime.utc(2026, 7, 25));
        expect(kept.priority, EisenhowerPriority.urgentImportant);
        expect(kept.templateId, 'tmpl-1');
        expect(kept.recurrence, const TaskRecurrence.daily());
        expect(kept.templateActive, isFalse);
        expect(kept.recurrenceStartDate, recurrenceStart);
        expect(kept.recurrenceEndDate, recurrenceEnd);
        expect(kept.reminderMinutesBefore, 30);
      });
    });

    test('props содержит все поля', () {
      final recurrenceStart = DateTime.utc(2026, 7, 1);
      final recurrenceEnd = DateTime.utc(2026, 8, 1);
      final task = createTask(
        description: 'Описание',
        deadline: DateTime.utc(2026, 7, 25),
        assignedMemberId: 'member-1',
        pinnedMemberId: 'member-1',
        completedAt: DateTime.utc(2026, 7, 20, 9),
        priority: EisenhowerPriority.urgentImportant,
        templateId: 'tmpl-1',
        recurrence: const TaskRecurrence.daily(),
        categoryId: 'cat-1',
        plannedTime: const Duration(hours: 8),
        templateActive: false,
      );
      final full = task.copyWith(
        recurrenceStartDate: recurrenceStart,
        recurrenceEndDate: recurrenceEnd,
        reminderMinutesBefore: 30,
      );

      expect(full.props, [
        'task-1',
        'household-1',
        'Вынести мусор',
        'Описание',
        10,
        plannedFor,
        DateTime.utc(2026, 7, 25),
        ['member-1', 'member-2'],
        'member-1',
        'member-1',
        TaskStatus.pending,
        createdAt,
        DateTime.utc(2026, 7, 20, 9),
        null, // updatedAt
        EisenhowerPriority.urgentImportant,
        'tmpl-1',
        const TaskRecurrence.daily(),
        recurrenceStart,
        recurrenceEnd,
        30,
        'cat-1',
        const Duration(hours: 8),
        false,
      ]);
    });
  });
}
