import 'package:equatable/equatable.dart';

import 'task.dart';
import 'task_recurrence.dart';

/// Область применения изменений при редактировании повторяющейся задачи —
/// как в Google Calendar.
enum RecurrenceEditScope {
  /// Только текущий экземпляр, серия не затрагивается.
  onlyThis,

  /// Текущий экземпляр и все последующие (шаблон).
  thisAndFollowing,

  /// Все экземпляры серии (шаблон + история).
  all;

  String get databaseValue {
    return switch (this) {
      RecurrenceEditScope.onlyThis => 'only_this',
      RecurrenceEditScope.thisAndFollowing => 'this_and_following',
      RecurrenceEditScope.all => 'all',
    };
  }
}

/// Параметры обновления повторяющейся задачи.
///
/// Используется, когда пользователь редактирует задачу из серии
/// и выбирает область «эта и последующие» или «все задачи в серии».
/// Обновляет шаблон серии и (при необходимости) экземпляры.
final class UpdateRecurringTaskParams extends Equatable {
  const UpdateRecurringTaskParams({
    required this.task,
    required this.recurrence,
    required this.scope,
    this.recurrenceStartDate,
    this.recurrenceEndDate,
    this.newStartDate,
  });

  /// Экземпляр, с которого открыто редактирование.
  final Task task;

  /// Новое расписание повторения.
  final TaskRecurrence recurrence;

  /// Область применения: серия / этот и последующие / все.
  final RecurrenceEditScope scope;

  /// Новая дата начала повторения (если меняется).
  final DateTime? recurrenceStartDate;

  /// Новая дата окончания повторения (если меняется).
  final DateTime? recurrenceEndDate;

  /// Новая дата, на которую переносится серия (перенос через reschedule).
  ///
  /// Задаётся, когда пользователь переносит повторяющуюся задачу целиком —
  /// тогда вся серия сдвигается на эту дату.
  final DateTime? newStartDate;

  UpdateRecurringTaskParams copyWith({
    Task? task,
    TaskRecurrence? recurrence,
    RecurrenceEditScope? scope,
    Object? recurrenceStartDate = _sentinel,
    Object? recurrenceEndDate = _sentinel,
    Object? newStartDate = _sentinel,
  }) {
    return UpdateRecurringTaskParams(
      task: task ?? this.task,
      recurrence: recurrence ?? this.recurrence,
      scope: scope ?? this.scope,
      recurrenceStartDate: identical(recurrenceStartDate, _sentinel)
          ? this.recurrenceStartDate
          : recurrenceStartDate as DateTime?,
      recurrenceEndDate: identical(recurrenceEndDate, _sentinel)
          ? this.recurrenceEndDate
          : recurrenceEndDate as DateTime?,
      newStartDate: identical(newStartDate, _sentinel)
          ? this.newStartDate
          : newStartDate as DateTime?,
    );
  }

  static const _sentinel = Object();

  @override
  List<Object?> get props => [
    task,
    recurrence,
    scope,
    recurrenceStartDate,
    recurrenceEndDate,
    newStartDate,
  ];
}
