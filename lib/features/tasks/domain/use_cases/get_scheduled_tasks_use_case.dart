import '../entities/task.dart';
import '../repositories/task_repository.dart';

final class GetScheduledTasksUseCase {
  const GetScheduledTasksUseCase({required this.repository});

  final TaskRepository repository;

  Future<List<Task>> call({
    required String householdId,
    required DateTime day,
  }) {
    return repository.getScheduledAfter(householdId: householdId, day: day);
  }
}
