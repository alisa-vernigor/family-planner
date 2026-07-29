import '../entities/task.dart';
import '../repositories/task_repository.dart';

/// Снимает закрепление задачи (pinned).
final class UnpinTaskUseCase {
  const UnpinTaskUseCase({required this.repository});

  final TaskRepository repository;

  Future<Task> call({required Task task}) async {
    final updated = task.unpin();
    await repository.save(updated);
    return updated;
  }
}
