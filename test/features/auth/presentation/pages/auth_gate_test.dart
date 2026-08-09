import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:family_planner/core/services/connectivity_service.dart';
import 'package:family_planner/core/sync/sync_cubit.dart';
import 'package:family_planner/features/auth/domain/entities/app_user.dart';
import 'package:family_planner/features/auth/domain/entities/auth_event.dart';
import 'package:family_planner/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:family_planner/features/auth/presentation/cubit/auth_state.dart';
import 'package:family_planner/features/auth/presentation/pages/auth_gate.dart';
import 'package:family_planner/features/auth/presentation/pages/auth_page.dart';
import 'package:family_planner/features/auth/presentation/pages/email_confirmation_page.dart';
import 'package:family_planner/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:family_planner/features/auth/presentation/pages/password_reset_sent_page.dart';
import 'package:family_planner/features/auth/presentation/pages/password_reset_success_page.dart';
import 'package:family_planner/features/auth/presentation/pages/reset_password_page.dart';
import 'package:family_planner/features/households/domain/entities/household.dart';
import 'package:family_planner/features/households/domain/repositories/household_repository.dart';
import 'package:family_planner/features/households/presentation/cubit/household_cubit.dart';
import 'package:family_planner/features/households/presentation/cubit/household_invitations_cubit.dart';
import 'package:family_planner/features/households/presentation/widgets/app_shell.dart';
import 'package:family_planner/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_category_repository.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_subtask_repository.dart';

import '../../../../helpers/mock_repository_factory.dart';

final class MockTaskCategoryRepository extends Mock
    implements TaskCategoryRepository {}

final class MockTaskSubtaskRepository extends Mock
    implements TaskSubtaskRepository {}

const _user = AppUser(id: 'member-1', email: 'anna@example.com');

void main() {
  late MockRepositoryFactory mocks;
  late MockTaskCategoryRepository categoryRepo;
  late MockTaskSubtaskRepository subtaskRepo;
  late AuthCubit authCubit;
  late StreamController<AuthStateEvent> authEvents;

  setUpAll(() {
    registerFallbackValue(const Household(id: 'h-1', name: 'Семья'));
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mocks = MockRepositoryFactory();
    categoryRepo = MockTaskCategoryRepository();
    subtaskRepo = MockTaskSubtaskRepository();
    authEvents = StreamController<AuthStateEvent>.broadcast();
    when(() => mocks.auth.authStateEvents).thenAnswer((_) => authEvents.stream);
    // currentUser → null: checkSession из initState переводит в
    // AuthUnauthenticated, маршрутизация задаётся реальными методами cubit.
    when(() => mocks.auth.currentUser).thenReturn(null);
    authCubit = AuthCubit(
      authRepository: mocks.auth,
      enableAuthListener: true,
    );
  });

  tearDown(() async {
    await authCubit.close();
    await authEvents.close();
  });

  /// Предоставляет репозитории и кубиты, необходимые AuthGate →
  /// HouseholdGate → AppShell.
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
          BlocProvider<AuthCubit>.value(value: authCubit),
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
        child: const MaterialApp(home: AuthGate()),
      ),
    );
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

  /// Монтирует AuthGate (initState → checkSession → AuthUnauthenticated).
  Future<void> mountGate(WidgetTester tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();
  }

  testWidgets('AuthLoading показывает спиннер', (tester) async {
    final completer = Completer<AppUser>();
    when(
      () => mocks.auth.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) => completer.future);

    await mountGate(tester);
    authCubit.signIn(email: 'a@b.com', password: 'Password123');
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Завершаем future, чтобы не осталось висящей задачи.
    completer.complete(_user);
    await tester.pump();
  });

  testWidgets('AuthUnauthenticated показывает AuthPage', (tester) async {
    await mountGate(tester);

    expect(find.byType(AuthPage), findsOneWidget);
  });

  testWidgets('AuthFailure показывает AuthPage', (tester) async {
    when(
      () => mocks.auth.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenThrow(const AuthExceptionMessage('bad'));

    await mountGate(tester);
    authCubit.signIn(email: 'a@b.com', password: 'wrong');
    await tester.pump();

    expect(find.byType(AuthPage), findsOneWidget);
  });

  testWidgets('AuthForgotPassword показывает ForgotPasswordPage', (
    tester,
  ) async {
    await mountGate(tester);
    authCubit.showForgotPassword();
    await tester.pumpAndSettle();

    expect(find.byType(ForgotPasswordPage), findsOneWidget);
  });

  testWidgets('AuthPasswordResetSent показывает PasswordResetSentPage', (
    tester,
  ) async {
    when(
      () => mocks.auth.sendPasswordReset(
        email: any(named: 'email'),
        redirectTo: any(named: 'redirectTo'),
      ),
    ).thenAnswer((_) async {});

    await mountGate(tester);
    await authCubit.sendPasswordReset(email: 'a@b.com');
    await tester.pump();

    expect(find.byType(PasswordResetSentPage), findsOneWidget);
  });

  testWidgets('auth listener: passwordRecovery → ResetPasswordPage', (
    tester,
  ) async {
    await mountGate(tester);

    // Эмуляция события слушателя: stream add + реальная асинхронная доставка.
    authEvents.add(AuthStateEvent.passwordRecovery);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    await tester.pump();

    expect(find.byType(ResetPasswordPage), findsOneWidget);
  });

  testWidgets('AuthPasswordResetSuccess показывает PasswordResetSuccessPage', (
    tester,
  ) async {
    when(
      () => mocks.auth.updatePassword(newPassword: any(named: 'newPassword')),
    ).thenAnswer((_) async {});

    await mountGate(tester);
    await authCubit.updatePassword(newPassword: 'Password123');
    await tester.pump();

    expect(find.byType(PasswordResetSuccessPage), findsOneWidget);
  });

  testWidgets('AuthEmailConfirmationRequired показывает EmailConfirmationPage', (
    tester,
  ) async {
    when(
      () => mocks.auth.signUp(
        email: any(named: 'email'),
        password: any(named: 'password'),
        displayName: any(named: 'displayName'),
      ),
    ).thenAnswer((_) async => null);

    await mountGate(tester);
    await authCubit.signUp(
      email: 'a@b.com',
      password: 'Password123',
      displayName: 'Anna',
    );
    await tester.pump();

    expect(find.byType(EmailConfirmationPage), findsOneWidget);
  });

  testWidgets('AuthAuthenticated показывает AppShell через HouseholdGate', (
    tester,
  ) async {
    when(() => mocks.auth.currentUser).thenReturn(_user);
    when(() => mocks.household.getMyHouseholds()).thenAnswer(
      (_) async => const [Household(id: 'h-1', name: 'Семья')],
    );
    stubShellDependencies();

    await mountGate(tester);
    await tester.pumpAndSettle();

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.text('Сегодня'), findsWidgets);
  });

  testWidgets('initState вызывает checkSession (null user → AuthPage)', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    verify(() => mocks.auth.currentUser).called(1);
    expect(find.byType(AuthPage), findsOneWidget);
  });
}

/// Простое исключение с текстом для AuthFailure-пути signIn.
final class AuthExceptionMessage implements Exception {
  const AuthExceptionMessage(this.message);
  final String message;
}
