import 'package:equatable/equatable.dart';

import '../../domain/entities/task.dart';

sealed class UpdateTaskState extends Equatable {
  const UpdateTaskState();

  @override
  List<Object?> get props => [];
}

final class UpdateTaskInitial extends UpdateTaskState {
  const UpdateTaskInitial();
}

final class UpdateTaskInProgress extends UpdateTaskState {
  const UpdateTaskInProgress();
}

final class UpdateTaskSuccess extends UpdateTaskState {
  const UpdateTaskSuccess({required this.task});

  final Task task;

  @override
  List<Object?> get props => [task];
}

final class UpdateTaskFailure extends UpdateTaskState {
  const UpdateTaskFailure({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
