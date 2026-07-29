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

    // patchStatus — 3 поля вместо save (11 полей).
    // При отмене выполнения assigned_member_id не трогаем.
    await repository.patchStatus(
      taskId: task.id,
      status: TaskStatus.pending.name,
      completedByMemberId: null,
      completedAt: null,
    );

    final pendingTask = task.patchStatus(
      status: TaskStatus.pending,
      completedAt: null,
      assignedMemberId: null,
    );

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
