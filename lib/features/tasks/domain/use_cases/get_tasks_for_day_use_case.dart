import '../entities/task.dart';
import '../repositories/task_repository.dart';

final class GetTasksForDayUseCase {
  const GetTasksForDayUseCase({required this.repository});

  final TaskRepository repository;

  Future<List<Task>> call({
    required String householdId,
    required DateTime day,
  }) {
    return repository.getForDay(householdId: householdId, day: day);
  }
}
