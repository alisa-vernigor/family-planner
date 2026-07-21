import '../entities/create_task_params.dart';
import '../entities/task.dart';
import '../entities/task_recurrence.dart';
import '../repositories/task_repository.dart';

final class CreateTaskUseCase {
  const CreateTaskUseCase({required this.repository});

  final TaskRepository repository;

  Future<Task> call({required CreateTaskParams params}) {
    final title = params.title.trim();

    if (title.isEmpty) {
      throw const TaskTitleEmptyException();
    }

    if (params.estimatedDurationMinutes <= 0) {
      throw const TaskDurationInvalidException();
    }

    _validateRecurrence(params.recurrence);

    _validateRecurrenceDates(
      recurrence: params.recurrence,
      startDate: params.recurrenceStartDate ?? params.plannedFor,
      endDate: params.recurrenceEndDate,
    );

    return repository.create(
      params: CreateTaskParams(
        householdId: params.householdId,
        title: title,
        description: params.description?.trim(),
        estimatedDurationMinutes: params.estimatedDurationMinutes,
        plannedFor: params.plannedFor,
        deadline: params.deadline,
        recurrence: params.recurrence,
        recurrenceStartDate: params.recurrenceStartDate,
        recurrenceEndDate: params.recurrenceEndDate,
      ),
    );
  }

  void _validateRecurrence(TaskRecurrence? recurrence) {
    if (recurrence == null) {
      return;
    }

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
  }

  void _validateRecurrenceDates({
    required TaskRecurrence? recurrence,
    required DateTime startDate,
    required DateTime? endDate,
  }) {
    if (recurrence == null || endDate == null) {
      return;
    }

    final startDateOnly = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );
    final endDateOnly = DateTime(endDate.year, endDate.month, endDate.day);

    if (endDateOnly.isBefore(startDateOnly)) {
      throw const TaskRecurrenceDatesInvalidException();
    }
  }
}

final class TaskTitleEmptyException implements Exception {
  const TaskTitleEmptyException();

  @override
  String toString() {
    return 'TaskTitleEmptyException: название задачи не может быть пустым.';
  }
}

final class TaskDurationInvalidException implements Exception {
  const TaskDurationInvalidException();

  @override
  String toString() {
    return 'TaskDurationInvalidException: длительность должна быть больше нуля.';
  }
}

final class TaskRecurrenceWeekdaysEmptyException implements Exception {
  const TaskRecurrenceWeekdaysEmptyException();

  @override
  String toString() {
    return 'TaskRecurrenceWeekdaysEmptyException: выберите дни недели.';
  }
}

final class TaskRecurrenceWeekdaysInvalidException implements Exception {
  const TaskRecurrenceWeekdaysInvalidException();

  @override
  String toString() {
    return 'TaskRecurrenceWeekdaysInvalidException: дни недели должны быть от 1 до 7.';
  }
}

final class TaskRecurrenceIntervalInvalidException implements Exception {
  const TaskRecurrenceIntervalInvalidException();

  @override
  String toString() {
    return 'TaskRecurrenceIntervalInvalidException: интервал должен быть больше нуля.';
  }
}

final class TaskRecurrenceDatesInvalidException implements Exception {
  const TaskRecurrenceDatesInvalidException();

  @override
  String toString() {
    return 'TaskRecurrenceDatesInvalidException: '
        'дата окончания не может быть раньше даты начала.';
  }
}
