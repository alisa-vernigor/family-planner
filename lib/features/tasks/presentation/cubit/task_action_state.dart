import 'package:equatable/equatable.dart';

import '../../domain/entities/task.dart';

/// Состояние для операций uncomplete и delete задач.
sealed class TaskActionState extends Equatable {
  const TaskActionState();

  @override
  List<Object?> get props => [];
}

final class TaskActionInitial extends TaskActionState {
  const TaskActionInitial();
}

final class TaskActionInProgress extends TaskActionState {
  const TaskActionInProgress();
}

final class TaskActionSuccess extends TaskActionState {
  const TaskActionSuccess({required this.task});

  final Task task;

  @override
  List<Object?> get props => [task];
}

final class TaskActionFailure extends TaskActionState {
  const TaskActionFailure({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
