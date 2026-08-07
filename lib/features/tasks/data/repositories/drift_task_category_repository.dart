import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:family_planner/core/database/app_database.dart';
import 'package:family_planner/core/database/daos/task_categories_dao.dart';
import 'package:family_planner/core/logging/app_logger.dart';
import 'package:family_planner/core/services/connectivity_service.dart';
import 'package:family_planner/features/tasks/domain/entities/create_task_category_params.dart';
import 'package:family_planner/features/tasks/domain/entities/task_category.dart'
    as domain;
import 'package:family_planner/features/tasks/domain/repositories/task_category_repository.dart';

/// Drift-backed [TaskCategoryRepository] with offline-first support.
///
/// - **Reads** are served from the local SQLite cache; when online, fetches
///   from Supabase into the cache first.
/// - **Writes** hit Supabase directly (categories are small reference data,
///   not queued offline — on failure the error surfaces to the caller).
class DriftTaskCategoryRepository implements TaskCategoryRepository {
  DriftTaskCategoryRepository({
    required AppDatabase database,
    required SupabaseClient supabaseClient,
    required ConnectivityService connectivityService,
  })  : _categoryDao = database.taskCategoriesDao,
        _supabase = supabaseClient,
        _connectivity = connectivityService;

  final TaskCategoriesDao _categoryDao;
  final SupabaseClient _supabase;
  final ConnectivityService _connectivity;

  @override
  Future<List<domain.TaskCategory>> getForHousehold(
    String householdId,
  ) async {
    if (_connectivity.currentOnline) {
      try {
        final rows = await _supabase
            .from('task_categories')
            .select('id, household_id, name, color_hex, icon_name')
            .eq('household_id', householdId)
            .order('name');
        await _categoryDao.upsertAll(rows.map((row) => TaskCategoriesCompanion(
          id: Value(row['id'] as String),
          householdId: Value(row['household_id'] as String),
          name: Value(row['name'] as String),
          colorHex: Value(row['color_hex'] as String?),
          iconName: Value(row['icon_name'] as String?),
        )).toList(growable: false));
      } catch (e) {
        AppLogger.debug('Supabase category fetch failed, using cache: $e');
      }
    }
    final rows = await _categoryDao.getForHousehold(householdId);
    return rows.map(_toDomain).toList(growable: false);
  }

  @override
  Future<domain.TaskCategory> create(CreateTaskCategoryParams params) async {
    final row = await _supabase
        .from('task_categories')
        .insert({
          'household_id': params.householdId,
          'name': params.name.trim(),
          'color_hex': params.colorHex,
          'icon_name': params.iconName,
        })
        .select('id, household_id, name, color_hex, icon_name')
        .single();

    await _categoryDao.upsert(TaskCategoriesCompanion(
      id: Value(row['id'] as String),
      householdId: Value(row['household_id'] as String),
      name: Value(row['name'] as String),
      colorHex: Value(row['color_hex'] as String?),
      iconName: Value(row['icon_name'] as String?),
    ));

    return _fromRow(row);
  }

  @override
  Future<void> update(domain.TaskCategory category) async {
    await _supabase
        .from('task_categories')
        .update({
          'name': category.name.trim(),
          'color_hex': category.colorHex,
          'icon_name': category.iconName,
        })
        .eq('id', category.id);

    await _categoryDao.upsert(TaskCategoriesCompanion(
      id: Value(category.id),
      householdId: Value(category.householdId),
      name: Value(category.name.trim()),
      colorHex: Value(category.colorHex),
      iconName: Value(category.iconName),
    ));
  }

  @override
  Future<void> delete(String categoryId) async {
    await _supabase.from('task_categories').delete().eq('id', categoryId);
    await _categoryDao.deleteCategory(categoryId);
  }

  domain.TaskCategory _toDomain(TaskCategory row) {
    return domain.TaskCategory(
      id: row.id,
      householdId: row.householdId,
      name: row.name,
      colorHex: row.colorHex,
      iconName: row.iconName,
    );
  }

  domain.TaskCategory _fromRow(Map<String, dynamic> row) {
    return domain.TaskCategory(
      id: row['id'] as String,
      householdId: row['household_id'] as String,
      name: row['name'] as String,
      colorHex: row['color_hex'] as String?,
      iconName: row['icon_name'] as String?,
    );
  }
}
