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
import 'package:family_planner/features/tasks/domain/entities/task_subtask.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_category_repository.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_subtask_repository.dart';
import 'package:family_planner/features/tasks/domain/entities/create_task_category_params.dart';
import 'package:family_planner/features/tasks/domain/entities/create_task_subtask_params.dart';
import 'package:family_planner/features/tasks/domain/entities/update_recurring_task_params.dart';
import 'package:family_planner/features/tasks/presentation/pages/edit_task_sheet.dart';

import '../../../../helpers/mock_repository_factory.dart';

final class MockTaskSubtaskRepository extends Mock
    implements TaskSubtaskRepository {}

final class MockTaskCategoryRepository extends Mock
    implements TaskCategoryRepository {}

void main() {
  late MockRepositoryFactory mocks;
  late MockTaskSubtaskRepository subtaskRepo;
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
    registerFallbackValue(
      CreateTaskSubtaskParams(taskId: 'fallback', title: 'fallback'),
    );
    registerFallbackValue(
      const CreateTaskCategoryParams(householdId: 'h', name: 'n'),
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
    subtaskRepo = MockTaskSubtaskRepository();
    categoryRepo = MockTaskCategoryRepository();
  });

  Task buildTask({
    String id = 'task-1',
    String? templateId,
    TaskRecurrence? recurrence,
    String? categoryId,
    String? assignedMemberId = 'member-1',
    DateTime? plannedFor,
  }) {
    return Task(
      id: id,
      householdId: 'household-1',
      title: 'Купить продукты',
      description: 'Молоко и хлеб',
      estimatedDurationMinutes: 30,
      plannedFor: plannedFor ?? DateTime(2026, 7, 20, 10),
      allowedMemberIds: const ['member-1'],
      assignedMemberId: assignedMemberId,
      status: TaskStatus.pending,
      createdAt: DateTime(2026, 7, 19),
      templateId: templateId,
      recurrence: recurrence,
      recurrenceStartDate: recurrence == null ? null : DateTime(2026, 7, 1),
      categoryId: categoryId,
    );
  }

  const member = HouseholdMember(
    profileId: 'member-1',
    displayName: 'Анна',
    role: 'owner',
  );

  void stubCommon() {
    when(
      () => mocks.household.getMembers(householdId: any(named: 'householdId')),
    ).thenAnswer((_) async => const [member]);
    when(
      () => subtaskRepo.getForTask(any()),
    ).thenAnswer((_) async => const <TaskSubtask>[]);
    when(
      () => categoryRepo.getForHousehold(any()),
    ).thenAnswer((_) async => const <TaskCategory>[]);
  }

  Future<void> openSheet(WidgetTester tester, Task task) async {
    await tester.pumpWidget(
      RepositoryProvider<TaskRepository>(
        create: (_) => mocks.task,
        child: RepositoryProvider<HouseholdRepository>(
          create: (_) => mocks.household,
          child: RepositoryProvider<TaskSubtaskRepository>(
            create: (_) => subtaskRepo,
            child: RepositoryProvider<TaskCategoryRepository>(
              create: (_) => categoryRepo,
              child: MaterialApp(
                home: Scaffold(
                  body: Builder(
                    builder: (context) => Center(
                      child: ElevatedButton(
                        onPressed: () =>
                            showEditTaskSheet(context: context, task: task),
                        child: const Text('open'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('показывает поля формы, предзаполненные из задачи', (
    tester,
  ) async {
    stubCommon();

    await openSheet(tester, buildTask());

    expect(find.text('Редактировать задачу'), findsOneWidget);
    expect(find.byKey(const Key('edit_task_title_field')), findsOneWidget);
    expect(find.byKey(const Key('edit_task_description_field')), findsOneWidget);
    expect(find.byKey(const Key('edit_task_duration_field')), findsOneWidget);
    expect(find.byKey(const Key('edit_start_time_field')), findsOneWidget);
    expect(find.byKey(const Key('edit_reminder_selector')), findsOneWidget);
    expect(find.byKey(const Key('edit_category_field')), findsOneWidget);
    expect(find.byKey(const Key('save_task_button')), findsOneWidget);
    expect(find.byKey(const Key('edit_subtask_editor')), findsOneWidget);

    expect(find.text('Купить продукты'), findsOneWidget);
    expect(find.text('Молоко и хлеб'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(find.text('Анна'), findsOneWidget);
  });

  testWidgets('пустое название показывает ошибку валидации', (tester) async {
    stubCommon();

    await openSheet(tester, buildTask());

    await tester.enterText(
      find.byKey(const Key('edit_task_title_field')),
      '',
    );
    await tester.ensureVisible(find.byKey(const Key('save_task_button')));
    await tester.tap(find.byKey(const Key('save_task_button')));
    await tester.pumpAndSettle();

    expect(find.text('Введите название задачи.'), findsOneWidget);
  });

  testWidgets('сохранение вызывает repository.save и закрывает лист', (
    tester,
  ) async {
    stubCommon();
    when(() => mocks.task.save(any())).thenAnswer((_) async {});

    await openSheet(tester, buildTask());

    await tester.enterText(
      find.byKey(const Key('edit_task_title_field')),
      'Купить продукты и молоко',
    );
    await tester.ensureVisible(find.byKey(const Key('save_task_button')));
    await tester.tap(find.byKey(const Key('save_task_button')));
    await tester.pumpAndSettle();

    verify(() => mocks.task.save(any())).called(1);
    // Лист закрылся (showModalBottomSheet вернул true → Navigator.pop).
    expect(find.byKey(const Key('save_task_button')), findsNothing);
  });

  testWidgets('для повторяющейся задачи показывается scope-диалог', (
    tester,
  ) async {
    stubCommon();

    await openSheet(
      tester,
      buildTask(templateId: 'tpl-1', recurrence: const TaskRecurrence.daily()),
    );

    expect(
      find.text('Это повторяющаяся задача. Что нужно изменить?'),
      findsOneWidget,
    );
    expect(find.text('Только эту задачу'), findsOneWidget);
    expect(find.text('Эту и последующие'), findsOneWidget);
    expect(find.text('Все задачи в серии'), findsOneWidget);
  });

  testWidgets('выбор «Только эту задачу» открывает редактор без повторения', (
    tester,
  ) async {
    stubCommon();

    await openSheet(
      tester,
      buildTask(templateId: 'tpl-1', recurrence: const TaskRecurrence.daily()),
    );

    await tester.tap(find.text('Только эту задачу'));
    await tester.pumpAndSettle();

    expect(find.text('Редактировать задачу'), findsOneWidget);
    expect(find.byKey(const Key('edit_recurrence_editor')), findsNothing);
    expect(find.byKey(const Key('edit_subtask_editor')), findsOneWidget);
  });

  testWidgets('выбор «Эту и последующие» показывает редактор повторения', (
    tester,
  ) async {
    stubCommon();

    await openSheet(
      tester,
      buildTask(templateId: 'tpl-1', recurrence: const TaskRecurrence.daily()),
    );

    await tester.tap(find.text('Эту и последующие'));
    await tester.pumpAndSettle();

    expect(find.text('Редактировать задачу'), findsOneWidget);
    expect(find.byKey(const Key('edit_recurrence_editor')), findsOneWidget);
    // Подзадач нет для серии.
    expect(find.byKey(const Key('edit_subtask_editor')), findsNothing);
  });

  testWidgets('отмена scope-диалога не открывает редактор', (tester) async {
    stubCommon();

    await openSheet(
      tester,
      buildTask(templateId: 'tpl-1', recurrence: const TaskRecurrence.daily()),
    );

    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    expect(find.text('Редактировать задачу'), findsNothing);
  });

  testWidgets('подзадачи загружаются и показываются в редакторе', (
    tester,
  ) async {
    when(
      () => mocks.household.getMembers(householdId: any(named: 'householdId')),
    ).thenAnswer((_) async => const [member]);
    when(
      () => categoryRepo.getForHousehold(any()),
    ).thenAnswer((_) async => const <TaskCategory>[]);
    when(
      () => subtaskRepo.getForTask('task-1'),
    ).thenAnswer(
      (_) async => [
        TaskSubtask(
          id: 'sub-1',
          taskId: 'task-1',
          title: 'Помыть',
          position: 0,
          isCompleted: false,
          createdAt: DateTime(2026, 7, 19),
        ),
        TaskSubtask(
          id: 'sub-2',
          taskId: 'task-1',
          title: 'Убрать',
          position: 1,
          isCompleted: false,
          createdAt: DateTime(2026, 7, 19),
        ),
      ],
    );

    await openSheet(tester, buildTask());

    expect(find.text('Помыть'), findsOneWidget);
    expect(find.text('Убрать'), findsOneWidget);
  });

  testWidgets('категории загружаются и показываются в поле', (tester) async {
    when(
      () => mocks.household.getMembers(householdId: any(named: 'householdId')),
    ).thenAnswer((_) async => const [member]);
    when(
      () => subtaskRepo.getForTask(any()),
    ).thenAnswer((_) async => const <TaskSubtask>[]);
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

    final task = buildTask(categoryId: 'cat-1');
    await openSheet(tester, task);

    expect(find.text('Кухня'), findsNWidgets(2));
  });

  testWidgets('некорректная длительность показывает ошибку валидации', (
    tester,
  ) async {
    stubCommon();

    await openSheet(tester, buildTask());

    await tester.enterText(
      find.byKey(const Key('edit_task_duration_field')),
      '0',
    );
    await tester.ensureVisible(find.byKey(const Key('save_task_button')));
    await tester.tap(find.byKey(const Key('save_task_button')));
    await tester.pumpAndSettle();

    expect(find.text('Введите длительность больше нуля.'), findsOneWidget);
  });

  testWidgets('слишком длинное название показывает ошибку валидации', (
    tester,
  ) async {
    stubCommon();

    await openSheet(tester, buildTask());

    await tester.enterText(
      find.byKey(const Key('edit_task_title_field')),
      List.filled(161, 'а').join(),
    );
    await tester.ensureVisible(find.byKey(const Key('save_task_button')));
    await tester.tap(find.byKey(const Key('save_task_button')));
    await tester.pumpAndSettle();

    expect(
      find.text('Название должно быть не длиннее 160 символов.'),
      findsOneWidget,
    );
  });

  testWidgets('слишком длинное описание показывает ошибку валидации', (
    tester,
  ) async {
    stubCommon();

    await openSheet(tester, buildTask());

    await tester.enterText(
      find.byKey(const Key('edit_task_description_field')),
      List.filled(2001, 'а').join(),
    );
    await tester.ensureVisible(find.byKey(const Key('save_task_button')));
    await tester.tap(find.byKey(const Key('save_task_button')));
    await tester.pumpAndSettle();

    expect(
      find.text('Описание должно быть не длиннее 2000 символов.'),
      findsOneWidget,
    );
  });

  testWidgets('добавление подзадачи вызывает subtaskRepo.create', (tester) async {
    stubCommon();
    when(() => subtaskRepo.create(any())).thenAnswer(
      (_) async => TaskSubtask(
        id: 'sub-new',
        taskId: 'task-1',
        title: 'Новая подзадача',
        position: 0,
        isCompleted: false,
        createdAt: DateTime(2026, 7, 19),
      ),
    );
    when(() => subtaskRepo.getForTask('task-1')).thenAnswer((_) async => const []);

    await openSheet(tester, buildTask());

    await tester.ensureVisible(
      find.widgetWithText(TextField, 'Добавить подзадачу…'),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Добавить подзадачу…'),
      'Новая подзадача',
    );
    await tester.tap(find.byTooltip('Добавить'));
    await tester.pumpAndSettle();

    verify(() => subtaskRepo.create(any())).called(1);
  });

  testWidgets('переключение подзадачи вызывает subtaskRepo.toggle', (
    tester,
  ) async {
    stubCommon();
    final subtask = TaskSubtask(
      id: 'sub-1',
      taskId: 'task-1',
      title: 'Помыть',
      position: 0,
      isCompleted: false,
      createdAt: DateTime(2026, 7, 19),
    );
    when(() => subtaskRepo.getForTask('task-1')).thenAnswer(
      (_) async => [subtask],
    );
    when(() => subtaskRepo.toggle('sub-1', true)).thenAnswer(
      (_) async => subtask.copyWith(isCompleted: true),
    );

    await openSheet(tester, buildTask());

    await tester.ensureVisible(find.byTooltip('Отметить выполненной'));
    await tester.tap(find.byTooltip('Отметить выполненной'));
    await tester.pumpAndSettle();

    verify(() => subtaskRepo.toggle('sub-1', true)).called(1);
  });

  testWidgets('удаление подзадачи свайпом вызывает subtaskRepo.delete', (
    tester,
  ) async {
    stubCommon();
    final subtask = TaskSubtask(
      id: 'sub-1',
      taskId: 'task-1',
      title: 'Помыть',
      position: 0,
      isCompleted: false,
      createdAt: DateTime(2026, 7, 19),
    );
    when(() => subtaskRepo.getForTask('task-1')).thenAnswer(
      (_) async => [subtask],
    );
    when(() => subtaskRepo.delete('sub-1')).thenAnswer((_) async {});

    await openSheet(tester, buildTask());

    await tester.ensureVisible(find.text('Помыть'));
    await tester.drag(find.text('Помыть'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    verify(() => subtaskRepo.delete('sub-1')).called(1);
  });

  testWidgets('ошибка загрузки подзадач не ломает форму', (tester) async {
    when(
      () => mocks.household.getMembers(householdId: any(named: 'householdId')),
    ).thenAnswer((_) async => const [member]);
    when(
      () => categoryRepo.getForHousehold(any()),
    ).thenAnswer((_) async => const <TaskCategory>[]);
    when(() => subtaskRepo.getForTask(any())).thenThrow(Exception('boom'));

    await openSheet(tester, buildTask());

    expect(find.byKey(const Key('edit_task_title_field')), findsOneWidget);
  });

  testWidgets('выбор дедлайна через пикер и очистка', (tester) async {
    stubCommon();

    // plannedFor в будущем — чтобы date picker открылся без assertion.
    await openSheet(
      tester,
      buildTask(plannedFor: DateTime(2026, 9, 1, 10)),
    );

    // Текущая дата 2026-08-09 (в тестах) — выбираем первый доступный день.
    await tester.tap(find.text('Добавить дедлайн'));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Time picker.
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Убрать дедлайн'), findsOneWidget);

    await tester.tap(find.text('Убрать дедлайн'));
    await tester.pumpAndSettle();

    expect(find.text('Добавить дедлайн'), findsOneWidget);
  });

  testWidgets('выбор исполнителя через пикер и сохранение', (tester) async {
    stubCommon();
    when(() => mocks.task.save(any())).thenAnswer((_) async {});

    await openSheet(tester, buildTask(assignedMemberId: null));

    await tester.ensureVisible(find.text('Назначить ответственного'));
    await tester.tap(find.text('Назначить ответственного'));
    await tester.pumpAndSettle();

    expect(find.text('Назначить ответственного'), findsWidgets);
    await tester.tap(find.text('Анна'));
    await tester.pumpAndSettle();

    // Теперь должен появиться переключатель «Закрепить».
    expect(find.byKey(const Key('edit_pin_assignee_switch')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('save_task_button')));
    await tester.tap(find.byKey(const Key('save_task_button')));
    await tester.pumpAndSettle();

    verify(() => mocks.task.save(any())).called(1);
  });

  testWidgets('снятие исполнителя (Без ответственного) снимает закрепление', (
    tester,
  ) async {
    stubCommon();

    await openSheet(tester, buildTask());

    await tester.ensureVisible(find.text('Анна'));
    await tester.tap(find.text('Анна'));
    await tester.pumpAndSettle();

    // Открыть пикер.
    await tester.tap(find.text('Назначить ответственного'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Без ответственного'));
    await tester.pumpAndSettle();

    // Пин-свитч исчез (нет исполнителя).
    expect(find.byKey(const Key('edit_pin_assignee_switch')), findsNothing);
  });

  testWidgets('серия: «Все задачи в серии» → updateTemplate с scope all', (
    tester,
  ) async {
    stubCommon();
    when(() => mocks.task.updateTemplate(params: any(named: 'params')))
        .thenAnswer((_) async {});

    await openSheet(
      tester,
      buildTask(templateId: 'tpl-1', recurrence: const TaskRecurrence.daily()),
    );

    await tester.tap(find.text('Все задачи в серии'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('edit_recurrence_editor')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('save_task_button')));
    await tester.tap(find.byKey(const Key('save_task_button')));
    await tester.pumpAndSettle();

    verify(
      () => mocks.task.updateTemplate(params: any(named: 'params')),
    ).called(1);
  });

  testWidgets('ошибка загрузки участников показывает форму и не падает', (
    tester,
  ) async {
    when(
      () => mocks.household.getMembers(householdId: any(named: 'householdId')),
    ).thenThrow(Exception('boom'));
    when(() => subtaskRepo.getForTask(any())).thenAnswer((_) async => const []);
    when(
      () => categoryRepo.getForHousehold(any()),
    ).thenAnswer((_) async => const <TaskCategory>[]);

    await openSheet(tester, buildTask());

    expect(find.byKey(const Key('edit_task_title_field')), findsOneWidget);
  });

  testWidgets('выбор времени начала и напоминания сохраняет изменения', (
    tester,
  ) async {
    stubCommon();
    when(() => mocks.task.save(any())).thenAnswer((_) async {});

    await openSheet(tester, buildTask());

    // StartTimeField — кликаем по кнопке «Время начала», открывается time picker.
    await tester.ensureVisible(find.text('Время начала (весь день)'));
    await tester.tap(find.text('Время начала (весь день)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // ReminderSelector — выбираем «За 30 мин».
    await tester.ensureVisible(find.byKey(const Key('edit_reminder_selector')));
    await tester.tap(find.byKey(const Key('edit_reminder_selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('За 30 мин').last);
    await tester.pumpAndSettle();

    // PrioritySelector — кликаем по «Срочно и важно».
    await tester.ensureVisible(find.text('Срочно и важно'));
    await tester.tap(find.text('Срочно и важно'));
    await tester.pumpAndSettle();

    // Сохраняем — все onChanged ветки сработали.
    await tester.ensureVisible(find.byKey(const Key('save_task_button')));
    await tester.tap(find.byKey(const Key('save_task_button')));
    await tester.pumpAndSettle();

    verify(() => mocks.task.save(any())).called(1);
  });

  testWidgets('задача с ошибкой сохранения показывает снекбар', (tester) async {
    stubCommon();
    when(() => mocks.task.save(any())).thenThrow(Exception('boom'));

    await openSheet(tester, buildTask());

    await tester.ensureVisible(find.byKey(const Key('save_task_button')));
    await tester.tap(find.byKey(const Key('save_task_button')));
    await tester.pumpAndSettle();

    expect(
      find.text('Не удалось сохранить изменения задачи.'),
      findsOneWidget,
    );
  });

  testWidgets('добавление исполнителя, отсутствующего в allowedMemberIds', (
    tester,
  ) async {
    stubCommon();
    when(() => mocks.task.save(any())).thenAnswer((_) async {});

    // assignedMemberId не в allowedMemberIds → должен добавиться.
    final task = buildTask(assignedMemberId: 'member-2');
    await openSheet(tester, task);

    await tester.ensureVisible(find.byKey(const Key('save_task_button')));
    await tester.tap(find.byKey(const Key('save_task_button')));
    await tester.pumpAndSettle();

    verify(
      () => mocks.task.save(
        any(
          that: isA<Task>().having(
            (t) => t.allowedMemberIds,
            'allowedMemberIds',
            contains('member-2'),
          ),
        ),
      ),
    ).called(1);
  });

  testWidgets('переупорядочивание подзадач вызывает subtaskRepo.reorder', (
    tester,
  ) async {
    stubCommon();
    final sub1 = TaskSubtask(
      id: 'sub-1',
      taskId: 'task-1',
      title: 'Помыть',
      position: 0,
      isCompleted: false,
      createdAt: DateTime(2026, 7, 19),
    );
    final sub2 = TaskSubtask(
      id: 'sub-2',
      taskId: 'task-1',
      title: 'Убрать',
      position: 1,
      isCompleted: false,
      createdAt: DateTime(2026, 7, 19),
    );
    when(() => subtaskRepo.getForTask('task-1')).thenAnswer(
      (_) async => [sub1, sub2],
    );
    when(() => subtaskRepo.reorder(any(), any())).thenAnswer((_) async {});

    await openSheet(tester, buildTask());

    // Drag & drop: тащим первую подзадачу вниз (как в subtask_editor_test).
    await tester.ensureVisible(find.byIcon(Icons.drag_indicator).first);
    await tester.drag(
      find.byIcon(Icons.drag_indicator).first,
      const Offset(0, 100),
    );
    await tester.pumpAndSettle();

    verify(() => subtaskRepo.reorder('task-1', any())).called(1);
  });

  testWidgets('серия: редактирование повторения и сохранение через updateTemplate', (
    tester,
  ) async {
    stubCommon();
    when(() => mocks.task.updateTemplate(params: any(named: 'params')))
        .thenAnswer((_) async {});

    await openSheet(
      tester,
      buildTask(templateId: 'tpl-1', recurrence: const TaskRecurrence.daily()),
    );

    await tester.tap(find.text('Все задачи в серии'));
    await tester.pumpAndSettle();

    // RecurrenceEditor показан для серии.
    expect(find.byKey(const Key('edit_recurrence_editor')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('save_task_button')));
    await tester.tap(find.byKey(const Key('save_task_button')));
    await tester.pumpAndSettle();

    verify(
      () => mocks.task.updateTemplate(params: any(named: 'params')),
    ).called(1);
  });

  testWidgets('ошибка добавления подзадачи показывает снекбар', (tester) async {
    stubCommon();
    when(() => subtaskRepo.getForTask('task-1')).thenAnswer((_) async => const []);
    when(() => subtaskRepo.create(any())).thenThrow(Exception('boom'));

    await openSheet(tester, buildTask());

    await tester.ensureVisible(
      find.widgetWithText(TextField, 'Добавить подзадачу…'),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Добавить подзадачу…'),
      'Новая',
    );
    await tester.tap(find.byTooltip('Добавить'));
    await tester.pumpAndSettle();

    expect(find.text('Не удалось добавить подзадачу.'), findsOneWidget);
  });

  testWidgets('дедлайн с уже установленным значением редактируется', (
    tester,
  ) async {
    stubCommon();

    // plannedFor в будущем + deadline уже установлен.
    final task = buildTask(plannedFor: DateTime(2026, 9, 1, 10)).copyWith(
      deadline: DateTime(2026, 9, 5, 18, 30),
    );
    await openSheet(tester, task);

    // Подпись дедлайна видна.
    expect(find.text('Дедлайн: 05.09.2026, 18:30'), findsOneWidget);

    // Редактируем дедлайн через пикер (уже установлен → TimeOfDay.fromDateTime).
    await tester.tap(find.text('Дедлайн: 05.09.2026, 18:30'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Дедлайн:'), findsOneWidget);
  });

  testWidgets('закрепление исполнителя через переключатель', (tester) async {
    stubCommon();
    when(() => mocks.task.save(any())).thenAnswer((_) async {});

    await openSheet(tester, buildTask());

    // Переключатель «Закрепить» есть (исполнитель назначен).
    await tester.ensureVisible(find.byKey(const Key('edit_pin_assignee_switch')));
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('edit_pin_assignee_switch')),
          )
          .value,
      isFalse,
    );

    // Включаем закрепление.
    await tester.tap(find.byKey(const Key('edit_pin_assignee_switch')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('edit_pin_assignee_switch')),
          )
          .value,
      isTrue,
    );

    // Сохраняем — pinnedMemberId должен стать member-1.
    await tester.ensureVisible(find.byKey(const Key('save_task_button')));
    await tester.tap(find.byKey(const Key('save_task_button')));
    await tester.pumpAndSettle();

    verify(
      () => mocks.task.save(
        any(
          that: isA<Task>().having((t) => t.pinnedMemberId, 'pinnedMemberId', 'member-1'),
        ),
      ),
    ).called(1);
  });

  testWidgets('ошибка переключения подзадачи показывает снекбар', (
    tester,
  ) async {
    stubCommon();
    final subtask = TaskSubtask(
      id: 'sub-1',
      taskId: 'task-1',
      title: 'Помыть',
      position: 0,
      isCompleted: false,
      createdAt: DateTime(2026, 7, 19),
    );
    when(() => subtaskRepo.getForTask('task-1')).thenAnswer(
      (_) async => [subtask],
    );
    when(() => subtaskRepo.toggle(any(), any())).thenThrow(Exception('boom'));

    await openSheet(tester, buildTask());

    await tester.ensureVisible(find.byTooltip('Отметить выполненной'));
    await tester.tap(find.byTooltip('Отметить выполненной'));
    await tester.pumpAndSettle();

    expect(find.text('Не удалось обновить подзадачу.'), findsOneWidget);
  });

  testWidgets('ошибка удаления подзадачи показывает снекбар', (tester) async {
    stubCommon();
    final subtask = TaskSubtask(
      id: 'sub-1',
      taskId: 'task-1',
      title: 'Помыть',
      position: 0,
      isCompleted: false,
      createdAt: DateTime(2026, 7, 19),
    );
    when(() => subtaskRepo.getForTask('task-1')).thenAnswer(
      (_) async => [subtask],
    );
    when(() => subtaskRepo.delete(any())).thenThrow(Exception('boom'));

    await openSheet(tester, buildTask());

    await tester.ensureVisible(find.text('Помыть'));
    await tester.drag(find.text('Помыть'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Не удалось удалить подзадачу.'), findsOneWidget);
  });

  testWidgets('ошибка переупорядочивания подзадач показывает снекбар', (
    tester,
  ) async {
    stubCommon();
    final sub1 = TaskSubtask(
      id: 'sub-1',
      taskId: 'task-1',
      title: 'Помыть',
      position: 0,
      isCompleted: false,
      createdAt: DateTime(2026, 7, 19),
    );
    final sub2 = TaskSubtask(
      id: 'sub-2',
      taskId: 'task-1',
      title: 'Убрать',
      position: 1,
      isCompleted: false,
      createdAt: DateTime(2026, 7, 19),
    );
    when(() => subtaskRepo.getForTask('task-1')).thenAnswer(
      (_) async => [sub1, sub2],
    );
    when(() => subtaskRepo.reorder(any(), any())).thenThrow(Exception('boom'));

    await openSheet(tester, buildTask());

    await tester.ensureVisible(find.byIcon(Icons.drag_indicator).first);
    await tester.drag(
      find.byIcon(Icons.drag_indicator).first,
      const Offset(0, 100),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Не удалось изменить порядок подзадач.'),
      findsOneWidget,
    );
  });

  testWidgets('снятие категории через крестик вызывает onChanged(null)', (
    tester,
  ) async {
    when(
      () => mocks.household.getMembers(householdId: any(named: 'householdId')),
    ).thenAnswer((_) async => const [member]);
    when(() => subtaskRepo.getForTask(any())).thenAnswer(
      (_) async => const <TaskSubtask>[],
    );
    when(() => categoryRepo.getForHousehold('household-1')).thenAnswer(
      (_) async => const [
        TaskCategory(
          id: 'cat-1',
          householdId: 'household-1',
          name: 'Кухня',
          colorHex: 'FF5722',
        ),
      ],
    );

    final task = buildTask(categoryId: 'cat-1');
    await openSheet(tester, task);

    // Крестик сброса категории.
    await tester.ensureVisible(find.byIcon(Icons.close));
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // Категория снята → подпись «Категория — необязательно».
    await tester.ensureVisible(find.text('Категория — необязательно'));
    expect(find.text('Категория — необязательно'), findsOneWidget);
  });

  testWidgets('создание новой категории из поля в редактировании', (
    tester,
  ) async {
    when(
      () => mocks.household.getMembers(householdId: any(named: 'householdId')),
    ).thenAnswer((_) async => const [member]);
    when(() => subtaskRepo.getForTask(any())).thenAnswer(
      (_) async => const <TaskSubtask>[],
    );
    when(() => categoryRepo.getForHousehold('household-1')).thenAnswer(
      (_) async => const <TaskCategory>[],
    );
    when(() => categoryRepo.create(any())).thenAnswer(
      (_) async => const TaskCategory(
        id: 'cat-3',
        householdId: 'household-1',
        name: 'Работа',
        colorHex: '43A047',
      ),
    );

    await openSheet(tester, buildTask());

    await tester.ensureVisible(find.text('Категория — необязательно'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Категория — необязательно'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Создать новую'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'Работа',
    );
    await tester.pump();

    await tester.tap(find.text('Создать'));
    await tester.pumpAndSettle();

    verify(() => categoryRepo.create(any())).called(1);
    expect(find.text('Работа'), findsWidgets);
  });

  testWidgets('выбор категории в поле редактирования', (tester) async {
    when(
      () => mocks.household.getMembers(householdId: any(named: 'householdId')),
    ).thenAnswer((_) async => const [member]);
    when(() => subtaskRepo.getForTask(any())).thenAnswer(
      (_) async => const <TaskSubtask>[],
    );
    when(() => categoryRepo.getForHousehold('household-1')).thenAnswer(
      (_) async => const [
        TaskCategory(
          id: 'cat-1',
          householdId: 'household-1',
          name: 'Кухня',
          colorHex: 'FF5722',
        ),
      ],
    );

    await openSheet(tester, buildTask());

    await tester.ensureVisible(find.text('Категория — необязательно'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Категория — необязательно'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Кухня'));
    await tester.pumpAndSettle();

    // После выбора на поле появляется чип с названием → два вхождения.
    expect(find.text('Кухня'), findsNWidgets(2));
  });

  testWidgets('смена исполнителя на нового добавляет его в allowedMemberIds', (
    tester,
  ) async {
    stubCommon();
    when(() => mocks.task.save(any())).thenAnswer((_) async {});

    // Задача назначена на member-1; выбираем member-2 (другой участник).
    final task = buildTask(assignedMemberId: 'member-1');
    final otherMember = const HouseholdMember(
      profileId: 'member-2',
      displayName: 'Борис',
      role: 'member',
    );
    when(
      () => mocks.household.getMembers(householdId: any(named: 'householdId')),
    ).thenAnswer((_) async => [member, otherMember]);

    await openSheet(tester, task);

    await tester.ensureVisible(find.text('Анна'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Анна'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Борис'));
    await tester.pumpAndSettle();

    // _isPinned остаётся false (новая ветка не выбрана) — сохраняем.
    await tester.ensureVisible(find.byKey(const Key('save_task_button')));
    await tester.tap(find.byKey(const Key('save_task_button')));
    await tester.pumpAndSettle();

    verify(
      () => mocks.task.save(
        any(
          that: isA<Task>().having(
            (t) => t.allowedMemberIds,
            'allowedMemberIds',
            contains('member-2'),
          ),
        ),
      ),
    ).called(1);
  });

  testWidgets('серия: выбор «Эту и последующие» и сохранение через updateTemplate', (
    tester,
  ) async {
    stubCommon();
    when(() => mocks.task.updateTemplate(params: any(named: 'params')))
        .thenAnswer((_) async {});

    await openSheet(
      tester,
      buildTask(templateId: 'tpl-1', recurrence: const TaskRecurrence.daily()),
    );

    await tester.tap(find.text('Эту и последующие'));
    await tester.pumpAndSettle();

    // Редактор повторения виден и активен.
    expect(find.byKey(const Key('edit_recurrence_editor')), findsOneWidget);

    // Изменяем повторение через onChanged → ветка setState(_recurrenceDraft).
    await tester.ensureVisible(
      find.byKey(const Key('recurrence_type_dropdown')),
    );
    await tester.tap(find.byKey(const Key('recurrence_type_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Раз в несколько дней').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('save_task_button')));
    await tester.tap(find.byKey(const Key('save_task_button')));
    await tester.pumpAndSettle();

    verify(
      () => mocks.task.updateTemplate(params: any(named: 'params')),
    ).called(1);
  });

  testWidgets('серия: выбор «Все задачи в серии» с редактированием повторения', (
    tester,
  ) async {
    stubCommon();
    when(() => mocks.task.updateTemplate(params: any(named: 'params')))
        .thenAnswer((_) async {});

    await openSheet(
      tester,
      buildTask(templateId: 'tpl-1', recurrence: const TaskRecurrence.daily()),
    );

    await tester.tap(find.text('Все задачи в серии'));
    await tester.pumpAndSettle();

    // Меняем тип повторения на intervalDays → обновляется draft.
    await tester.ensureVisible(
      find.byKey(const Key('recurrence_type_dropdown')),
    );
    await tester.tap(find.byKey(const Key('recurrence_type_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Раз в несколько дней').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('save_task_button')));
    await tester.tap(find.byKey(const Key('save_task_button')));
    await tester.pumpAndSettle();

    verify(
      () => mocks.task.updateTemplate(params: any(named: 'params')),
    ).called(1);
  });
}
