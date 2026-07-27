import 'package:equatable/equatable.dart';

import 'task_status.dart';

final class Task extends Equatable {
  const Task({
    required this.id,
    required this.householdId,
    required this.title,
    required this.estimatedDurationMinutes,
    required this.plannedFor,
    required this.allowedMemberIds,
    required this.status,
    required this.createdAt,
    this.description,
    this.assignedMemberId,
    this.pinnedMemberId,
    this.deadline,
    this.completedAt,
    this.updatedAt,
  });

  final String id;
  final String householdId;
  final String title;
  final String? description;
  final int estimatedDurationMinutes;
  final DateTime plannedFor;
  final DateTime? deadline;
  final List<String> allowedMemberIds;
  final String? assignedMemberId;
  final String? pinnedMemberId;
  final TaskStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? updatedAt;

  bool get isCompleted => status == TaskStatus.completed;

  bool get isPinned => pinnedMemberId != null;

  bool canBeCompletedBy(String memberId) {
    return allowedMemberIds.contains(memberId);
  }

  Task copyWith({
    String? id,
    String? householdId,
    String? title,
    Object? description = _sentinel,
    int? estimatedDurationMinutes,
    DateTime? plannedFor,
    Object? deadline = _sentinel,
    List<String>? allowedMemberIds,
    Object? assignedMemberId = _sentinel,
    Object? pinnedMemberId = _sentinel,
    TaskStatus? status,
    DateTime? createdAt,
    Object? completedAt = _sentinel,
  }) {
    return Task(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      title: title ?? this.title,
      description: identical(description, _sentinel) ? this.description : description as String?,
      estimatedDurationMinutes:
          estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      plannedFor: plannedFor ?? this.plannedFor,
      deadline: identical(deadline, _sentinel) ? this.deadline : deadline as DateTime?,
      allowedMemberIds: allowedMemberIds ?? this.allowedMemberIds,
      assignedMemberId: identical(assignedMemberId, _sentinel)
          ? this.assignedMemberId
          : assignedMemberId as String?,
      pinnedMemberId: identical(pinnedMemberId, _sentinel)
          ? this.pinnedMemberId
          : pinnedMemberId as String?,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      completedAt: identical(completedAt, _sentinel) ? this.completedAt : completedAt as DateTime?,
      updatedAt: this.updatedAt,
    );
  }

  static const _sentinel = _Sentinel();

  @override

  @override
  List<Object?> get props {
    return [
      id,
      householdId,
      title,
      description,
      estimatedDurationMinutes,
      plannedFor,
      deadline,
      allowedMemberIds,
      assignedMemberId,
      pinnedMemberId,
      status,
      createdAt,
      completedAt,
      updatedAt,
    ];
  }
}

final class _Sentinel {
  const _Sentinel();
}
