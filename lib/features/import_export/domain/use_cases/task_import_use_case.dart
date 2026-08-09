import 'dart:convert';

import 'package:family_planner/core/logging/app_logger.dart';
import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/households/domain/repositories/household_repository.dart';
import 'package:family_planner/features/import_export/domain/entities/task_import_result.dart';
import 'package:family_planner/features/import_export/domain/entities/task_transfer_file.dart';
import 'package:family_planner/features/tasks/domain/entities/create_task_category_params.dart';
import 'package:family_planner/features/tasks/domain/entities/create_task_params.dart';
import 'package:family_planner/features/tasks/domain/entities/create_task_subtask_params.dart';
import 'package:family_planner/features/tasks/domain/entities/task_category.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_category_repository.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_subtask_repository.dart';
import 'package:family_planner/features/tasks/domain/use_cases/create_task_use_case.dart';

/// Выполняет импорт задач из JSON-строки в семью.
///
/// Требует подключения к интернету: задачи создаются напрямую через
/// `create_task_occurrence` RPC, что возвращает настоящий серверный id.
/// Только на его основе можно создавать подзадачи (в формате они привязаны
/// к задаче через `task_occurrence_id`). Если задача создаётся через
/// offline-очередь — серверный id будет сгенерирован на сервере позже,
/// и сопоставить его с локальным id невозможно (нет id-mapping).
///
/// Поэтому импорт работает онлайн. Офлайн — выбрасывает [TaskImportOfflineException].
final class TaskImportUseCase {
  TaskImportUseCase({
    required this.taskRepository,
    required this.taskCategoryRepository,
    required this.taskSubtaskRepository,
    required this.householdRepository,
    required this.isOnline,
  });

  final TaskRepository taskRepository;
  final TaskCategoryRepository taskCategoryRepository;
  final TaskSubtaskRepository taskSubtaskRepository;
  final HouseholdRepository householdRepository;

  /// Текущее состояние сети. Импорт требует онлайн (см. доку-комментарий).
  final bool Function() isOnline;

  /// Парсит и импортирует JSON-строку в семью.
  ///
  /// Возвращает [TaskImportResult] с количеством импортированных/пропущенных
  /// задач и ошибками. Каждая задача импортируется независимо: ошибка одной
  /// не прерывает остальные.
  Future<TaskImportResult> import({
    required String jsonString,
    required String householdId,
  }) async {
    if (!isOnline()) {
      throw const TaskImportOfflineException();
    }

    TaskTransferFile file;
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Корень JSON должен быть объектом.');
      }
      file = TaskTransferFile.fromJson(decoded);
    } on FormatException catch (e) {
      throw TaskImportFormatException(e.message);
    }

    if (file.tasks.isEmpty) {
      return const TaskImportResult();
    }

    // Резолвим участников и категории один раз (для всего импорта).
    final members = await householdRepository.getMembers(
      householdId: householdId,
    );
    final memberByName = {
      for (final m in members) m.displayName.trim().toLowerCase(): m,
    };
    var categories = await _loadCategories(householdId);

    var imported = 0;
    var skipped = 0;
    final errors = <String>[];

    for (final item in file.tasks) {
      try {
        // Категория по имени: если её нет в семье — создаём (онлайн).
        if (item.category != null && item.category!.isNotEmpty) {
          final key = item.category!.trim().toLowerCase();
          if (!categories.containsKey(key)) {
            final created = await taskCategoryRepository.create(
              CreateTaskCategoryParams(
                householdId: householdId,
                name: item.category!.trim(),
              ),
            );
            categories = {...categories, key: created};
          }
        }

        final params = _buildParams(
          item: item,
          householdId: householdId,
          memberByName: memberByName,
          categoriesById: categories,
        );

        // Валидация через существующий use case (title, duration, recurrence).
        final validated = validateCreateTaskParams(params);

        // Создаём задачу напрямую через repository (онлайн → RPC возвращает id).
        final task = await taskRepository.create(params: validated);

        // Подзадачи привязываются к серверному id задачи.
        await _createSubtasks(task.id, item.subtasks);

        imported++;
      } catch (e, st) {
        skipped++;
        final title = item.title.isEmpty ? '(без названия)' : item.title;
        errors.add('«$title»: $e');
        AppLogger.error(
          'Импорт задачи не удался: $title',
          error: e,
          stackTrace: st,
        );
      }
    }

    AppLogger.info(
      'Импорт завершён: imported=$imported; skipped=$skipped; '
      'errors=${errors.length}',
    );

    return TaskImportResult(
      imported: imported,
      skipped: skipped,
      errors: errors,
    );
  }

  Future<Map<String, TaskCategory>> _loadCategories(
    String householdId,
  ) async {
    try {
      final list = await taskCategoryRepository.getForHousehold(householdId);
      return {for (final c in list) c.name.trim().toLowerCase(): c};
    } catch (e) {
      AppLogger.warning('Не удалось загрузить категории для импорта: $e');
      return {};
    }
  }

  Future<void> _createSubtasks(String taskId, List<String> subtasks) async {
    for (final subtask in subtasks) {
      try {
        await taskSubtaskRepository.create(
          CreateTaskSubtaskParams(taskId: taskId, title: subtask),
        );
      } catch (e, st) {
        AppLogger.warning(
          'Подзадача «$subtask» не создана для задачи $taskId: $e',
        );
        AppLogger.error(
          'Ошибка создания подзадачи',
          error: e,
          stackTrace: st,
        );
      }
    }
  }

  CreateTaskParams _buildParams({
    required TaskTransferItem item,
    required String householdId,
    required Map<String, HouseholdMember> memberByName,
    required Map<String, TaskCategory> categoriesById,
  }) {
    final today = DateTime.now();

    return CreateTaskParams(
      householdId: householdId,
      title: item.title,
      description: item.description,
      estimatedDurationMinutes: item.durationMinutes,
      plannedFor: item.date ?? today,
      plannedTime: item.time,
      deadline: item.deadline,
      priority: item.priority,
      assignedMemberId: _resolveMemberId(item.assignee, memberByName),
      categoryId: _resolveCategoryId(item.category, categoriesById),
    );
  }

  String? _resolveMemberId(
    String? assignee,
    Map<String, HouseholdMember> memberByName,
  ) {
    if (assignee == null || assignee.isEmpty) return null;
    return memberByName[assignee.trim().toLowerCase()]?.profileId;
  }

  String? _resolveCategoryId(
    String? categoryName,
    Map<String, TaskCategory> categoriesById,
  ) {
    if (categoryName == null || categoryName.isEmpty) return null;
    final existing = categoriesById[categoryName.trim().toLowerCase()];
    if (existing != null) return existing.id;
    return null;
  }
}

/// Импорт возможен только онлайн (см. доку-комментарий [TaskImportUseCase]).
final class TaskImportOfflineException implements Exception {
  const TaskImportOfflineException();

  @override
  String toString() => 'Импорт задач работает только при подключении к '
      'интернету. Подключитесь и попробуйте ещё раз.';
}

/// Ошибка парсинга/структуры JSON.
final class TaskImportFormatException implements Exception {
  const TaskImportFormatException(this.message);

  final String message;

  @override
  String toString() => 'Не удалось разобрать JSON: $message';
}
