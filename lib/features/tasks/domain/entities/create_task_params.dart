import 'package:equatable/equatable.dart';

import 'task_recurrence.dart';

final class CreateTaskParams extends Equatable {
  const CreateTaskParams({
    required this.householdId,
    required this.title,
    required this.estimatedDurationMinutes,
    required this.plannedFor,
    this.description,
    this.deadline,
    this.recurrence,
    this.recurrenceStartDate,
    this.recurrenceEndDate,
  });

  final String householdId;
  final String title;
  final String? description;
  final int estimatedDurationMinutes;
  final DateTime plannedFor;
  final DateTime? deadline;

  /// `null` означает обычную одноразовую задачу.
  final TaskRecurrence? recurrence;

  /// Необязательная дата, с которой начинается повторение.
  /// Если null, используется plannedFor.
  final DateTime? recurrenceStartDate;

  /// Необязательная дата, после которой повторы больше не создаются.
  final DateTime? recurrenceEndDate;

  bool get isRecurring => recurrence != null;

  @override
  List<Object?> get props => [
    householdId,
    title,
    description,
    estimatedDurationMinutes,
    plannedFor,
    deadline,
    recurrence,
    recurrenceStartDate,
    recurrenceEndDate,
  ];
}
