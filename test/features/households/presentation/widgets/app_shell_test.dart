import 'package:drift/drift.dart' hide Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:family_planner/core/database/app_database.dart' hide HouseholdMember;
import 'package:family_planner/core/services/connectivity_service.dart';
import 'package:family_planner/core/sync/sync_cubit.dart';
import 'package:family_planner/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:family_planner/features/households/domain/entities/household.dart';
import 'package:family_planner/features/households/domain/entities/household_invitation.dart';
import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/households/domain/repositories/household_repository.dart';
import 'package:family_planner/features/households/presentation/cubit/household_cubit.dart';
import 'package:family_planner/features/households/presentation/cubit/household_invitations_cubit.dart';
import 'package:family_planner/features/households/presentation/pages/create_household_page.dart';
import 'package:family_planner/features/households/presentation/pages/household_invitations_page.dart';
import 'package:family_planner/features/households/presentation/pages/household_members_page.dart';
import 'package:family_planner/features/households/presentation/widgets/app_shell.dart';
import 'package:family_planner/features/import_export/presentation/pages/import_export_page.dart';
import 'package:family_planner/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:family_planner/features/profile/domain/entities/user_profile.dart';
import 'package:family_planner/features/profile/domain/repositories/profile_repository.dart';
import 'package:family_planner/features/profile/presentation/pages/profile_settings_page.dart';
import 'package:family_planner/features/tasks/domain/entities/create_task_params.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_category_repository.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_subtask_repository.dart';

import '../../../../helpers/mock_repository_factory.dart';

final class MockTaskCategoryRepository extends Mock
    implements TaskCategoryRepository {}

final class MockTaskSubtaskRepository extends Mock
    implements TaskSubtaskRepository {}

/// Хост-виджет, который держит `currentTab` и выбранную семью в состоянии
/// и передаёт настоящие `onTabChanged`/`onHouseholdChanged`, чтобы переключение
/// табов и смена семьи реально перестраивали AppShell.
final class _AppShellHost extends StatefulWidget {
  const _AppShellHost({
    this.households = const [Household(id: 'h-1', name: 'Семья')],
    this.initialSelectedHouseholdId = 'h-1',
  });

  final List<Household> households;
  final String initialSelectedHouseholdId;

  @override
  State<_AppShellHost> createState() => _AppShellHostState();
}

final class _AppShellHostState extends State<_AppShellHost> {
  int _currentTab = 0;
  late String _selectedHouseholdId;

  @override
  void initState() {
    super.initState();
    _selectedHouseholdId = widget.initialSelectedHouseholdId;
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      households: widget.households,
      selectedHouseholdId: _selectedHouseholdId,
      currentMemberId: 'member-1',
      currentTab: _currentTab,
      onTabChanged: (index) => setState(() => _currentTab = index),
      onHouseholdChanged: (id) => setState(() => _selectedHouseholdId = id),
    );
  }
}

