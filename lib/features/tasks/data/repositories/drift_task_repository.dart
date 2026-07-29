import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:family_planner/core/database/app_database.dart';
import 'package:family_planner/core/database/daos/sync_queue_dao.dart';
import 'package:family_planner/core/database/daos/task_dao.dart';
import 'package:family_planner/core/logging/app_logger.dart';
import 'package:family_planner/core/services/connectivity_service.dart';
import 'package:family_planner/features/tasks/domain/entities/create_task_params.dart';
import 'package:family_planner/features/tasks/domain/entities/eisenhower_priority.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';

/// Drift-backed implementation of [TaskRepository] with offline-first support.
///
/// - **Reads** are served from the local SQLite database (Drift).
/// - **Writes** update local DB immediately, then enqueue a sync operation.
/// - When online, a direct Supabase fast-path is attempted first.
/// - The [SyncProcessor] replays queued operations against Supabase
///   when connectivity is restored.
class DriftTaskRepository implements TaskRepository {
  DriftTaskRepository({
    required AppDatabase database,
    required SupabaseClient supabaseClient,
    required ConnectivityService connectivityService,
  })  : _taskDao = database.taskDao,
        _syncQueueDao = database.syncQueueDao,
        _supabase = supabaseClient,
        _connectivity = connectivityService;

  final TaskDao _taskDao;
  final SyncQueueDao _syncQueueDao;
  final SupabaseClient _supabase;
  final ConnectivityService _connectivity;
  final _uuid = const Uuid();

  // ── Date helpers (match Supabase format) ─────────────────

