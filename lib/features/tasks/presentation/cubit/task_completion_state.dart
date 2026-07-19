import 'package:equatable/equatable.dart';

import '../../domain/entities/task.dart';

sealed class TaskCompletionState extends Equatable {
  const TaskCompletionState();

  @override
  List<Object?> get props => [];
}

final class TaskCompletionInitial extends TaskCompletionState {
  const TaskCompletionInitial();
}

final class TaskCompletionInProgress extends TaskCompletionState {
  const TaskCompletionInProgress();
}

final class TaskCompletionSuccess extends TaskCompletionState {
  const TaskCompletionSuccess({required this.task});

  final Task task;

  @override
  List<Object?> get props => [task];
}

final class TaskCompletionFailure extends TaskCompletionState {
  const TaskCompletionFailure({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