void main() {
  late MockRepositoryFactory mocks;
  late MockTaskCategoryRepository categoryRepo;
  late MockTaskSubtaskRepository subtaskRepo;
  late AppDatabase testDb;

  setUpAll(() {
    registerFallbackValue(const Household(id: 'h-1', name: 'Семья'));
    registerFallbackValue(const HouseholdMembersCompanion(
      profileId: Value('p'),
      householdId: Value('h'),
      displayName: Value('d'),
      role: Value('member'),
    ));
    registerFallbackValue(
      CreateTaskParams(
        householdId: 'h-1',
        title: 'fallback',
        estimatedDurationMinutes: 30,
        plannedFor: DateTime(2026, 8, 9),
      ),
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mocks = MockRepositoryFactory();
    categoryRepo = MockTaskCategoryRepository();
    subtaskRepo = MockTaskSubtaskRepository();
    testDb = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await testDb.close();
  });

  void stubDependencies({bool online = true}) {
    when(() => mocks.household.getPendingInvitations()).thenAnswer(
      (_) async => const [],
    );
    when(
      () => mocks.household.getMembers(householdId: any(named: 'householdId')),
    ).thenAnswer((_) async => const []);
    when(
      () => mocks.task.getForDay(
        householdId: any(named: 'householdId'),
        day: any(named: 'day'),
      ),
    ).thenAnswer((_) async => const []);
    when(
      () => mocks.task.getAllPending(
        householdId: any(named: 'householdId'),
      ),
    ).thenAnswer((_) async => const []);
    when(
      () => categoryRepo.getForHousehold(any()),
    ).thenAnswer((_) async => const []);
    when(
      () => subtaskRepo.getForTask(any()),
    ).thenAnswer((_) async => const []);
    when(
      () => mocks.notifications.getActivityFeed(
        householdId: any(named: 'householdId'),
      ),
    ).thenAnswer((_) async => const []);
    when(() => mocks.notifications.markAllRead()).thenAnswer((_) async {});
    when(() => mocks.auth.signOut()).thenAnswer((_) async {});
    when(
      () => mocks.household.updateHousehold(
        householdId: any(named: 'householdId'),
        name: any(named: 'name'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mocks.household.deleteHousehold(householdId: any(named: 'householdId')),
    ).thenAnswer((_) async {});
    when(() => mocks.household.create(name: any(named: 'name')))
        .thenAnswer(
      (_) async => const Household(id: 'h-new', name: 'Новая семья'),
    );
    when(() => mocks.connectivity.currentOnline).thenReturn(online);
    when(() => mocks.connectivity.isOnline)
        .thenAnswer((_) => const Stream<bool>.empty());
    when(
      () => mocks.household.getMyHouseholds(),
    ).thenAnswer((_) async => const [Household(id: 'h-1', name: 'Семья')]);
    when(() => mocks.profile.getProfile(any())).thenAnswer(
      (_) async => const UserProfile(
        id: 'member-1',
        displayName: 'Анна',
        timezone: 'Europe/Moscow',
      ),
    );
  }

  Widget buildSubject({
    List<Household> households = const [Household(id: 'h-1', name: 'Семья')],
    String? initialSelectedHouseholdId,
  }) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<HouseholdRepository>(
          create: (_) => mocks.household,
        ),
        RepositoryProvider<TaskRepository>(create: (_) => mocks.task),
        RepositoryProvider<TaskCategoryRepository>(
          create: (_) => categoryRepo,
        ),
        RepositoryProvider<TaskSubtaskRepository>(
          create: (_) => subtaskRepo,
        ),
        RepositoryProvider<NotificationsRepository>(
          create: (_) => mocks.notifications,
        ),
        RepositoryProvider<ProfileRepository>(
          create: (_) => mocks.profile,
        ),
        RepositoryProvider<ConnectivityService>(
          create: (_) => mocks.connectivity,
        ),
        RepositoryProvider<AppDatabase>(
          create: (_) => testDb,
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>(
            create: (_) => AuthCubit(
              authRepository: mocks.auth,
              enableAuthListener: false,
            ),
          ),
          BlocProvider<HouseholdCubit>(
            create: (_) =>
                HouseholdCubit(householdRepository: mocks.household),
          ),
          BlocProvider<HouseholdInvitationsCubit>(
            create: (_) => HouseholdInvitationsCubit(
              householdRepository: mocks.household,
            ),
          ),
          BlocProvider<SyncCubit>(
            create: (_) => SyncCubit(
              connectivityService: mocks.connectivity,
            ),
          ),
        ],
        child: MaterialApp(
          home: _AppShellHost(
            households: households,
            initialSelectedHouseholdId:
                initialSelectedHouseholdId ?? households.first.id,
          ),
        ),
      ),
    );
  }

  testWidgets('показывает три таба и семью в AppBar', (tester) async {
    stubDependencies();

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Сегодня'), findsWidgets);
    expect(find.text('Запланированные'), findsWidgets);
    expect(find.text('Уведомления'), findsWidgets);
  });

  testWidgets('переключение на таб «Запланированные» работает', (
    tester,
  ) async {
    stubDependencies();

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Запланированные'));
    await tester.pumpAndSettle();

    // ScheduledPage активна: пустое состояние экрана видно.
    expect(find.text('Запланированных задач нет'), findsOneWidget);
  });

  testWidgets('переключение на таб «Уведомления» работает', (tester) async {
    stubDependencies();

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Уведомления'));
    await tester.pumpAndSettle();

    expect(find.text('Пока нет уведомлений.'), findsOneWidget);
  });

  testWidgets('кнопка «Участники» открывает HouseholdMembersPage', (
    tester,
  ) async {
    stubDependencies();

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Участники'));
    await tester.pumpAndSettle();

    expect(find.byType(HouseholdMembersPage), findsOneWidget);
  });

  testWidgets('меню «Ещё» открывает ImportExportPage', (tester) async {
    stubDependencies();

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Ещё'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Импорт / экспорт задач'));
    await tester.pumpAndSettle();

    expect(find.byType(ImportExportPage), findsOneWidget);
  });

  testWidgets('меню «Ещё» открывает ProfileSettingsPage', (tester) async {
    stubDependencies();

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Ещё'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Настройки профиля'));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileSettingsPage), findsOneWidget);
    // Профиль загрузился — форма настроек видна.
    expect(find.text('Отображаемое имя'), findsOneWidget);
    expect(find.text('Анна'), findsOneWidget);
  });

  testWidgets('смена семьи через dropdown вызывает onHouseholdChanged', (
    tester,
  ) async {
    stubDependencies();

    await tester.pumpWidget(
      buildSubject(
        households: const [
          Household(id: 'h-1', name: 'Семья'),
          Household(id: 'h-2', name: 'Дача'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // Открываем dropdown выбора семьи.
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Дача').last);
    await tester.pumpAndSettle();

    // Выбранная семья теперь «Дача» — AppShell перестроился с новым
    // selectedHouseholdId и появился текст семьи в AppBar.
    expect(find.text('Дача'), findsWidgets);
    expect(find.text('Семья'), findsNothing);
  });

  testWidgets('меню «Ещё» → «Переименовать» переименовывает семью', (
    tester,
  ) async {
    stubDependencies();

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Ещё'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Переименовать'));
    await tester.pumpAndSettle();

    // Диалог переименования открыт.
    expect(find.text('Переименовать семью'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Дом и дача');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    verify(
      () => mocks.household.updateHousehold(
        householdId: 'h-1',
        name: 'Дом и дача',
      ),
    ).called(1);
  });

  testWidgets('меню «Ещё» → «Переименовать» → отмена не вызывает update', (
    tester,
  ) async {
    stubDependencies();

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Ещё'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Переименовать'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    verifyNever(
      () => mocks.household.updateHousehold(
        householdId: any(named: 'householdId'),
        name: any(named: 'name'),
      ),
    );
  });

  testWidgets('меню «Ещё» → «Удалить семью» → подтверждение удаляет', (
    tester,
  ) async {
    stubDependencies();

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Ещё'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить семью'));
    await tester.pumpAndSettle();

    // Диалог подтверждения.
    expect(find.text('Удалить семью?'), findsOneWidget);

    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();

    verify(
      () => mocks.household.deleteHousehold(householdId: 'h-1'),
    ).called(1);
  });

  testWidgets('меню «Ещё» → «Удалить семью» → отмена не удаляет', (
    tester,
  ) async {
    stubDependencies();

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Ещё'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить семью'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    verifyNever(
      () => mocks.household.deleteHousehold(householdId: any(named: 'householdId')),
    );
  });

  testWidgets('меню «Ещё» → «Создать семью» открывает CreateHouseholdPage', (
    tester,
  ) async {
    stubDependencies();

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Ещё'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Создать семью'));
    await tester.pumpAndSettle();

    expect(find.byType(CreateHouseholdPage), findsOneWidget);
  });

  testWidgets('меню «Ещё» → «Выйти из аккаунта» вызывает signOut', (
    tester,
  ) async {
    stubDependencies();

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Ещё'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выйти из аккаунта'));
    await tester.pumpAndSettle();

    verify(() => mocks.auth.signOut()).called(1);
  });

  testWidgets('кнопка «Участники» после возврата вызывает refresh()', (
    tester,
  ) async {
    stubDependencies();

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Участники'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    // _onHouseholdActionDone → refresh() на HouseholdCubit.
    verify(() => mocks.household.getMyHouseholds()).called(1);
  });

  testWidgets('кнопка «Приглашения» показывает бейдж с количеством', (
    tester,
  ) async {
    stubDependencies();
    when(
      () => mocks.household.getPendingInvitations(),
    ).thenAnswer(
      (_) async => [
        HouseholdInvitation(
          id: 'inv-1',
          householdId: 'h-9',
          householdName: 'Друзья',
          invitedByDisplayName: 'Пётр',
          createdAt: DateTime(2026, 8, 1),
          expiresAt: DateTime(2026, 8, 15),
        ),
      ],
    );

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    // Бейдж с цифрой 1 виден в AppBar.
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.byTooltip('Приглашения'));
    await tester.pumpAndSettle();

    expect(find.byType(HouseholdInvitationsPage), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    // После возврата refresh() вызван.
    verify(() => mocks.household.getMyHouseholds()).called(1);
  });

  testWidgets('при первом показе кэширует участников семьи в локальную БД', (
    tester,
  ) async {
    stubDependencies();
    when(
      () => mocks.household.getMembers(householdId: any(named: 'householdId')),
    ).thenAnswer(
      (_) async => [
        HouseholdMember(
          profileId: 'member-1',
          displayName: 'Анна',
          role: 'owner',
        ),
      ],
    );

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    // Участники записаны в SQLite-кэш.
    final cached = await testDb.householdMembersDao.getMembers('h-1');
    expect(cached, hasLength(1));
    expect(cached.first.displayName, 'Анна');
  });

  testWidgets('офлайн: кэширование участников пропускается', (tester) async {
    stubDependencies(online: false);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    // _syncIfNeeded выходит по offline — в локальную БД ничего не записано.
    final cached = await testDb.householdMembersDao.getMembers('h-1');
    expect(cached, isEmpty);
  });

  testWidgets('ошибка кэширования участников не роняет AppShell', (
    tester,
  ) async {
    stubDependencies();
    when(
      () => mocks.household.getMembers(householdId: any(named: 'householdId')),
    ).thenThrow(Exception('boom'));

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    // Приложение продолжает работать: табы на месте.
    expect(find.text('Сегодня'), findsWidgets);
    expect(find.text('Запланированные'), findsWidgets);
  });

  testWidgets('меню «Ещё» → «Создать семью» → возврат вызывает load()', (
    tester,
  ) async {
    stubDependencies();

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    // Сбросим счётчик getMyHouseholds, чтобы verify был точным.
    clearInteractions(mocks.household);

    await tester.tap(find.byTooltip('Ещё'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Создать семью'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    verify(() => mocks.household.getMyHouseholds()).called(1);
  });

  testWidgets('профиль после возврата вызывает refresh()', (tester) async {
    stubDependencies();

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    clearInteractions(mocks.household);

    await tester.tap(find.byTooltip('Ещё'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Настройки профиля'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    // _onHouseholdActionDone → refresh() на HouseholdCubit.
    verify(() => mocks.household.getMyHouseholds()).called(1);
  });

  testWidgets('несуществующий selectedHouseholdId → берётся первая семья', (
    tester,
  ) async {
    stubDependencies();

    await tester.pumpWidget(
      buildSubject(
        households: const [
          Household(id: 'h-1', name: 'Семья'),
          Household(id: 'h-2', name: 'Дача'),
        ],
        initialSelectedHouseholdId: 'nope',
      ),
    );
    await tester.pumpAndSettle();

    // _selectedHousehold вернул первую семью — кнопка «Участники» открывает
    // страницу именно её.
    await tester.tap(find.byTooltip('Участники'));
    await tester.pumpAndSettle();

    expect(find.byType(HouseholdMembersPage), findsOneWidget);
  });

  testWidgets('импорт задач вызывает onImported → пересоздание табов', (
    tester,
  ) async {
    stubDependencies();
    // Валидный JSON в буфере: одна задача.
    final messenger = TestDefaultBinaryMessengerBinding.instance
        .defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        return <String, dynamic>{
          'text': '{"version":1,"tasks":[{"title":"Помыть посуду"}]}',
        };
      }
      return null;
    });
    // create возвращает задачу (импорт успешен, imported=1).
    when(
      () => mocks.task.create(params: any(named: 'params')),
    ).thenAnswer(
      (_) async => Task(
        id: 't-new',
        householdId: 'h-1',
        title: 'Помыть посуду',
        estimatedDurationMinutes: 30,
        plannedFor: DateTime(2026, 8, 9),
        allowedMemberIds: const [],
        status: TaskStatus.pending,
        createdAt: DateTime(2026, 8, 9),
      ),
    );

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    // Идём на страницу импорта.
    await tester.tap(find.byTooltip('Ещё'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Импорт / экспорт задач'));
    await tester.pumpAndSettle();

    // Импортируем из буфера.
    await tester.tap(find.text('Импортировать из буфера'));
    await tester.pumpAndSettle();

    // Импорт прошёл: snack с результатом виден.
    expect(find.text('Импортировано: 1'), findsOneWidget);

    // Возвращаемся — табы пересозданы (не падает).
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Сегодня'), findsWidgets);
  });
}
