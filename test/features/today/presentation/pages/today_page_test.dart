import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/households/domain/repositories/household_repository.dart';
import 'package:family_planner/features/tasks/domain/entities/create_task_params.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_category.dart';
import 'package:family_planner/features/tasks/domain/entities/task_recurrence.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:family_planner/features/tasks/domain/entities/update_recurring_task_params.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_category_repository.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/today/presentation/pages/today_page.dart';

import '../../../../helpers/load_roboto_font.dart';
import '../../../../helpers/mock_repository_factory.dart';

final class MockTaskCategoryRepository extends Mock
    implements TaskCategoryRepository {}

void main() {
  late MockRepositoryFactory mocks;
  late MockTaskCategoryRepository categoryRepo;

  setUpAll(() async {
    await loadRobotoFont();
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
    registerFallbackValue(
      CreateTaskParams(
        householdId: 'household-1',
        title: 'fallback',
        estimatedDurationMinutes: 30,
        plannedFor: DateTime(2026, 7, 20),
      ),
    );
    registerFallbackValue(
      UpdateRecurringTaskParams(
        task: Task(
          id: 'fallback',
          householdId: 'household-1',
          title: 'fallback',
          estimatedDurationMinutes: 30,
          plannedFor: DateTime(2026, 7, 20),
          allowedMemberIds: const ['member-1'],
          status: TaskStatus.pending,
          createdAt: DateTime(2026, 7, 19),
        ),
        recurrence: const TaskRecurrence.daily(),
        scope: RecurrenceEditScope.all,
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
    // void-возвращающие методы мока без стаба возвращают null,
    // и `await` падает (null не является Future<void>). Стабим заранее.
    when(
      () => mocks.task.save(any()),
    ).thenAnswer((_) async {});
    when(
      () => mocks.task.patchStatus(
        taskId: any(named: 'taskId'),
        status: any(named: 'status'),
        completedByMemberId: any(named: 'completedByMemberId'),
        completedAt: any(named: 'completedAt'),
        assignedMemberId: any(named: 'assignedMemberId'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mocks.task.delete(taskId: any(named: 'taskId')),
    ).thenAnswer((_) async {});
    when(
      () => mocks.task.addAllowedMember(
        taskId: any(named: 'taskId'),
        memberId: any(named: 'memberId'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mocks.task.pauseTemplate(templateId: any(named: 'templateId')),
    ).thenAnswer((_) async {});
    when(
      () => mocks.task.resumeTemplate(templateId: any(named: 'templateId')),
    ).thenAnswer((_) async {});
    when(
      () => mocks.task.updateTemplate(params: any(named: 'params')),
    ).thenAnswer((_) async {});
  }

  Widget buildSubject({String householdId = 'household-1'}) {
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
            householdId: householdId,
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
    // 1 — первичная загрузка, 2 — внутри DistributeTasksUseCase,
    // 3 — load() после распределения.
    verify(
      () => mocks.task.getForDay(
        householdId: any(named: 'householdId'),
        day: any(named: 'day'),
      ),
    ).called(3);
  });

  testWidgets('CreateTaskSheet: создание задачи → silent reload', (tester) async {
    // Форма создания — высокая; задаём высокий вьюпорт, чтобы кнопка
    // «Создать задачу» была на экране.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

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
    // Форма выше экрана — прокручиваем к кнопке «Создать задачу».
    await tester.ensureVisible(find.text('Создать задачу').last);
    await tester.pumpAndSettle();
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
    // Редактор — высокая форма; задаём высокий вьюпорт, чтобы кнопка
    // сохранения была на экране.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

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
    // Форма выше экрана — прокручиваем к кнопке сохранения.
    await tester.ensureVisible(find.byKey(const Key('save_task_button')));
    await tester.pumpAndSettle();
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

  // ── Ошибки операций: откат + reload ─────────────────────────

  testWidgets('удаление: ошибка репозитория → откат + reload + снекбар', (
    tester,
  ) async {
    final task = buildTask();
    stubCommon(tasks: [task]);
    when(() => mocks.task.delete(taskId: any(named: 'taskId'))).thenThrow(
      Exception('delete failed'),
    );

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Действия'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить').last);
    await tester.pumpAndSettle();

    // Снекбар об ошибке от TaskActionsCubit (TaskActionFailure).
    expect(find.text('Не удалось удалить задачу.'), findsOneWidget);
    // Откат — задача снова в списке.
    expect(find.text('Купить продукты'), findsOneWidget);
  });

  testWidgets('пропуск: ошибка репозитория → откат + reload', (tester) async {
    final task = buildTask();
    stubCommon(tasks: [task]);
    when(
      () => mocks.task.patchStatus(
        taskId: any(named: 'taskId'),
        status: any(named: 'status'),
        completedByMemberId: any(named: 'completedByMemberId'),
        completedAt: any(named: 'completedAt'),
      ),
    ).thenThrow(Exception('skip failed'));

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Действия'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Пропустить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Пропустить').last);
    await tester.pumpAndSettle();

    expect(find.text('Купить продукты'), findsOneWidget);
  });

  testWidgets('назначение: ошибка → снекбар и reload', (tester) async {
    final task = buildTask(assignedMemberId: null);
    stubCommon(tasks: [task]);
    when(() => mocks.task.save(any())).thenThrow(Exception('assign failed'));
    // addAllowedMember стабим из stubCommon.

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Действия'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Назначить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Анна'));
    await tester.pumpAndSettle();

    expect(find.text('Не удалось назначить ответственного.'), findsOneWidget);
    // Откат — задача вернулась в список.
    expect(find.text('Купить продукты'), findsOneWidget);
  });

  testWidgets('открепление: ошибка → снекбар и reload', (tester) async {
    final task = buildTask(pinnedMemberId: 'member-1');
    stubCommon(tasks: [task]);
    when(() => mocks.task.save(any())).thenThrow(Exception('unpin failed'));

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Действия'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Открепить'));
    await tester.pumpAndSettle();

    expect(find.text('Не удалось открепить задачу.'), findsOneWidget);
    expect(find.text('Купить продукты'), findsOneWidget);
  });

  testWidgets('перенос: ошибка → снекбар и reload', (tester) async {
    final task = buildTask();
    stubCommon(tasks: [task]);
    when(() => mocks.task.save(any())).thenThrow(Exception('resched failed'));

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Действия'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Перенести'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Не удалось перенести задачу.'), findsOneWidget);
    expect(find.text('Купить продукты'), findsOneWidget);
  });

  testWidgets('дублирование: ошибка → снекбар и reload', (tester) async {
    final task = buildTask();
    stubCommon(tasks: [task]);
    when(() => mocks.task.create(params: any(named: 'params'))).thenThrow(
      Exception('dup failed'),
    );

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Действия'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дублировать'));
    await tester.pumpAndSettle();

    expect(find.text('Не удалось скопировать задачу.'), findsOneWidget);
    expect(find.text('Купить продукты'), findsOneWidget);
  });

  testWidgets('пауза серии: ошибка → снекбар и reload', (tester) async {
    final task = buildTask(
      templateId: 'template-1',
      recurrence: const TaskRecurrence.daily(),
      templateActive: true,
    );
    stubCommon(tasks: [task]);
    when(
      () => mocks.task.pauseTemplate(templateId: any(named: 'templateId')),
    ).thenThrow(Exception('pause failed'));

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Действия'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Поставить на паузу'));
    await tester.pumpAndSettle();

    expect(find.text('Не удалось изменить состояние серии.'), findsOneWidget);
    expect(find.text('Купить продукты'), findsOneWidget);
  });

  testWidgets('дублирование серии: снекбар «Серия скопирована»', (
    tester,
  ) async {
    final task = buildTask(
      templateId: 'template-1',
      recurrence: const TaskRecurrence.daily(),
      templateActive: true,
    );
    stubCommon(tasks: [task]);
    when(
      () => mocks.task.create(params: any(named: 'params')),
    ).thenAnswer((_) async => task.copyWith(id: 'task-copy-2'));

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Действия'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дублировать'));
    await tester.pumpAndSettle();

    expect(find.text('Серия скопирована.'), findsOneWidget);
  });

  // ── Batch-режим ─────────────────────────────────────────────

  testWidgets('batch: long press двух задач → «Выполнить (2)» → batch complete', (
    tester,
  ) async {
    final task1 = buildTask();
    final task2 = buildTask(id: 'task-2', title: 'Полить цветы');
    stubCommon(tasks: [task1, task2]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Купить продукты'));
    await tester.pumpAndSettle();
    // В batch-режиме тап по чекбоксу добавляет задачу в выбор.
    await tester.tap(find.byKey(Key('complete_task_button_${task2.id}')));
    await tester.pumpAndSettle();

    expect(find.text('Выполнить (2)'), findsOneWidget);

    await tester.tap(find.text('Выполнить (2)'));
    await tester.pumpAndSettle();

    // Две задачи завершены.
    verify(
      () => mocks.task.patchStatus(
        taskId: task1.id,
        status: TaskStatus.completed.name,
        completedByMemberId: 'member-1',
        completedAt: any(named: 'completedAt'),
        assignedMemberId: any(named: 'assignedMemberId'),
      ),
    ).called(1);
    verify(
      () => mocks.task.patchStatus(
        taskId: task2.id,
        status: TaskStatus.completed.name,
        completedByMemberId: 'member-1',
        completedAt: any(named: 'completedAt'),
        assignedMemberId: any(named: 'assignedMemberId'),
      ),
    ).called(1);
    expect(find.text('Выполнено задач: 2'), findsOneWidget);
    // Панель скрыта.
    expect(find.text('Выполнить (2)'), findsNothing);
  });

  testWidgets('batch: тап по второй задаче добавляет в выбор; повторный снимает', (
    tester,
  ) async {
    final task1 = buildTask();
    final task2 = buildTask(id: 'task-2', title: 'Полить цветы');
    stubCommon(tasks: [task1, task2]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Купить продукты'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('complete_task_button_${task2.id}')));
    await tester.pumpAndSettle();

    expect(find.text('Выполнить (2)'), findsOneWidget);

    // Повторный тап снимает выбор → возвращаемся к 1.
    await tester.tap(find.byKey(Key('complete_task_button_${task2.id}')));
    await tester.pumpAndSettle();

    expect(find.text('Выполнить (1)'), findsOneWidget);

    // Снимаем и последний выбор → панель исчезает.
    await tester.tap(find.byKey(Key('complete_task_button_${task1.id}')));
    await tester.pumpAndSettle();

    expect(find.text('Выполнить (1)'), findsNothing);
  });

  testWidgets('batch: «Отменить» в панели очищает выбор', (tester) async {
    final task1 = buildTask();
    final task2 = buildTask(id: 'task-2', title: 'Полить цветы');
    stubCommon(tasks: [task1, task2]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Купить продукты'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('complete_task_button_${task2.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отменить'));
    await tester.pumpAndSettle();

    expect(find.text('Выполнить (2)'), findsNothing);
  });

  testWidgets('batch: уже выполненная задача не пересчитывается в count', (
    tester,
  ) async {
    final task1 = buildTask();
    final task2 = buildTask(
      id: 'task-2',
      title: 'Полить цветы',
      status: TaskStatus.completed,
      completedAt: DateTime.now(),
    );
    stubCommon(tasks: [task1, task2]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    // Long press сначала по выполненной задаче — она выделяется первой.
    await tester.longPress(find.text('Полить цветы'));
    await tester.pumpAndSettle();
    // Затем чекбокс pending-задачи добавляет её в выбор.
    await tester.tap(find.byKey(Key('complete_task_button_${task1.id}')));
    await tester.pumpAndSettle();

    // Обе в выборе, но выполненная не попадёт в batch.
    expect(find.text('Выполнить (2)'), findsOneWidget);

    await tester.tap(find.text('Выполнить (2)'));
    await tester.pumpAndSettle();

    expect(find.text('Выполнено задач: 1'), findsOneWidget);
    verify(
      () => mocks.task.patchStatus(
        taskId: task1.id,
        status: TaskStatus.completed.name,
        completedByMemberId: 'member-1',
        completedAt: any(named: 'completedAt'),
        assignedMemberId: any(named: 'assignedMemberId'),
      ),
    ).called(1);
    verifyNever(
      () => mocks.task.patchStatus(
        taskId: task2.id,
        status: any(named: 'status'),
        completedByMemberId: any(named: 'completedByMemberId'),
        completedAt: any(named: 'completedAt'),
        assignedMemberId: any(named: 'assignedMemberId'),
      ),
    );
  });

  // ── Свайпы / статусы ────────────────────────────────────────

  testWidgets('свайп вправо выполненной задачи → uncomplete', (tester) async {
    final task = buildTask(
      status: TaskStatus.completed,
      completedAt: DateTime.now(),
    );
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
        status: TaskStatus.pending.name,
        completedByMemberId: null,
        completedAt: null,
      ),
    ).called(1);
  });

  testWidgets('свайп влево открывает диалог удаления; отмена → задача остаётся', (
    tester,
  ) async {
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
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    expect(find.text('Купить продукты'), findsOneWidget);
    verifyNever(() => mocks.task.delete(taskId: any(named: 'taskId')));
  });

  testWidgets('выполнение задачи → снекбар с «Отменить» → uncomplete', (
    tester,
  ) async {
    final task = buildTask();
    stubCommon(tasks: [task]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('complete_task_button_${task.id}')));
    await tester.pumpAndSettle();

    expect(find.text('Задача выполнена. Отличная работа!'), findsOneWidget);

    await tester.tap(find.text('Отменить'));
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

  testWidgets('смена сортировки в TaskListView через SortSelector', (
    tester,
  ) async {
    stubCommon(tasks: [buildTask(), buildTask(id: 'task-2', title: 'Полить цветы')]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    // Сортировка по умолчанию — deadline. Меняем на title.
    await tester.tap(find.byIcon(Icons.sort_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('По названию').last);
    await tester.pumpAndSettle();

    expect(find.text('Купить продукты'), findsOneWidget);
    expect(find.text('Полить цветы'), findsOneWidget);
  });

  testWidgets('Pull-to-refresh вызывает reload', (tester) async {
    stubCommon(tasks: [buildTask()]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.fling(
      find.text('Купить продукты'),
      const Offset(0, 300),
      1000,
    );
    await tester.pumpAndSettle();

    // Первичная + refresh.
    verify(
      () => mocks.task.getForDay(
        householdId: any(named: 'householdId'),
        day: any(named: 'day'),
      ),
    ).called(2);
  });

  testWidgets('смена household вызывает didUpdateWidget → перезагрузка', (
    tester,
  ) async {
    stubCommon(tasks: [buildTask()]);

    await tester.pumpWidget(buildSubject(householdId: 'household-1'));
    await tester.pumpAndSettle();

    expect(find.text('Купить продукты'), findsOneWidget);

    // Пересобираем с другим householdId — didUpdateWidget → load.
    await tester.pumpWidget(buildSubject(householdId: 'household-2'));
    await tester.pumpAndSettle();

    // getForDay вызывался с новым householdId.
    verify(
      () => mocks.task.getForDay(
        householdId: 'household-2',
        day: any(named: 'day'),
      ),
    ).called(1);
  });

  testWidgets('группировка: «Мои задачи», «Задачи семьи», «Неназначенные»', (
    tester,
  ) async {
    stubCommon(tasks: [
      buildTask(title: 'Моя'),
      buildTask(id: 'task-2', title: 'Чужая', assignedMemberId: 'member-2'),
      buildTask(id: 'task-3', title: 'Ничья', assignedMemberId: null),
    ]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Мои задачи'), findsOneWidget);
    expect(find.text('Задачи семьи'), findsOneWidget);
    expect(find.text('Неназначенные'), findsOneWidget);
    expect(find.text('Моя'), findsOneWidget);
    expect(find.text('Чужая'), findsOneWidget);
    expect(find.text('Ничья'), findsOneWidget);
  });

  testWidgets('задача не для меня: swipe-complete → снекбар об ошибке', (
    tester,
  ) async {
    // allowedMemberIds не содержит 'member-1' → CompleteTaskUseCase кидает
    // TaskCompletionNotAllowedException → TaskCompletionFailure.
    final task = Task(
      id: 'task-1',
      householdId: 'household-1',
      title: 'Чужая задача',
      estimatedDurationMinutes: 30,
      plannedFor: day,
      allowedMemberIds: const ['member-2'],
      status: TaskStatus.pending,
      createdAt: DateTime(2026, 7, 19),
    );
    stubCommon(tasks: [task]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    // Чекбокс неактивен (не назначены), но свайп вправо вызывает completeTask.
    await tester.drag(
      find.text('Чужая задача'),
      const Offset(400, 0),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(find.text('У вас нет права выполнить эту задачу.'), findsOneWidget);
  });

  testWidgets('смена направления сортировки (возрастание/убывание)', (
    tester,
  ) async {
    stubCommon(tasks: [buildTask(), buildTask(id: 'task-2', title: 'Полить цветы')]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    // Сортировка по умолчанию — deadline, по возрастанию.
    // Открываем dropdown направления.
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('По убыванию').last);
    await tester.pumpAndSettle();

    // После смены направления иконка становится arrow_downward.
    expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
  });
}
