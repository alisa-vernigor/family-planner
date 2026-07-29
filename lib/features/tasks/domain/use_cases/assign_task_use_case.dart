import '../entities/task.dart';
import '../repositories/task_repository.dart';

/// Назначает задачу участнику семьи.
///
/// Если [memberId] == null или пустая строка — снимает назначение.
/// Если участник ещё не в allowedMemberIds — добавляет его.
/// Сохраняет изменения через [repository.save].
final class AssignTaskUseCase {
  const AssignTaskUseCase({required this.repository});

  final TaskRepository repository;

  Future<Task> call({required Task task, required String? memberId}) async {
    final updated = task.copyWith(
      assignedMemberId: memberId?.isEmpty ?? true ? null : memberId,
    );

    if (memberId != null && memberId.isNotEmpty) {
      if (!task.allowedMemberIds.contains(memberId)) {
        await repository.addAllowedMember(
          taskId: task.id,
          memberId: memberId,
        );
      }
    }

    await repository.save(updated);
    return updated;
  }
}
