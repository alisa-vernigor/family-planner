import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/scheduled/presentation/pages/scheduled_page.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';

void main() {
  Task task({
    String title = 'Купить продукты',
    String? description,
  }) {
    return Task(
      id: 'task-1',
      householdId: 'household-1',
      title: title,
      description: description,
      estimatedDurationMinutes: 30,
      plannedFor: DateTime(2026, 7, 22),
      allowedMemberIds: const ['member-1'],
      status: TaskStatus.pending,
      createdAt: DateTime(2026, 7, 19),
    );
  }

  group('ScheduledPage.matchesSearchQuery', () {
    test('пустой запрос возвращает true', () {
      expect(ScheduledPage.matchesSearchQuery(task(), ''), isTrue);
      expect(ScheduledPage.matchesSearchQuery(task(), '   '), isTrue);
    });

    test('ищет по названию case-insensitive', () {
      final t = task(title: 'Помыть Окна');
      expect(ScheduledPage.matchesSearchQuery(t, 'окна'), isTrue);
      expect(ScheduledPage.matchesSearchQuery(t, 'ПОМЫТЬ'), isTrue);
      expect(ScheduledPage.matchesSearchQuery(t, 'несуществующее'), isFalse);
    });

    test('ищет по описанию', () {
      final t = task(description: 'Купить молоко и хлеб');
      expect(ScheduledPage.matchesSearchQuery(t, 'молоко'), isTrue);
      expect(ScheduledPage.matchesSearchQuery(t, 'хлеб'), isTrue);
      expect(ScheduledPage.matchesSearchQuery(t, 'сыр'), isFalse);
    });

    test('не падает, если описание null', () {
      expect(
        ScheduledPage.matchesSearchQuery(task(description: null), 'молоко'),
        isFalse,
      );
    });
  });
}
