import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:family_planner/core/database/app_database.dart';
import 'package:family_planner/core/database/daos/sync_queue_dao.dart';
import 'package:family_planner/core/database/daos/task_dao.dart';
import 'package:family_planner/core/database/daos/task_subtasks_dao.dart';
import 'package:family_planner/core/logging/app_logger.dart';
import 'package:family_planner/core/services/connectivity_service.dart';
import 'package:family_planner/features/tasks/domain/entities/create_task_subtask_params.dart';
import 'package:family_planner/features/tasks/domain/entities/task_subtask.dart'
    as domain;
import 'package:family_planner/features/tasks/domain/repositories/task_subtask_repository.dart';

/// Drift-backed [TaskSubtaskRepository] with offline-first support.
///
/// - **Reads** are served from the local SQLite; when online, fetches from
///   Supabase into the cache first.
/// - **Writes** update local DB immediately, then enqueue a sync operation
///   (`SUBTASK_CREATE` / `SUBTASK_UPDATE` / `SUBTASK_DELETE`).
class DriftTaskSubtaskRepository implements TaskSubtaskRepository {
  DriftTaskSubtaskRepository({
    required AppDatabase database,
    required SupabaseClient supabaseClient,
    required ConnectivityService connectivityService,
  })  : _subtaskDao = database.taskSubtasksDao,
        _taskDao = database.taskDao,
        _syncQueueDao = database.syncQueueDao,
        _supabase = supabaseClient,
        _connectivity = connectivityService;

  final TaskSubtasksDao _subtaskDao;
  final TaskDao _taskDao;
  final SyncQueueDao _syncQueueDao;
  final SupabaseClient _supabase;
  final ConnectivityService _connectivity;
  final _uuid = const Uuid();

  // ── READ ─────────────────────────────────────────────────

  @override
  Future<List<domain.TaskSubtask>> getForTask(String taskId) async {
    if (_connectivity.currentOnline) {
      try {
        final rows = await _supabase
            .from('task_subtasks')
            .select('id, task_occurrence_id, title, "position", is_completed, completed_at, created_at')
            .eq('task_occurrence_id', taskId)
            .order('position');
        final companions = rows.map((row) => TaskSubtasksCompanion(
          id: Value(row['id'] as String),
          taskOccurrenceId: Value(row['task_occurrence_id'] as String),
          title: Value(row['title'] as String),
          position: Value(row['position'] as int),
          isCompleted: Value(row['is_completed'] as bool),
          completedAt: Value(row['completed_at'] as String?),
          createdAt: Value(row['created_at'] as String),
        )).toList(growable: false);
        await _subtaskDao.upsertAll(companions);
      } catch (e) {
        AppLogger.debug('Supabase subtask fetch failed, using local cache: $e');
      }
    }
    final rows = await _subtaskDao.getForTask(taskId);
    return rows.map(_toDomain).toList(growable: false);
  }

  // ── CREATE ───────────────────────────────────────────────

  @override
  Future<domain.TaskSubtask> create(CreateTaskSubtaskParams params) async {
    final localId = _uuid.v4();
    final now = DateTime.now();
    final existing = await _subtaskDao.getForTask(params.taskId);
    final position = existing.length;
    final householdId = await _householdForTask(params.taskId);

    await _subtaskDao.upsert(TaskSubtasksCompanion(
      id: Value(localId),
      taskOccurrenceId: Value(params.taskId),
      title: Value(params.title.trim()),
      position: Value(position),
      isCompleted: const Value(false),
      completedAt: const Value(null),
      createdAt: Value(now.toUtc().toIso8601String()),
    ));

    await _syncQueueDao.enqueue(
      entityType: 'task_subtask',
      operation: 'SUBTASK_CREATE',
      entityId: params.taskId, // entityId = task_occurrence_id
      householdId: householdId,
      payload: {
        'task_occurrence_id': params.taskId,
        'title': params.title.trim(),
        'position': position,
      },
    );

    AppLogger.info('Subtask created locally: $localId');
    return domain.TaskSubtask(
      id: localId,
      taskId: params.taskId,
      title: params.title.trim(),
      position: position,
      isCompleted: false,
      createdAt: now,
    );
  }

  // ── UPDATE ───────────────────────────────────────────────

