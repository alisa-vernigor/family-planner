import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:family_planner/core/services/connectivity_service.dart';
import 'package:family_planner/core/sync/sync_cubit.dart';
import 'package:family_planner/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:family_planner/features/households/domain/entities/household.dart';
import 'package:family_planner/features/households/domain/repositories/household_repository.dart';
import 'package:family_planner/features/households/presentation/cubit/household_cubit.dart';
import 'package:family_planner/features/households/presentation/cubit/household_invitations_cubit.dart';
import 'package:family_planner/features/households/presentation/pages/household_members_page.dart';
import 'package:family_planner/features/households/presentation/widgets/app_shell.dart';
import 'package:family_planner/features/import_export/presentation/pages/import_export_page.dart';
import 'package:family_planner/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:family_planner/features/profile/domain/entities/user_profile.dart';
import 'package:family_planner/features/profile/domain/repositories/profile_repository.dart';
import 'package:family_planner/features/profile/presentation/pages/profile_settings_page.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_category_repository.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_subtask_repository.dart';

import '../../../../helpers/mock_repository_factory.dart';

final class MockTaskCategoryRepository extends Mock
    implements TaskCategoryRepository {}

final class MockTaskSubtaskRepository extends Mock
    implements TaskSubtaskRepository {}

/// Хост-виджет, который держит `currentTab` в состоянии и передаёт настоящий
/// `onTabChanged`, чтобы переключение табов реально перестраивало AppShell.
final class _AppShellHost extends StatefulWidget {
  const _AppShellHost();

  @override
  State<_AppShellHost> createState() => _AppShellHostState();
}

final class _AppShellHostState extends State<_AppShellHost> {
  int _currentTab = 0;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      households: const [Household(id: 'h-1', name: 'Семья')],
      selectedHouseholdId: 'h-1',
      currentMemberId: 'member-1',
      currentTab: _currentTab,
      onTabChanged: (index) => setState(() => _currentTab = index),
      onHouseholdChanged: (_) {},
    );
  }
}

void main() {
  late MockRepositoryFactory mocks;
  late MockTaskCategoryRepository categoryRepo;
  late MockTaskSubtaskRepository subtaskRepo;

  setUpAll(() {
    registerFallbackValue(const Household(id: 'h-1', name: 'Семья'));
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mocks = MockRepositoryFactory();
    categoryRepo = MockTaskCategoryRepository();
    subtaskRepo = MockTaskSubtaskRepository();
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

  Widget buildSubject() {
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
        child: const MaterialApp(home: _AppShellHost()),
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
}
