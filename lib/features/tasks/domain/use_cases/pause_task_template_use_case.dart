import '../repositories/task_repository.dart';

/// Ставит повторяющуюся задачу на паузу: будущие экземпляры серии
/// удаляются (на сервере), история сохраняется.
final class PauseTaskTemplateUseCase {
  const PauseTaskTemplateUseCase({required this.repository});

  final TaskRepository repository;

  Future<void> call({required String templateId}) {
    return repository.pauseTemplate(templateId: templateId);
  }
}
