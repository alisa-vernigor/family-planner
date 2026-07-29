import 'task.dart';

/// Варианты сортировки задач на экранах списка.
enum TaskSortOption {
  deadline('По сроку'),
  priority('По приоритету'),
  duration('По длительности'),
  title('По названию'),
  createdAt('По дате создания'),
  plannedFor('По плановой дате');

  const TaskSortOption(this.label);

  final String label;

  /// Сортирует список задач согласно выбранному варианту.
  static List<Task> apply(List<Task> tasks, TaskSortOption option) {
    final sorted = List<Task>.from(tasks);
    switch (option) {
      case TaskSortOption.deadline:
        sorted.sort((a, b) {
          final now = DateTime.now();
          final aOverdue = a.deadline != null && a.deadline!.isBefore(now);
          final bOverdue = b.deadline != null && b.deadline!.isBefore(now);
          if (aOverdue && !bOverdue) return -1;
          if (!aOverdue && bOverdue) return 1;
          if (a.deadline != null && b.deadline != null) {
            return a.deadline!.compareTo(b.deadline!);
          }
          if (a.deadline != null) return -1;
          if (b.deadline != null) return 1;
          return 0;
        });
      case TaskSortOption.priority:
        sorted.sort(
          (a, b) => a.effectivePriority.value.compareTo(b.effectivePriority.value),
        );
      case TaskSortOption.duration:
        sorted.sort(
          (a, b) => a.estimatedDurationMinutes.compareTo(b.estimatedDurationMinutes),
        );
      case TaskSortOption.title:
        sorted.sort((a, b) => a.title.compareTo(b.title));
      case TaskSortOption.createdAt:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case TaskSortOption.plannedFor:
        sorted.sort((a, b) => a.plannedFor.compareTo(b.plannedFor));
    }
    return sorted;
  }
}
