// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_subtasks_dao.dart';

// ignore_for_file: type=lint
mixin _$TaskSubtasksDaoMixin on DatabaseAccessor<AppDatabase> {
  $TaskSubtasksTable get taskSubtasks => attachedDatabase.taskSubtasks;
  TaskSubtasksDaoManager get managers => TaskSubtasksDaoManager(this);
}

class TaskSubtasksDaoManager {
  final _$TaskSubtasksDaoMixin _db;
  TaskSubtasksDaoManager(this._db);
  $$TaskSubtasksTableTableManager get taskSubtasks =>
      $$TaskSubtasksTableTableManager(_db.attachedDatabase, _db.taskSubtasks);
}
