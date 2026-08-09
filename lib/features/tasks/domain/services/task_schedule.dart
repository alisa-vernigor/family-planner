import 'package:flutter/material.dart';

import '../entities/task.dart';

abstract final class TaskSchedule {
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

  static List<Task> forDateRange({
    required List<Task> tasks,
    required DateTime start,
    required DateTime end,
  }) {
    return tasks
        .where((task) =>
            !task.plannedFor.isBefore(start) &&
            !task.plannedFor.isAfter(end))
        .toList();
  }
}
