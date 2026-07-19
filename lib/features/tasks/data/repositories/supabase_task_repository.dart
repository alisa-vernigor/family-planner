import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/task.dart';
import '../../domain/entities/task_status.dart';
import '../../domain/repositories/task_repository.dart';
import '../../domain/entities/create_task_params.dart';

final class SupabaseTaskRepository implements TaskRepository {
  SupabaseTaskRepository({required this._client});

  final SupabaseClient _client;

  @override
  Future<List<Task>> getForDay({
    required String householdId,
    required DateTime day,
  }) async {
    final plannedFor = _dateOnly(day);

    final rows = await _client
        .from('task_occurrences')
        .select(
          'id, household_id, title, description, '
          'estimated_duration_minutes, planned_for, deadline_at, '
          'assigned_member_id, status, created_at, completed_at, '
          'task_occurrence_allowed_members(profile_id)',
        )
        .eq('household_id', householdId)
        .eq('planned_for', plannedFor)
        .order('deadline_at');

    return rows.map((row) => _toTask(row)).toList(growable: false);
  }

  @override
  Future<List<Task>> getScheduledAfter({
    required String householdId,
    required DateTime day,
  }) async {
    final startOfTomorrow = DateTime(day.year, day.month, day.day + 1);

    final rows = await _client
        .from('task_occurrences')
        .select(
          'id, household_id, title, description, '
          'estimated_duration_minutes, planned_for, deadline_at, '
          'assigned_member_id, status, created_at, completed_at, '
          'task_occurrence_allowed_members(profile_id)',
        )
        .eq('household_id', householdId)
        .gte('planned_for', _dateOnly(startOfTomorrow))
        .neq('status', TaskStatus.completed.name)
        .order('planned_for')
        .order('deadline_at');

    return rows.map((row) => _toTask(row)).toList(growable: false);
  }

  @override
  Future<Task> create({required CreateTaskParams params}) async {
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
      status: _toTaskStatus(row['status'] as String),
      createdAt: DateTime.parse(row['created_at'] as String),
      completedAt: _parseNullableDateTime(row['completed_at']),
    );
  }

  @override
  Future<void> save(Task task) async {
    await _client
        .from('task_occurrences')
        .update({
          'title': task.title,
          'description': task.description,
          'estimated_duration_minutes': task.estimatedDurationMinutes,
          'planned_for': _dateOnly(task.plannedFor),
          'deadline_at': task.deadline?.toUtc().toIso8601String(),
          'assigned_member_id': task.assignedMemberId,
          'status': task.status.name,
          'completed_by_member_id': task.isCompleted
              ? task.assignedMemberId
              : null,
          'completed_at': task.completedAt?.toUtc().toIso8601String(),
        })
        .eq('id', task.id);
  }

  @override
  Future<void> delete({required String taskId}) async {
    await _client.from('task_occurrences').delete().eq('id', taskId);
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
      status: _toTaskStatus(row['status'] as String),
      createdAt: DateTime.parse(row['created_at'] as String),
      completedAt: _parseNullableDateTime(row['completed_at']),
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
