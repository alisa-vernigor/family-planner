import 'package:flutter/material.dart';

import '../entities/task.dart';

final class TaskSchedule {
  const TaskSchedule._();

  static List<Task> forDay({required List<Task> tasks, required DateTime day}) {
    return tasks
        .where((task) => DateUtils.isSameDay(task.plannedFor, day))
        .toList();
  }

  static List<Task> scheduledAfter({
    required List<Task> tasks,
    required DateTime day,
  }) {
    final startOfTomorrow = DateTime(day.year, day.month, day.day + 1);

    final scheduledTasks =
        tasks
            .where((task) => !task.plannedFor.isBefore(startOfTomorrow))
            .toList()
          ..sort((first, second) {
            return first.plannedFor.compareTo(second.plannedFor);
          });

    return scheduledTasks;
  }

  static List<Task> overdueBefore({
    required List<Task> tasks,
    required DateTime day,
  }) {
    final startOfDay = DateTime(day.year, day.month, day.day);

    return tasks.where((task) => task.plannedFor.isBefore(startOfDay)).toList();
  }
}
