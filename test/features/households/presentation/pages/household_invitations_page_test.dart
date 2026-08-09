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
      child: MaterialApp(
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

  testWidgets('ошибка загрузки: snackbar с сообщением + «Повторить»', (
    tester,
  ) async {
    when(() => mocks.household.getPendingInvitations()).thenAnswer(
      (_) async => throw Exception('boom'),
    );

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Не удалось загрузить приглашения.'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);
  });

  testWidgets('«Повторить» перезагружает список приглашений', (tester) async {
    var fail = true;
    when(() => mocks.household.getPendingInvitations()).thenAnswer(
      (_) async {
        if (fail) throw Exception('boom');
        return [invitation()];
      },
    );

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Повторить'), findsOneWidget);

    fail = false;
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();

    expect(find.text('Семья Анны'), findsOneWidget);
    expect(find.text('Принять'), findsOneWidget);
  });

  testWidgets('во время принятия приглашения кнопка блокируется', (
    tester,
  ) async {
    when(() => mocks.household.getPendingInvitations()).thenAnswer(
      (_) async => [invitation()],
    );
    final gate = Completer<String>();
    when(() => mocks.household.acceptInvitation(invitationId: 'inv-1'))
        .thenAnswer((_) => gate.future);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Принять'));
    await tester.pump();

    // Пока RPC «висит» — спиннер внутри кнопки, кнопка disabled.
    expect(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    gate.complete('h-1');
    when(() => mocks.household.getMyHouseholds()).thenAnswer(
      (_) async => const [Household(id: 'h-1', name: 'Семья Анны')],
    );
    await tester.pumpAndSettle();
  });

  testWidgets('ошибка принятия приглашения показывает snackbar об ошибке', (
    tester,
  ) async {
    when(() => mocks.household.getPendingInvitations()).thenAnswer(
      (_) async => [invitation()],
    );
    when(() => mocks.household.acceptInvitation(invitationId: 'inv-1'))
        .thenAnswer((_) async => throw Exception('boom'));

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Принять'));
    await tester.pumpAndSettle();

    expect(find.text('Не удалось принять приглашение.'), findsOneWidget);
    // После ошибки показывается экран «Повторить».
    expect(find.text('Повторить'), findsOneWidget);
  });

  testWidgets('ошибка отклонения приглашения показывает snackbar об ошибке', (
    tester,
  ) async {
    when(() => mocks.household.getPendingInvitations()).thenAnswer(
      (_) async => [invitation()],
    );
    when(() => mocks.household.declineInvitation(invitationId: 'inv-1'))
        .thenAnswer((_) async => throw Exception('boom'));

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Отклонить'));
    await tester.pumpAndSettle();

    expect(find.text('Не удалось отклонить приглашение.'), findsOneWidget);
    // После ошибки показывается экран «Повторить».
    expect(find.text('Повторить'), findsOneWidget);
  });

  testWidgets('успешное принятие: попап со snackbar и закрытие страницы', (
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

    // Помещаем страницу на роут, чтобы pop был наблюдаем.
    await tester.pumpWidget(
      MultiBlocProvider(
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
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const HouseholdInvitationsPage(),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(HouseholdInvitationsPage), findsOneWidget);

    await tester.tap(find.text('Принять'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    // Прошли Future.delayed(300ms) в _accept.
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    // Страница закрылась после принятия.
    expect(find.byType(HouseholdInvitationsPage), findsNothing);
  });

  testWidgets('pull-to-refresh перезагружает список приглашений', (
    tester,
  ) async {
    var calls = 0;
    when(() => mocks.household.getPendingInvitations()).thenAnswer(
      (_) async {
        calls++;
        return [invitation()];
      },
    );

    await tester.pumpWidget(buildSubject());
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

  testWidgets('pull-to-refresh в пустом состоянии перезагружает', (
    tester,
  ) async {
    var calls = 0;
    when(() => mocks.household.getPendingInvitations()).thenAnswer(
      (_) async {
        calls++;
        return const <HouseholdInvitation>[];
      },
    );

    await tester.pumpWidget(buildSubject());
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

  testWidgets('несколько приглашений: разделители между карточками', (
    tester,
  ) async {
    when(() => mocks.household.getPendingInvitations()).thenAnswer(
      (_) async => [
        invitation(id: 'inv-1', householdName: 'Семья Анны'),
        invitation(id: 'inv-2', householdName: 'Семья Влада'),
      ],
    );

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Семья Анны'), findsOneWidget);
    expect(find.text('Семья Влада'), findsOneWidget);
    expect(find.byType(Card), findsNWidgets(2));
  });
}
