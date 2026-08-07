import 'package:equatable/equatable.dart';

import 'eisenhower_priority.dart';
import 'task_recurrence.dart';
import 'task_status.dart';

final class Task extends Equatable {
  const Task({
    required this.id,
    required this.householdId,
    required this.title,
    required this.estimatedDurationMinutes,
    required this.plannedFor,
    required this.allowedMemberIds,
    required this.status,
    required this.createdAt,
    this.description,
    this.assignedMemberId,
    this.pinnedMemberId,
    this.deadline,
    this.completedAt,
    this.updatedAt,
    this.priority,
    this.templateId,
    this.recurrence,
    this.recurrenceStartDate,
    this.recurrenceEndDate,
    this.reminderMinutesBefore,
    this.categoryId,
  });

  final String id;
  final String householdId;
  final String title;
  final String? description;
  final int estimatedDurationMinutes;
  final DateTime plannedFor;
  final DateTime? deadline;
  final List<String> allowedMemberIds;
  final String? assignedMemberId;
  final String? pinnedMemberId;
  final TaskStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? updatedAt;
  final EisenhowerPriority? priority;

  /// ID шаблона серии повторяющейся задачи.
  /// `null` — обычная одноразовая задача.
  final String? templateId;

  /// Расписание повторения (если задача из серии).
  final TaskRecurrence? recurrence;

  /// Дата начала повторения (из шаблона).
  final DateTime? recurrenceStartDate;

  /// Дата окончания повторения (из шаблона), `null` — бессрочно.
  final DateTime? recurrenceEndDate;

  /// За сколько минут до дедлайна/начала прислать напоминание.
  /// `null` — напоминание не настроено.
  final int? reminderMinutesBefore;

  /// ID категории задачи (`task_categories.id`). `null` — без категории.
  final String? categoryId;

  bool get isRecurring => templateId != null && recurrence != null;

  bool get isCompleted => status == TaskStatus.completed;

  bool get isPinned => pinnedMemberId != null;

  /// Снимает назначение с задачи.
  Task unpin() => copyWith(pinnedMemberId: null);

  /// Меняет приоритет.
  Task withPriority(EisenhowerPriority? priority) => copyWith(priority: priority);

  /// Назначает ответственного (null — снять назначение).
  Task assignTo(String? memberId) => copyWith(assignedMemberId: memberId);

  /// Быстрая смена статуса — для complete/uncomplete/delete операций.
  /// Заменяет [copyWith] для 3 самых частых полей без sentinel-шума.
  Task patchStatus({
    TaskStatus? status,
    DateTime? completedAt,
    String? assignedMemberId,
  }) {
    return copyWith(
      status: status,
      completedAt: completedAt,
      assignedMemberId: assignedMemberId,
    );
  }

  bool canBeCompletedBy(String memberId) {
    return allowedMemberIds.contains(memberId);
  }

  /// Приоритет по умолчанию для задач без приоритета (4 — не срочно и не важно).
  EisenhowerPriority get effectivePriority => priority ?? EisenhowerPriority.notUrgentNotImportant;

  Task copyWith({
    String? id,
    String? householdId,
    String? title,
    Object? description = _sentinel,
    int? estimatedDurationMinutes,
    DateTime? plannedFor,
    Object? deadline = _sentinel,
    List<String>? allowedMemberIds,
    Object? assignedMemberId = _sentinel,
    Object? pinnedMemberId = _sentinel,
    TaskStatus? status,
    DateTime? createdAt,
    Object? completedAt = _sentinel,
    Object? priority = _sentinel,
    Object? templateId = _sentinel,
    Object? recurrence = _sentinel,
    Object? recurrenceStartDate = _sentinel,
    Object? recurrenceEndDate = _sentinel,
    Object? reminderMinutesBefore = _sentinel,
    Object? categoryId = _sentinel,
  }) {
    return Task(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      title: title ?? this.title,
      description: identical(description, _sentinel) ? this.description : description as String?,
      estimatedDurationMinutes:
          estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      plannedFor: plannedFor ?? this.plannedFor,
      deadline: identical(deadline, _sentinel) ? this.deadline : deadline as DateTime?,
      allowedMemberIds: allowedMemberIds ?? this.allowedMemberIds,
      assignedMemberId: identical(assignedMemberId, _sentinel)
          ? this.assignedMemberId
          : assignedMemberId as String?,
      pinnedMemberId: identical(pinnedMemberId, _sentinel)
          ? this.pinnedMemberId
          : pinnedMemberId as String?,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      completedAt: identical(completedAt, _sentinel) ? this.completedAt : completedAt as DateTime?,
      updatedAt: updatedAt,
      priority: identical(priority, _sentinel) ? this.priority : priority as EisenhowerPriority?,
      templateId: identical(templateId, _sentinel)
          ? this.templateId
          : templateId as String?,
      recurrence: identical(recurrence, _sentinel)
          ? this.recurrence
          : recurrence as TaskRecurrence?,
      recurrenceStartDate: identical(recurrenceStartDate, _sentinel)
          ? this.recurrenceStartDate
          : recurrenceStartDate as DateTime?,
      recurrenceEndDate: identical(recurrenceEndDate, _sentinel)
          ? this.recurrenceEndDate
          : recurrenceEndDate as DateTime?,
      reminderMinutesBefore: identical(reminderMinutesBefore, _sentinel)
          ? this.reminderMinutesBefore
          : reminderMinutesBefore as int?,
      categoryId: identical(categoryId, _sentinel)
          ? this.categoryId
          : categoryId as String?,
    );
  }

  static const _sentinel = _Sentinel();

  @override
  List<Object?> get props {
    return [
      id,
      householdId,
      title,
      description,
      estimatedDurationMinutes,
      plannedFor,
      deadline,
      allowedMemberIds,
      assignedMemberId,
      pinnedMemberId,
      status,
      createdAt,
      completedAt,
      updatedAt,
      priority,
      templateId,
      recurrence,
      recurrenceStartDate,
      recurrenceEndDate,
      reminderMinutesBefore,
      categoryId,
    ];
  }
}

final class _Sentinel {
  const _Sentinel();
}
