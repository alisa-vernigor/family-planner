import 'package:equatable/equatable.dart';

import '../../domain/entities/task.dart';

sealed class CreateTaskState extends Equatable {
  const CreateTaskState();

  @override
  List<Object?> get props => [];
}

final class CreateTaskInitial extends CreateTaskState {
  const CreateTaskInitial();
}

final class CreateTaskInProgress extends CreateTaskState {
  const CreateTaskInProgress();
}

final class CreateTaskSuccess extends CreateTaskState {
  const CreateTaskSuccess({required this.task});

  final Task task;

  @override
  List<Object?> get props => [task];
}

final class CreateTaskFailure extends CreateTaskState {
  const CreateTaskFailure({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
