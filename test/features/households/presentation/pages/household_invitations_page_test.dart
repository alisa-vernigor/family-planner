import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:family_planner/features/households/domain/entities/household.dart';
import 'package:family_planner/features/households/domain/entities/household_invitation.dart';
import 'package:family_planner/features/households/presentation/cubit/household_cubit.dart';
import 'package:family_planner/features/households/presentation/cubit/household_invitations_cubit.dart';
import 'package:family_planner/features/households/presentation/pages/household_invitations_page.dart';

import '../../../../helpers/mock_repository_factory.dart';

void main() {
  late MockRepositoryFactory mocks;

  setUp(() {
    mocks = MockRepositoryFactory();
  });

  HouseholdInvitation invitation({
    String id = 'inv-1',
    String householdName = 'Семья Анны',
    Duration expiresIn = const Duration(days: 6),
  }) {
    return HouseholdInvitation(
      id: id,
      householdId: 'h-1',
      householdName: householdName,
      invitedByDisplayName: 'Анна',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      expiresAt: DateTime.now().add(expiresIn),
    );
  }

  Widget buildSubject() {
    return MultiBlocProvider(
      providers: [
        BlocProvider<HouseholdInvitationsCubit>(
          create: (_) => HouseholdInvitationsCubit(
            householdRepository: mocks.household,
          ),
        ),
        BlocProvider<HouseholdCubit>(
          create: (_) => HouseholdCubit(householdRepository: mocks.household),
        ),
      ],
      child: const MaterialApp(
        home: HouseholdInvitationsPage(),
      ),
    );
  }

  testWidgets('показывает спиннер во время загрузки', (tester) async {
    when(() => mocks.household.getPendingInvitations()).thenAnswer(
      (_) => Completer<List<HouseholdInvitation>>().future,
    );

    await tester.pumpWidget(buildSubject());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('пустое состояние: «Новых приглашений нет.»', (tester) async {
    when(() => mocks.household.getPendingInvitations()).thenAnswer(
      (_) async => const <HouseholdInvitation>[],
    );

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Новых приглашений нет.'), findsOneWidget);
  });

  testWidgets('список приглашений с кнопками Принять/Отклонить', (tester) async {
    when(() => mocks.household.getPendingInvitations()).thenAnswer(
      (_) async => [invitation()],
    );

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Семья Анны'), findsOneWidget);
    expect(find.textContaining('Анна приглашает вас'), findsOneWidget);
    expect(find.text('Принять'), findsOneWidget);
    expect(find.text('Отклонить'), findsOneWidget);
  });

  testWidgets('истёкшее приглашение не имеет кнопок', (tester) async {
    when(() => mocks.household.getPendingInvitations()).thenAnswer(
      (_) async => [
        invitation(expiresIn: const Duration(days: -1)),
      ],
    );

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Срок действия истёк'), findsOneWidget);
    expect(find.text('Принять'), findsNothing);
    expect(find.text('Отклонить'), findsNothing);
  });

  testWidgets('ошибка загрузки показывает кнопку «Повторить»', (tester) async {
    when(() => mocks.household.getPendingInvitations())
        .thenThrow(Exception('boom'));

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Повторить'), findsOneWidget);
  });

  testWidgets('принятие приглашения вызывает accept и загружает семьи', (
    tester,
  ) async {
    when(() => mocks.household.getPendingInvitations()).thenAnswer(
      (_) async => [invitation()],
    );
    when(() => mocks.household.acceptInvitation(invitationId: 'inv-1'))
        .thenAnswer((_) async => 'h-1');
    when(() => mocks.household.getMyHouseholds()).thenAnswer(
      (_) async => const [Household(id: 'h-1', name: 'Семья Анны')],
    );

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Принять'));
    await tester.pumpAndSettle();

    verify(() => mocks.household.acceptInvitation(invitationId: 'inv-1'))
        .called(1);
    verify(() => mocks.household.getMyHouseholds()).called(1);
  });

  testWidgets('отклонение приглашения вызывает decline и убирает из списка', (
    tester,
  ) async {
    when(() => mocks.household.getPendingInvitations()).thenAnswer(
      (_) async => [invitation()],
    );
    when(() => mocks.household.declineInvitation(invitationId: 'inv-1'))
        .thenAnswer((_) async {});

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Отклонить'));
    await tester.pumpAndSettle();

    verify(() => mocks.household.declineInvitation(invitationId: 'inv-1'))
        .called(1);
    expect(find.text('Новых приглашений нет.'), findsOneWidget);
  });
}
