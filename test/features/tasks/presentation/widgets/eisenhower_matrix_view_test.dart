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
    void Function(Task)? onEdit,
    void Function(Task)? onDelete,
    void Function(Task, List<HouseholdMember>)? onAssign,
    void Function(Task)? onTogglePin,
  }) {
    return MockRepoProvider(
      child: MaterialApp(
        home: Scaffold(
          body: EisenhowerMatrixView(
            tasks: tasks,
            members: members ?? [member, otherMember],
            currentMemberId: currentMemberId ?? 'user-1',
            onEdit: onEdit ?? (_) {},
            onDelete: onDelete ?? (_) {},
            onAssign: onAssign ?? (_, _) {},
            onTogglePin: onTogglePin ?? (_) {},
            onComplete: onComplete ?? (_) {},
            onSwipeComplete: (_) {},
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

  testWidgets('клик по мини-карточке в grid вызывает onEdit', (tester) async {
    setWidth(tester, 800);
    Task? edited;
    await tester.pumpWidget(
      buildSubject(tasks: [urgentImportant], onEdit: (t) => edited = t),
    );

    await tester.tap(find.text('Срочно-важно'));
    await tester.pump();

    expect(edited?.id, 't-1');
  });

  testWidgets('в grid drag & drop: onAcceptWithDetails вызывает onUpdatePriority', (
    tester,
  ) async {
    setWidth(tester, 800);
    Task? dropped;
    EisenhowerPriority? newPriority;
    await tester.pumpWidget(
      buildSubject(
        tasks: [urgentImportant],
        onUpdatePriority: (task, priority) {
          dropped = task;
          newPriority = priority;
        },
      ),
    );

    // Найти DragTarget (квадрант) и перетащить задачу.
    final source = tester.getCenter(find.text('Срочно-важно'));
    final targets = find.byType(DragTarget<Task>);
    expect(targets, findsWidgets);
    final destination = tester.getCenter(targets.first);

    final gesture = await tester.startGesture(source);
    await tester.pump(const Duration(milliseconds: 600)); // long-press
    await gesture.moveTo(destination);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(dropped?.id, 't-1');
    expect(newPriority, isNotNull);
  });

  testWidgets('drag & drop в узком режиме переносит задачу между квадрантами', (
    tester,
  ) async {
    setWidth(tester, 400);
    final called = <String>[];
    await tester.pumpWidget(
      buildSubject(
        tasks: [urgentImportant],
        onUpdatePriority: (task, priority) =>
            called.add('${task.id}:${priority.name}'),
      ),
    );

    final dragTarget = find.byType(DragTarget<Task>);
    expect(dragTarget, findsWidgets);

    // Квадрант 1 — «Срочно и важно» (содержит задачу), первый DragTarget.
    final source = tester.getCenter(find.text('Срочно-важно').first);
    final destination = tester.getCenter(dragTarget.at(1));

    final gesture = await tester.startGesture(source);
    await tester.pump(const Duration(milliseconds: 600)); // long-press
    await gesture.moveTo(destination);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(called, isNotEmpty);
    expect(called.first, startsWith('t-1:'));
  });

  testWidgets('клик по чекбоксу в узком режиме (TaskCard) вызывает onComplete', (
    tester,
  ) async {
    setWidth(tester, 400);
    Task? completed;
    await tester.pumpWidget(
      buildSubject(tasks: [urgentImportant], onComplete: (t) => completed = t),
    );

    // TaskCard в узком режиме: чекбокс с ключом complete_task_button_t-1.
    await tester.tap(find.byKey(const Key('complete_task_button_t-1')));
    await tester.pump();

    expect(completed?.id, 't-1');
  });

  testWidgets('меню TaskCard в узком режиме вызывает onEdit/onDelete/onAssign', (
    tester,
  ) async {
    setWidth(tester, 400);
    final called = <String>[];
    await tester.pumpWidget(
      buildSubject(
        tasks: [urgentImportant],
        onEdit: (_) => called.add('edit'),
        onDelete: (_) => called.add('delete'),
        onAssign: (_, _) => called.add('assign'),
      ),
    );

    // TaskCard: меню через tooltip «Действия» (PopupMenuButton без ключа).
    await tester.tap(find.byTooltip('Действия'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Редактировать'));
    await tester.pumpAndSettle();
    expect(called, contains('edit'));

    await tester.tap(find.byTooltip('Действия'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    expect(called, contains('delete'));

    await tester.tap(find.byTooltip('Действия'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Назначить'));
    await tester.pumpAndSettle();
    expect(called, contains('assign'));
    expect(called, ['edit', 'delete', 'assign']);
  });

  testWidgets('мини-карточка в grid: тап по чекбоксу вызывает onComplete', (
    tester,
  ) async {
    setWidth(tester, 800);
    Task? completed;
    await tester.pumpWidget(
      buildSubject(tasks: [urgentImportant], onComplete: (t) => completed = t),
    );

    // В grid-режиме _MiniTaskCard: иконка radio_button_unchecked_outlined.
    await tester.tap(find.byIcon(Icons.radio_button_unchecked_outlined));
    await tester.pump();

    expect(completed?.id, 't-1');
  });

  testWidgets('закреплённая задача в узком режиме: пункт «Открепить» вызывает onTogglePin', (
    tester,
  ) async {
    setWidth(tester, 400);
    final pinned = urgentImportant.copyWith(pinnedMemberId: 'user-1');
    bool? toggled;
    await tester.pumpWidget(
      buildSubject(tasks: [pinned], onTogglePin: (_) => toggled = true),
    );

    // TaskCard: меню → «Открепить» (задача закреплена).
    await tester.tap(find.byTooltip('Действия'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Открепить'));
    await tester.pumpAndSettle();

    expect(toggled, isTrue);
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
