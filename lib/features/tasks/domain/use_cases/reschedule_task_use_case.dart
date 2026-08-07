import '../entities/task.dart';
import '../entities/update_recurring_task_params.dart';
import '../repositories/task_repository.dart';

/// Переносит задачу на новую дату/время.
///
/// - Обычная задача → меняется `plannedFor` (+ опционально время дедлайна).
/// - Повторяющаяся задача → использует область [scope] (как в Google Calendar):
///   переносит серию целиком через `updateTemplate` с `newStartDate`,
///   либо переносит только этот экземпляр через `save`.
final class RescheduleTaskUseCase {
  const RescheduleTaskUseCase({required this.repository});

  final TaskRepository repository;

  /// Переносит задачу на [newDate]. Для повторяющейся задачи [scope]
  /// определяет область: только эта / эта и последующие / все.
  ///
  /// Возвращает обновлённую задачу.
  Future<Task> call({
    required Task task,
    required DateTime newDate,
    RecurrenceEditScope? scope,
  }) async {
    // Новая дата только для планирования (без времени).
    final newPlannedFor = DateTime(newDate.year, newDate.month, newDate.day);

    // Для серии «только этот экземпляр» и для обычных задач — обычный save.
    if (!task.isRecurring || scope == null || scope == RecurrenceEditScope.onlyThis) {
      final updated = task.copyWith(plannedFor: newPlannedFor);
      await repository.save(updated);
      return updated;
    }

    // Перенос серии целиком (все экземпляры) — сдвигаем шаблон на новую дату.
    final updated = task.copyWith(plannedFor: newPlannedFor);
    await repository.updateTemplate(
      params: UpdateRecurringTaskParams(
        task: updated,
        recurrence: task.recurrence!,
        scope: RecurrenceEditScope.all,
        recurrenceStartDate: task.recurrenceStartDate,
        recurrenceEndDate: task.recurrenceEndDate,
        newStartDate: newPlannedFor,
      ),
    );
    return updated;
  }
}
