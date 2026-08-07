import 'package:equatable/equatable.dart';

/// Входные данные для создания подзадачи.
final class CreateTaskSubtaskParams extends Equatable {
  const CreateTaskSubtaskParams({
    required this.taskId,
    required this.title,
  });

  final String taskId;
  final String title;

  @override
  List<Object?> get props => [taskId, title];
}
