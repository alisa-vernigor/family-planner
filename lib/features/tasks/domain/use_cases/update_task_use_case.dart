import '../entities/task.dart';
import '../entities/task_recurrence.dart';
import '../entities/update_recurring_task_params.dart';
import '../repositories/task_repository.dart';
import 'create_task_use_case.dart';

final class UpdateTaskUseCase {
  const UpdateTaskUseCase({required this.repository});

  final TaskRepository repository;

  Future<void> call({required Task task}) async {
    final title = task.title.trim();

    if (title.isEmpty) {
      throw ArgumentError.value(
        task.title,
        'task.title',
        'Название задачи не может быть пустым.',
      );
    }

    if (task.estimatedDurationMinutes <= 0) {
      throw ArgumentError.value(
        task.estimatedDurationMinutes,
        'task.estimatedDurationMinutes',
        'Длительность должна быть больше нуля.',
      );
    }

    await repository.save(
      task.copyWith(
        title: title,
        description: task.description?.trim().isEmpty ?? true
            ? null
            : task.description?.trim(),
      ),
    );
  }

  /// Обновляет повторяющуюся задачу (шаблон + экземпляры)
  /// с учётом области применения [params.scope].
  Future<void> updateRecurring({
    required UpdateRecurringTaskParams params,
  }) async {
    final task = params.task;

    if (task.title.trim().isEmpty) {
      throw ArgumentError.value(
        task.title,
        'task.title',
        'Название задачи не может быть пустым.',
      );
    }

    if (task.estimatedDurationMinutes <= 0) {
      throw ArgumentError.value(
        task.estimatedDurationMinutes,
        'task.estimatedDurationMinutes',
        'Длительность должна быть больше нуля.',
      );
    }

    final recurrence = params.recurrence;
    if (recurrence.type == TaskRecurrenceType.weekly &&
        recurrence.weekdays.isEmpty) {
      throw const TaskRecurrenceWeekdaysEmptyException();
    }

    if (recurrence.type == TaskRecurrenceType.weekly &&
        recurrence.weekdays.any((day) => day < 1 || day > 7)) {
      throw const TaskRecurrenceWeekdaysInvalidException();
    }

    if (recurrence.type == TaskRecurrenceType.intervalDays &&
        (recurrence.intervalDays == null || recurrence.intervalDays! <= 0)) {
      throw const TaskRecurrenceIntervalInvalidException();
    }

    final start = params.recurrenceStartDate;
    final end = params.recurrenceEndDate;
    if (start != null && end != null) {
      final startOnly = DateTime(start.year, start.month, start.day);
      final endOnly = DateTime(end.year, end.month, end.day);
      if (endOnly.isBefore(startOnly)) {
        throw const TaskRecurrenceDatesInvalidException();
      }
    }

    await repository.updateTemplate(
      params: params.copyWith(
        task: task.copyWith(title: task.title.trim()),
      ),
    );
  }
}
