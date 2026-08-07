import 'package:equatable/equatable.dart';

/// Подзадача внутри задачи (`task_subtasks`).
final class TaskSubtask extends Equatable {
  const TaskSubtask({
    required this.id,
    required this.taskId,
    required this.title,
    required this.position,
    required this.isCompleted,
    required this.createdAt,
    this.completedAt,
  });

  final String id;

  /// ID родительской задачи (`task_occurrences.id`).
  final String taskId;
  final String title;

  /// Порядок отображения (0, 1, 2…).
  final int position;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime? completedAt;

  TaskSubtask copyWith({
    String? id,
    String? taskId,
    String? title,
    int? position,
    bool? isCompleted,
    DateTime? createdAt,
    Object? completedAt = _sentinel,
  }) {
    return TaskSubtask(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      title: title ?? this.title,
      position: position ?? this.position,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      completedAt: identical(completedAt, _sentinel)
          ? this.completedAt
          : completedAt as DateTime?,
    );
  }

  TaskSubtask toggle() =>
      copyWith(isCompleted: !isCompleted, completedAt: isCompleted ? null : DateTime.now());

  static const _sentinel = _Sentinel();

  @override
  List<Object?> get props => [
    id,
    taskId,
    title,
    position,
    isCompleted,
    createdAt,
    completedAt,
  ];
}

final class _Sentinel {
  const _Sentinel();
}
