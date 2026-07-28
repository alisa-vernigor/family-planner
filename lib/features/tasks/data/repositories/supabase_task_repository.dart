import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/create_task_params.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/task_status.dart';
import '../../domain/repositories/task_repository.dart';

final class SupabaseTaskRepository implements TaskRepository {
  SupabaseTaskRepository({required this._client});

  final SupabaseClient _client;

  @override
  Future<List<Task>> getForDay({
    required String householdId,
    required DateTime day,
  }) async {
    final plannedFor = _dateOnly(day);

    AppLogger.debug(
      'SupabaseTaskRepository.getForDay: '
      'householdId=$householdId; day=$plannedFor',
    );

    final rows = await _client
        .from('task_occurrences')
        .select(
          'id, household_id, title, description, '
          'estimated_duration_minutes, planned_for, deadline_at, '
          'assigned_member_id, pinned_member_id, status, created_at, completed_at, updated_at, '
          'task_occurrence_allowed_members(profile_id)',
        )
        .eq('household_id', householdId)
        .eq('planned_for', plannedFor)
        .order('deadline_at');

    AppLogger.debug(
      'SupabaseTaskRepository.getForDay: получил ${rows.length} записей',
    );

    return rows.map((row) => _toTask(row)).toList(growable: false);
  }

  @override
  Future<List<Task>> getScheduledAfter({
    required String householdId,
    required DateTime day,
  }) async {
    final startOfTomorrow = DateTime(day.year, day.month, day.day + 1);

    AppLogger.debug(
      'SupabaseTaskRepository.getScheduledAfter: '
      'householdId=$householdId; after=${_dateOnly(startOfTomorrow)}',
    );

    final rows = await _client
        .from('task_occurrences')
        .select(
          'id, household_id, title, description, '
          'estimated_duration_minutes, planned_for, deadline_at, '
          'assigned_member_id, pinned_member_id, status, created_at, completed_at, updated_at, '
          'task_occurrence_allowed_members(profile_id)',
        )
        .eq('household_id', householdId)
        .gte('planned_for', _dateOnly(startOfTomorrow))
        .lte('planned_for', _dateOnly(day.add(const Duration(days: 180)))) // максимум 6 месяцев вперёд
        .neq('status', TaskStatus.completed.name)
        .order('planned_for')
        .order('deadline_at');

    AppLogger.debug(
      'SupabaseTaskRepository.getScheduledAfter: получил ${rows.length} записей',
    );

    return rows.map((row) => _toTask(row)).toList(growable: false);
  }

  @override
  Future<List<Task>> getAllPending({
    required String householdId,
  }) async {
    AppLogger.debug(
      'SupabaseTaskRepository.getAllPending: householdId=$householdId',
    );

    final rows = await _client
        .from('task_occurrences')
        .select(
          'id, household_id, title, description, '
          'estimated_duration_minutes, planned_for, deadline_at, '
          'assigned_member_id, pinned_member_id, status, created_at, completed_at, updated_at, '
          'task_occurrence_allowed_members(profile_id)',
        )
        .eq('household_id', householdId)
        .neq('status', TaskStatus.completed.name)
        .gte('planned_for', _dateOnly(DateTime.now().subtract(const Duration(days: 7)))) // не тащим просрочку на месяцы
        .order('planned_for')
        .order('deadline_at')
        .limit(200); // не тащим больше 200 записей

    AppLogger.debug(
      'SupabaseTaskRepository.getAllPending: получил ${rows.length} записей',
    );

    return rows.map((row) => _toTask(row)).toList(growable: false);
  }

  @override
  Future<Task> create({required CreateTaskParams params}) async {
    AppLogger.debug(
      'SupabaseTaskRepository.create: '
      'title="${params.title}"; isRecurring=${params.isRecurring}',
    );

    Task task;

    if (params.isRecurring) {
      task = await _createRecurring(params: params);
    } else {
      final row =
          await _client.rpc(
                'create_task_occurrence',
                params: {
                  'p_household_id': params.householdId,
                  'p_title': params.title,
                  'p_description': params.description ?? '',
                  'p_estimated_duration_minutes': params.estimatedDurationMinutes,
                  'p_planned_for': _dateOnly(params.plannedFor),
                  'p_deadline_at': params.deadline?.toUtc().toIso8601String(),
                },
              )
              as Map<String, dynamic>;

      task = _taskFromCreatedRow(row);
    }

    AppLogger.info(
      'Задача создана: taskId=${task.id}; householdId=${task.householdId}',
    );

    // Apply post-creation updates for assignment fields
    final memberToAdd = params.assignedMemberId;
    final isPinned = params.pinnedMemberId;

    if (memberToAdd != null || isPinned != null) {
      task = task.copyWith(
        assignedMemberId: memberToAdd ?? task.assignedMemberId,
        pinnedMemberId: isPinned ?? task.pinnedMemberId,
      );

      await save(task);
    }

    // Add the assigned member to allowed members list
    if (memberToAdd != null && !task.allowedMemberIds.contains(memberToAdd)) {
      await addAllowedMember(taskId: task.id, memberId: memberToAdd);
    }

    return task;
  }

