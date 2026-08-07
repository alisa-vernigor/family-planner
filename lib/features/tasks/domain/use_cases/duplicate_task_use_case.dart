import '../entities/create_task_params.dart';
import '../entities/task.dart';
import '../repositories/task_repository.dart';

/// Дублирует задачу (или повторяющуюся серию).
///
/// Создаёт копию через [TaskRepository.create]:
/// - одноразовая задача → копия на следующий день, статус pending,
///   без ответственного/закрепления;
/// - повторяющаяся задача → новая серия с тем же расписанием,
///   экземпляры с сегодняшнего дня.
final class DuplicateTaskUseCase {
  const DuplicateTaskUseCase({required this.repository});

  final TaskRepository repository;

  Future<Task> call({required Task task}) async {
    final now = DateTime.now();

    return repository.create(
      params: CreateTaskParams(
        householdId: task.householdId,
        title: task.title,
        description: task.description,
        estimatedDurationMinutes: task.estimatedDurationMinutes,
        plannedFor: task.isRecurring
            ? task.plannedFor
            : DateTime(now.year, now.month, now.day)
                .add(const Duration(days: 1)),
        deadline: task.deadline,
        priority: task.priority,
        recurrence: task.recurrence,
        recurrenceStartDate: task.isRecurring
            ? task.recurrenceStartDate ?? task.plannedFor
            : null,
        recurrenceEndDate: task.recurrenceEndDate,
      ),
    );
  }
}
