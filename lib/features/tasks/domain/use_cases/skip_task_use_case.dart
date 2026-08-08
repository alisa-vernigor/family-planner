import '../entities/task.dart';
import '../entities/task_status.dart';
import '../repositories/task_repository.dart';

/// Пометить задачу как пропущенную (статус `skipped`).
///
/// «Пропустить» — как выполнить, но без назначения ответственного:
/// задача исчезает из списков (Today/Scheduled), но остаётся в истории.
/// Использует [TaskRepository.patchStatus] — 3 поля вместо save (11 полей).
final class SkipTaskUseCase {
  const SkipTaskUseCase({required this.repository});

  final TaskRepository repository;

  Future<Task> call({required Task task}) async {
    if (task.status == TaskStatus.skipped) {
      throw const TaskAlreadySkippedException();
    }

    await repository.patchStatus(
      taskId: task.id,
      status: TaskStatus.skipped.name,
      completedByMemberId: null,
      completedAt: null,
    );

    final skippedTask = task.patchStatus(status: TaskStatus.skipped);

    return skippedTask;
  }
}

final class TaskAlreadySkippedException implements Exception {
  const TaskAlreadySkippedException();

  @override
  String toString() {
    return 'TaskAlreadySkippedException: задача уже пропущена.';
  }
}
