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

    final completedAt = now();

    // patchStatus — 3 поля вместо save (11 полей)
    await repository.patchStatus(
      taskId: task.id,
      status: TaskStatus.completed.name,
      completedByMemberId: memberId,
      completedAt: completedAt.toUtc().toIso8601String(),
      assignedMemberId: memberId,
    );

    final completedTask = task.patchStatus(
      status: TaskStatus.completed,
      completedAt: completedAt,
      assignedMemberId: memberId,
    );

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
