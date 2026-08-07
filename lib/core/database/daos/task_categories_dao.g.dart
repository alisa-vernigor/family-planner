// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_categories_dao.dart';

// ignore_for_file: type=lint
mixin _$TaskCategoriesDaoMixin on DatabaseAccessor<AppDatabase> {
  $TaskCategoriesTable get taskCategories => attachedDatabase.taskCategories;
  TaskCategoriesDaoManager get managers => TaskCategoriesDaoManager(this);
}

class TaskCategoriesDaoManager {
  final _$TaskCategoriesDaoMixin _db;
  TaskCategoriesDaoManager(this._db);
  $$TaskCategoriesTableTableManager get taskCategories =>
      $$TaskCategoriesTableTableManager(
        _db.attachedDatabase,
        _db.taskCategories,
      );
}
