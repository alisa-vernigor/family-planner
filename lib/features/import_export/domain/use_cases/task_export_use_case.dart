import 'package:family_planner/core/logging/app_logger.dart';
import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/households/domain/repositories/household_repository.dart';
import 'package:family_planner/features/import_export/domain/entities/task_transfer_file.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_category.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_category_repository.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_subtask_repository.dart';

/// Экспортирует задачи семьи в JSON (формат [TaskTransferFile]).
///
/// Экспортируются невыполненные задачи (`getAllPending` — как в списке
/// «Запланированные»). Внутренние id в JSON не попадают: категория — по имени,
/// ответственный — по имени участника. Поэтому файл можно переимпортировать
/// в другую семью/аккаунт.
final class TaskExportUseCase {
  TaskExportUseCase({
    required this.taskRepository,
    required this.taskCategoryRepository,
    required this.taskSubtaskRepository,
    required this.householdRepository,
  });

  final TaskRepository taskRepository;
  final TaskCategoryRepository taskCategoryRepository;
  final TaskSubtaskRepository taskSubtaskRepository;
  final HouseholdRepository householdRepository;

  /// Собирает и сериализует задачи семьи в JSON-строку.
  Future<String> export({required String householdId}) async {
    final tasksFuture = taskRepository.getAllPending(
      householdId: householdId,
    );
    final membersFuture = householdRepository.getMembers(
      householdId: householdId,
    );
    final categoriesFuture = taskCategoryRepository.getForHousehold(
      householdId,
    );

    final results = await Future.wait<Object>([
      tasksFuture,
      membersFuture,
      categoriesFuture,
    ]);

    final tasks = results[0] as List<Task>;
    final members = results[1] as List<HouseholdMember>;
    final categories = results[2] as List<TaskCategory>;

    final memberNameById = {
      for (final m in members) m.profileId: m.displayName,
    };
    final categoryNameById = {
      for (final c in categories) c.id: c.name,
    };

    final items = <TaskTransferItem>[];
    for (final task in tasks) {
      final subtasks = await _subtasksFor(task.id);
      items.add(_toTransferItem(
        task: task,
        memberNameById: memberNameById,
        categoryNameById: categoryNameById,
        subtasks: subtasks,
      ));
    }

    AppLogger.info(
      'Экспорт задач: householdId=$householdId; count=${items.length}',
    );

    return TaskTransferFile(tasks: items).toJsonString();
  }

  Future<List<String>> _subtasksFor(String taskId) async {
    try {
      final list = await taskSubtaskRepository.getForTask(taskId);
      return list.map((s) => s.title).toList(growable: false);
    } catch (e) {
      AppLogger.warning('Не удалось загрузить подзадачи для $taskId: $e');
      return const [];
    }
  }

  TaskTransferItem _toTransferItem({
    required Task task,
    required Map<String, String> memberNameById,
    required Map<String, String> categoryNameById,
    required List<String> subtasks,
  }) {
    return TaskTransferItem(
      title: task.title,
      description: task.description,
      date: task.plannedFor,
      time: task.plannedTime,
      deadline: task.deadline,
      durationMinutes: task.estimatedDurationMinutes,
      priority: task.priority,
      assignee: task.assignedMemberId == null
          ? null
          : memberNameById[task.assignedMemberId],
      category: task.categoryId == null
          ? null
          : categoryNameById[task.categoryId],
      subtasks: subtasks,
    );
  }
}
