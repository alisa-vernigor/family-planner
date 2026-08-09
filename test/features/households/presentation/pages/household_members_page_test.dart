import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/households/domain/repositories/household_repository.dart';
import 'package:family_planner/features/households/presentation/cubit/household_cubit.dart';
import 'package:family_planner/features/households/presentation/pages/household_members_page.dart';

import '../../../../helpers/mock_repository_factory.dart';

void main() {
  late MockRepositoryFactory mocks;

  setUp(() {
    mocks = MockRepositoryFactory();
  });

  const owner = HouseholdMember(
    profileId: 'user-owner',
    displayName: 'Влад',
    role: 'owner',
  );
  const member = HouseholdMember(
    profileId: 'user-1',
    displayName: 'Анна',
    role: 'member',
  );

  Widget buildSubject({
    String currentMemberId = 'user-1',
  }) {
    return RepositoryProvider<HouseholdRepository>(
      create: (_) => mocks.household,
      child: MultiBlocProvider(
        providers: [
          BlocProvider<HouseholdCubit>(
            create: (_) => HouseholdCubit(householdRepository: mocks.household),
          ),
        ],
        child: MaterialApp(
          home: HouseholdMembersPage(
            householdId: 'h-1',
            householdName: 'Моя семья',
            currentMemberId: currentMemberId,
          ),
        ),
      ),
    );
  }

  void stubMembers(List<HouseholdMember> members) {
    when(() => mocks.household.getMembers(householdId: 'h-1')).thenAnswer(
      (_) async => members,
    );
  }

  testWidgets('показывает спиннер во время загрузки', (tester) async {
    when(() => mocks.household.getMembers(householdId: 'h-1')).thenAnswer(
      (_) => Completer<List<HouseholdMember>>().future,
    );

    await tester.pumpWidget(buildSubject());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('список участников с заголовком и ролями', (tester) async {
    stubMembers([owner, member]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Участники: Моя семья'), findsOneWidget);
    expect(find.text('Участники (2)'), findsOneWidget);
    expect(find.text('Влад'), findsOneWidget);
    expect(find.text('Анна'), findsOneWidget);
    expect(find.text('Владелец семьи'), findsOneWidget);
    expect(find.text('Участник'), findsOneWidget);
  });

  testWidgets('владелец видит форму приглашения и кнопку удаления', (
    tester,
  ) async {
    stubMembers([owner, member]);

    await tester.pumpWidget(buildSubject(currentMemberId: 'user-owner'));
    await tester.pumpAndSettle();

    expect(find.text('Пригласить участника'), findsOneWidget);
    expect(
      find.byKey(const Key('household_invitation_email_field')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('send_household_invitation_button')),
        findsOneWidget);
    expect(find.byIcon(Icons.remove_circle_outline), findsOneWidget);
    // Владелец не видит кнопку выхода из семьи
    expect(find.text('Выйти из семьи'), findsNothing);
  });

  testWidgets('не-владелец не видит форму приглашения, но видит выход', (
    tester,
  ) async {
    stubMembers([owner, member]);

    await tester.pumpWidget(buildSubject(currentMemberId: 'user-1'));
    await tester.pumpAndSettle();

    expect(find.text('Пригласить участника'), findsNothing);
    expect(find.text('Выйти из семьи'), findsOneWidget);
  });

  testWidgets('валидация email в форме приглашения', (tester) async {
    stubMembers([owner, member]);

    await tester.pumpWidget(buildSubject(currentMemberId: 'user-owner'));
    await tester.pumpAndSettle();

    // Пустой email
    await tester.tap(
      find.byKey(const Key('send_household_invitation_button')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Введите email.'), findsOneWidget);

    // Некорректный email
    await tester.enterText(
      find.byKey(const Key('household_invitation_email_field')),
      'not-an-email',
    );
    await tester.tap(
      find.byKey(const Key('send_household_invitation_button')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Введите корректный email.'), findsOneWidget);
  });

  testWidgets('отправка приглашения вызывает createInvitation', (tester) async {
    stubMembers([owner, member]);
    when(
      () => mocks.household.createInvitation(
        householdId: 'h-1',
        email: 'friend@example.com',
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(buildSubject(currentMemberId: 'user-owner'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('household_invitation_email_field')),
      'friend@example.com',
    );
    await tester.tap(
      find.byKey(const Key('send_household_invitation_button')),
    );
    await tester.pumpAndSettle();

    verify(
      () => mocks.household.createInvitation(
        householdId: 'h-1',
        email: 'friend@example.com',
      ),
    ).called(1);
  });

  testWidgets('ошибка загрузки показывает «Повторить»', (tester) async {
    when(() => mocks.household.getMembers(householdId: 'h-1'))
        .thenThrow(Exception('boom'));

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Повторить'), findsOneWidget);
  });
}
