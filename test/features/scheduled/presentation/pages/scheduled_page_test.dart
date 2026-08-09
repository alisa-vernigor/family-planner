import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/households/domain/repositories/household_repository.dart';
import 'package:family_planner/features/tasks/domain/entities/create_task_params.dart';
import 'package:family_planner/features/tasks/domain/entities/eisenhower_priority.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_category.dart';
import 'package:family_planner/features/tasks/domain/entities/task_recurrence.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:family_planner/features/tasks/domain/entities/update_recurring_task_params.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_category_repository.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/scheduled/presentation/pages/scheduled_page.dart';

import '../../../../helpers/load_roboto_font.dart';
import '../../../../helpers/mock_repository_factory.dart';

final class MockTaskCategoryRepository extends Mock
    implements TaskCategoryRepository {}

void main() {
  late MockRepositoryFactory mocks;
  late MockTaskCategoryRepository categoryRepo;

  setUpAll(() async {
    await loadRobotoFont();
    await initializeDateFormatting('ru_RU');
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

  Task buildTask({
    String id = 'task-1',
    String title = 'Купить продукты',
    DateTime? plannedFor,
    String? assignedMemberId = 'member-1',
    String? description,
    String? pinnedMemberId,
    String? templateId,
    TaskRecurrence? recurrence,
    bool? templateActive,
    TaskStatus status = TaskStatus.pending,
    DateTime? completedAt,
    int? estimatedDurationMinutes = 30,
  }) {
    return Task(
      id: id,
      householdId: 'household-1',
      title: title,
      description: description,
      estimatedDurationMinutes: estimatedDurationMinutes!,
      plannedFor: plannedFor ?? DateTime(2026, 8, 1, 10),
      allowedMemberIds: const ['member-1'],
      assignedMemberId: assignedMemberId,
      pinnedMemberId: pinnedMemberId,
      status: status,
      createdAt: DateTime(2026, 7, 19),
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
    // void-возвращающие методы мока без стаба возвращают null,
    // и `await` падает (null не является Future<void>). Стабим заранее.
    when(() => mocks.task.save(any())).thenAnswer((_) async {});
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
          body: ScheduledPage(
            householdId: householdId,
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

  testWidgets('поиск без результатов показывает «Ничего не найдено»', (
    tester,
  ) async {
    stubCommon(tasks: [buildTask(title: 'Купить продукты')]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('task_search_field')),
      'несуществующий запрос',
    );
    await tester.pumpAndSettle();

    expect(find.text('Ничего не найдено'), findsOneWidget);
    expect(find.text('Купить продукты'), findsNothing);
  });

  testWidgets('очистка поиска возвращает задачи', (tester) async {
    stubCommon(tasks: [buildTask(title: 'Купить продукты')]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    // Ищем запрос, который даёт результаты — только тогда кнопка «Очистить» доступна.
    await tester.enterText(
      find.byKey(const Key('task_search_field')),
      'Купить',
    );
    await tester.pumpAndSettle();
    expect(find.text('Купить продукты'), findsOneWidget);

    // Кнопка «Очистить» появляется, когда в поиске есть текст.
    await tester.tap(find.byTooltip('Очистить'));
    await tester.pumpAndSettle();

    expect(find.text('Купить продукты'), findsOneWidget);
  });

  testWidgets('поиск по описанию фильтрует задачи', (tester) async {
    stubCommon(
      tasks: [
        buildTask(title: 'Купить продукты', description: 'Молоко и хлеб'),
        buildTask(id: 'task-2', title: 'Полить цветы'),
      ],
    );

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('task_search_field')),
      'молоко',
    );
    await tester.pumpAndSettle();

    expect(find.text('Купить продукты'), findsOneWidget);
    expect(find.text('Полить цветы'), findsNothing);
  });

  testWidgets('смена сортировки переупорядочивает задачи', (tester) async {
    stubCommon(
      tasks: [
        buildTask(id: 'task-a', title: 'Задача А', estimatedDurationMinutes: 120),
        buildTask(id: 'task-b', title: 'Задача Б', estimatedDurationMinutes: 10),
      ],
    );

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    // По умолчанию — сортировка по плановой дате (обе на одну дату → порядок вставки).
    final before = tester.getTopLeft(find.text('Задача А')).dy;
    final beforeB = tester.getTopLeft(find.text('Задача Б')).dy;
    expect(before, lessThan(beforeB));

    // Меняем на сортировку по длительности (по возрастанию) — сначала 10 мин.
    await tester.tap(find.byIcon(Icons.sort_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('По длительности').last);
    await tester.pumpAndSettle();

    final afterA = tester.getTopLeft(find.text('Задача А')).dy;
    final afterB = tester.getTopLeft(find.text('Задача Б')).dy;
    expect(afterB, lessThan(afterA));
  });

  testWidgets('переключение в календарь и обратно в список', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    stubCommon(tasks: [buildTask()]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Календарь'));
    await tester.pumpAndSettle();

    // Календарь показывает сетку и сегменты месяц/неделя/день.
    expect(find.text('Месяц'), findsOneWidget);
    expect(find.text('Неделя'), findsOneWidget);
    expect(find.text('День'), findsOneWidget);

    await tester.tap(find.byTooltip('Список'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Календарь'), findsOneWidget);
    expect(find.text('Купить продукты'), findsOneWidget);
  });

  testWidgets('календарь: смена режима неделя/день работает', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    stubCommon(tasks: [buildTask()]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Календарь'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Неделя'));
    await tester.pumpAndSettle();
    // Шкала времени недели рендерится без ошибок.
    expect(find.text('Месяц'), findsOneWidget);

    await tester.tap(find.text('День'));
    await tester.pumpAndSettle();
    expect(find.text('Месяц'), findsOneWidget);
  });

  testWidgets('меню карточки: «Пропустить» → диалог → patchStatus(skipped)', (
    tester,
  ) async {
    stubCommon(tasks: [buildTask()]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('task_menu_task-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Пропустить'));
    await tester.pumpAndSettle();

    // Диалог подтверждения.
    expect(find.text('Пропустить задачу?'), findsOneWidget);
    await tester.tap(find.text('Пропустить').last);
    await tester.pumpAndSettle();

    verify(
      () => mocks.task.patchStatus(
        taskId: 'task-1',
        status: TaskStatus.skipped.name,
        completedByMemberId: null,
        completedAt: null,
      ),
    ).called(1);
    expect(find.text('Задача пропущена.'), findsOneWidget);
    // Задача исчезает из списка (оптимистично).
    expect(find.text('Купить продукты'), findsNothing);
  });

  testWidgets('меню карточки: отмена диалога пропуска не вызывает patchStatus', (
    tester,
  ) async {
    stubCommon(tasks: [buildTask()]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('task_menu_task-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Пропустить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    verifyNever(
      () => mocks.task.patchStatus(
        taskId: 'task-1',
        status: TaskStatus.skipped.name,
        completedByMemberId: any(named: 'completedByMemberId'),
        completedAt: any(named: 'completedAt'),
      ),
    );
    expect(find.text('Купить продукты'), findsOneWidget);
  });

  testWidgets('меню карточки: «Удалить» → диалог → repository.delete', (
    tester,
  ) async {
    stubCommon(tasks: [buildTask()]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('task_menu_task-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();

    expect(find.text('Удалить задачу?'), findsOneWidget);
    await tester.tap(find.text('Удалить').last);
    await tester.pumpAndSettle();

    verify(() => mocks.task.delete(taskId: 'task-1')).called(1);
    expect(find.text('Купить продукты'), findsNothing);
  });

  testWidgets('меню карточки: «Дублировать» создаёт копию и показывает снекбар', (
    tester,
  ) async {
    final task = buildTask();
    stubCommon(tasks: [task]);
    when(
      () => mocks.task.create(params: any(named: 'params')),
    ).thenAnswer((_) async => task.copyWith(id: 'task-copy'));

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('task_menu_task-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дублировать'));
    await tester.pumpAndSettle();

    verify(() => mocks.task.create(params: any(named: 'params'))).called(1);
    expect(find.text('Задача скопирована.'), findsOneWidget);
  });

  testWidgets('серия: меню «Поставить на паузу» → pauseTemplate + снекбар', (
    tester,
  ) async {
    stubCommon(
      tasks: [
        buildTask(
          templateId: 'template-1',
          recurrence: const TaskRecurrence.daily(),
          templateActive: true,
        ),
      ],
    );

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('task_menu_task-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Поставить на паузу'));
    await tester.pumpAndSettle();

    verify(() => mocks.task.pauseTemplate(templateId: 'template-1')).called(1);
    expect(find.text('Серия поставлена на паузу.'), findsOneWidget);
  });

  testWidgets('серия на паузе: меню «Возобновить серию» → resumeTemplate', (
    tester,
  ) async {
    stubCommon(
      tasks: [
        buildTask(
          templateId: 'template-1',
          recurrence: const TaskRecurrence.daily(),
          templateActive: false,
        ),
      ],
    );

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('task_menu_task-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Возобновить серию'));
    await tester.pumpAndSettle();

    verify(() => mocks.task.resumeTemplate(templateId: 'template-1')).called(1);
    expect(find.text('Серия возобновлена.'), findsOneWidget);
  });

  testWidgets('меню карточки: «Перенести» → date picker → save с новой датой', (
    tester,
  ) async {
    stubCommon(tasks: [buildTask()]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('task_menu_task-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Перенести'));
    await tester.pumpAndSettle();

    expect(find.text('Перенести задачу'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    verify(() => mocks.task.save(any())).called(1);
  });

  testWidgets('меню карточки: «Назначить» → bottom sheet → save с новым исполнителем', (
    tester,
  ) async {
    final task = buildTask(assignedMemberId: null);
    stubCommon(tasks: [task]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('task_menu_task-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Назначить'));
    await tester.pumpAndSettle();

    expect(find.text('Назначить ответственного'), findsOneWidget);
    await tester.tap(find.text('Анна'));
    await tester.pumpAndSettle();

    verify(
      () => mocks.task.save(
        any(that: isA<Task>().having((t) => t.assignedMemberId, 'assignedMemberId', 'member-1')),
      ),
    ).called(1);
  });

  testWidgets('закреплённая задача: меню «Открепить» → save(unpinned)', (
    tester,
  ) async {
    stubCommon(tasks: [buildTask(pinnedMemberId: 'member-1')]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Закреплено'), findsOneWidget);

    await tester.tap(find.byKey(const Key('task_menu_task-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Открепить'));
    await tester.pumpAndSettle();

    verify(
      () => mocks.task.save(
        any(that: isA<Task>().having((t) => t.pinnedMemberId, 'pinnedMemberId', null)),
      ),
    ).called(1);
  });

  testWidgets('EditTaskSheet: сохранение изменений → reload + «Изменения сохранены.»', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    stubCommon(tasks: [buildTask()]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('task_menu_task-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Редактировать'));
    await tester.pumpAndSettle();

    expect(find.text('Редактировать задачу'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('edit_task_title_field')),
      'Обновлённая задача',
    );
    await tester.ensureVisible(find.byKey(const Key('save_task_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save_task_button')));
    await tester.pumpAndSettle();

    verify(
      () => mocks.task.save(
        any(that: isA<Task>().having((t) => t.title, 'title', 'Обновлённая задача')),
      ),
    ).called(1);
    expect(find.text('Изменения сохранены.'), findsOneWidget);
    // После сохранения — тихая перезагрузка (getAllPending вызывается повторно).
    verify(
      () => mocks.task.getAllPending(householdId: any(named: 'householdId')),
    ).called(2);
  });

  testWidgets('CreateTaskSheet: создание задачи → silent reload', (tester) async {
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

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Название'),
      'Купить молоко',
    );
    await tester.ensureVisible(find.text('Создать задачу').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Создать задачу').last);
    await tester.pumpAndSettle();

    verify(() => mocks.task.create(params: any(named: 'params'))).called(1);
    // После создания — тихая перезагрузка.
    verify(
      () => mocks.task.getAllPending(householdId: any(named: 'householdId')),
    ).called(2);
  });

  testWidgets('матрица: complete через чекбокс мини-карточки', (tester) async {
    stubCommon(tasks: [buildTask()]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Матрица Эйзенхауэра'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.radio_button_unchecked_outlined));
    await tester.pumpAndSettle();

    verify(
      () => mocks.task.patchStatus(
        taskId: 'task-1',
        status: TaskStatus.completed.name,
        completedByMemberId: 'member-1',
        completedAt: any(named: 'completedAt'),
        assignedMemberId: 'member-1',
      ),
    ).called(1);
    expect(find.text('Задача выполнена. Отличная работа!'), findsOneWidget);
  });

  testWidgets('ошибка удаления показывает снекбар и перезагружает', (
    tester,
  ) async {
    stubCommon(tasks: [buildTask()]);
    when(() => mocks.task.delete(taskId: any(named: 'taskId'))).thenThrow(
      Exception('boom'),
    );

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('task_menu_task-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить').last);
    await tester.pumpAndSettle();

    expect(find.text('Не удалось удалить задачу.'), findsOneWidget);
  });

  testWidgets('ошибка пропуска показывает снекбар и перезагружает', (
    tester,
  ) async {
    stubCommon(tasks: [buildTask()]);
    when(
      () => mocks.task.patchStatus(
        taskId: any(named: 'taskId'),
        status: any(named: 'status'),
        completedByMemberId: any(named: 'completedByMemberId'),
        completedAt: any(named: 'completedAt'),
        assignedMemberId: any(named: 'assignedMemberId'),
      ),
    ).thenThrow(Exception('boom'));

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('task_menu_task-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Пропустить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Пропустить').last);
    await tester.pumpAndSettle();

    expect(find.text('Не удалось пропустить задачу.'), findsOneWidget);
  });

  testWidgets('ошибка дублирования показывает снекбар', (tester) async {
    stubCommon(tasks: [buildTask()]);
    when(() => mocks.task.create(params: any(named: 'params'))).thenThrow(
      Exception('boom'),
    );

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('task_menu_task-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дублировать'));
    await tester.pumpAndSettle();

    expect(find.text('Не удалось скопировать задачу.'), findsOneWidget);
  });

  testWidgets('ошибка назначения показывает снекбар и перезагружает', (
    tester,
  ) async {
    final task = buildTask(assignedMemberId: null);
    stubCommon(tasks: [task]);
    when(() => mocks.task.save(any())).thenThrow(Exception('boom'));

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('task_menu_task-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Назначить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Анна'));
    await tester.pumpAndSettle();

    expect(find.text('Не удалось назначить ответственного.'), findsOneWidget);
  });

  testWidgets('ошибка открепления показывает снекбар', (tester) async {
    stubCommon(tasks: [buildTask(pinnedMemberId: 'member-1')]);
    when(() => mocks.task.save(any())).thenThrow(Exception('boom'));

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('task_menu_task-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Открепить'));
    await tester.pumpAndSettle();

    expect(find.text('Не удалось открепить задачу.'), findsOneWidget);
  });

  testWidgets('ошибка паузы серии показывает снекбар и перезагружает', (
    tester,
  ) async {
    stubCommon(
      tasks: [
        buildTask(
          templateId: 'template-1',
          recurrence: const TaskRecurrence.daily(),
          templateActive: true,
        ),
      ],
    );
    when(
      () => mocks.task.pauseTemplate(templateId: any(named: 'templateId')),
    ).thenThrow(Exception('boom'));

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('task_menu_task-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Поставить на паузу'));
    await tester.pumpAndSettle();

    expect(find.text('Не удалось изменить состояние серии.'), findsOneWidget);
  });

  testWidgets('ошибка переноса показывает снекбар', (tester) async {
    stubCommon(tasks: [buildTask()]);
    when(() => mocks.task.save(any())).thenThrow(Exception('boom'));

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('task_menu_task-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Перенести'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Не удалось перенести задачу.'), findsOneWidget);
  });

  testWidgets('uncomplete через «Отменить» в снекбаре complete', (tester) async {
    stubCommon(tasks: [buildTask()]);
    when(
      () => mocks.task.patchStatus(
        taskId: any(named: 'taskId'),
        status: any(named: 'status'),
        completedByMemberId: any(named: 'completedByMemberId'),
        completedAt: any(named: 'completedAt'),
        assignedMemberId: any(named: 'assignedMemberId'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    // Переключаемся в матрицу, где есть чекбокс complete.
    await tester.tap(find.byTooltip('Матрица Эйзенхауэра'));
    await tester.pumpAndSettle();

    // Выполняем задачу через чекбокс.
    await tester.tap(find.byIcon(Icons.radio_button_unchecked_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Задача выполнена. Отличная работа!'), findsOneWidget);

    // Жмём «Отменить» → uncomplete.
    await tester.tap(find.text('Отменить'));
    await tester.pumpAndSettle();

    verify(
      () => mocks.task.patchStatus(
        taskId: 'task-1',
        status: TaskStatus.pending.name,
        completedByMemberId: null,
        completedAt: null,
        assignedMemberId: null,
      ),
    ).called(1);
  });

  testWidgets('смена household вызывает didUpdateWidget → перезагрузка', (
    tester,
  ) async {
    stubCommon(tasks: [buildTask()]);

    await tester.pumpWidget(buildSubject(householdId: 'household-1'));
    await tester.pumpAndSettle();

    expect(find.text('Купить продукты'), findsOneWidget);

    // Пересобираем с другим householdId — didUpdateWidget → перезагрузка.
    await tester.pumpWidget(buildSubject(householdId: 'household-2'));
    await tester.pumpAndSettle();

    verify(
      () => mocks.task.getAllPending(householdId: any(named: 'householdId')),
    ).called(2);
  });

  testWidgets('календарь: drag&drop перенос задачи на другой день', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final today = DateTime.now();
    stubCommon(tasks: [buildTask(plannedFor: today)]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Календарь'));
    await tester.pumpAndSettle();

    final tomorrow = today.add(const Duration(days: 1));
    final draggable = find.byKey(Key('draggable_task_task-1'));
    expect(draggable, findsOneWidget);

    final target = find.byKey(
      Key('calendar_day_${tomorrow.year}_${tomorrow.month}_${tomorrow.day}'),
    );
    expect(target, findsOneWidget);

    final source = tester.getCenter(draggable);
    final destination = tester.getCenter(target);

    final gesture = await tester.startGesture(source);
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(destination);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    verify(() => mocks.task.save(any())).called(1);
  });

  testWidgets('календарь: ошибка переноса при drag&drop показывает снекбар', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final today = DateTime.now();
    stubCommon(tasks: [buildTask(plannedFor: today)]);
    when(() => mocks.task.save(any())).thenThrow(Exception('boom'));

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Календарь'));
    await tester.pumpAndSettle();

    final tomorrow = today.add(const Duration(days: 1));
    final draggable = find.byKey(Key('draggable_task_task-1'));
    final target = find.byKey(
      Key('calendar_day_${tomorrow.year}_${tomorrow.month}_${tomorrow.day}'),
    );

    final gesture = await tester.startGesture(tester.getCenter(draggable));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(tester.getCenter(target));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('Не удалось перенести задачу.'), findsOneWidget);
  });

  testWidgets('матрица: ошибка выполнения показывает снекбар', (tester) async {
    stubCommon(tasks: [buildTask()]);
    when(
      () => mocks.task.patchStatus(
        taskId: any(named: 'taskId'),
        status: any(named: 'status'),
        completedByMemberId: any(named: 'completedByMemberId'),
        completedAt: any(named: 'completedAt'),
        assignedMemberId: any(named: 'assignedMemberId'),
      ),
    ).thenThrow(Exception('boom'));

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Матрица Эйзенхауэра'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.radio_button_unchecked_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Не удалось выполнить задачу.'), findsOneWidget);
  });

  testWidgets('календарь: ошибка отмены выполнения показывает снекбар', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final today = DateTime.now();
    stubCommon(
      tasks: [
        buildTask(
          plannedFor: today,
          status: TaskStatus.completed,
          completedAt: today,
        ),
      ],
    );
    when(
      () => mocks.task.patchStatus(
        taskId: any(named: 'taskId'),
        status: any(named: 'status'),
        completedByMemberId: any(named: 'completedByMemberId'),
        completedAt: any(named: 'completedAt'),
        assignedMemberId: any(named: 'assignedMemberId'),
      ),
    ).thenThrow(Exception('boom'));

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Календарь'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.check_circle).first);
    await tester.pumpAndSettle();

    expect(find.text('Не удалось отменить выполнение.'), findsOneWidget);
  });

  testWidgets('меню карточки: отмена диалога удаления не вызывает delete', (
    tester,
  ) async {
    stubCommon(tasks: [buildTask()]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('task_menu_task-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();

    expect(find.text('Удалить задачу?'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    verifyNever(() => mocks.task.delete(taskId: 'task-1'));
    expect(find.text('Купить продукты'), findsOneWidget);
  });

  testWidgets('матрица: drag&drop меняет приоритет задачи', (tester) async {
    stubCommon(tasks: [buildTask()]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Матрица Эйзенхауэра'));
    await tester.pumpAndSettle();

    // Задача в 4-м квадранте (приоритет по умолчанию). Переносим в 1-й.
    final source = tester.getCenter(find.text('Купить продукты'));
    final targets = find.byType(DragTarget<Task>);
    expect(targets, findsWidgets);
    final destination = tester.getCenter(targets.at(0));

    final gesture = await tester.startGesture(source);
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(destination);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    verify(
      () => mocks.task.save(
        any(
          that: isA<Task>().having(
            (t) => t.priority,
            'priority',
            EisenhowerPriority.urgentImportant,
          ),
        ),
      ),
    ).called(1);
  });

  testWidgets('матрица: ошибка смены приоритета показывает снекбар', (
    tester,
  ) async {
    stubCommon(tasks: [buildTask()]);
    when(() => mocks.task.save(any())).thenThrow(Exception('boom'));

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Матрица Эйзенхауэра'));
    await tester.pumpAndSettle();

    final source = tester.getCenter(find.text('Купить продукты'));
    final targets = find.byType(DragTarget<Task>);
    final destination = tester.getCenter(targets.at(0));

    final gesture = await tester.startGesture(source);
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(destination);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('Не удалось изменить приоритет задачи.'), findsOneWidget);
  });

  testWidgets('фильтр «Все» возвращает полный список', (tester) async {
    stubCommon(tasks: [
      buildTask(title: 'Моя задача'),
      buildTask(id: 'task-2', title: 'Без исполнителя', assignedMemberId: null),
    ]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Мои'));
    await tester.pumpAndSettle();
    expect(find.text('Без исполнителя'), findsNothing);

    await tester.tap(find.text('Все'));
    await tester.pumpAndSettle();

    expect(find.text('Моя задача'), findsOneWidget);
    expect(find.text('Без исполнителя'), findsOneWidget);
  });

  testWidgets('смена направления сортировки переупорядочивает задачи', (
    tester,
  ) async {
    stubCommon(
      tasks: [
        buildTask(id: 'task-a', title: 'Задача А', estimatedDurationMinutes: 10),
        buildTask(
          id: 'task-b',
          title: 'Задача Б',
          estimatedDurationMinutes: 120,
        ),
      ],
    );

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    // Сортируем по длительности (по возрастанию) — сначала 10 мин.
    await tester.tap(find.byIcon(Icons.sort_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('По длительности').last);
    await tester.pumpAndSettle();

    var a = tester.getTopLeft(find.text('Задача А')).dy;
    var b = tester.getTopLeft(find.text('Задача Б')).dy;
    expect(a, lessThan(b));

    // Меняем направление на «По убыванию» — сначала 120 мин.
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('По убыванию').last);
    await tester.pumpAndSettle();

    a = tester.getTopLeft(find.text('Задача А')).dy;
    b = tester.getTopLeft(find.text('Задача Б')).dy;
    expect(b, lessThan(a));
  });

  testWidgets('переключение матрица→календарь→матрица→список работает', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    stubCommon(tasks: [buildTask()]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    // Список → матрица.
    await tester.tap(find.byTooltip('Матрица Эйзенхауэра'));
    await tester.pumpAndSettle();
    expect(find.text('Срочно и важно'), findsWidgets);

    // Матрица → календарь.
    await tester.tap(find.byTooltip('Календарь'));
    await tester.pumpAndSettle();
    expect(find.text('Месяц'), findsOneWidget);

    // Календарь → матрица.
    await tester.tap(find.byTooltip('Матрица Эйзенхауэра'));
    await tester.pumpAndSettle();
    expect(find.text('Срочно и важно'), findsWidgets);

    // Матрица → список.
    await tester.tap(find.byTooltip('Список'));
    await tester.pumpAndSettle();
    expect(find.text('Купить продукты'), findsOneWidget);
  });

  testWidgets('календарь: чекбокс выполняет задачу', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final today = DateTime.now();
    stubCommon(tasks: [buildTask(plannedFor: today)]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Календарь'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.radio_button_unchecked).first);
    await tester.pumpAndSettle();

    verify(
      () => mocks.task.patchStatus(
        taskId: 'task-1',
        status: TaskStatus.completed.name,
        completedByMemberId: 'member-1',
        completedAt: any(named: 'completedAt'),
        assignedMemberId: 'member-1',
      ),
    ).called(1);
  });

  testWidgets('Pull-to-refresh вызывает перезагрузку', (tester) async {
    stubCommon(tasks: [buildTask()]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.fling(
      find.text('Купить продукты'),
      const Offset(0, 300),
      1000,
    );
    await tester.pumpAndSettle();

    verify(
      () => mocks.task.getAllPending(householdId: any(named: 'householdId')),
    ).called(2);
  });

  testWidgets('матрица (узкий экран): свайп вправо выполняет задачу', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(590, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    stubCommon(tasks: [buildTask()]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Матрица Эйзенхауэра'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Купить продукты'));
    await tester.pumpAndSettle();

    await tester.drag(
      find.text('Купить продукты'),
      const Offset(300, 0),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    verify(
      () => mocks.task.patchStatus(
        taskId: 'task-1',
        status: TaskStatus.completed.name,
        completedByMemberId: 'member-1',
        completedAt: any(named: 'completedAt'),
        assignedMemberId: 'member-1',
      ),
    ).called(1);
  });

  testWidgets('матрица (узкий экран): свайп влево удаляет задачу', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(590, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    stubCommon(tasks: [buildTask()]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Матрица Эйзенхауэра'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Купить продукты'));
    await tester.pumpAndSettle();

    await tester.drag(
      find.text('Купить продукты'),
      const Offset(-300, 0),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(find.text('Удалить задачу?'), findsOneWidget);
    await tester.tap(find.text('Удалить').last);
    await tester.pumpAndSettle();

    verify(() => mocks.task.delete(taskId: 'task-1')).called(1);
  });
}
