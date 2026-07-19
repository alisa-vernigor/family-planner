import '../entities/create_task_params.dart';
import '../entities/task.dart';

abstract interface class TaskRepository {
  Future<List<Task>> getForDay({
    required String householdId,
    required DateTime day,
  });

  Future<List<Task>> getScheduledAfter({
    required String householdId,
    required DateTime day,
  });

  Future<Task> create({required CreateTaskParams params});

  Future<void> save(Task task);

  Future<void> delete({required String taskId});
}
