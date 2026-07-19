import '../entities/create_task_params.dart';
import '../entities/task.dart';
import '../repositories/task_repository.dart';

final class CreateTaskUseCase {
  const CreateTaskUseCase({required this.repository});

  final TaskRepository repository;

  Future<Task> call({required CreateTaskParams params}) {
    final title = params.title.trim();

    if (title.isEmpty) {
      throw const TaskTitleEmptyException();
    }

    if (params.estimatedDurationMinutes <= 0) {
      throw const TaskDurationInvalidException();
    }

    return repository.create(
      params: CreateTaskParams(
        householdId: params.householdId,
        title: title,
        description: params.description?.trim(),
        estimatedDurationMinutes: params.estimatedDurationMinutes,
        plannedFor: params.plannedFor,
        deadline: params.deadline,
      ),
    );
  }
}

final class TaskTitleEmptyException implements Exception {
  const TaskTitleEmptyException();

  @override
  String toString() {
    return 'TaskTitleEmptyException: название задачи не может быть пустым.';
  }
}

final class TaskDurationInvalidException implements Exception {
  const TaskDurationInvalidException();

  @override
  String toString() {
    return 'TaskDurationInvalidException: длительность должна быть больше нуля.';
  }
}
