import '../entities/eisenhower_priority.dart';
import '../entities/task.dart';
import '../repositories/task_repository.dart';

/// Меняет приоритет задачи (матрица Эйзенхауэра).
final class UpdateTaskPriorityUseCase {
  const UpdateTaskPriorityUseCase({required this.repository});

  final TaskRepository repository;

  Future<Task> call({required Task task, required EisenhowerPriority newPriority}) async {
    if (task.priority == newPriority) return task;

    final updated = task.withPriority(newPriority);
    await repository.save(updated);
    return updated;
  }
}
