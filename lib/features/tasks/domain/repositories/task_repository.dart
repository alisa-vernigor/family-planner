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

  /// Все невыполненные задачи домохозяйства (на сегодня, на будущее, просроченные).
  Future<List<Task>> getAllPending({
    required String householdId,
  });

  Future<Task> create({required CreateTaskParams params});

  Future<void> save(Task task);

  Future<void> delete({required String taskId});

  Future<void> addAllowedMember({
    required String taskId,
    required String memberId,
  });

  Future<void> removeAllowedMember({
    required String taskId,
    required String memberId,
  });
}