  @override
  Future<domain.TaskSubtask> toggle(String subtaskId, bool isCompleted) async {
    final row = await _findById(subtaskId);
    if (row == null) {
      throw StateError('Подзадача не найдена: $subtaskId');
    }
    final now = isCompleted ? DateTime.now() : null;

    await _subtaskDao.upsert(TaskSubtasksCompanion(
      id: Value(subtaskId),
      taskOccurrenceId: Value(row.taskOccurrenceId),
      title: Value(row.title),
      position: Value(row.position),
      isCompleted: Value(isCompleted),
      completedAt: Value(now?.toUtc().toIso8601String()),
      createdAt: Value(row.createdAt),
    ));

    await _syncQueueDao.enqueue(
      entityType: 'task_subtask',
      operation: 'SUBTASK_UPDATE',
      entityId: subtaskId,
      householdId: await _householdForTask(row.taskOccurrenceId),
      payload: {
        'title': row.title,
        'is_completed': isCompleted,
        'completed_at': now?.toUtc().toIso8601String(),
        'position': row.position,
      },
    );

    return _toDomain(row.copyWith(
      isCompleted: isCompleted,
      completedAt: Value(now?.toUtc().toIso8601String()),
    ));
  }

  @override
  Future<domain.TaskSubtask> updateTitle(
    String subtaskId,
    String title,
  ) async {
    final row = await _findById(subtaskId);
    if (row == null) {
      throw StateError('Подзадача не найдена: $subtaskId');
    }

    await _subtaskDao.upsert(TaskSubtasksCompanion(
      id: Value(subtaskId),
      taskOccurrenceId: Value(row.taskOccurrenceId),
      title: Value(title.trim()),
      position: Value(row.position),
      isCompleted: Value(row.isCompleted),
      completedAt: Value(row.completedAt),
      createdAt: Value(row.createdAt),
    ));

    await _syncQueueDao.enqueue(
      entityType: 'task_subtask',
      operation: 'SUBTASK_UPDATE',
      entityId: subtaskId,
      householdId: await _householdForTask(row.taskOccurrenceId),
      payload: {
        'title': title.trim(),
        'is_completed': row.isCompleted,
        'completed_at': row.completedAt,
        'position': row.position,
      },
    );

    return _toDomain(row.copyWith(title: title.trim()));
  }

  @override
  Future<void> reorder(String taskId, List<String> orderedIds) async {
    final householdId = await _householdForTask(taskId);
    for (var i = 0; i < orderedIds.length; i++) {
      final row = await _findById(orderedIds[i]);
      if (row == null) continue;
      await _subtaskDao.upsert(TaskSubtasksCompanion(
        id: Value(orderedIds[i]),
        taskOccurrenceId: Value(row.taskOccurrenceId),
        title: Value(row.title),
        position: Value(i),
        isCompleted: Value(row.isCompleted),
        completedAt: Value(row.completedAt),
        createdAt: Value(row.createdAt),
      ));
      await _syncQueueDao.enqueue(
        entityType: 'task_subtask',
        operation: 'SUBTASK_UPDATE',
        entityId: orderedIds[i],
        householdId: householdId,
        payload: {
          'title': row.title,
          'is_completed': row.isCompleted,
          'completed_at': row.completedAt,
          'position': i,
        },
      );
    }
  }

  // ── DELETE ───────────────────────────────────────────────

  @override
  Future<void> delete(String subtaskId) async {
    final row = await _findById(subtaskId);
    final householdId = row == null ? '' : await _householdForTask(row.taskOccurrenceId);

    await _subtaskDao.deleteSubtask(subtaskId);

    await _syncQueueDao.enqueue(
      entityType: 'task_subtask',
      operation: 'SUBTASK_DELETE',
      entityId: subtaskId,
      householdId: householdId,
      payload: {},
    );
  }

  // ── Helpers ──────────────────────────────────────────────

  Future<TaskSubtask?> _findById(String subtaskId) {
    return _subtaskDao.getById(subtaskId);
  }

  Future<String> _householdForTask(String taskId) async {
    final task = await _taskDao.getTaskById(taskId);
    return task?.householdId ?? '';
  }

  domain.TaskSubtask _toDomain(TaskSubtask row) {
    return domain.TaskSubtask(
      id: row.id,
      taskId: row.taskOccurrenceId,
      title: row.title,
      position: row.position,
      isCompleted: row.isCompleted,
      completedAt: row.completedAt == null ? null : DateTime.parse(row.completedAt!),
      createdAt: DateTime.parse(row.createdAt),
    );
  }
}
