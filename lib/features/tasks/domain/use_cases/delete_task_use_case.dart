import '../repositories/task_repository.dart';

final class DeleteTaskUseCase {
  const DeleteTaskUseCase({required this.repository});

  final TaskRepository repository;

  Future<void> call({required String taskId}) {
    return repository.delete(taskId: taskId);
  }
}
