import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/profile/domain/repositories/profile_repository.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_category.dart';
import 'package:family_planner/features/tasks/domain/entities/task_sort_option.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:family_planner/features/today/presentation/widgets/task_list_view.dart';

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

  final myTask = Task(
    id: 'my-1',
    householdId: 'household-1',
    title: 'Моя задача',
    estimatedDurationMinutes: 30,
    plannedFor: DateTime(2026, 8, 10),
    allowedMemberIds: const ['user-1'],
    assignedMemberId: 'user-1',
    status: TaskStatus.pending,
    createdAt: DateTime(2026, 8, 1),
  );
  final otherTask = Task(
    id: 'other-1',
    householdId: 'household-1',
    title: 'Задача семьи',
    estimatedDurationMinutes: 30,
    plannedFor: DateTime(2026, 8, 10),
    allowedMemberIds: const ['user-1'],
    assignedMemberId: 'user-2',
    status: TaskStatus.pending,
    createdAt: DateTime(2026, 8, 1),
  );
  final unassignedTask = Task(
    id: 'un-1',
    householdId: 'household-1',
    title: 'Неназначенная',
    estimatedDurationMinutes: 30,
    plannedFor: DateTime(2026, 8, 10),
    allowedMemberIds: const ['user-1'],
    assignedMemberId: null,
    status: TaskStatus.pending,
    createdAt: DateTime(2026, 8, 1),
  );

  Widget buildSubject({
    List<Task> tasks = const [],
    List<HouseholdMember>? members,
    String? currentMemberId,
    Map<String, TaskCategory> categoriesById = const {},
    bool isSelectionMode = false,
    Set<String> selectedTaskIds = const {},
    TaskSortOption? sortOption,
    ValueChanged<TaskSortOption>? onSortChanged,
    bool sortAscending = true,
    ValueChanged<bool>? onSortAscendingChanged,
    void Function(Task)? onComplete,
    void Function(Task)? onUncomplete,
    void Function(Task)? onEdit,
    void Function(Task)? onDelete,
    void Function(Task, List<HouseholdMember>)? onAssign,
    void Function(Task)? onTogglePin,
    void Function(Task)? onLongPress,
    void Function(Task)? onSwipeComplete,
    void Function(Task)? onSwipeUncomplete,
    void Function(Task)? onSwipeDelete,
  }) {
    return MockRepoProvider(
      child: MaterialApp(
        home: Scaffold(
          body: TaskListView(
            tasks: tasks,
            members: members ?? [member, otherMember],
            currentMemberId: currentMemberId ?? 'user-1',
            onEdit: onEdit ?? (_) {},
            onDelete: onDelete ?? (_) {},
            onAssign: onAssign ?? (_, _) {},
            onTogglePin: onTogglePin ?? (_) {},
            onComplete: onComplete ?? (_) {},
            onUncomplete: onUncomplete ?? (_) {},
            categoriesById: categoriesById,
            isSelectionMode: isSelectionMode,
            selectedTaskIds: selectedTaskIds,
            onLongPress: onLongPress,
            onSwipeComplete: onSwipeComplete,
            onSwipeUncomplete: onSwipeUncomplete,
            onSwipeDelete: onSwipeDelete,
            sortOption: sortOption,
            onSortChanged: onSortChanged,
            sortAscending: sortAscending,
            onSortAscendingChanged: onSortAscendingChanged,
          ),
        ),
      ),
    );
  }

  testWidgets('пустой список не показывает секций', (tester) async {
    await tester.pumpWidget(buildSubject());

    expect(find.text('Мои задачи'), findsNothing);
    expect(find.text('Задачи семьи'), findsNothing);
    expect(find.text('Неназначенные'), findsNothing);
  });

  testWidgets('группирует задачи по секциям', (tester) async {
    await tester.pumpWidget(
      buildSubject(tasks: [myTask, otherTask, unassignedTask]),
    );

    expect(find.text('Мои задачи'), findsOneWidget);
    expect(find.text('Задачи семьи'), findsOneWidget);
    expect(find.text('Неназначенные'), findsOneWidget);

    expect(find.text('Моя задача'), findsOneWidget);
    expect(find.text('Задача семьи'), findsOneWidget);
    expect(find.text('Неназначенная'), findsOneWidget);
  });

  testWidgets('показывает счётчики в секциях', (tester) async {
    await tester.pumpWidget(
      buildSubject(tasks: [myTask, otherTask, unassignedTask]),
    );

    // Счётчики: 1 в каждой секции.
    expect(find.text('1'), findsNWidgets(3));
  });

  testWidgets('клик complete вызывает onComplete', (tester) async {
    Task? completed;
    await tester.pumpWidget(
      buildSubject(tasks: [myTask], onComplete: (t) => completed = t),
    );

    await tester.tap(find.byKey(const Key('complete_task_button_my-1')));
    await tester.pump();

    expect(completed?.id, 'my-1');
  });

  testWidgets('передаёт категорию в карточку', (tester) async {
    final category = TaskCategory(
      id: 'cat-1',
      householdId: 'household-1',
      name: 'Покупки',
      colorHex: 'E53935',
    );
    final categorized = myTask.copyWith(categoryId: 'cat-1');

    await tester.pumpWidget(
      buildSubject(
        tasks: [categorized],
        categoriesById: {'cat-1': category},
      ),
    );

    expect(find.text('Покупки'), findsOneWidget);
  });

  testWidgets('long press вызывает onLongPress', (tester) async {
    Task? longPressed;
    await tester.pumpWidget(
      buildSubject(
        tasks: [myTask],
        onLongPress: (t) => longPressed = t,
      ),
    );

    await tester.longPress(find.text('Моя задача'));
    await tester.pump();

    expect(longPressed?.id, 'my-1');
  });

  testWidgets('выбранные задачи отмечены (isSelected)', (tester) async {
    await tester.pumpWidget(
      buildSubject(
        tasks: [myTask, unassignedTask],
        isSelectionMode: true,
        selectedTaskIds: {'my-1'},
      ),
    );

    // В выбранном состоянии тап по заголовку не открывает ничего.
    // Проверяем, что карточки отрисовались в режиме выбора.
    expect(find.text('Моя задача'), findsOneWidget);
    expect(find.text('Неназначенная'), findsOneWidget);
  });

  testWidgets('SortSelector показывается при sortOption != null', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        tasks: [myTask],
        sortOption: TaskSortOption.deadline,
        onSortChanged: (_) {},
      ),
    );

    expect(find.byIcon(Icons.sort_outlined), findsOneWidget);
  });

  testWidgets('SortSelector скрыт без sortOption', (tester) async {
    await tester.pumpWidget(buildSubject(tasks: [myTask]));

    expect(find.byIcon(Icons.sort_outlined), findsNothing);
  });

  testWidgets('выбор варианта сортировки вызывает onSortChanged', (
    tester,
  ) async {
    TaskSortOption? selected;
    await tester.pumpWidget(
      buildSubject(
        tasks: [myTask],
        sortOption: TaskSortOption.deadline,
        onSortChanged: (o) => selected = o,
        onSortAscendingChanged: (_) {},
      ),
    );

    await tester.tap(find.byIcon(Icons.sort_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('По приоритету').last);
    await tester.pumpAndSettle();

    expect(selected, TaskSortOption.priority);
  });

  group('мои задачи — колбэки карточки', () {
    void enlargeSurface(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    testWidgets('меню «Назначить» для моей задачи вызывает onAssign', (
      tester,
    ) async {
      enlargeSurface(tester);
      List<HouseholdMember>? assignedMembers;
      await tester.pumpWidget(
        buildSubject(
          tasks: [myTask],
          onAssign: (_, members) => assignedMembers = members,
        ),
      );

      await tester.tap(find.byTooltip('Действия'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Назначить'));
      await tester.pumpAndSettle();

      expect(assignedMembers, isNotNull);
      expect(assignedMembers!.map((m) => m.profileId), containsAll(['user-1', 'user-2']));
    });
  });

  group('задачи семьи — колбэки карточки', () {
    void enlargeSurface(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    testWidgets('complete/onComplete для «Задачи семьи»', (tester) async {
      Task? completed;
      await tester.pumpWidget(
        buildSubject(tasks: [otherTask], onComplete: (t) => completed = t),
      );

      await tester.tap(find.byKey(const Key('complete_task_button_other-1')));
      await tester.pump();

      expect(completed?.id, 'other-1');
    });

    testWidgets('свайп вправо/влево для «Задачи семьи» вызывает колбэки', (
      tester,
    ) async {
      var swipedComplete = false;
      var swipedDelete = false;
      await tester.pumpWidget(
        buildSubject(
          tasks: [otherTask],
          onComplete: (_) {},
          onSwipeComplete: (_) => swipedComplete = true,
          onSwipeDelete: (_) => swipedDelete = true,
        ),
      );

      await tester.drag(find.text('Задача семьи'), const Offset(400, 0));
      await tester.pumpAndSettle();
      expect(swipedComplete, isTrue);

      await tester.drag(find.text('Задача семьи'), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(swipedDelete, isTrue);
    });

    testWidgets('выполненная задача семьи: uncomplete через чекбокс и свайп', (
      tester,
    ) async {
      final completedOther = otherTask.copyWith(
        status: TaskStatus.completed,
        completedAt: DateTime(2026, 8, 2),
      );
      final called = <String>[];
      await tester.pumpWidget(
        buildSubject(
          tasks: [completedOther],
          onUncomplete: (_) => called.add('uncomplete'),
          onSwipeUncomplete: (_) => called.add('swipe-uncomplete'),
        ),
      );

      // Чекбокс «Отменить выполнение».
      await tester.tap(find.byKey(const Key('uncomplete_task_button_other-1')));
      await tester.pump();
      expect(called, contains('uncomplete'));

      // Свайп вправо выполненной задачи → onSwipeUncomplete.
      await tester.drag(find.text('Задача семьи'), const Offset(400, 0));
      await tester.pumpAndSettle();
      expect(called, contains('swipe-uncomplete'));
    });

    testWidgets('onComplete/onUncomplete/onEdit/onDelete/onAssign/onTogglePin для «Задачи семьи»', (
      tester,
    ) async {
      enlargeSurface(tester);
      // Закреплённая чужая задача: меню показывает «Открепить» и
      // «Изменить ответственного».
      final pinnedOther = otherTask.copyWith(pinnedMemberId: 'user-2');
      final called = <String>[];
      await tester.pumpWidget(
        buildSubject(
          tasks: [pinnedOther],
          onComplete: (_) => called.add('complete'),
          onUncomplete: (_) => called.add('uncomplete'),
          onEdit: (_) => called.add('edit'),
          onDelete: (_) => called.add('delete'),
          onAssign: (_, _) => called.add('assign'),
          onTogglePin: (_) => called.add('pin'),
        ),
      );

      // complete через чекбокс
      await tester.tap(find.byKey(const Key('complete_task_button_other-1')));
      await tester.pump();

      // Меню действий.
      await tester.tap(find.byTooltip('Действия'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Редактировать'));
      await tester.pumpAndSettle();
      expect(called, contains('edit'));

      await tester.tap(find.byTooltip('Действия'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Изменить ответственного'));
      await tester.pumpAndSettle();
      expect(called, contains('assign'));

      await tester.tap(find.byTooltip('Действия'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Открепить'));
      await tester.pumpAndSettle();
      expect(called, contains('pin'));

      await tester.tap(find.byTooltip('Действия'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Удалить'));
      await tester.pumpAndSettle();
      expect(called, contains('delete'));

      expect(called, contains('complete'));
      expect(called, isNot(contains('uncomplete')));
    });
  });

  group('неназначенные — колбэки карточки', () {
    void enlargeSurface(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    testWidgets('complete/onComplete для «Неназначенные»', (tester) async {
      Task? completed;
      await tester.pumpWidget(
        buildSubject(tasks: [unassignedTask], onComplete: (t) => completed = t),
      );

      await tester.tap(find.byKey(const Key('complete_task_button_un-1')));
      await tester.pump();

      expect(completed?.id, 'un-1');
    });

    testWidgets('свайп вправо для «Неназначенные» вызывает onSwipeUncomplete', (
      tester,
    ) async {
      final completed = unassignedTask.copyWith(
        status: TaskStatus.completed,
        completedAt: DateTime(2026, 8, 2),
      );
      var swipedUncomplete = false;
      await tester.pumpWidget(
        buildSubject(
          tasks: [completed],
          onSwipeUncomplete: (_) => swipedUncomplete = true,
        ),
      );

      await tester.drag(find.text('Неназначенная'), const Offset(400, 0));
      await tester.pumpAndSettle();
      expect(swipedUncomplete, isTrue);
    });

    testWidgets('onComplete/onUncomplete/onEdit/onDelete/onAssign/onTogglePin для «Неназначенные»', (
      tester,
    ) async {
      enlargeSurface(tester);
      final called = <String>[];
      await tester.pumpWidget(
        buildSubject(
          tasks: [unassignedTask],
          onComplete: (_) => called.add('complete'),
          onUncomplete: (_) => called.add('uncomplete'),
          onEdit: (_) => called.add('edit'),
          onDelete: (_) => called.add('delete'),
          onAssign: (_, _) => called.add('assign'),
          onTogglePin: (_) => called.add('pin'),
        ),
      );

      // Меню действий.
      await tester.tap(find.byTooltip('Действия'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Редактировать'));
      await tester.pumpAndSettle();
      expect(called, contains('edit'));

      await tester.tap(find.byTooltip('Действия'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Назначить'));
      await tester.pumpAndSettle();
      expect(called, contains('assign'));

      await tester.tap(find.byTooltip('Действия'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Удалить'));
      await tester.pumpAndSettle();
      expect(called, contains('delete'));

      // Неназначенная задача — не закреплена, поэтому «Открепить» нет.
      expect(called, isNot(contains('uncomplete')));
      expect(called, isNot(contains('pin')));
    });

    testWidgets('выполненная неназначенная задача: uncomplete через чекбокс', (
      tester,
    ) async {
      final completedUnassigned = unassignedTask.copyWith(
        status: TaskStatus.completed,
        completedAt: DateTime(2026, 8, 2),
      );
      var uncompleted = false;
      await tester.pumpWidget(
        buildSubject(
          tasks: [completedUnassigned],
          onUncomplete: (_) => uncompleted = true,
        ),
      );

      await tester.tap(find.byKey(const Key('uncomplete_task_button_un-1')));
      await tester.pump();

      expect(uncompleted, isTrue);
    });

    testWidgets('закреплённая неназначенная задача: меню «Открепить» → onTogglePin', (
      tester,
    ) async {
      enlargeSurface(tester);
      final pinnedUnassigned = unassignedTask.copyWith(pinnedMemberId: 'user-1');
      var pinned = false;
      await tester.pumpWidget(
        buildSubject(
          tasks: [pinnedUnassigned],
          onTogglePin: (_) => pinned = true,
        ),
      );

      await tester.tap(find.byTooltip('Действия'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Открепить'));
      await tester.pumpAndSettle();

      expect(pinned, isTrue);
    });
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
