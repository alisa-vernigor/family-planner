import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/households/domain/repositories/household_repository.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_category.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_category_repository.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/scheduled/presentation/pages/scheduled_page.dart';

import '../../../../helpers/mock_repository_factory.dart';

final class MockTaskCategoryRepository extends Mock
    implements TaskCategoryRepository {}

void main() {
  late MockRepositoryFactory mocks;
  late MockTaskCategoryRepository categoryRepo;

  setUpAll(() {
    registerFallbackValue(
      Task(
        id: 'fallback',
        householdId: 'household-1',
        title: 'fallback',
        estimatedDurationMinutes: 30,
        plannedFor: DateTime(2026, 7, 20),
        allowedMemberIds: const ['member-1'],
        status: TaskStatus.pending,
        createdAt: DateTime(2026, 7, 19),
      ),
    );
  });

  setUp(() {
    mocks = MockRepositoryFactory();
    categoryRepo = MockTaskCategoryRepository();
  });

  Task buildTask({
    String id = 'task-1',
    String title = 'Купить продукты',
    DateTime? plannedFor,
    String? assignedMemberId = 'member-1',
    String? description,
  }) {
    return Task(
      id: id,
      householdId: 'household-1',
      title: title,
      description: description,
      estimatedDurationMinutes: 30,
      plannedFor: plannedFor ?? DateTime(2026, 8, 1, 10),
      allowedMemberIds: const ['member-1'],
      assignedMemberId: assignedMemberId,
      status: TaskStatus.pending,
      createdAt: DateTime(2026, 7, 19),
    );
  }

  const member = HouseholdMember(
    profileId: 'member-1',
    displayName: 'Анна',
    role: 'owner',
  );

  void stubCommon({List<Task>? tasks, bool fail = false}) {
    when(
      () => mocks.household.getMembers(householdId: any(named: 'householdId')),
    ).thenAnswer((_) async => const [member]);
    when(
      () => mocks.task.getAllPending(
        householdId: any(named: 'householdId'),
      ),
    ).thenAnswer(
      (_) async => fail ? throw Exception('boom') : (tasks ?? const <Task>[]),
    );
    when(
      () => categoryRepo.getForHousehold(any()),
    ).thenAnswer((_) async => const <TaskCategory>[]);
  }

  Widget buildSubject() {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<TaskRepository>(create: (_) => mocks.task),
        RepositoryProvider<HouseholdRepository>(
          create: (_) => mocks.household,
        ),
        RepositoryProvider<TaskCategoryRepository>(
          create: (_) => categoryRepo,
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ScheduledPage(
            householdId: 'household-1',
            currentMemberId: 'member-1',
          ),
        ),
      ),
    );
  }

  testWidgets('показывает спиннер во время загрузки', (tester) async {
    final tasksCompleter = Completer<List<Task>>();
    when(
      () => mocks.household.getMembers(householdId: any(named: 'householdId')),
    ).thenAnswer((_) async => const [member]);
    when(
      () => mocks.task.getAllPending(
        householdId: any(named: 'householdId'),
      ),
    ).thenAnswer((_) => tasksCompleter.future);
    when(
      () => categoryRepo.getForHousehold(any()),
    ).thenAnswer((_) async => const <TaskCategory>[]);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Завершаем future, чтобы не осталось висящих Timer'ов от .timeout(15s).
    tasksCompleter.complete(const <Task>[]);
    await tester.pumpAndSettle();
  });

  testWidgets('пустой список показывает «Запланированных задач нет»', (
    tester,
  ) async {
    stubCommon(tasks: const []);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Запланированных задач нет'), findsOneWidget);
    expect(find.text('Создать задачу'), findsWidgets);
  });

  testWidgets('задачи группируются по дате и показываются', (tester) async {
    stubCommon(tasks: [buildTask(), buildTask(id: 'task-2', title: 'Полить цветы')]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Купить продукты'), findsOneWidget);
    expect(find.text('Полить цветы'), findsOneWidget);
  });

  testWidgets('ошибка загрузки показывает «Повторить»', (tester) async {
    stubCommon(fail: true);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(
      find.text('Не удалось загрузить запланированные задачи.'),
      findsOneWidget,
    );
    expect(find.text('Повторить'), findsOneWidget);
  });

  testWidgets('фильтры Все/Мои/Без назначения работают', (tester) async {
    stubCommon(tasks: [
      buildTask(title: 'Моя задача'),
      buildTask(id: 'task-2', title: 'Без исполнителя', assignedMemberId: null),
    ]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    // «Все» — обе задачи.
    expect(find.text('Моя задача'), findsOneWidget);
    expect(find.text('Без исполнителя'), findsOneWidget);

    // «Мои» — только назначенная на текущего участника.
    await tester.tap(find.text('Мои'));
    await tester.pumpAndSettle();

    expect(find.text('Моя задача'), findsOneWidget);
    expect(find.text('Без исполнителя'), findsNothing);

    // «Без назначения» — только неназначенная.
    await tester.tap(find.text('Без назначения'));
    await tester.pumpAndSettle();

    expect(find.text('Моя задача'), findsNothing);
    expect(find.text('Без исполнителя'), findsOneWidget);
  });

  testWidgets('поиск фильтрует задачи по названию', (tester) async {
    stubCommon(tasks: [buildTask(title: 'Купить продукты'), buildTask(id: 'task-2', title: 'Полить цветы')]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('task_search_field')),
      'продукты',
    );
    await tester.pumpAndSettle();

    expect(find.text('Купить продукты'), findsOneWidget);
    expect(find.text('Полить цветы'), findsNothing);
  });

  testWidgets('переключение в режим матрицы работает', (tester) async {
    stubCommon(tasks: [buildTask()]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Матрица Эйзенхауэра'));
    await tester.pumpAndSettle();

    // Матрица показывает квадранты Эйзенхауэра.
    expect(find.text('Срочно и важно'), findsWidgets);
  });

  testWidgets('FAB создания задачи открывает CreateTaskSheet', (tester) async {
    stubCommon(tasks: const []);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Создать задачу').first);
    await tester.pumpAndSettle();

    expect(find.text('Новая задача'), findsOneWidget);
  });
}
