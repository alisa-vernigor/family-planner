import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:family_planner/features/auth/domain/entities/app_user.dart';
import 'package:family_planner/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:family_planner/features/households/domain/entities/household_invitation.dart';
import 'package:family_planner/features/households/presentation/cubit/household_cubit.dart';
import 'package:family_planner/features/households/presentation/cubit/household_invitations_cubit.dart';
import 'package:family_planner/features/households/presentation/widgets/empty_shell.dart';
import 'package:family_planner/features/households/presentation/pages/create_household_page.dart';
import 'package:family_planner/features/households/presentation/pages/household_invitations_page.dart';

import '../../../../helpers/mock_repository_factory.dart';

void main() {
  late MockRepositoryFactory mocks;

  setUp(() {
    mocks = MockRepositoryFactory();
  });

  Widget buildSubject() {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>(
          create: (_) => AuthCubit(
            authRepository: mocks.auth,
            enableAuthListener: false,
          ),
        ),
        BlocProvider<HouseholdCubit>(
          create: (_) => HouseholdCubit(householdRepository: mocks.household),
        ),
        BlocProvider<HouseholdInvitationsCubit>(
          create: (_) => HouseholdInvitationsCubit(
            householdRepository: mocks.household,
          ),
        ),
      ],
      child: MaterialApp(
        home: const EmptyShell(currentMemberId: 'user-1'),
      ),
    );
  }

  testWidgets('показывает спиннер во время загрузки приглашений', (
    tester,
  ) async {
    when(() => mocks.household.getPendingInvitations()).thenAnswer(
      (_) => Completer<List<HouseholdInvitation>>().future,
    );

    await tester.pumpWidget(buildSubject());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('без приглашений показывает форму создания семьи', (
    tester,
  ) async {
    when(() => mocks.household.getPendingInvitations()).thenAnswer(
      (_) async => const <HouseholdInvitation>[],
    );

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.byType(CreateHouseholdPage), findsOneWidget);
    expect(find.text('Создайте семью'), findsOneWidget);
  });

  testWidgets('с приглашениями показывает InvitationsPrompt', (tester) async {
    when(() => mocks.household.getPendingInvitations()).thenAnswer(
      (_) async => [
        HouseholdInvitation(
          id: 'inv-1',
          householdId: 'h-1',
          householdName: 'Семья Анны',
          invitedByDisplayName: 'Анна',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          expiresAt: DateTime.now().add(const Duration(days: 6)),
        ),
      ],
    );

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Вас пригласили в семью'), findsOneWidget);
    expect(find.text('Посмотреть приглашения'), findsOneWidget);
    expect(find.text('Создать свою семью'), findsOneWidget);
  });

  testWidgets('бейдж приглашений показывает количество', (tester) async {
    when(() => mocks.household.getPendingInvitations()).thenAnswer(
      (_) async => [
        HouseholdInvitation(
          id: 'inv-1',
          householdId: 'h-1',
          householdName: 'Семья Анны',
          invitedByDisplayName: 'Анна',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          expiresAt: DateTime.now().add(const Duration(days: 6)),
        ),
        HouseholdInvitation(
          id: 'inv-2',
          householdId: 'h-2',
          householdName: 'Семья Влада',
          invitedByDisplayName: 'Влад',
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
          expiresAt: DateTime.now().add(const Duration(days: 5)),
        ),
      ],
    );

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('тап по кнопке «Посмотреть приглашения» открывает список', (
    tester,
  ) async {
    when(() => mocks.household.getPendingInvitations()).thenAnswer(
      (_) async => [
        HouseholdInvitation(
          id: 'inv-1',
          householdId: 'h-1',
          householdName: 'Семья Анны',
          invitedByDisplayName: 'Анна',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          expiresAt: DateTime.now().add(const Duration(days: 6)),
        ),
      ],
    );
    when(() => mocks.household.getMyHouseholds()).thenAnswer(
      (_) async => const [],
    );

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Посмотреть приглашения'));
    await tester.pumpAndSettle();

    expect(find.byType(HouseholdInvitationsPage), findsOneWidget);
  });

  testWidgets('меню «Выйти из аккаунта» вызывает signOut', (tester) async {
    when(() => mocks.household.getPendingInvitations()).thenAnswer(
      (_) async => const <HouseholdInvitation>[],
    );
    when(() => mocks.auth.currentUser).thenReturn(
      const AppUser(id: 'user-1', email: 'test@test.com'),
    );
    when(() => mocks.auth.authStateEvents)
        .thenAnswer((_) => const Stream.empty());
    when(() => mocks.auth.signOut()).thenAnswer((_) async {});

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Ещё'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Выйти из аккаунта'));
    await tester.pumpAndSettle();

    verify(() => mocks.auth.signOut()).called(1);
  });

  testWidgets('иконка приглашений открывает список и перезагружает семьи', (
    tester,
  ) async {
    when(() => mocks.household.getPendingInvitations()).thenAnswer(
      (_) async => [
        HouseholdInvitation(
          id: 'inv-1',
          householdId: 'h-1',
          householdName: 'Семья Анны',
          invitedByDisplayName: 'Анна',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          expiresAt: DateTime.now().add(const Duration(days: 6)),
        ),
      ],
    );
    when(() => mocks.household.getMyHouseholds()).thenAnswer(
      (_) async => const [],
    );

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    // Иконка в AppBar (tooltip «Приглашения»).
    await tester.tap(find.byTooltip('Приглашения'));
    await tester.pumpAndSettle();

    expect(find.byType(HouseholdInvitationsPage), findsOneWidget);

    // Возвращаемся — HouseholdCubit.load() вызван.
    await tester.pageBack();
    await tester.pumpAndSettle();
    verify(() => mocks.household.getMyHouseholds()).called(1);
  });

  testWidgets('кнопка «Создать свою семью» открывает форму и перезагружает', (
    tester,
  ) async {
    when(() => mocks.household.getPendingInvitations()).thenAnswer(
      (_) async => [
        HouseholdInvitation(
          id: 'inv-1',
          householdId: 'h-1',
          householdName: 'Семья Анны',
          invitedByDisplayName: 'Анна',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          expiresAt: DateTime.now().add(const Duration(days: 6)),
        ),
      ],
    );
    when(() => mocks.household.getMyHouseholds()).thenAnswer(
      (_) async => const [],
    );

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Создать свою семью'));
    await tester.pumpAndSettle();

    expect(find.byType(CreateHouseholdPage), findsOneWidget);

    // Возвращаемся — HouseholdCubit.load() вызывается после pop.
    await tester.pageBack();
    await tester.pumpAndSettle();
    verify(() => mocks.household.getMyHouseholds()).called(1);
  });

  testWidgets('кнопка «Посмотреть приглашения» возвращает и перезагружает', (
    tester,
  ) async {
    when(() => mocks.household.getPendingInvitations()).thenAnswer(
      (_) async => [
        HouseholdInvitation(
          id: 'inv-1',
          householdId: 'h-1',
          householdName: 'Семья Анны',
          invitedByDisplayName: 'Анна',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          expiresAt: DateTime.now().add(const Duration(days: 6)),
        ),
      ],
    );
    when(() => mocks.household.getMyHouseholds()).thenAnswer(
      (_) async => const [],
    );

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    // Кнопка в InvitationsPrompt (не иконка AppBar).
    await tester.tap(find.text('Посмотреть приглашения'));
    await tester.pumpAndSettle();

    expect(find.byType(HouseholdInvitationsPage), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    verify(() => mocks.household.getMyHouseholds()).called(1);
  });

  testWidgets('ошибка загрузки приглашений показывает форму создания семьи', (
    tester,
  ) async {
    when(() => mocks.household.getPendingInvitations()).thenThrow(
      Exception('boom'),
    );

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    // Состояние Failure → invitations пусто → CreateHouseholdPage.
    expect(find.byType(CreateHouseholdPage), findsOneWidget);
  });
}
