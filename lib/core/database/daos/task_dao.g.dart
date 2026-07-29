// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_dao.dart';

// ignore_for_file: type=lint
mixin _$TaskDaoMixin on DatabaseAccessor<AppDatabase> {
  $TaskOccurrencesTable get taskOccurrences => attachedDatabase.taskOccurrences;
  TaskDaoManager get managers => TaskDaoManager(this);
}

class TaskDaoManager {
  final _$TaskDaoMixin _db;
  TaskDaoManager(this._db);
  $$TaskOccurrencesTableTableManager get taskOccurrences =>
      $$TaskOccurrencesTableTableManager(
        _db.attachedDatabase,
        _db.taskOccurrences,
      );
}
