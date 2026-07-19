import 'package:equatable/equatable.dart';

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
  const ScheduledTasksLoaded({required this.tasks});

  final List<Task> tasks;

  @override
  List<Object?> get props => [tasks];
}

final class ScheduledTasksFailure extends ScheduledTasksState {
  const ScheduledTasksFailure({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
