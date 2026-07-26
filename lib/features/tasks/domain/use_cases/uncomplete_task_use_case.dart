import '../entities/task.dart';
import '../entities/task_status.dart';
import '../repositories/task_repository.dart';

final class UncompleteTaskUseCase {
  const UncompleteTaskUseCase({required this.repository});

  final TaskRepository repository;

  Future<Task> call({required Task task}) async {
    if (!task.isCompleted) {
      throw const TaskNotCompletedException();
    }

    final pendingTask = task.copyWith(
      assignedMemberId: null,
      status: TaskStatus.pending,
      completedAt: null,
    );

    await repository.save(pendingTask);

    return pendingTask;
  }
}

final class TaskNotCompletedException implements Exception {
  const TaskNotCompletedException();

  @override
  String toString() {
    return 'TaskNotCompletedException: задача ещё не выполнена.';
  }
}
