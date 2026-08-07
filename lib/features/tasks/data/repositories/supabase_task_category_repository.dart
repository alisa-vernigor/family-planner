import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:family_planner/core/logging/app_logger.dart';
import 'package:family_planner/features/tasks/domain/entities/create_task_category_params.dart';
import 'package:family_planner/features/tasks/domain/entities/task_category.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_category_repository.dart';

/// Supabase-реализация [TaskCategoryRepository].
///
/// Категории — справочные данные семьи: читаются напрямую (RLS разрешает
/// членам семьи), изменения пишутся сразу в БД (без offline-очереди,
/// т.к. категории не критичны и их мало).
final class SupabaseTaskCategoryRepository implements TaskCategoryRepository {
  SupabaseTaskCategoryRepository({required SupabaseClient client})
    : _client = client;

  final SupabaseClient _client;

  @override
  Future<List<TaskCategory>> getForHousehold(String householdId) async {
    final rows = await _client
        .from('task_categories')
        .select('id, household_id, name, color_hex, icon_name')
        .eq('household_id', householdId)
        .order('name');

    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  Future<TaskCategory> create(CreateTaskCategoryParams params) async {
    final row = await _client
        .from('task_categories')
        .insert({
          'household_id': params.householdId,
          'name': params.name.trim(),
          'color_hex': params.colorHex,
          'icon_name': params.iconName,
        })
        .select('id, household_id, name, color_hex, icon_name')
        .single();

    AppLogger.info('Категория создана: id=${row['id']}');
    return _fromRow(row);
  }

  @override
  Future<void> update(TaskCategory category) async {
    await _client
        .from('task_categories')
        .update({
          'name': category.name.trim(),
          'color_hex': category.colorHex,
          'icon_name': category.iconName,
        })
        .eq('id', category.id);
  }

  @override
  Future<void> delete(String categoryId) async {
    await _client.from('task_categories').delete().eq('id', categoryId);
    AppLogger.info('Категория удалена: id=$categoryId');
  }

  TaskCategory _fromRow(Map<String, dynamic> row) {
    return TaskCategory(
      id: row['id'] as String,
      householdId: row['household_id'] as String,
      name: row['name'] as String,
      colorHex: row['color_hex'] as String?,
      iconName: row['icon_name'] as String?,
    );
  }
}
