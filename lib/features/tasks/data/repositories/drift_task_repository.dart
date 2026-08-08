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
import 'package:family_planner/features/tasks/domain/entities/task_recurrence.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:family_planner/features/tasks/domain/entities/update_recurring_task_params.dart';
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

  /// Minutes since midnight → `HH:MM:SS` for Supabase `TIME` columns.
  /// `null` — задача без времени / весь день.
  static String? _timeToString(Duration? plannedTime) {
    if (plannedTime == null) return null;
    final h = plannedTime.inHours.toString().padLeft(2, '0');
    final m = (plannedTime.inMinutes % 60).toString().padLeft(2, '0');
    return '$h:$m:00';
  }

  /// Supabase `TIME` string (`HH:MM:SS`) → minutes since midnight for Drift.
  static int? _minutesFromTime(String? time) {
    if (time == null) return null;
    final parts = time.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  /// Drift `plannedTime` (minutes) → domain [Duration]. `null` — весь день.
  static Duration? _durationFromMinutes(int? minutes) {
    if (minutes == null) return null;
    return Duration(minutes: minutes);
  }

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
          'estimated_duration_minutes, planned_for, planned_time, deadline_at, '
          'assigned_member_id, pinned_member_id, status, '
          'created_at, completed_at, updated_at, priority, '
          'reminder_minutes_before, category_id, '
          'template_id, '
          'task_occurrence_allowed_members(profile_id), '
          'task_templates(recurrence_type, interval_days, weekdays, recurrence_start_date, recurrence_end_date, is_active)',
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
          'estimated_duration_minutes, planned_for, planned_time, deadline_at, '
          'assigned_member_id, pinned_member_id, status, '
          'created_at, completed_at, updated_at, priority, '
          'reminder_minutes_before, category_id, '
          'template_id, '
          'task_occurrence_allowed_members(profile_id), '
          'task_templates(recurrence_type, interval_days, weekdays, recurrence_start_date, recurrence_end_date, is_active)',
        )
        .eq('household_id', householdId)
        .gte('planned_for', _dateOnly(startOfTomorrow))
        .lte('planned_for', _dateOnly(day.add(const Duration(days: 180))))
        .not('status', 'in', ['completed', 'skipped']);
    await _upsertRemoteRows(rows, householdId);
  }

  Future<void> _fetchAllPending(String householdId) async {
    final rows = await _supabase
        .from('task_occurrences')
        .select(
          'id, household_id, title, description, '
          'estimated_duration_minutes, planned_for, planned_time, deadline_at, '
          'assigned_member_id, pinned_member_id, status, '
          'created_at, completed_at, updated_at, priority, '
          'reminder_minutes_before, category_id, '
          'template_id, '
          'task_occurrence_allowed_members(profile_id), '
          'task_templates(recurrence_type, interval_days, weekdays, recurrence_start_date, recurrence_end_date, is_active)',
        )
        .eq('household_id', householdId)
        .not('status', 'in', ['completed', 'skipped'])
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

      final rawTemplate =
          row['task_templates'] as Map<String, dynamic>?;
      final recurrenceType =
          rawTemplate?['recurrence_type'] as String?;
      final weekdaysRaw =
          rawTemplate?['weekdays'] as List<dynamic>? ?? const [];

      companions.add(TaskOccurrencesCompanion(
        id: Value(id),
        householdId: Value(row['household_id'] as String),
        title: Value(row['title'] as String),
        description: Value(row['description'] as String?),
        estimatedDurationMinutes:
            Value(row['estimated_duration_minutes'] as int),
        plannedFor: Value(row['planned_for'] as String),
        plannedTime: Value(_minutesFromTime(row['planned_time'] as String?)),
        deadline: Value(row['deadline_at'] as String?),
        assignedMemberId: Value(row['assigned_member_id'] as String?),
        pinnedMemberId: Value(row['pinned_member_id'] as String?),
        status: Value(row['status'] as String),
        createdAt: Value(row['created_at'] as String),
        completedAt: Value(row['completed_at'] as String?),
        updatedAt: Value(row['updated_at'] as String?),
        priority: Value(row['priority'] as int?),
        allowedMemberIds: Value(jsonEncode(allowedRaw)),
        templateId: Value(row['template_id'] as String?),
        recurrenceType: Value(recurrenceType),
        intervalDays: Value(rawTemplate?['interval_days'] as int?),
        weekdays: Value(jsonEncode(weekdaysRaw)),
        recurrenceStartDate: Value(
          rawTemplate?['recurrence_start_date'] as String?,
        ),
        recurrenceEndDate: Value(
          rawTemplate?['recurrence_end_date'] as String?,
        ),
        reminderMinutesBefore: Value(row['reminder_minutes_before'] as int?),
        categoryId: Value(row['category_id'] as String?),
        templateActive: Value(rawTemplate?['is_active'] as bool?),
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
      reminderMinutesBefore: params.reminderMinutesBefore,
      categoryId: params.categoryId,
      plannedTime: params.plannedTime,
    );

    // Write to local DB
    await _taskDao.upsertTask(TaskOccurrencesCompanion(
      id: Value(localId),
      householdId: Value(params.householdId),
      title: Value(params.title),
      description: Value(params.description),
      estimatedDurationMinutes: Value(params.estimatedDurationMinutes),
      plannedFor: Value(plannedForStr),
      plannedTime: Value(_minutesFromTime(_timeToString(params.plannedTime))),
      deadline: Value(_toIso(params.deadline)),
      assignedMemberId: Value(params.assignedMemberId),
      pinnedMemberId: Value(params.pinnedMemberId),
      status: Value('pending'),
      createdAt: Value(_toIso(now)!),
      completedAt: const Value(null),
      updatedAt: Value(_toIso(now)),
      priority: Value(params.priority?.value),
      allowedMemberIds: Value(jsonEncode(domainTask.allowedMemberIds)),
      reminderMinutesBefore: Value(params.reminderMinutesBefore),
      categoryId: Value(params.categoryId),
    ));

    // Enqueue sync operation.
    // Обычные задачи создаются RPC `create_task_occurrence` (нужен p_planned_for),
    // повторяющиеся — RPC `create_recurring_task_template` (нужны p_start_date,
    // p_deadline_time, p_end_date, p_reminder_minutes_before). is_recurring
    // остаётся в payload, чтобы SyncProcessor выбрал правильный RPC.
    final recurrence = params.recurrence;
    final payload = <String, dynamic>{
      'p_household_id': params.householdId,
      'p_title': params.title,
      'p_description': params.description ?? '',
      'p_estimated_duration_minutes': params.estimatedDurationMinutes,
      'p_deadline_at': _toIso(params.deadline),
      'p_priority': params.priority?.value,
      'p_reminder_minutes_before': params.reminderMinutesBefore,
      'p_category_id': params.categoryId,
      'p_planned_time': _timeToString(params.plannedTime),
      'is_recurring': params.isRecurring,
    };

    if (params.isRecurring) {
      payload.addAll({
        'p_start_date':
            _dateOnly(params.recurrenceStartDate ?? params.plannedFor),
        'p_recurrence_type': recurrence!.type.databaseValue,
        'p_interval_days': recurrence.intervalDays,
        'p_weekdays': recurrence.weekdays,
        'p_end_date': params.recurrenceEndDate == null
            ? null
            : _dateOnly(params.recurrenceEndDate!),
        'p_deadline_time': params.deadline == null
            ? null
            : '${params.deadline!.hour.toString().padLeft(2, '0')}:'
                  '${params.deadline!.minute.toString().padLeft(2, '0')}:00',
      });
    } else {
      payload['p_planned_for'] = plannedForStr;
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
      plannedTime: Value(_minutesFromTime(_timeToString(task.plannedTime))),
      deadline: Value(_toIso(task.deadline)),
      assignedMemberId: Value(task.assignedMemberId),
      pinnedMemberId: Value(task.pinnedMemberId),
      status: Value(task.status.name),
      createdAt: Value(_toIso(task.createdAt)!),
      completedAt: Value(_toIso(task.completedAt)),
      updatedAt: Value(_toIso(now)),
      priority: Value(task.priority?.value),
      allowedMemberIds: Value(jsonEncode(task.allowedMemberIds)),
      reminderMinutesBefore: Value(task.reminderMinutesBefore),
      categoryId: Value(task.categoryId),
    ));

    await _syncQueueDao.enqueue(
      entityType: 'task_occurrence',
      operation: 'UPDATE',
      entityId: task.id,
      householdId: task.householdId,
      payload: {'base_updated_at': _toIso(task.updatedAt)},
    );
  }

  // ── UPDATE TEMPLATE (recurring series) ───────────────────

  @override
  Future<void> updateTemplate({
    required UpdateRecurringTaskParams params,
  }) async {
    final task = params.task;
    final now = DateTime.now();

    // Оптимистично обновляем локальный экземпляр (метаданные + расписание).
    await _taskDao.upsertTask(
      _companionFromTask(task).copyWith(updatedAt: Value(_toIso(now))),
    );

    await _syncQueueDao.enqueue(
      entityType: 'task_occurrence',
      operation: 'UPDATE_TEMPLATE',
      entityId: task.id,
      householdId: task.householdId,
      payload: {
        'p_task_occurrence_id': task.id,
        'p_scope': params.scope.databaseValue,
        'p_title': task.title,
        'p_description': task.description ?? '',
        'p_estimated_duration_minutes': task.estimatedDurationMinutes,
        'p_deadline_time': task.deadline == null
            ? null
            : '${task.deadline!.hour.toString().padLeft(2, '0')}:'
                  '${task.deadline!.minute.toString().padLeft(2, '0')}:00',
        'p_planned_time': _timeToString(task.plannedTime),
        'p_recurrence_type': params.recurrence.type.databaseValue,
        'p_interval_days': params.recurrence.intervalDays,
        'p_weekdays': params.recurrence.weekdays,
        'p_start_date': params.recurrenceStartDate == null
            ? null
            : _dateOnly(params.recurrenceStartDate!),
        'p_end_date': params.recurrenceEndDate == null
            ? null
            : _dateOnly(params.recurrenceEndDate!),
        'p_priority': task.priority?.value,
        'p_assigned_member_id': task.assignedMemberId,
        'p_pinned_member_id': task.pinnedMemberId,
        'p_add_allowed_member_ids': task.allowedMemberIds,
        'p_new_start_date': params.newStartDate == null
            ? null
            : _dateOnly(params.newStartDate!),
        'p_category_id': task.categoryId,
      },
    );

    AppLogger.info('Template update queued for task: ${task.id}');
  }

  // ── PAUSE / RESUME (recurring series) ─────────────────────

  @override
  Future<void> pauseTemplate({required String templateId}) async {
    // Помечаем все локальные экземпляры серии как «на паузе».
    await _taskDao.pauseTemplateLocally(templateId);
    final householdId =
        await _taskDao.getHouseholdIdByTemplate(templateId) ?? '';

    await _syncQueueDao.enqueue(
      entityType: 'task_occurrence',
      operation: 'PAUSE_TEMPLATE',
      entityId: templateId,
      householdId: householdId,
      payload: {'p_task_template_id': templateId},
    );

    AppLogger.info('Template pause queued: $templateId');
  }

  @override
  Future<void> resumeTemplate({required String templateId}) async {
    // Снимаем пометку паузы со всех локальных экземпляров серии.
    await _taskDao.resumeTemplateLocally(templateId);
    final householdId =
        await _taskDao.getHouseholdIdByTemplate(templateId) ?? '';

    await _syncQueueDao.enqueue(
      entityType: 'task_occurrence',
      operation: 'RESUME_TEMPLATE',
      entityId: templateId,
      householdId: householdId,
      payload: {'p_task_template_id': templateId},
    );

    AppLogger.info('Template resume queued: $templateId');
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

  /// Строит companion из доменного [Task], сохраняя recurrence-поля серии.
  TaskOccurrencesCompanion _companionFromTask(Task task) {
    return TaskOccurrencesCompanion(
      id: Value(task.id),
      householdId: Value(task.householdId),
      title: Value(task.title),
      description: Value(task.description),
      estimatedDurationMinutes: Value(task.estimatedDurationMinutes),
      plannedFor: Value(_dateOnly(task.plannedFor)),
      plannedTime: Value(_minutesFromTime(_timeToString(task.plannedTime))),
      deadline: Value(_toIso(task.deadline)),
      assignedMemberId: Value(task.assignedMemberId),
      pinnedMemberId: Value(task.pinnedMemberId),
      status: Value(task.status.name),
      createdAt: Value(_toIso(task.createdAt)!),
      completedAt: Value(_toIso(task.completedAt)),
      updatedAt: Value(_toIso(task.updatedAt)),
      priority: Value(task.priority?.value),
      allowedMemberIds: Value(jsonEncode(task.allowedMemberIds)),
      templateId: Value(task.templateId),
      recurrenceType: Value(task.recurrence?.type.databaseValue),
      intervalDays: Value(task.recurrence?.intervalDays),
      weekdays: Value(jsonEncode(task.recurrence?.weekdays ?? const [])),
      recurrenceStartDate: Value(_toIso(task.recurrenceStartDate)),
      recurrenceEndDate: Value(_toIso(task.recurrenceEndDate)),
      reminderMinutesBefore: Value(task.reminderMinutesBefore),
      categoryId: Value(task.categoryId),
      templateActive: Value(task.templateActive),
    );
  }

  Task _toDomain(TaskOccurrence row) {
    return Task(
      id: row.id,
      householdId: row.householdId,
      title: row.title,
      description: row.description,
      estimatedDurationMinutes: row.estimatedDurationMinutes,
      plannedFor: DateTime.parse(row.plannedFor),
      plannedTime: _durationFromMinutes(row.plannedTime),
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
      templateId: row.templateId,
      recurrence: _recurrenceFromColumns(
        type: row.recurrenceType,
        intervalDays: row.intervalDays,
        weekdays: row.weekdays,
      ),
      recurrenceStartDate: _parseDt(row.recurrenceStartDate),
      recurrenceEndDate: _parseDt(row.recurrenceEndDate),
      reminderMinutesBefore: row.reminderMinutesBefore,
      categoryId: row.categoryId,
      templateActive: row.templateActive,
    );
  }

  TaskRecurrence? _recurrenceFromColumns({
    required String? type,
    required int? intervalDays,
    required String? weekdays,
  }) {
    return switch (type) {
      'daily' => const TaskRecurrence.daily(),
      'weekly' => TaskRecurrence.weekly(
        weekdays: _decodeIntList(weekdays),
      ),
      'interval_days' => TaskRecurrence.intervalDays(
        intervalDays: intervalDays ?? 1,
      ),
      _ => null,
    };
  }

  List<int> _decodeIntList(String? jsonList) {
    if (jsonList == null || jsonList.isEmpty) return const [];

    try {
      return (jsonDecode(jsonList) as List<dynamic>).cast<int>();
    } catch (_) {
      return const [];
    }
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
      plannedTime: Value(_minutesFromTime(_timeToString(task.plannedTime))),
      deadline: Value(_toIso(task.deadline)),
      assignedMemberId: Value(task.assignedMemberId),
      pinnedMemberId: Value(task.pinnedMemberId),
      status: Value(task.status.name),
      createdAt: Value(_toIso(task.createdAt)!),
      completedAt: Value(_toIso(task.completedAt)),
      updatedAt: Value(_toIso(task.updatedAt)),
      priority: Value(task.priority?.value),
      allowedMemberIds: Value(jsonEncode(task.allowedMemberIds)),
      reminderMinutesBefore: Value(task.reminderMinutesBefore),
    )).toList();

    await _taskDao.upsertTasks(companions);
  }
}
