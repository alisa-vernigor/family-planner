import 'package:equatable/equatable.dart';

import 'eisenhower_priority.dart';
import 'task_recurrence.dart';

final class CreateTaskParams extends Equatable {
  const CreateTaskParams({
    required this.householdId,
    required this.title,
    required this.estimatedDurationMinutes,
    required this.plannedFor,
    this.description,
    this.deadline,
    this.assignedMemberId,
    this.pinnedMemberId,
    this.recurrence,
    this.recurrenceStartDate,
    this.recurrenceEndDate,
    this.priority,
    this.reminderMinutesBefore,
    this.categoryId,
  });

  final String householdId;
  final String title;
  final String? description;
  final int estimatedDurationMinutes;
  final DateTime plannedFor;
  final DateTime? deadline;
  final String? assignedMemberId;
  final String? pinnedMemberId;
  final EisenhowerPriority? priority;

  /// `null` означает обычную одноразовую задачу.
  final TaskRecurrence? recurrence;

  /// Необязательная дата, с которой начинается повторение.
  /// Если null, используется plannedFor.
  final DateTime? recurrenceStartDate;

  /// Необязательная дата, после которой повторы больше не создаются.
  final DateTime? recurrenceEndDate;

  /// За сколько минут до дедлайна/начала прислать напоминание.
  /// `null` — без напоминания.
  final int? reminderMinutesBefore;

  /// ID категории задачи. `null` — без категории.
  final String? categoryId;

  bool get isRecurring => recurrence != null;

  @override
  List<Object?> get props => [
    householdId,
    title,
    description,
    estimatedDurationMinutes,
    plannedFor,
    deadline,
    assignedMemberId,
    pinnedMemberId,
    recurrence,
    recurrenceStartDate,
    recurrenceEndDate,
    priority,
    reminderMinutesBefore,
    categoryId,
  ];
}
