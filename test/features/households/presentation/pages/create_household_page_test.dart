import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:family_planner/features/auth/domain/entities/app_user.dart';
import 'package:family_planner/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:family_planner/features/households/domain/entities/household.dart';
import 'package:family_planner/features/households/presentation/cubit/household_cubit.dart';
import 'package:family_planner/features/households/presentation/pages/create_household_page.dart';

import '../../../../helpers/mock_repository_factory.dart';

void main() {
  late MockRepositoryFactory mocks;

  setUp(() {
    mocks = MockRepositoryFactory();
  });

  Widget buildSubject({
    bool closeAfterCreate = false,
  }) {
    return MaterialApp(
      home: MultiBlocProvider(
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
        ],
        child: CreateHouseholdPage(closeAfterCreate: closeAfterCreate),
      ),
    );
  }

  testWidgets('показывает форму создания семьи и кнопку выхода', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    expect(find.text('Создайте семью'), findsOneWidget);
    expect(find.text('Как назвать вашу семью?'), findsOneWidget);
    expect(find.text('Создать семью'), findsWidgets);
    expect(find.text('Что такое семья и зачем она нужна?'), findsOneWidget);
    expect(find.byTooltip('Выйти из аккаунта'), findsOneWidget);
  });

  testWidgets('невалидное имя показывает ошибку валидации', (tester) async {
    await tester.pumpWidget(buildSubject());

    await tester.tap(find.widgetWithText(FilledButton, 'Создать семью'));
    await tester.pumpAndSettle();

    expect(find.text('Введите название семьи.'), findsOneWidget);
  });

  testWidgets('имя длиннее 100 символов отклоняется', (tester) async {
    await tester.pumpWidget(buildSubject());

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Название семьи'),
      'Ф' * 101,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Создать семью'));
    await tester.pumpAndSettle();

    expect(
      find.text('Название должно быть не длиннее 100 символов.'),
      findsOneWidget,
    );
  });

  testWidgets('создание семьи вызывает репозиторий и показывает загрузку', (
    tester,
  ) async {
    when(() => mocks.household.create(name: 'Моя семья')).thenAnswer(
      (_) async => const Household(id: 'h-1', name: 'Моя семья'),
    );
    when(() => mocks.household.getMyHouseholds()).thenAnswer(
      (_) async => const [Household(id: 'h-1', name: 'Моя семья')],
    );

    await tester.pumpWidget(buildSubject());

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Название семьи'),
      'Моя семья',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Создать семью'));
    await tester.pump();
    await tester.pumpAndSettle();

    verify(() => mocks.household.create(name: 'Моя семья')).called(1);
  });

  testWidgets('ошибка создания показывает сообщение об ошибке', (tester) async {
    when(() => mocks.household.create(name: 'Моя семья'))
        .thenThrow(Exception('boom'));

    await tester.pumpWidget(buildSubject());

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Название семьи'),
      'Моя семья',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Создать семью'));
    await tester.pumpAndSettle();

    expect(find.text('Не удалось создать семью.'), findsOneWidget);
  });

  testWidgets('closeAfterCreate скрывает кнопку выхода и info-ссылку', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject(closeAfterCreate: true));

    expect(find.text('Что такое семья и зачем она нужна?'), findsNothing);
    expect(find.byTooltip('Выйти из аккаунта'), findsNothing);
  });

  testWidgets('кнопка «Выйти из аккаунта» вызывает signOut', (tester) async {
    when(() => mocks.auth.currentUser).thenReturn(
      const AppUser(id: 'user-1', email: 'test@test.com'),
    );
    when(() => mocks.auth.authStateEvents)
        .thenAnswer((_) => const Stream.empty());
    when(() => mocks.auth.signOut()).thenAnswer((_) async {});

    await tester.pumpWidget(buildSubject());

    await tester.tap(find.byTooltip('Выйти из аккаунта'));
    await tester.pumpAndSettle();

    verify(() => mocks.auth.signOut()).called(1);
  });

  testWidgets('диалог «Зачем нужна семья?» открывается и закрывается', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    await tester.tap(find.text('Что такое семья и зачем она нужна?'));
    await tester.pumpAndSettle();

    expect(find.text('Зачем нужна семья?'), findsOneWidget);

    await tester.tap(find.text('Понятно'));
    await tester.pumpAndSettle();

    expect(find.text('Зачем нужна семья?'), findsNothing);
  });
}
