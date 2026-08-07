import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:family_planner/core/logging/app_logger.dart';
import 'package:family_planner/features/tasks/domain/entities/create_task_subtask_params.dart';
import 'package:family_planner/features/tasks/domain/entities/task_subtask.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_subtask_repository.dart';

/// Supabase-реализация [TaskSubtaskRepository].
///
/// Подзадачи читаются и пишутся напрямую (RLS разрешает членам семьи).
/// Используется на web (online-only). На нативных платформах работает
/// [DriftTaskSubtaskRepository] с offline-очередью.
final class SupabaseTaskSubtaskRepository implements TaskSubtaskRepository {
  SupabaseTaskSubtaskRepository({required SupabaseClient client})
    : _client = client;

  final SupabaseClient _client;

  @override
  Future<List<TaskSubtask>> getForTask(String taskId) async {
    final rows = await _client
        .from('task_subtasks')
        .select('id, task_occurrence_id, title, "position", is_completed, completed_at, created_at')
        .eq('task_occurrence_id', taskId)
        .order('position');

    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  Future<TaskSubtask> create(CreateTaskSubtaskParams params) async {
    // Позиция = количество уже существующих подзадач (в конец списка).
    final existing = await getForTask(params.taskId);

    final row = await _client
        .from('task_subtasks')
        .insert({
          'task_occurrence_id': params.taskId,
          'title': params.title.trim(),
          'position': existing.length,
        })
        .select('id, task_occurrence_id, title, "position", is_completed, completed_at, created_at')
        .single();

    AppLogger.info('Подзадача создана: id=${row['id']}');
    return _fromRow(row);
  }

  @override
  Future<TaskSubtask> toggle(String subtaskId, bool isCompleted) async {
    final row = await _client
        .from('task_subtasks')
        .update({
          'is_completed': isCompleted,
          'completed_at': isCompleted ? DateTime.now().toUtc().toIso8601String() : null,
        })
        .eq('id', subtaskId)
        .select('id, task_occurrence_id, title, "position", is_completed, completed_at, created_at')
        .single();

    return _fromRow(row);
  }

  @override
  Future<TaskSubtask> updateTitle(String subtaskId, String title) async {
    final row = await _client
        .from('task_subtasks')
        .update({'title': title.trim()})
        .eq('id', subtaskId)
        .select('id, task_occurrence_id, title, "position", is_completed, completed_at, created_at')
        .single();

    return _fromRow(row);
  }

  @override
  Future<void> reorder(String taskId, List<String> orderedIds) async {
    // Позиции обновляем по порядку переданных id.
    for (var i = 0; i < orderedIds.length; i++) {
      await _client
          .from('task_subtasks')
          .update({'position': i})
          .eq('id', orderedIds[i])
          .eq('task_occurrence_id', taskId);
    }
  }

  @override
  Future<void> delete(String subtaskId) async {
    await _client.from('task_subtasks').delete().eq('id', subtaskId);
    AppLogger.info('Подзадача удалена: id=$subtaskId');
  }

  TaskSubtask _fromRow(Map<String, dynamic> row) {
    return TaskSubtask(
      id: row['id'] as String,
      taskId: row['task_occurrence_id'] as String,
      title: row['title'] as String,
      position: row['position'] as int,
      isCompleted: row['is_completed'] as bool,
      completedAt: _parseNullable(row['completed_at']),
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  DateTime? _parseNullable(dynamic value) {
    if (value == null) return null;
    return DateTime.parse(value as String);
  }
}
