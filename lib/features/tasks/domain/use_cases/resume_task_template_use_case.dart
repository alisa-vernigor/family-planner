import '../repositories/task_repository.dart';

/// Возобновляет повторяющуюся задачу после паузы: генерирует экземпляры
/// серии на 30 дней вперёд.
final class ResumeTaskTemplateUseCase {
  const ResumeTaskTemplateUseCase({required this.repository});

  final TaskRepository repository;

  Future<void> call({required String templateId}) {
    return repository.resumeTemplate(templateId: templateId);
  }
}
