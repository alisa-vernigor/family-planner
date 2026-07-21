import 'package:equatable/equatable.dart';

enum TaskRecurrenceType {
  daily,
  weekly,
  intervalDays;

  String get databaseValue {
    return switch (this) {
      TaskRecurrenceType.daily => 'daily',
      TaskRecurrenceType.weekly => 'weekly',
      TaskRecurrenceType.intervalDays => 'interval_days',
    };
  }
}

final class TaskRecurrence extends Equatable {
  const TaskRecurrence.daily()
    : type = TaskRecurrenceType.daily,
      intervalDays = null,
      weekdays = const [];

  const TaskRecurrence.weekly({required this.weekdays})
    : type = TaskRecurrenceType.weekly,
      intervalDays = null;

  const TaskRecurrence.intervalDays({required this.intervalDays})
    : type = TaskRecurrenceType.intervalDays,
      weekdays = const [];

  final TaskRecurrenceType type;
  final int? intervalDays;

  /// ISO-дни недели: 1 — понедельник, 7 — воскресенье.
  final List<int> weekdays;

  @override
  List<Object?> get props => [type, intervalDays, weekdays];
}
