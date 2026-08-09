import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/scheduled/presentation/widgets/scheduled_task_card.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_category.dart';
import 'package:family_planner/features/tasks/domain/entities/task_recurrence.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';

void main() {
  final member = HouseholdMember(
    profileId: 'user-1',
    displayName: 'Анна',
    role: 'member',
  );
  final otherMember = HouseholdMember(
    profileId: 'user-2',
    displayName: 'Влад',
    role: 'owner',
  );

  final baseTask = Task(
    id: 'task-1',
    householdId: 'household-1',
    title: 'Задача',
    description: 'Описание задачи',
    estimatedDurationMinutes: 45,
    plannedFor: DateTime(2026, 8, 10),
    allowedMemberIds: const ['user-1'],
    assignedMemberId: 'user-1',
    status: TaskStatus.pending,
    createdAt: DateTime(2026, 8, 1),
  );

  Widget buildSubject({
    Task? task,
    List<HouseholdMember>? members,
    String? currentMemberId,
    VoidCallback? onEdit,
    VoidCallback? onAssign,
    VoidCallback? onTogglePin,
    VoidCallback? onDelete,
    VoidCallback? onReschedule,
    VoidCallback? onDuplicate,
    VoidCallback? onTogglePause,
    VoidCallback? onSkip,
    TaskCategory? category,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ScheduledTaskCard(
          task: task ?? baseTask,
          members: members ?? [member, otherMember],
          currentMemberId: currentMemberId ?? 'user-1',
          formatDate: (d) => '10.08.2026',
          onEdit: onEdit ?? () {},
          onAssign: onAssign ?? () {},
          onTogglePin: onTogglePin ?? () {},
          onDelete: onDelete ?? () {},
          onReschedule: onReschedule,
          onDuplicate: onDuplicate,
          onTogglePause: onTogglePause,
          onSkip: onSkip,
          category: category,
        ),
      ),
    );
  }

  testWidgets('показывает заголовок, дату, длительность, исполнителя', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    expect(find.text('Задача'), findsOneWidget);
    expect(find.text('Описание задачи'), findsOneWidget);
    expect(find.text('10.08.2026'), findsOneWidget);
    expect(find.text('45 мин'), findsOneWidget);
    expect(find.text('Анна'), findsOneWidget);
  });

  testWidgets('показывает категорию чипом', (tester) async {
    await tester.pumpWidget(
      buildSubject(
        category: const TaskCategory(
          id: 'cat-1',
          householdId: 'household-1',
          name: 'Покупки',
          colorHex: 'E53935',
        ),
      ),
    );

    expect(find.text('Покупки'), findsOneWidget);
  });

  testWidgets('повторяющаяся задача показывает бейджи «Повтор» и даты', (
    tester,
  ) async {
    final recurring = baseTask.copyWith(
      templateId: 'template-1',
      recurrence: const TaskRecurrence.daily(),
    );
    await tester.pumpWidget(buildSubject(task: recurring));

    expect(find.text('Повтор'), findsOneWidget);
  });

  testWidgets('задача на паузе показывает бейдж «Серия на паузе»', (
    tester,
  ) async {
    final paused = baseTask.copyWith(
      templateId: 'template-1',
      recurrence: const TaskRecurrence.daily(),
      templateActive: false,
    );
    await tester.pumpWidget(buildSubject(task: paused));

    expect(find.text('Серия на паузе'), findsOneWidget);
  });

  testWidgets('закреплённая задача показывает «Закреплено»', (tester) async {
    final pinned = baseTask.copyWith(pinnedMemberId: 'user-1');
    await tester.pumpWidget(buildSubject(task: pinned));

    expect(find.text('Закреплено'), findsOneWidget);
  });

  testWidgets('задача с временем показывает plannedTimeLabel', (tester) async {
    final withTime = baseTask.copyWith(
      plannedTime: const Duration(hours: 9, minutes: 30),
    );
    await tester.pumpWidget(buildSubject(task: withTime));

    expect(find.text('09:30'), findsOneWidget);
  });

  testWidgets('назначенный исполнитель вне списка участников показывает «Участник»', (
    tester,
  ) async {
    final unassigned = baseTask.copyWith(assignedMemberId: 'ghost-user');
    await tester.pumpWidget(buildSubject(task: unassigned, members: [member]));

    expect(find.text('Участник'), findsOneWidget);
  });

  group('меню карточки', () {
    testWidgets('вызов edit через меню', (tester) async {
      var edited = false;
      await tester.pumpWidget(buildSubject(onEdit: () => edited = true));

      await tester.tap(find.byKey(const Key('task_menu_task-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Редактировать'));
      await tester.pumpAndSettle();

      expect(edited, isTrue);
    });

    testWidgets('вызов assign через меню', (tester) async {
      var assigned = false;
      await tester.pumpWidget(buildSubject(onAssign: () => assigned = true));

      await tester.tap(find.byKey(const Key('task_menu_task-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Назначить'));
      await tester.pumpAndSettle();

      expect(assigned, isTrue);
    });

    testWidgets('вызов delete через меню', (tester) async {
      var deleted = false;
      await tester.pumpWidget(buildSubject(onDelete: () => deleted = true));

      await tester.tap(find.byKey(const Key('task_menu_task-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Удалить'));
      await tester.pumpAndSettle();

      expect(deleted, isTrue);
    });

    testWidgets('перенос/дублирование/пауза/пропуск видны при наличии колбэков', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          onReschedule: () {},
          onDuplicate: () {},
          onTogglePause: () {},
          onSkip: () {},
        ),
      );

      await tester.tap(find.byKey(const Key('task_menu_task-1')));
      await tester.pumpAndSettle();

      expect(find.text('Перенести'), findsOneWidget);
      expect(find.text('Дублировать'), findsOneWidget);
      expect(find.text('Поставить на паузу'), findsOneWidget);
      expect(find.text('Пропустить'), findsOneWidget);
    });

    testWidgets('закреплённая задача показывает «Открепить»', (tester) async {
      final pinned = baseTask.copyWith(pinnedMemberId: 'user-1');
      var unpinned = false;
      await tester.pumpWidget(
        buildSubject(task: pinned, onTogglePin: () => unpinned = true),
      );

      await tester.tap(find.byKey(const Key('task_menu_task-1')));
      await tester.pumpAndSettle();

      expect(find.text('Открепить'), findsOneWidget);

      await tester.tap(find.text('Открепить'));
      await tester.pumpAndSettle();

      expect(unpinned, isTrue);
    });

    testWidgets('серия на паузе в меню показывает «Возобновить серию»', (
      tester,
    ) async {
      final paused = baseTask.copyWith(
        templateId: 'template-1',
        recurrence: const TaskRecurrence.daily(),
        templateActive: false,
      );
      await tester.pumpWidget(
        buildSubject(task: paused, onTogglePause: () {}),
      );

      await tester.tap(find.byKey(const Key('task_menu_task-1')));
      await tester.pumpAndSettle();

      expect(find.text('Возобновить серию'), findsOneWidget);
    });

    testWidgets('обычная задача без колбэков не показывает доп. пункты', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.byKey(const Key('task_menu_task-1')));
      await tester.pumpAndSettle();

      expect(find.text('Перенести'), findsNothing);
      expect(find.text('Дублировать'), findsNothing);
      expect(find.text('Пропустить'), findsNothing);
      expect(find.text('Поставить на паузу'), findsNothing);
    });
  });
}
