import 'package:equatable/equatable.dart';

import '../../../households/domain/entities/household_member.dart';
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
  const TodayTasksLoaded({
    required this.tasks,
    this.members = const [],
  });

  final List<Task> tasks;
  final List<HouseholdMember> members;

  bool get isEmpty => tasks.isEmpty;

  @override
  List<Object?> get props => [tasks, members];
}

final class TodayTasksFailure extends TodayTasksState {
  const TodayTasksFailure({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
