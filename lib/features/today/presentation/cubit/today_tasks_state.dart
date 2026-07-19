import 'package:equatable/equatable.dart';

import '../../../tasks/domain/entities/task.dart';

sealed class TodayTasksState extends Equatable {
  const TodayTasksState();

  @override
  List<Object?> get props => [];
}

final class TodayTasksInitial extends TodayTasksState {
  const TodayTasksInitial();
}

final class TodayTasksLoading extends TodayTasksState {
  const TodayTasksLoading();
}

final class TodayTasksLoaded extends TodayTasksState {
  const TodayTasksLoaded({required this.tasks});

  final List<Task> tasks;

  bool get isEmpty => tasks.isEmpty;

  @override
  List<Object?> get props => [tasks];
}

final class TodayTasksFailure extends TodayTasksState {
  const TodayTasksFailure({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