  static String _dateOnly(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}'
        '-${dt.month.toString().padLeft(2, '0')}'
        '-${dt.day.toString().padLeft(2, '0')}';
  }

  static String? _toIso(DateTime? dt) =>
      dt?.toUtc().toIso8601String();

  static DateTime? _parseDt(String? s) =>
      s != null ? DateTime.parse(s) : null;

  // ── READ ─────────────────────────────────────────────────

  @override
  Future<List<Task>> getForDay({
    required String householdId,
    required DateTime day,
  }) async {
    if (_connectivity.currentOnline) {
      await _tryFetchAndCache(() => _fetchForDay(householdId, day));
    }
    final rows = await _taskDao.getForDay(householdId, _dateOnly(day));
    return rows.map(_toDomain).toList(growable: false);
  }

  @override
  Future<List<Task>> getScheduledAfter({
    required String householdId,
    required DateTime day,
  }) async {
    if (_connectivity.currentOnline) {
      await _tryFetchAndCache(
        () => _fetchScheduledAfter(householdId, day),
      );
    }
    final rows = await _taskDao.getScheduledAfter(
      householdId,
      _dateOnly(day),
    );
    return rows.map(_toDomain).toList(growable: false);
  }

  @override
  Future<List<Task>> getAllPending({
    required String householdId,
  }) async {
    if (_connectivity.currentOnline) {
      await _tryFetchAndCache(() => _fetchAllPending(householdId));
    }
    final rows = await _taskDao.getAllPending(householdId);
    return rows.map(_toDomain).toList(growable: false);
  }

  /// Try to fetch from Supabase and cache locally. Fail silently.
  Future<void> _tryFetchAndCache(Future<void> Function() fetch) async {
    try {
      await fetch();
    } catch (e) {
      AppLogger.debug('Supabase fetch failed, using local cache: $e');
    }
  }

  Future<void> _fetchForDay(String householdId, DateTime day) async {
    final rows = await _supabase
        .from('task_occurrences')
        .select(
          'id, household_id, title, description, '
          'estimated_duration_minutes, planned_for, deadline_at, '
          'assigned_member_id, pinned_member_id, status, '
          'created_at, completed_at, updated_at, priority, '
          'task_occurrence_allowed_members(profile_id)',
        )
        .eq('household_id', householdId)
        .eq('planned_for', _dateOnly(day));
    await _upsertRemoteRows(rows, householdId);
  }

  Future<void> _fetchScheduledAfter(String householdId, DateTime day) async {
    final startOfTomorrow = DateTime(day.year, day.month, day.day + 1);
    final rows = await _supabase
        .from('task_occurrences')
        .select(
          'id, household_id, title, description, '
          'estimated_duration_minutes, planned_for, deadline_at, '
          'assigned_member_id, pinned_member_id, status, '
          'created_at, completed_at, updated_at, priority, '
          'task_occurrence_allowed_members(profile_id)',
        )
        .eq('household_id', householdId)
        .gte('planned_for', _dateOnly(startOfTomorrow))
        .lte('planned_for', _dateOnly(day.add(const Duration(days: 180))))
        .neq('status', 'completed');
    await _upsertRemoteRows(rows, householdId);
  }

  Future<void> _fetchAllPending(String householdId) async {
    final rows = await _supabase
        .from('task_occurrences')
        .select(
          'id, household_id, title, description, '
          'estimated_duration_minutes, planned_for, deadline_at, '
          'assigned_member_id, pinned_member_id, status, '
          'created_at, completed_at, updated_at, priority, '
          'task_occurrence_allowed_members(profile_id)',
        )
        .eq('household_id', householdId)
        .neq('status', 'completed')
        .gte(
          'planned_for',
          _dateOnly(DateTime.now().subtract(const Duration(days: 7))),
        );
    await _upsertRemoteRows(rows, householdId);
  }

  /// Write remote rows to local DB, NOT overwriting tasks with pending ops.
  Future<void> _upsertRemoteRows(
    List<dynamic> rows,
    String householdId,
  ) async {
    final pendingIds = await _syncQueueDao.getPendingIds(householdId);
    final companions = <TaskOccurrencesCompanion>[];

    for (final row in rows) {
      final id = row['id'] as String;
      if (pendingIds.contains(id)) continue; // don't clobber pending changes

      final allowedRaw = (row['task_occurrence_allowed_members']
              as List<dynamic>?)
          ?.map((e) => (e as Map<String, dynamic>)['profile_id'] as String)
          .toList() ??
          <String>[];

      companions.add(TaskOccurrencesCompanion(
        id: Value(id),
        householdId: Value(row['household_id'] as String),
        title: Value(row['title'] as String),
        description: Value(row['description'] as String?),
        estimatedDurationMinutes:
            Value(row['estimated_duration_minutes'] as int),
        plannedFor: Value(row['planned_for'] as String),
        deadline: Value(row['deadline_at'] as String?),
        assignedMemberId: Value(row['assigned_member_id'] as String?),
        pinnedMemberId: Value(row['pinned_member_id'] as String?),
        status: Value(row['status'] as String),
        createdAt: Value(row['created_at'] as String),
        completedAt: Value(row['completed_at'] as String?),
        updatedAt: Value(row['updated_at'] as String?),
        priority: Value(row['priority'] as int?),
        allowedMemberIds: Value(jsonEncode(allowedRaw)),
      ));
    }

    if (companions.isNotEmpty) {
      await _taskDao.upsertTasks(companions);
    }
  }

  // ── CREATE ────────────────────────────────────────────────

  @override
  Future<Task> create({required CreateTaskParams params}) async {
    final now = DateTime.now();
    final localId = _uuid.v4();
    final currentUserId = _supabase.auth.currentUser?.id ?? '';
    final plannedForStr = _dateOnly(params.plannedFor);

    final domainTask = Task(
      id: localId,
      householdId: params.householdId,
      title: params.title,
      description: params.description,
      estimatedDurationMinutes: params.estimatedDurationMinutes,
      plannedFor: params.plannedFor,
      deadline: params.deadline,
      allowedMemberIds: [
        currentUserId,
        if (params.assignedMemberId != null) params.assignedMemberId!,
      ],
      assignedMemberId: params.assignedMemberId,
      pinnedMemberId: params.pinnedMemberId,
      status: TaskStatus.pending,
      createdAt: now,
      completedAt: null,
      updatedAt: now,
      priority: params.priority,
    );

    // Write to local DB
    await _taskDao.upsertTask(TaskOccurrencesCompanion(
      id: Value(localId),
      householdId: Value(params.householdId),
      title: Value(params.title),
      description: Value(params.description),
      estimatedDurationMinutes: Value(params.estimatedDurationMinutes),
      plannedFor: Value(plannedForStr),
      deadline: Value(_toIso(params.deadline)),
      assignedMemberId: Value(params.assignedMemberId),
      pinnedMemberId: Value(params.pinnedMemberId),
      status: Value('pending'),
      createdAt: Value(_toIso(now)!),
      completedAt: const Value(null),
      updatedAt: Value(_toIso(now)),
      priority: Value(params.priority?.value),
      allowedMemberIds: Value(jsonEncode(domainTask.allowedMemberIds)),
    ));

    // Enqueue sync operation
    final payload = <String, dynamic>{
      'local_id': localId,
      'p_household_id': params.householdId,
      'p_title': params.title,
      'p_description': params.description ?? '',
      'p_estimated_duration_minutes': params.estimatedDurationMinutes,
      'p_planned_for': plannedForStr,
      'p_deadline_at': _toIso(params.deadline),
      'p_priority': params.priority?.value,
      'is_recurring': params.isRecurring,
    };

    if (params.isRecurring) {
      payload['p_start_date'] = plannedForStr;
      payload['p_recurrence_type'] =
          params.recurrence!.type.databaseValue;
      payload['p_interval_days'] = params.recurrence!.intervalDays;
      payload['p_weekdays'] = params.recurrence!.weekdays;
    }

    await _syncQueueDao.enqueue(
      entityType: 'task_occurrence',
      operation: 'CREATE',
      entityId: localId,
      householdId: params.householdId,
      payload: payload,
    );

    AppLogger.info('Task created locally: $localId');
    return domainTask;
  }

  // ── SAVE ─────────────────────────────────────────────────

  @override
  Future<void> save(Task task) async {
    final now = DateTime.now();

    await _taskDao.upsertTask(TaskOccurrencesCompanion(
      id: Value(task.id),
      householdId: Value(task.householdId),
      title: Value(task.title),
      description: Value(task.description),
      estimatedDurationMinutes: Value(task.estimatedDurationMinutes),
      plannedFor: Value(_dateOnly(task.plannedFor)),
      deadline: Value(_toIso(task.deadline)),
      assignedMemberId: Value(task.assignedMemberId),
      pinnedMemberId: Value(task.pinnedMemberId),
      status: Value(task.status.name),
      createdAt: Value(_toIso(task.createdAt)!),
      completedAt: Value(_toIso(task.completedAt)),
      updatedAt: Value(_toIso(now)),
      priority: Value(task.priority?.value),
      allowedMemberIds: Value(jsonEncode(task.allowedMemberIds)),
    ));

    await _syncQueueDao.enqueue(
      entityType: 'task_occurrence',
      operation: 'UPDATE',
      entityId: task.id,
      householdId: task.householdId,
      payload: {'base_updated_at': _toIso(task.updatedAt)},
    );
  }

  // ── PATCH STATUS ─────────────────────────────────────────

  @override
  Future<void> patchStatus({
    required String taskId,
    required String status,
    String? completedByMemberId,
    String? completedAt,
    String? assignedMemberId,
  }) async {
    final existing = await _taskDao.getTaskById(taskId);
    if (existing != null) {
      final now = _toIso(DateTime.now());
      await _taskDao.upsertTask(TaskOccurrencesCompanion(
        id: Value(taskId),
        status: Value(status),
        completedAt: Value(completedAt),
        updatedAt: Value(now),
        assignedMemberId: Value(assignedMemberId),
        // Keep existing values for other fields
        householdId: Value(existing.householdId),
        title: Value(existing.title),
        description: Value(existing.description),
        estimatedDurationMinutes: Value(existing.estimatedDurationMinutes),
        plannedFor: Value(existing.plannedFor),
        deadline: Value(existing.deadline),
        pinnedMemberId: Value(existing.pinnedMemberId),
        createdAt: Value(existing.createdAt),
        priority: Value(existing.priority),
        allowedMemberIds: Value(existing.allowedMemberIds),
      ));
    }

    await _syncQueueDao.enqueue(
      entityType: 'task_occurrence',
      operation: 'PATCH_STATUS',
      entityId: taskId,
      householdId: existing?.householdId ?? '',
      payload: {
        'status': status,
        'completed_by_member_id': completedByMemberId,
        'completed_at': completedAt,
        'assigned_member_id': assignedMemberId,
      },
    );
  }

  // ── DELETE ───────────────────────────────────────────────

  @override
  Future<void> delete({required String taskId}) async {
    final existing = await _taskDao.getTaskById(taskId);
    if (existing != null) {
      await _taskDao.deleteTask(taskId);
    }

    await _syncQueueDao.enqueue(
      entityType: 'task_occurrence',
      operation: 'DELETE',
      entityId: taskId,
      householdId: existing?.householdId ?? '',
      payload: {},
    );
  }

  // ── ALLOWED MEMBERS ──────────────────────────────────────

  @override
  Future<void> addAllowedMember({
    required String taskId,
    required String memberId,
  }) async {
    final existing = await _taskDao.getTaskById(taskId);
    if (existing != null) {
      final ids = jsonDecode(existing.allowedMemberIds) as List<dynamic>;
      if (!ids.contains(memberId)) {
        ids.add(memberId);
        await _taskDao.upsertTask(TaskOccurrencesCompanion(
          id: Value(taskId),
          allowedMemberIds: Value(jsonEncode(ids)),
        ));
      }
    }

    await _syncQueueDao.enqueue(
      entityType: 'task_occurrence',
      operation: 'ADD_ALLOWED',
      entityId: taskId,
      householdId: existing?.householdId ?? '',
      payload: {
        'task_occurrence_id': taskId,
        'profile_id': memberId,
      },
    );
  }

  @override
  Future<void> removeAllowedMember({
    required String taskId,
    required String memberId,
  }) async {
    final existing = await _taskDao.getTaskById(taskId);
    if (existing != null) {
      final ids = jsonDecode(existing.allowedMemberIds) as List<dynamic>;
      ids.remove(memberId);
      await _taskDao.upsertTask(TaskOccurrencesCompanion(
        id: Value(taskId),
        allowedMemberIds: Value(jsonEncode(ids)),
      ));
    }

    await _syncQueueDao.enqueue(
      entityType: 'task_occurrence',
      operation: 'REMOVE_ALLOWED',
      entityId: taskId,
      householdId: existing?.householdId ?? '',
      payload: {
        'task_occurrence_id': taskId,
        'profile_id': memberId,
      },
    );
  }

  // ── Converters ───────────────────────────────────────────

  Task _toDomain(TaskOccurrence row) {
    return Task(
      id: row.id,
      householdId: row.householdId,
      title: row.title,
      description: row.description,
      estimatedDurationMinutes: row.estimatedDurationMinutes,
      plannedFor: DateTime.parse(row.plannedFor),
      deadline: _parseDt(row.deadline),
      allowedMemberIds: (jsonDecode(row.allowedMemberIds) as List<dynamic>)
          .cast<String>(),
      assignedMemberId: row.assignedMemberId,
      pinnedMemberId: row.pinnedMemberId,
      status: switch (row.status) {
        'pending' => TaskStatus.pending,
        'completed' => TaskStatus.completed,
        'skipped' => TaskStatus.skipped,
        _ => TaskStatus.pending,
      },
      createdAt: DateTime.parse(row.createdAt),
      completedAt: _parseDt(row.completedAt),
      updatedAt: _parseDt(row.updatedAt),
      priority: EisenhowerPriority.fromValue(row.priority),
    );
  }

  /// Bulk-sync: replace all local data for a household with fresh server data.
  /// Called from the full-sync flow.
  Future<void> replaceHouseholdData({
    required String householdId,
    required List<Task> tasks,
    required List<dynamic> members,
  }) async {
    await _taskDao.clearHousehold(householdId);

    if (tasks.isEmpty) return;

    final companions = tasks.map((task) => TaskOccurrencesCompanion(
      id: Value(task.id),
      householdId: Value(task.householdId),
      title: Value(task.title),
      description: Value(task.description),
      estimatedDurationMinutes: Value(task.estimatedDurationMinutes),
      plannedFor: Value(_dateOnly(task.plannedFor)),
      deadline: Value(_toIso(task.deadline)),
      assignedMemberId: Value(task.assignedMemberId),
      pinnedMemberId: Value(task.pinnedMemberId),
      status: Value(task.status.name),
      createdAt: Value(_toIso(task.createdAt)!),
      completedAt: Value(_toIso(task.completedAt)),
      updatedAt: Value(_toIso(task.updatedAt)),
      priority: Value(task.priority?.value),
      allowedMemberIds: Value(jsonEncode(task.allowedMemberIds)),
    )).toList();

    await _taskDao.upsertTasks(companions);
  }
}
