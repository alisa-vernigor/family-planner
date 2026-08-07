import '../entities/create_task_params.dart';
import '../entities/task.dart';
import '../entities/update_recurring_task_params.dart';

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

  /// Обновляет повторяющуюся задачу (шаблон серии + экземпляры)
  /// с учётом выбранной области применения (только эта / эта и последующие / все).
  Future<void> updateTemplate({
    required UpdateRecurringTaskParams params,
  });

  /// Быстрая смена статуса (complete/uncomplete).
  /// Отправляет 3 поля вместо 11 — для самого частого действия.
  Future<void> patchStatus({
    required String taskId,
    required String status,
    String? completedByMemberId,
    String? completedAt,
    String? assignedMemberId,
  });

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
