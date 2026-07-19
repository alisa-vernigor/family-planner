import 'package:equatable/equatable.dart';

final class CreateTaskParams extends Equatable {
  const CreateTaskParams({
    required this.householdId,
    required this.title,
    required this.estimatedDurationMinutes,
    required this.plannedFor,
    this.description,
    this.deadline,
  });

  final String householdId;
  final String title;
  final String? description;
  final int estimatedDurationMinutes;
  final DateTime plannedFor;
  final DateTime? deadline;

  @override
  List<Object?> get props => [
    householdId,
    title,
    description,
    estimatedDurationMinutes,
    plannedFor,
    deadline,
  ];
}