  Future<Task> _createRecurring({required CreateTaskParams params}) async {
    final recurrence = params.recurrence!;

    final row =
        await _client.rpc(
              'create_recurring_task_template',
              params: {
                'p_household_id': params.householdId,
                'p_title': params.title,
                'p_description': params.description ?? '',
                'p_estimated_duration_minutes': params.estimatedDurationMinutes,
                'p_start_date': _dateOnly(
                  params.recurrenceStartDate ?? params.plannedFor,
                ),
                'p_deadline_at': params.deadline?.toUtc().toIso8601String(),
                'p_recurrence_type': recurrence.type.databaseValue,
                'p_interval_days': recurrence.intervalDays,
                'p_weekdays': recurrence.weekdays,
                'p_deadline_time': params.deadline == null
                    ? null
                    : '${params.deadline!.hour.toString().padLeft(2, '0')}:${params.deadline!.minute.toString().padLeft(2, '0')}:00',
                'p_end_date': params.recurrenceEndDate == null
                    ? null
                    : _dateOnly(params.recurrenceEndDate!),
              },
            )
            as Map<String, dynamic>;

    return _taskFromCreatedRow(row);
  }

  @override
  Future<void> save(Task task) async {
    AppLogger.debug(
      'SupabaseTaskRepository.save: taskId=${task.id}; '
      'status=${task.status.name}; assignedMemberId=${task.assignedMemberId}',
    );

    var query = _client
        .from('task_occurrences')
        .update({
          'title': task.title,
          'description': task.description,
          'estimated_duration_minutes': task.estimatedDurationMinutes,
          'planned_for': _dateOnly(task.plannedFor),
          'deadline_at': task.deadline?.toUtc().toIso8601String(),
          'assigned_member_id': task.assignedMemberId,
          'pinned_member_id': task.pinnedMemberId,
          'status': task.status.name,
          'completed_by_member_id': task.isCompleted
              ? task.assignedMemberId
              : null,
          'completed_at': task.completedAt?.toUtc().toIso8601String(),
        })
        .eq('id', task.id);

    // Оптимистичная блокировка: проверяем, что никто не изменил задачу
    if (task.updatedAt != null) {
      query = query.eq('updated_at', task.updatedAt!.toUtc().toIso8601String());
    }

    final result = await query.select('id');
    if (result.isEmpty) {
      AppLogger.warning(
        'Конфликт при сохранении задачи: taskId=${task.id} — '
        'другой пользователь изменил задачу',
      );
    }
  }

  @override
  Future<void> delete({required String taskId}) async {
    AppLogger.info('SupabaseTaskRepository.delete: taskId=$taskId');

    await _client.from('task_occurrences').delete().eq('id', taskId);
  }

  @override
  Future<void> addAllowedMember({
    required String taskId,
    required String memberId,
  }) async {
    AppLogger.debug(
      'SupabaseTaskRepository.addAllowedMember: '
      'taskId=$taskId; memberId=$memberId',
    );

    await _client.from('task_occurrence_allowed_members').insert({
      'task_occurrence_id': taskId,
      'profile_id': memberId,
    });
  }

  @override
  Future<void> removeAllowedMember({
    required String taskId,
    required String memberId,
  }) async {
    AppLogger.debug(
      'SupabaseTaskRepository.removeAllowedMember: '
      'taskId=$taskId; memberId=$memberId',
    );

    await _client
        .from('task_occurrence_allowed_members')
        .delete()
        .eq('task_occurrence_id', taskId)
        .eq('profile_id', memberId);
  }

  Task _taskFromCreatedRow(Map<String, dynamic> row) {
    final currentUserId = _client.auth.currentUser?.id;

    if (currentUserId == null) {
      throw const TaskUserNotAuthenticatedException();
    }

    return Task(
      id: row['id'] as String,
      householdId: row['household_id'] as String,
      title: row['title'] as String,
      description: row['description'] as String?,
      estimatedDurationMinutes: row['estimated_duration_minutes'] as int,
      plannedFor: DateTime.parse(row['planned_for'] as String),
      deadline: _parseNullableDateTime(row['deadline_at']),
      allowedMemberIds: [currentUserId],
      assignedMemberId: row['assigned_member_id'] as String?,
      pinnedMemberId: row['pinned_member_id'] as String?,
      status: _toTaskStatus(row['status'] as String),
      createdAt: DateTime.parse(row['created_at'] as String),
      completedAt: _parseNullableDateTime(row['completed_at']),
      updatedAt: _parseNullableDateTime(row['updated_at']),
    );
  }

  Task _toTask(Map<String, dynamic> row) {
    final rawAllowedMembers =
        row['task_occurrence_allowed_members'] as List<dynamic>? ?? const [];

    return Task(
      id: row['id'] as String,
      householdId: row['household_id'] as String,
      title: row['title'] as String,
      description: row['description'] as String?,
      estimatedDurationMinutes: row['estimated_duration_minutes'] as int,
      plannedFor: DateTime.parse(row['planned_for'] as String),
      deadline: _parseNullableDateTime(row['deadline_at']),
      allowedMemberIds: rawAllowedMembers
          .map((item) => (item as Map<String, dynamic>)['profile_id'] as String)
          .toList(growable: false),
      assignedMemberId: row['assigned_member_id'] as String?,
      pinnedMemberId: row['pinned_member_id'] as String?,
      status: _toTaskStatus(row['status'] as String),
      createdAt: DateTime.parse(row['created_at'] as String),
      completedAt: _parseNullableDateTime(row['completed_at']),
      updatedAt: _parseNullableDateTime(row['updated_at']),
    );
  }

  TaskStatus _toTaskStatus(String value) {
    return switch (value) {
      'pending' => TaskStatus.pending,
      'completed' => TaskStatus.completed,
      'skipped' => TaskStatus.skipped,
      _ => throw FormatException('Неизвестный статус задачи: $value'),
    };
  }

  DateTime? _parseNullableDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    return DateTime.parse(value as String);
  }

  String _dateOnly(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }
}

final class TaskUserNotAuthenticatedException implements Exception {
  const TaskUserNotAuthenticatedException();

  @override
  String toString() {
    return 'TaskUserNotAuthenticatedException: пользователь не авторизован.';
  }
}
