import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/households/domain/repositories/household_repository.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_category.dart';
import 'package:family_planner/features/tasks/domain/entities/task_recurrence.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_category_repository.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/today/presentation/pages/today_page.dart';

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

  final day = DateTime.now();

  Task buildTask({
    String id = 'task-1',
    String title = 'Купить продукты',
    String? categoryId,
    String? assignedMemberId = 'member-1',
    String? pinnedMemberId,
    String? templateId,
    TaskRecurrence? recurrence,
    bool? templateActive,
    TaskStatus status = TaskStatus.pending,
    DateTime? completedAt,
  }) {
    return Task(
      id: id,
      householdId: 'household-1',
      title: title,
      estimatedDurationMinutes: 30,
      plannedFor: day,
      allowedMemberIds: const ['member-1'],
      assignedMemberId: assignedMemberId,
      pinnedMemberId: pinnedMemberId,
      status: status,
      createdAt: DateTime(2026, 7, 19),
      categoryId: categoryId,
      templateId: templateId,
      recurrence: recurrence,
      templateActive: templateActive,
      completedAt: completedAt,
    );
  }

  const member = HouseholdMember(
    profileId: 'member-1',
    displayName: 'Анна',
    role: 'owner',
  );

  void stubCommon({
    List<Task>? tasks,
    bool fail = false,
  }) {
    when(
      () => mocks.household.getMembers(householdId: any(named: 'householdId')),
    ).thenAnswer((_) async => const [member]);
    when(
      () => mocks.task.getForDay(
        householdId: any(named: 'householdId'),
        day: any(named: 'day'),
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
          body: TodayPage(
            householdId: 'household-1',
            householdName: 'Семья',
            currentMemberId: 'member-1',
          ),
        ),
      ),
    );
  }

  testWidgets('показывает спиннер во время загрузки', (tester) async {
    stubCommon(tasks: const []);
    when(
      () => mocks.task.getForDay(
        householdId: any(named: 'householdId'),
        day: any(named: 'day'),
      ),
    ).thenAnswer((_) => Completer<List<Task>>().future);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('пустой список показывает «На сегодня задач нет»', (
    tester,
  ) async {
    stubCommon(tasks: const []);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('На сегодня задач нет'), findsOneWidget);
    expect(find.text('Создать задачу'), findsOneWidget);
  });

  testWidgets('загруженные задачи показываются списком', (tester) async {
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

    expect(find.text('Не удалось загрузить задачи на сегодня.'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);
  });

  testWidgets('«Повторить» перезагружает задачи', (tester) async {
    var fail = true;
    when(
      () => mocks.household.getMembers(householdId: any(named: 'householdId')),
    ).thenAnswer((_) async => const [member]);
    when(
      () => categoryRepo.getForHousehold(any()),
    ).thenAnswer((_) async => const <TaskCategory>[]);
    when(
      () => mocks.task.getForDay(
        householdId: any(named: 'householdId'),
        day: any(named: 'day'),
      ),
    ).thenAnswer((_) async {
      if (fail) throw Exception('boom');
      return [buildTask()];
    });

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Повторить'), findsOneWidget);

    fail = false;
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();

    expect(find.text('Купить продукты'), findsOneWidget);
  });

  testWidgets('показывает FAB создания задачи и авто-распределения', (
    tester,
  ) async {
    stubCommon(tasks: const []);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.byTooltip('Создать задачу'), findsWidgets);
    expect(find.byTooltip('Автораспределить задачи'), findsOneWidget);
  });

  testWidgets('тап по FAB открывает CreateTaskSheet', (tester) async {
    stubCommon(tasks: const []);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Создать задачу').first);
    await tester.pumpAndSettle();

    // CreateTaskSheet показывает заголовок создания задачи.
    expect(find.text('Новая задача'), findsOneWidget);
  });

  testWidgets('категории передаются в карточку', (tester) async {
    stubCommon(tasks: [buildTask(categoryId: 'cat-1')]);
    when(
      () => categoryRepo.getForHousehold('household-1'),
    ).thenAnswer(
      (_) async => const [
        TaskCategory(
          id: 'cat-1',
          householdId: 'household-1',
          name: 'Кухня',
          colorHex: 'FF5722',
        ),
      ],
    );

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Кухня'), findsOneWidget);
  });

  // ── Поведение: меню карточки / свайпы / batch / FAB ─────────────

  testWidgets('меню «Пропустить»: диалог → задача исчезает, patchStatus(skipped)', (
    tester,
  ) async {
    final task = buildTask();
    stubCommon(tasks: [task]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Действия'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Пропустить'));
    await tester.pumpAndSettle();

    expect(find.text('Пропустить задачу?'), findsOneWidget);

    await tester.tap(find.text('Пропустить').last);
    await tester.pumpAndSettle();

    verify(
      () => mocks.task.patchStatus(
        taskId: task.id,
        status: TaskStatus.skipped.name,
        completedByMemberId: null,
        completedAt: null,
      ),
    ).called(1);
    expect(find.text('Задача пропущена.'), findsOneWidget);
    expect(find.text('Купить продукты'), findsNothing);
  });

  testWidgets('отмена диалога пропуска не вызывает patchStatus', (tester) async {
    final task = buildTask();
    stubCommon(tasks: [task]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Действия'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Пропустить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    verifyNever(
      () => mocks.task.patchStatus(
        taskId: any(named: 'taskId'),
        status: any(named: 'status'),
        completedByMemberId: any(named: 'completedByMemberId'),
        completedAt: any(named: 'completedAt'),
      ),
    );
    expect(find.text('Купить продукты'), findsOneWidget);
  });

  testWidgets('меню «Удалить»: диалог → repository.delete + задача удалена', (
    tester,
  ) async {
    final task = buildTask();
    stubCommon(tasks: [task]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Действия'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();

    expect(find.text('Удалить задачу?'), findsOneWidget);

    await tester.tap(find.text('Удалить').last);
    await tester.pumpAndSettle();

    verify(() => mocks.task.delete(taskId: task.id)).called(1);
    expect(find.text('Купить продукты'), findsNothing);
  });

  testWidgets('меню «Дублировать» создаёт копию и показывает снекбар', (
    tester,
  ) async {
    final task = buildTask();
    stubCommon(tasks: [task]);
    when(
      () => mocks.task.create(params: any(named: 'params')),
    ).thenAnswer(
      (_) async => task.copyWith(id: 'task-copy'),
    );

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Действия'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дублировать'));
    await tester.pumpAndSettle();

    verify(() => mocks.task.create(params: any(named: 'params'))).called(1);
    expect(find.text('Задача скопирована.'), findsOneWidget);
  });

  testWidgets('серия: меню «Поставить на паузу» → pauseTemplate + снекбар', (
    tester,
  ) async {
    final task = buildTask(
      templateId: 'template-1',
      recurrence: const TaskRecurrence.daily(),
      templateActive: true,
    );
    stubCommon(tasks: [task]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Действия'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Поставить на паузу'));
    await tester.pumpAndSettle();

    verify(() => mocks.task.pauseTemplate(templateId: 'template-1')).called(1);
    expect(find.text('Серия поставлена на паузу.'), findsOneWidget);
  });

  testWidgets('серия на паузе: меню «Возобновить серию» → resumeTemplate', (
    tester,
  ) async {
    final task = buildTask(
      templateId: 'template-1',
      recurrence: const TaskRecurrence.daily(),
      templateActive: false,
    );
    stubCommon(tasks: [task]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Серия на паузе'), findsOneWidget);

    await tester.tap(find.byTooltip('Действия'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Возобновить серию'));
    await tester.pumpAndSettle();

    verify(() => mocks.task.resumeTemplate(templateId: 'template-1')).called(1);
    expect(find.text('Серия возобновлена.'), findsOneWidget);
  });

  testWidgets('меню «Перенести»: date picker → save с новой датой', (
    tester,
  ) async {
    final task = buildTask();
    stubCommon(tasks: [task]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Действия'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Перенести'));
    await tester.pumpAndSettle();

    expect(find.text('Перенести задачу'), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    verify(
      () => mocks.task.save(
        any(that: isA<Task>().having((t) => t.id, 'id', task.id)),
      ),
    ).called(1);
  });

  testWidgets('меню «Назначить»: bottom sheet → tap участника → save', (
    tester,
  ) async {
    final task = buildTask(assignedMemberId: null);
    stubCommon(tasks: [task]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Действия'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Назначить'));
    await tester.pumpAndSettle();

    expect(find.text('Назначить ответственного'), findsOneWidget);

    await tester.tap(find.text('Анна'));
    await tester.pumpAndSettle();

    verify(
      () => mocks.task.save(
        any(that: isA<Task>().having((t) => t.assignedMemberId, 'assigned', 'member-1')),
      ),
    ).called(1);
  });

  testWidgets('закреплённая задача: меню «Открепить» → save(unpinned)', (
    tester,
  ) async {
    final task = buildTask(pinnedMemberId: 'member-1');
    stubCommon(tasks: [task]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Закреплено'), findsOneWidget);

    await tester.tap(find.byTooltip('Действия'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Открепить'));
    await tester.pumpAndSettle();

    verify(
      () => mocks.task.save(
        any(that: isA<Task>().having((t) => t.pinnedMemberId, 'pinned', null)),
      ),
    ).called(1);
  });

  testWidgets('long press включает batch-режим: «Выполнить (1)» → complete', (
    tester,
  ) async {
    final task = buildTask();
    stubCommon(tasks: [task]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Купить продукты'));
    await tester.pumpAndSettle();

    expect(find.text('Выполнить (1)'), findsOneWidget);

    await tester.tap(find.text('Выполнить (1)'));
    await tester.pumpAndSettle();

    verify(
      () => mocks.task.patchStatus(
        taskId: task.id,
        status: TaskStatus.completed.name,
        completedByMemberId: 'member-1',
        completedAt: any(named: 'completedAt'),
        assignedMemberId: any(named: 'assignedMemberId'),
      ),
    ).called(1);
    expect(find.text('Выполнено задач: 1'), findsOneWidget);
  });

  testWidgets('batch-режим: «Отменить» выходит из режима и убирает панель', (
    tester,
  ) async {
    stubCommon(tasks: [buildTask()]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Купить продукты'));
    await tester.pumpAndSettle();

    expect(find.text('Выполнить (1)'), findsOneWidget);

    await tester.tap(find.text('Отменить'));
    await tester.pumpAndSettle();

    expect(find.text('Выполнить (1)'), findsNothing);
  });

  testWidgets('свайп вправо выполняет задачу (complete → patchStatus)', (
    tester,
  ) async {
    final task = buildTask();
    stubCommon(tasks: [task]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.drag(
      find.text('Купить продукты'),
      const Offset(400, 0),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    verify(
      () => mocks.task.patchStatus(
        taskId: task.id,
        status: TaskStatus.completed.name,
        completedByMemberId: 'member-1',
        completedAt: any(named: 'completedAt'),
        assignedMemberId: any(named: 'assignedMemberId'),
      ),
    ).called(1);
  });

  testWidgets('свайп влево открывает диалог удаления', (tester) async {
    final task = buildTask();
    stubCommon(tasks: [task]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.drag(
      find.text('Купить продукты'),
      const Offset(-400, 0),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(find.text('Удалить задачу?'), findsOneWidget);
  });

  testWidgets('тап по чекбоксу выполняет задачу и показывает снекбар', (
    tester,
  ) async {
    final task = buildTask();
    stubCommon(tasks: [task]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('complete_task_button_${task.id}')));
    await tester.pumpAndSettle();

    verify(
      () => mocks.task.patchStatus(
        taskId: task.id,
        status: TaskStatus.completed.name,
        completedByMemberId: 'member-1',
        completedAt: any(named: 'completedAt'),
        assignedMemberId: any(named: 'assignedMemberId'),
      ),
    ).called(1);
    expect(find.text('Задача выполнена. Отличная работа!'), findsOneWidget);
  });

  testWidgets('выполненная задача: «Отменить выполнение» → patchStatus(pending)', (
    tester,
  ) async {
    final task = buildTask(
      status: TaskStatus.completed,
      completedAt: DateTime.now(),
    );
    stubCommon(tasks: [task]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('uncomplete_task_button_${task.id}')));
    await tester.pumpAndSettle();

    verify(
      () => mocks.task.patchStatus(
        taskId: task.id,
        status: TaskStatus.pending.name,
        completedByMemberId: null,
        completedAt: null,
      ),
    ).called(1);
  });

  testWidgets('FAB авто-распределения: распределяет и показывает снекбар', (
    tester,
  ) async {
    stubCommon(tasks: [buildTask(assignedMemberId: null)]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Автораспределить задачи'));
    await tester.pumpAndSettle();

    expect(find.text('Задачи распределены между участниками.'), findsOneWidget);
    // После распределения список перезагружается.
    verify(
      () => mocks.task.getForDay(
        householdId: any(named: 'householdId'),
        day: any(named: 'day'),
      ),
    ).called(2);
  });

  testWidgets('CreateTaskSheet: создание задачи → silent reload', (tester) async {
    stubCommon(tasks: const []);
    when(
      () => mocks.task.create(params: any(named: 'params')),
    ).thenAnswer(
      (_) async => buildTask(id: 'new-task', title: 'Новая задача'),
    );

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Создать задачу').first);
    await tester.pumpAndSettle();

    expect(find.text('Новая задача'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Название'),
      'Купить молоко',
    );
    await tester.tap(find.text('Создать задачу').last);
    await tester.pumpAndSettle();

    verify(() => mocks.task.create(params: any(named: 'params'))).called(1);
    // После создания — тихая перезагрузка (getForDay вызывается повторно).
    verify(
      () => mocks.task.getForDay(
        householdId: any(named: 'householdId'),
        day: any(named: 'day'),
      ),
    ).called(2);
  });

  testWidgets('EditTaskSheet: сохранение изменений → silent reload', (
    tester,
  ) async {
    final task = buildTask();
    stubCommon(tasks: [task]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Действия'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Редактировать'));
    await tester.pumpAndSettle();

    expect(find.text('Редактировать задачу'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('edit_task_title_field')),
      'Обновлённая задача',
    );
    await tester.tap(find.byKey(const Key('save_task_button')));
    await tester.pumpAndSettle();

    verify(
      () => mocks.task.save(
        any(that: isA<Task>().having((t) => t.title, 'title', 'Обновлённая задача')),
      ),
    ).called(1);
    verify(
      () => mocks.task.getForDay(
        householdId: any(named: 'householdId'),
        day: any(named: 'day'),
      ),
    ).called(2);
  });
}
