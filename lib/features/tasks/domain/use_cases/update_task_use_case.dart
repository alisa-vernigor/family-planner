import '../entities/task.dart';
import '../repositories/task_repository.dart';

final class UpdateTaskUseCase {
  const UpdateTaskUseCase({required this.repository});

  final TaskRepository repository;

  Future<void> call({required Task task}) async {
    final title = task.title.trim();

    if (title.isEmpty) {
      throw ArgumentError.value(
        task.title,
        'task.title',
        'Название задачи не может быть пустым.',
      );
    }

    if (task.estimatedDurationMinutes <= 0) {
      throw ArgumentError.value(
        task.estimatedDurationMinutes,
        'task.estimatedDurationMinutes',
        'Длительность должна быть больше нуля.',
      );
    }

    await repository.save(
      task.copyWith(
        title: title,
        description: task.description?.trim().isEmpty ?? true
            ? null
            : task.description?.trim(),
      ),
    );
  }
}
