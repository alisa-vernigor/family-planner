import '../entities/task.dart';
import '../repositories/task_repository.dart';

final class GetAllPendingTasksUseCase {
  const GetAllPendingTasksUseCase({required this.repository});

  final TaskRepository repository;

  Future<List<Task>> call({
    required String householdId,
  }) {
    return repository.getAllPending(householdId: householdId);
  }
}
