import '../entities/task.dart';
import '../entities/task_status.dart';
import '../repositories/task_repository.dart';

final class CompleteTaskUseCase {
  const CompleteTaskUseCase({required this.repository, required this.now});

  final TaskRepository repository;
  final DateTime Function() now;

  Future<Task> call({required Task task, required String memberId}) async {
    if (task.isCompleted) {
      throw const TaskAlreadyCompletedException();
    }

    if (!task.canBeCompletedBy(memberId)) {
      throw TaskCompletionNotAllowedException(
        taskId: task.id,
        memberId: memberId,
      );
    }

    final completedTask = task.copyWith(
      assignedMemberId: memberId,
      status: TaskStatus.completed,
      completedAt: now(),
    );

    await repository.save(completedTask);

    return completedTask;
  }
}

final class TaskAlreadyCompletedException implements Exception {
  const TaskAlreadyCompletedException();

  @override
  String toString() {
    return 'TaskAlreadyCompletedException: задача уже выполнена.';
  }
}

final class TaskCompletionNotAllowedException implements Exception {
  const TaskCompletionNotAllowedException({
    required this.taskId,
    required this.memberId,
  });

  final String taskId;
  final String memberId;

  @override
  String toString() {
    return 'TaskCompletionNotAllowedException: '
        'участник $memberId не может выполнить задачу $taskId.';
  }
}
