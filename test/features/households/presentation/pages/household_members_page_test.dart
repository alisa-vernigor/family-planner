import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:family_planner/features/households/domain/entities/household.dart';
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

  testWidgets('кнопка «Повторить» перезагружает список участников', (
    tester,
  ) async {
    var fail = true;
    when(() => mocks.household.getMembers(householdId: 'h-1')).thenAnswer(
      (_) async {
        if (fail) throw Exception('boom');
        return [owner];
      },
    );

    await tester.pumpWidget(buildSubject(currentMemberId: 'user-owner'));
    await tester.pumpAndSettle();

    expect(find.text('Повторить'), findsOneWidget);

    fail = false;
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();

    expect(find.text('Повторить'), findsNothing);
    expect(find.text('Влад'), findsOneWidget);
    // Только владелец в списке — форма приглашения видна.
    expect(find.text('Пригласить участника'), findsOneWidget);
  });

  testWidgets('ошибка загрузки с пустым списком: «Повторить» в центре', (
    tester,
  ) async {
    when(() => mocks.household.getMembers(householdId: 'h-1')).thenAnswer(
      (_) async => throw Exception('boom'),
    );

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Повторить'), findsOneWidget);
  });

  testWidgets('владелец: отправка приглашения показывает snackbar и очищает поле', (
    tester,
  ) async {
    stubMembers([owner]);
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

    expect(find.text('Приглашение отправлено.'), findsOneWidget);
    // Поле очистилось после успешной отправки.
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('household_invitation_email_field')),
          )
          .controller
          ?.text,
      isEmpty,
    );
  });

  testWidgets('ошибка отправки приглашения показывает snackbar с ошибкой', (
    tester,
  ) async {
    stubMembers([owner]);
    when(
      () => mocks.household.createInvitation(
        householdId: 'h-1',
        email: 'friend@example.com',
      ),
    ).thenAnswer((_) async => throw Exception('boom'));

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

    expect(find.text('Не удалось отправить приглашение.'), findsOneWidget);
  });

  testWidgets('onFieldSubmitted с валидным email отправляет приглашение', (
    tester,
  ) async {
    stubMembers([owner]);
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
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    verify(
      () => mocks.household.createInvitation(
        householdId: 'h-1',
        email: 'friend@example.com',
      ),
    ).called(1);
  });

  testWidgets('onFieldSubmitted с невалидным email не отправляет приглашение', (
    tester,
  ) async {
    stubMembers([owner]);

    await tester.pumpWidget(buildSubject(currentMemberId: 'user-owner'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('household_invitation_email_field')),
      'not-an-email',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    verifyNever(
      () => mocks.household.createInvitation(
        householdId: any(named: 'householdId'),
        email: any(named: 'email'),
      ),
    );
    expect(find.text('Введите корректный email.'), findsOneWidget);
  });

  testWidgets('не-владелец: подтверждение выхода из семьи вызывает leaveHousehold', (
    tester,
  ) async {
    stubMembers([owner, member]);
    when(() => mocks.household.leaveHousehold(householdId: 'h-1'))
        .thenAnswer((_) async {});
    when(() => mocks.household.getMyHouseholds()).thenAnswer(
      (_) async => const [Household(id: 'h-1', name: 'Моя семья')],
    );

    await tester.pumpWidget(buildSubject(currentMemberId: 'user-1'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Выйти из семьи'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выйти из семьи'));
    await tester.pumpAndSettle();

    expect(find.text('Выйти из семьи?'), findsOneWidget);

    await tester.tap(find.text('Выйти'));
    await tester.pumpAndSettle();

    verify(() => mocks.household.leaveHousehold(householdId: 'h-1'))
        .called(1);
  });

  testWidgets('не-владелец: отмена выхода из семьи ничего не вызывает', (
    tester,
  ) async {
    stubMembers([owner, member]);

    await tester.pumpWidget(buildSubject(currentMemberId: 'user-1'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Выйти из семьи'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выйти из семьи'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    verifyNever(
      () => mocks.household.leaveHousehold(
        householdId: any(named: 'householdId'),
      ),
    );
  });

  testWidgets('не-владелец: неуспешный выход показывает snackbar об ошибке', (
    tester,
  ) async {
    stubMembers([owner, member]);
    when(() => mocks.household.leaveHousehold(householdId: 'h-1'))
        .thenAnswer((_) async => throw Exception('boom'));

    await tester.pumpWidget(buildSubject(currentMemberId: 'user-1'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Выйти из семьи'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выйти из семьи'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Выйти'));
    await tester.pumpAndSettle();

    expect(find.text('Не удалось выйти из семьи.'), findsOneWidget);
  });

  testWidgets('владелец: подтверждение удаления участника вызывает removeMember', (
    tester,
  ) async {
    stubMembers([owner, member]);

    await tester.pumpWidget(buildSubject(currentMemberId: 'user-owner'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Удалить участника'));
    await tester.pumpAndSettle();

    expect(find.text('Удалить участника?'), findsOneWidget);
    expect(find.textContaining('Удалить «Анна» из семьи?'), findsOneWidget);

    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();

    verify(
      () => mocks.household.removeMember(
        householdId: 'h-1',
        profileId: 'user-1',
      ),
    ).called(1);
  });

  testWidgets('владелец: отмена удаления участника ничего не вызывает', (
    tester,
  ) async {
    stubMembers([owner, member]);

    await tester.pumpWidget(buildSubject(currentMemberId: 'user-owner'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Удалить участника'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    verifyNever(
      () => mocks.household.removeMember(
        householdId: any(named: 'householdId'),
        profileId: any(named: 'profileId'),
      ),
    );
  });

  testWidgets('владелец: неуспешное удаление участника показывает snackbar', (
    tester,
  ) async {
    stubMembers([owner, member]);
    when(
      () => mocks.household.removeMember(
        householdId: 'h-1',
        profileId: 'user-1',
      ),
    ).thenAnswer((_) async => throw Exception('boom'));

    await tester.pumpWidget(buildSubject(currentMemberId: 'user-owner'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Удалить участника'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();

    expect(find.text('Не удалось удалить участника.'), findsOneWidget);
  });

  testWidgets('pull-to-refresh перезагружает список участников', (
    tester,
  ) async {
    var calls = 0;
    when(() => mocks.household.getMembers(householdId: 'h-1')).thenAnswer(
      (_) async {
        calls++;
        return [owner];
      },
    );

    await tester.pumpWidget(buildSubject(currentMemberId: 'user-owner'));
    await tester.pumpAndSettle();

    expect(calls, 1);

    await tester.fling(
      find.byType(ListView),
      const Offset(0, 300),
      1000,
    );
    await tester.pumpAndSettle();

    expect(calls, greaterThanOrEqualTo(2));
  });
}
