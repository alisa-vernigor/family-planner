import 'dart:async';

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
import 'package:family_planner/features/households/presentation/cubit/household_state.dart';
import 'package:family_planner/features/households/presentation/cubit/household_invitations_cubit.dart';
import 'package:family_planner/features/households/presentation/pages/household_gate.dart';
import 'package:family_planner/features/households/presentation/pages/create_household_page.dart';
import 'package:family_planner/features/households/presentation/widgets/empty_shell.dart';
import 'package:family_planner/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_category_repository.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_subtask_repository.dart';

import '../../../../helpers/mock_repository_factory.dart';

final class MockTaskCategoryRepository extends Mock
    implements TaskCategoryRepository {}

final class MockTaskSubtaskRepository extends Mock
    implements TaskSubtaskRepository {}

void main() {
  late MockRepositoryFactory mocks;
  late MockTaskCategoryRepository categoryRepo;
  late MockTaskSubtaskRepository subtaskRepo;

  setUpAll(() {
    registerFallbackValue(
      const Household(id: 'h-1', name: 'Семья'),
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mocks = MockRepositoryFactory();
    categoryRepo = MockTaskCategoryRepository();
    subtaskRepo = MockTaskSubtaskRepository();
  });

  void stubGateState(HouseholdState state) {
    when(() => mocks.household.getMyHouseholds()).thenAnswer((_) async {
      switch (state) {
        case HouseholdLoaded(:final households):
          return households;
        case HouseholdEmpty():
          return const <Household>[];
        default:
          throw Exception('boom');
      }
    });
  }

  void stubShellDependencies() {
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
    when(() => mocks.connectivity.currentOnline).thenReturn(true);
    when(
      () => mocks.connectivity.isOnline,
    ).thenAnswer((_) => const Stream<bool>.empty());
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
        child: MaterialApp(
          home: HouseholdGate(currentMemberId: 'member-1'),
        ),
      ),
    );
  }

  testWidgets('показывает спиннер в состоянии Loading', (tester) async {
    when(() => mocks.household.getMyHouseholds()).thenAnswer(
      (_) => Completer<List<Household>>().future,
    );

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Завершаем future, чтобы не осталось висящих задач.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('пустой список семей показывает EmptyShell', (tester) async {
    stubGateState(const HouseholdEmpty());
    when(() => mocks.household.getPendingInvitations()).thenAnswer(
      (_) async => const [],
    );
    when(() => mocks.auth.currentUser).thenReturn(null);
    when(() => mocks.auth.authStateEvents)
        .thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.byType(EmptyShell), findsOneWidget);
    expect(find.byType(CreateHouseholdPage), findsOneWidget);
  });

  testWidgets('ошибка загрузки показывает «Повторить»', (tester) async {
    when(() => mocks.household.getMyHouseholds()).thenThrow(Exception('boom'));

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Не удалось загрузить или создать семью.'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);
  });

  testWidgets('«Повторить» перезагружает и при успехе показывает AppShell', (
    tester,
  ) async {
    var fail = true;
    when(() => mocks.household.getMyHouseholds()).thenAnswer((_) async {
      if (fail) throw Exception('boom');
      return const [Household(id: 'h-1', name: 'Семья')];
    });
    stubShellDependencies();

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Повторить'), findsOneWidget);

    fail = false;
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();

    // AppShell с NavigationBar и тремя табами.
    expect(find.text('Сегодня'), findsWidgets);
    expect(find.text('Запланированные'), findsWidgets);
    expect(find.text('Уведомления'), findsWidgets);
  });

  testWidgets('загруженные семьи показывают AppShell', (tester) async {
    stubGateState(
      const HouseholdLoaded(households: [Household(id: 'h-1', name: 'Семья')]),
    );
    stubShellDependencies();

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Семья'), findsOneWidget); // dropdown
    expect(find.text('Сегодня'), findsWidgets);
    expect(find.text('Запланированные'), findsWidgets);
    expect(find.text('Уведомления'), findsWidgets);
  });

  testWidgets('переключение таба сохраняет выбранный таб в SharedPreferences', (
    tester,
  ) async {
    stubGateState(
      const HouseholdLoaded(households: [Household(id: 'h-1', name: 'Семья')]),
    );
    stubShellDependencies();

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    // Переключаемся на таб «Уведомления» (индекс 2).
    await tester.tap(find.text('Уведомления'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('selected_tab'), 2);
  });

  testWidgets('восстановление состояния: сохранённый таб и семья применяются', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'selected_tab': 1,
      'selected_household_id': 'h-1',
    });
    stubGateState(
      const HouseholdLoaded(
        households: [Household(id: 'h-1', name: 'Семья')],
      ),
    );
    stubShellDependencies();

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    // Таб «Запланированные» активен (сохранён индекс 1).
    final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.selectedIndex, 1);
  });

  testWidgets('восстановление: несуществующий household id фолбэчится на первый', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'selected_tab': 0,
      'selected_household_id': 'stale-id',
    });
    stubGateState(
      const HouseholdLoaded(
        households: [Household(id: 'h-1', name: 'Семья')],
      ),
    );
    stubShellDependencies();

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    // Dropdown показывает первую семью (id не найден → fallback).
    expect(find.text('Семья'), findsOneWidget);
  });

  testWidgets('переключение семьи сохраняет выбор в SharedPreferences', (
    tester,
  ) async {
    stubGateState(
      const HouseholdLoaded(
        households: [
          Household(id: 'h-1', name: 'Семья'),
          Household(id: 'h-2', name: 'Работа'),
        ],
      ),
    );
    stubShellDependencies();

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    // Открываем dropdown и выбираем «Работа».
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Работа').last);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('selected_household_id'), 'h-2');
  });
}
