import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/profile/domain/repositories/profile_repository.dart';
import 'package:family_planner/features/tasks/domain/entities/eisenhower_priority.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:family_planner/features/tasks/presentation/widgets/eisenhower_matrix_view.dart';

import '../../../../helpers/load_roboto_font.dart';
import '../../../../helpers/mock_repository_factory.dart';

void main() {
  setUpAll(loadRobotoFont);

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

  Task buildTask({
    String id = 'task-1',
    String title = 'Задача',
    EisenhowerPriority priority = EisenhowerPriority.urgentImportant,
    TaskStatus status = TaskStatus.pending,
  }) {
    return Task(
      id: id,
      householdId: 'household-1',
      title: title,
      estimatedDurationMinutes: 30,
      plannedFor: DateTime(2026, 8, 10),
      allowedMemberIds: const ['user-1'],
      assignedMemberId: 'user-1',
      status: status,
      createdAt: DateTime(2026, 8, 1),
      priority: priority,
    );
  }

  final urgentImportant = buildTask(
    id: 't-1',
    title: 'Срочно-важно',
    priority: EisenhowerPriority.urgentImportant,
  );
  final notUrgentImportant = buildTask(
    id: 't-2',
    title: 'Несрочно-важно',
    priority: EisenhowerPriority.notUrgentImportant,
  );
  final urgentNotImportant = buildTask(
    id: 't-3',
    title: 'Срочно-неважно',
    priority: EisenhowerPriority.urgentNotImportant,
  );
  final notUrgentNotImportant = buildTask(
    id: 't-4',
    title: 'Несрочно-неважно',
    priority: EisenhowerPriority.notUrgentNotImportant,
  );

  Widget buildSubject({
    List<Task> tasks = const [],
    List<HouseholdMember>? members,
    String? currentMemberId,
    void Function(Task, EisenhowerPriority)? onUpdatePriority,
    void Function(Task)? onComplete,
  }) {
    return MockRepoProvider(
      child: MaterialApp(
        home: Scaffold(
          body: EisenhowerMatrixView(
            tasks: tasks,
            members: members ?? [member, otherMember],
            currentMemberId: currentMemberId ?? 'user-1',
            onEdit: (_) {},
            onDelete: (_) {},
            onAssign: (_, _) {},
            onTogglePin: (_) {},
            onComplete: onComplete ?? (_) {},
            onUncomplete: (_) {},
            onSwipeComplete: (_) {},
            onSwipeUncomplete: (_) {},
            onSwipeDelete: (_) {},
            onUpdatePriority: onUpdatePriority,
          ),
        ),
      ),
    );
  }

  void setWidth(WidgetTester tester, double width) {
    tester.view.physicalSize = Size(width, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('показывает все 4 квадранта на узком экране', (tester) async {
    setWidth(tester, 400);
    await tester.pumpWidget(buildSubject());

    expect(find.text('Срочно и важно'), findsOneWidget);
    expect(find.text('Не срочно, но важно'), findsOneWidget);
    expect(find.text('Срочно, но не важно'), findsOneWidget);
    expect(find.text('Не срочно и не важно'), findsOneWidget);
    // Подзаголовки.
    expect(find.text('Делать в первую очередь'), findsOneWidget);
    expect(find.text('Запланировать'), findsOneWidget);
    expect(find.text('Делегировать'), findsOneWidget);
    expect(find.text('По возможности'), findsOneWidget);
  });

  testWidgets('пустой список показывает «Нет задач» в каждом квадранте', (
    tester,
  ) async {
    setWidth(tester, 400);
    await tester.pumpWidget(buildSubject());

    expect(find.text('Нет задач'), findsNWidgets(4));
  });

  testWidgets('задачи распределяются по квадрантам (узкий экран)', (
    tester,
  ) async {
    setWidth(tester, 400);
    await tester.pumpWidget(
      buildSubject(
        tasks: [
          urgentImportant,
          notUrgentImportant,
          urgentNotImportant,
          notUrgentNotImportant,
        ],
      ),
    );

    expect(find.text('Срочно-важно'), findsOneWidget);
    expect(find.text('Несрочно-важно'), findsOneWidget);
    expect(find.text('Срочно-неважно'), findsOneWidget);
    expect(find.text('Несрочно-неважно'), findsOneWidget);
  });

  testWidgets('счётчики показывают количество задач в квадрантах', (
    tester,
  ) async {
    setWidth(tester, 400);
    await tester.pumpWidget(
      buildSubject(
        tasks: [
          urgentImportant,
          urgentImportant.copyWith(id: 't-5', title: 'Ещё одна'),
        ],
      ),
    );

    // В квадранте «Срочно и важно» счётчик 2.
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('выполненные задачи не попадают в квадранты', (tester) async {
    setWidth(tester, 400);
    final completed = urgentImportant.copyWith(
      status: TaskStatus.completed,
      completedAt: DateTime(2026, 8, 2),
    );
    await tester.pumpWidget(buildSubject(tasks: [completed]));

    expect(find.text('Срочно-важно'), findsNothing);
    expect(find.text('Нет задач'), findsNWidgets(4));
  });

  testWidgets('клик по чекбоксу вызывает onComplete', (tester) async {
    setWidth(tester, 400);
    Task? completed;
    await tester.pumpWidget(
      buildSubject(tasks: [urgentImportant], onComplete: (t) => completed = t),
    );

    await tester.tap(find.byKey(const Key('complete_task_button_t-1')));
    await tester.pump();

    expect(completed?.id, 't-1');
  });

  testWidgets('широкий экран показывает grid-ячейки без подзаголовков', (
    tester,
  ) async {
    setWidth(tester, 800);
    await tester.pumpWidget(
      buildSubject(
        tasks: [
          urgentImportant,
          notUrgentImportant,
          urgentNotImportant,
          notUrgentNotImportant,
        ],
      ),
    );

    // В grid-режиме подзаголовки не показываются.
    expect(find.text('Делать в первую очередь'), findsNothing);

    // Заголовки квадрантов видны.
    expect(find.text('Срочно и важно'), findsOneWidget);
    expect(find.text('Не срочно и не важно'), findsOneWidget);
  });

  testWidgets('в grid-режиме задачи отображаются как мини-карточки', (
    tester,
  ) async {
    setWidth(tester, 800);
    await tester.pumpWidget(buildSubject(tasks: [urgentImportant]));

    expect(find.text('Срочно-важно'), findsOneWidget);
    // Мини-карточка показывает длительность.
    expect(find.text('30м'), findsOneWidget);
  });

  testWidgets('в grid-режиме пустые ячейки показывают «Нет задач»', (
    tester,
  ) async {
    setWidth(tester, 800);
    await tester.pumpWidget(buildSubject());

    expect(find.text('Нет задач'), findsNWidgets(4));
  });

  testWidgets('drag & drop: при onUpdatePriority есть LongPressDraggable и DragTarget', (
    tester,
  ) async {
    setWidth(tester, 800);
    await tester.pumpWidget(
      buildSubject(
        tasks: [urgentImportant],
        onUpdatePriority: (_, _) {},
      ),
    );

    expect(
      find.byWidgetPredicate((w) => w is LongPressDraggable<Task>),
      findsWidgets,
    );
    expect(
      find.byWidgetPredicate((w) => w is DragTarget<Task>),
      findsWidgets,
    );
  });

  testWidgets('onUpdatePriority=null — нет drag-обёрток', (tester) async {
    setWidth(tester, 400);
    await tester.pumpWidget(buildSubject(tasks: [urgentImportant]));

    expect(
      find.byWidgetPredicate((w) => w is LongPressDraggable<Task>),
      findsNothing,
    );
    expect(
      find.byWidgetPredicate((w) => w is DragTarget<Task>),
      findsNothing,
    );
  });

  testWidgets('задача с plannedTime показывает время в мини-карточке', (
    tester,
  ) async {
    setWidth(tester, 800);
    final withTime = urgentImportant.copyWith(
      plannedTime: const Duration(hours: 9, minutes: 30),
    );
    await tester.pumpWidget(buildSubject(tasks: [withTime]));

    expect(find.text('09:30'), findsOneWidget);
  });

  testWidgets('задача без длительности не показывает «0м» в мини-карточке', (
    tester,
  ) async {
    setWidth(tester, 800);
    final zeroDuration = urgentImportant.copyWith(estimatedDurationMinutes: 0);
    await tester.pumpWidget(buildSubject(tasks: [zeroDuration]));

    expect(find.text('0м'), findsNothing);
  });
}

/// Оборачивает в RepositoryProvider&lt;ProfileRepository&gt; для TaskCard.
final class MockRepoProvider extends StatelessWidget {
  const MockRepoProvider({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<ProfileRepository>(
      create: (_) => MockProfileRepository(),
      child: child,
    );
  }
}
