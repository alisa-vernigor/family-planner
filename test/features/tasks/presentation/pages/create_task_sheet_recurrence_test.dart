import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/households/domain/entities/household.dart';
import 'package:family_planner/features/households/domain/entities/household_invitation.dart';
import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/households/domain/repositories/household_repository.dart';
import 'package:family_planner/features/tasks/domain/entities/create_task_category_params.dart';
import 'package:family_planner/features/tasks/domain/entities/create_task_params.dart';
import 'package:family_planner/features/tasks/domain/entities/eisenhower_priority.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_category.dart';
import 'package:family_planner/features/tasks/domain/entities/update_recurring_task_params.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_category_repository.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/tasks/domain/use_cases/create_task_use_case.dart';
import 'package:family_planner/features/tasks/presentation/cubit/create_task_cubit.dart';
import 'package:family_planner/features/tasks/presentation/pages/create_task_sheet.dart';
import 'package:family_planner/features/tasks/presentation/widgets/priority_selector.dart';
import 'package:family_planner/features/tasks/presentation/widgets/reminder_selector.dart';

const _member = HouseholdMember(
  profileId: 'member-1',
  displayName: 'Анна',
  role: 'owner',
);

void main() {
  Widget buildSubject({
    _FakeTaskRepository? taskRepository,
    _FakeHouseholdRepository? householdRepository,
    _FakeTaskCategoryRepository? categoryRepository,
  }) {
    // RepositoryProvider<TaskCategoryRepository> размещаем ВЫШЕ MaterialApp,
    // чтобы bottom sheet пикера категорий (новая route) мог до него достать.
    return RepositoryProvider<TaskCategoryRepository>(
      create: (_) => categoryRepository ?? _FakeTaskCategoryRepository(),
      child: MaterialApp(
        home: Scaffold(
          body: BlocProvider(
            create: (_) => CreateTaskCubit(
              createTaskUseCase: CreateTaskUseCase(
                repository: taskRepository ?? _FakeTaskRepository(),
              ),
            ),
            child: CreateTaskSheet(
              householdId: 'household-1',
              plannedFor: DateTime(2026, 7, 19),
              householdRepository:
                  householdRepository ?? _FakeHouseholdRepository(),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> useTallViewport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpForm(
    WidgetTester tester, {
    _FakeTaskRepository? taskRepository,
    _FakeHouseholdRepository? householdRepository,
    _FakeTaskCategoryRepository? categoryRepository,
  }) async {
    await useTallViewport(tester);
    await tester.pumpWidget(
      buildSubject(
        taskRepository: taskRepository,
        householdRepository: householdRepository,
        categoryRepository: categoryRepository,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapCreate(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Создать задачу'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Создать задачу'));
    await tester.pumpAndSettle();
  }

  testWidgets('поля повторения скрыты до включения переключателя', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    expect(find.byKey(const Key('recurrence_switch')), findsOneWidget);
    expect(find.byKey(const Key('recurrence_type_dropdown')), findsNothing);
    expect(find.byKey(const Key('weekday_chip_1')), findsNothing);
    expect(find.byKey(const Key('recurrence_interval_field')), findsNothing);
  });

  testWidgets('после включения показывается выбор режима повторения', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    await tester.tap(find.byKey(const Key('recurrence_switch')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('recurrence_type_dropdown')), findsOneWidget);
    expect(find.byKey(const Key('recurrence_type_dropdown')), findsOneWidget);
  });

  testWidgets('кнопки периода повтора появляются после включения', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    await tester.tap(find.byKey(const Key('recurrence_switch')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('recurrence_start_date_button')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('recurrence_end_date_button')), findsOneWidget);
    expect(find.text('Начать повторение с даты задачи'), findsOneWidget);
    expect(find.text('Закончить повторение — без срока'), findsOneWidget);
  });

  testWidgets('можно выбрать день недели для еженедельного повтора', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    await tester.tap(find.byKey(const Key('recurrence_switch')));
    await tester.pumpAndSettle();

    // Прокручиваем до dropdown (форма стала длиннее — StartTimeField).
    await tester.ensureVisible(
      find.byKey(const Key('recurrence_type_dropdown')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('recurrence_type_dropdown')));
    await tester.pumpAndSettle();

    // Опция в выпадающем списке может быть вне экрана — прокручиваем.
    final weeklyOption = find.text('В выбранные дни недели');
    await tester.ensureVisible(weeklyOption.last);
    await tester.pumpAndSettle();

    await tester.tap(weeklyOption.last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('weekday_chip_1')), findsOneWidget);

    // Прокручиваем до дня недели (RecurrenceSummary мог сдвинуть)
    await tester.ensureVisible(find.byKey(const Key('weekday_chip_1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('weekday_chip_1')));
    await tester.pumpAndSettle();

    final monday = tester.widget<FilterChip>(
      find.byKey(const Key('weekday_chip_1')),
    );

    expect(monday.selected, isTrue);
  });

  testWidgets('пустое название показывает ошибку валидации', (tester) async {
    await pumpForm(tester);

    await tapCreate(tester);

    expect(find.text('Введите название задачи.'), findsOneWidget);
  });

  testWidgets('название длиннее 160 символов — ошибка', (tester) async {
    await pumpForm(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Название'),
      'а' * 161,
    );
    await tapCreate(tester);

    expect(
      find.text('Название должно быть не длиннее 160 символов.'),
      findsOneWidget,
    );
  });

  testWidgets('описание длиннее 2000 символов — ошибка', (tester) async {
    await pumpForm(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Описание — необязательно'),
      'а' * 2001,
    );
    await tapCreate(tester);

    expect(
      find.text('Описание должно быть не длиннее 2000 символов.'),
      findsOneWidget,
    );
  });

  testWidgets('длительность не больше нуля — ошибка', (tester) async {
    await pumpForm(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Длительность работы, минут'),
      '0',
    );
    await tapCreate(tester);

    expect(find.text('Введите длительность больше нуля.'), findsOneWidget);
  });

  testWidgets('длительность больше 24 часов — ошибка', (tester) async {
    await pumpForm(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Длительность работы, минут'),
      '1500',
    );
    await tapCreate(tester);

    expect(find.text('Максимум 24 часа (1440 минут).'), findsOneWidget);
  });

  testWidgets('ошибка загрузки участников не роняет форму', (tester) async {
    await pumpForm(
      tester,
      householdRepository: _FakeHouseholdRepository(
        membersError: Exception('boom'),
      ),
    );

    expect(find.text('Новая задача'), findsOneWidget);
    expect(find.text('Назначить ответственного'), findsOneWidget);
  });

  testWidgets('отмена в календаре дедлайна ничего не меняет', (tester) async {
    await pumpForm(tester);

    await tester.ensureVisible(find.text('Добавить дедлайн'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Добавить дедлайн'));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Добавить дедлайн'), findsOneWidget);
  });

  testWidgets('отмена в выборе времени дедлайна ничего не меняет', (
    tester,
  ) async {
    await pumpForm(tester);

    await tester.ensureVisible(find.text('Добавить дедлайн'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Добавить дедлайн'));
    await tester.pumpAndSettle();

    // Выбираем начальную дату (OK без тапа по дню) — открывается time picker.
    await tester.tap(find.textContaining('OK').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Добавить дедлайн'), findsOneWidget);
  });

  testWidgets('дедлайн: установка и сброс', (tester) async {
    await pumpForm(tester);

    await tester.ensureVisible(find.text('Добавить дедлайн'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Добавить дедлайн'));
    await tester.pumpAndSettle();

    // Подтверждаем дату и время.
    await tester.tap(find.textContaining('OK').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Дедлайн:'), findsOneWidget);
    expect(find.text('Убрать дедлайн'), findsOneWidget);

    await tester.tap(find.text('Убрать дедлайн'));
    await tester.pumpAndSettle();

    expect(find.text('Добавить дедлайн'), findsOneWidget);
  });

  testWidgets('повторное открытие дедлайна использует установленное время', (
    tester,
  ) async {
    await pumpForm(tester);

    // Устанавливаем дедлайн (дата + время).
    await tester.ensureVisible(find.text('Добавить дедлайн'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Добавить дедлайн'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('OK').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Дедлайн:'), findsOneWidget);

    // Открываем снова — теперь _deadline != null,
    // initialTime у time picker берётся из TimeOfDay.fromDateTime(_deadline!).
    await tester.tap(find.textContaining('Дедлайн:'));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);

    // Подтверждаем дату → открывается time picker (не падает).
    await tester.tap(find.textContaining('OK').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Дедлайн:'), findsOneWidget);
  });

  testWidgets('выбор ответственного показывает его и закрепление', (
    tester,
  ) async {
    await pumpForm(
      tester,
      householdRepository: _FakeHouseholdRepository(members: const [_member]),
    );

    await tester.ensureVisible(find.text('Назначить ответственного'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Назначить ответственного'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Анна'));
    await tester.pumpAndSettle();

    // Имя отображается в кнопке.
    expect(find.text('Анна'), findsOneWidget);
    final pinSwitch = find.byKey(const Key('pin_assignee_switch'));
    expect(pinSwitch, findsOneWidget);

    // Включаем закрепление.
    await tester.ensureVisible(pinSwitch);
    await tester.pumpAndSettle();
    await tester.tap(pinSwitch);
    await tester.pumpAndSettle();

    final switchWidget = tester.widget<SwitchListTile>(pinSwitch);
    expect(switchWidget.value, isTrue);
  });

  testWidgets('выбор «Без ответственного» снимает назначение', (tester) async {
    await pumpForm(
      tester,
      householdRepository: _FakeHouseholdRepository(members: const [_member]),
    );

    await tester.ensureVisible(find.text('Назначить ответственного'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Назначить ответственного'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Анна'));
    await tester.pumpAndSettle();

    // Открываем снова (кнопка теперь показывает имя) и снимаем назначение.
    await tester.tap(find.text('Анна'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Без ответственного'));
    await tester.pumpAndSettle();

    expect(find.text('Назначить ответственного'), findsOneWidget);
    expect(find.byKey(const Key('pin_assignee_switch')), findsNothing);
  });

  testWidgets('отмена выбора ответственного ничего не меняет', (tester) async {
    await pumpForm(
      tester,
      householdRepository: _FakeHouseholdRepository(members: const [_member]),
    );

    await tester.ensureVisible(find.text('Назначить ответственного'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Назначить ответственного'));
    await tester.pumpAndSettle();

    // Закрываем по барьеру — пикер возвращает null.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('Назначить ответственного'), findsOneWidget);
  });

  testWidgets('еженедельный повтор без дней недели — ошибка', (tester) async {
    await pumpForm(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Название'),
      'Повтор',
    );

    await tester.ensureVisible(find.byKey(const Key('recurrence_switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recurrence_switch')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('recurrence_type_dropdown')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recurrence_type_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('В выбранные дни недели').last);
    await tester.pumpAndSettle();

    await tapCreate(tester);

    expect(find.text('Выберите хотя бы один день недели.'), findsOneWidget);
  });

  testWidgets('повтор с интервалом 0 — ошибка', (tester) async {
    await pumpForm(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Название'),
      'Повтор',
    );

    await tester.ensureVisible(find.byKey(const Key('recurrence_switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recurrence_switch')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('recurrence_type_dropdown')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recurrence_type_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Раз в несколько дней').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('recurrence_interval_field')),
      '0',
    );

    await tapCreate(tester);

    expect(
      find.text('Введите интервал повторения больше нуля.'),
      findsOneWidget,
    );
  });

  testWidgets('выбор времени начала', (tester) async {
    await pumpForm(tester);

    await tester.ensureVisible(find.text('Время начала (весь день)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Время начала (весь день)'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Начало: 09:00'), findsOneWidget);
  });

  testWidgets('выбор приоритета', (tester) async {
    await pumpForm(tester);

    await tester.ensureVisible(find.text('Срочно и важно'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Срочно и важно'));
    await tester.pumpAndSettle();

    final selector = tester.widget<PrioritySelector>(
      find.byType(PrioritySelector),
    );
    expect(selector.value, EisenhowerPriority.urgentImportant);
  });

  testWidgets('выбор напоминания', (tester) async {
    await pumpForm(tester);

    await tester.ensureVisible(find.text('Без напоминания'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Без напоминания'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('За 5 мин').last);
    await tester.pumpAndSettle();

    final selector = tester.widget<ReminderSelector>(
      find.byType(ReminderSelector),
    );
    expect(selector.value, 5);
  });

  testWidgets('выбор категории', (tester) async {
    final categoryRepo = _FakeTaskCategoryRepository(
      categories: const [
        TaskCategory(
          id: 'cat-1',
          householdId: 'household-1',
          name: 'Покупки',
          colorHex: 'E53935',
        ),
      ],
    );
    await pumpForm(tester, categoryRepository: categoryRepo);

    await tester.ensureVisible(find.text('Категория — необязательно'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Категория — необязательно'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Покупки'));
    await tester.pumpAndSettle();

    expect(find.text('Покупки'), findsWidgets);
  });

  testWidgets('создание новой категории из поля', (tester) async {
    final categoryRepo = _FakeTaskCategoryRepository(
      categories: const [],
      onCreateCategory: (params) async => TaskCategory(
        id: 'cat-3',
        householdId: 'household-1',
        name: params.name,
        colorHex: params.colorHex ?? 'E53935',
      ),
    );
    await pumpForm(tester, categoryRepository: categoryRepo);

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

    expect(find.text('Работа'), findsWidgets);
  });

  testWidgets('ошибка создания задачи показывает SnackBar', (tester) async {
    final repo = _FakeTaskRepository(
      onCreate: (_) async => throw Exception('boom'),
    );
    await pumpForm(tester, taskRepository: repo);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Название'),
      'Купить молоко',
    );

    await tapCreate(tester);

    expect(find.text('Не удалось создать задачу.'), findsOneWidget);

    // Дожимаем auto-dismiss таймер SnackBar.
    await tester.pump(const Duration(seconds: 5));
  });
}

final class _FakeTaskRepository implements TaskRepository {
  _FakeTaskRepository({this.onCreate});

  final Future<Task> Function(CreateTaskParams params)? onCreate;

  @override
  Future<void> updateTemplate({
    required UpdateRecurringTaskParams params,
  }) async {}

  @override
  Future<void> pauseTemplate({required String templateId}) async {}

  @override
  Future<void> resumeTemplate({required String templateId}) async {}

  @override
  Future<Task> create({required CreateTaskParams params}) {
    final handler = onCreate;
    if (handler != null) return handler(params);
    throw UnimplementedError();
  }

  @override
  Future<void> delete({required String taskId}) async {}

  @override
  Future<List<Task>> getForDay({
    required String householdId,
    required DateTime day,
  }) async {
    return const [];
  }

  @override
  Future<List<Task>> getScheduledAfter({
    required String householdId,
    required DateTime day,
  }) async {
    return const [];
  }

  @override
  Future<void> save(Task task) async {}

  @override
  Future<List<Task>> getAllPending({
    required String householdId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> addAllowedMember({
    required String taskId,
    required String memberId,
  }) async {}

  @override
  Future<void> removeAllowedMember({
    required String taskId,
    required String memberId,
  }) async {}

  @override
  Future<void> patchStatus({
    required String taskId,
    required String status,
    String? completedByMemberId,
    String? completedAt,
    String? assignedMemberId,
  }) async {}
}

final class _FakeHouseholdRepository implements HouseholdRepository {
  _FakeHouseholdRepository({this.members = const [], this.membersError});

  final List<HouseholdMember> members;
  final Object? membersError;

  @override
  Future<List<HouseholdMember>> getMembers({
    required String householdId,
  }) async {
    final error = membersError;
    if (error != null) throw error;
    return members;
  }

  @override
  Future<List<Household>> getMyHouseholds() async => [];

  @override
  Future<Household> create({required String name}) async =>
      Household(id: '1', name: name);

  @override
  Future<void> createInvitation({
    required String householdId,
    required String email,
  }) async {}

  @override
  Future<List<HouseholdInvitation>> getPendingInvitations() async => [];

  @override
  Future<String> acceptInvitation({required String invitationId}) async =>
      'household-1';

  @override
  Future<void> declineInvitation({required String invitationId}) async {}

  @override
  Future<void> leaveHousehold({required String householdId}) async {}

  @override
  Future<void> removeMember({
    required String householdId,
    required String profileId,
  }) async {}

  @override
  Future<void> deleteHousehold({required String householdId}) async {}

  @override
  Future<void> updateHousehold({
    required String householdId,
    required String name,
  }) async {}
}

final class _FakeTaskCategoryRepository implements TaskCategoryRepository {
  _FakeTaskCategoryRepository({
    this.categories = const [],
    this.onCreateCategory,
  });

  final List<TaskCategory> categories;
  final Future<TaskCategory> Function(CreateTaskCategoryParams params)?
  onCreateCategory;

  @override
  Future<List<TaskCategory>> getForHousehold(String householdId) async {
    return categories;
  }

  @override
  Future<TaskCategory> create(CreateTaskCategoryParams params) {
    final handler = onCreateCategory;
    if (handler != null) return handler(params);
    throw UnimplementedError();
  }

  @override
  Future<void> update(TaskCategory category) async {}

  @override
  Future<void> delete(String categoryId) async {}
}
