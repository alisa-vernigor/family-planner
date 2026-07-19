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
    this.deadline,
    this.completedAt,
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
  final TaskStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;

  bool get isCompleted => status == TaskStatus.completed;

  bool canBeCompletedBy(String memberId) {
    return allowedMemberIds.contains(memberId);
  }

  Task copyWith({
    String? id,
    String? householdId,
    String? title,
    String? description,
    int? estimatedDurationMinutes,
    DateTime? plannedFor,
    DateTime? deadline,
    List<String>? allowedMemberIds,
    String? assignedMemberId,
    TaskStatus? status,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return Task(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      title: title ?? this.title,
      description: description ?? this.description,
      estimatedDurationMinutes:
          estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      plannedFor: plannedFor ?? this.plannedFor,
      deadline: deadline ?? this.deadline,
      allowedMemberIds: allowedMemberIds ?? this.allowedMemberIds,
      assignedMemberId: assignedMemberId ?? this.assignedMemberId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

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
      status,
      createdAt,
      completedAt,
    ];
  }
}
