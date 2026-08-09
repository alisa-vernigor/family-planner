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
  }) {
    return Task(
      id: id,
      householdId: 'household-1',
      title: 'Купить продукты',
      description: 'Молоко и хлеб',
      estimatedDurationMinutes: 30,
      plannedFor: DateTime(2026, 7, 20, 10),
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
}
