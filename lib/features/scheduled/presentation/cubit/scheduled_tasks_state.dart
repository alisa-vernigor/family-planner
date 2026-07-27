import 'package:equatable/equatable.dart';

import '../../../households/domain/entities/household_member.dart';
import '../../../tasks/domain/entities/task.dart';

sealed class ScheduledTasksState extends Equatable {
  const ScheduledTasksState();

  @override
  List<Object?> get props => [];
}

final class ScheduledTasksInitial extends ScheduledTasksState {
  const ScheduledTasksInitial();
}

final class ScheduledTasksLoading extends ScheduledTasksState {
  const ScheduledTasksLoading();
}

final class ScheduledTasksLoaded extends ScheduledTasksState {
  const ScheduledTasksLoaded({
    required this.tasks,
    this.members = const [],
  });

  final List<Task> tasks;
  final List<HouseholdMember> members;

  @override
  List<Object?> get props => [tasks, members];
}

final class ScheduledTasksFailure extends ScheduledTasksState {
  const ScheduledTasksFailure({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
