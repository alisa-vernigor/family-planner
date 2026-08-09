import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:family_planner/features/auth/domain/entities/app_user.dart';
import 'package:family_planner/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:family_planner/features/auth/presentation/cubit/auth_state.dart';
import 'package:family_planner/features/auth/presentation/pages/auth_page.dart';

import '../../../../helpers/mock_repository_factory.dart';

const _user = AppUser(id: 'user-1', email: 'anna@example.com');

void main() {
  late MockRepositoryFactory mocks;

  setUp(() {
    mocks = MockRepositoryFactory();
    when(() => mocks.auth.authStateEvents)
        .thenAnswer((_) => const Stream.empty());
    when(() => mocks.auth.currentUser).thenReturn(null);
  });

  AuthCubit buildCubit() => AuthCubit(
        authRepository: mocks.auth,
        enableAuthListener: false,
      );

  Future<void> pumpState(WidgetTester tester, AuthState state) async {
    final cubit = buildCubit()..emit(state);
    await tester.pumpWidget(
      BlocProvider<AuthCubit>.value(
        value: cubit,
        child: const MaterialApp(home: AuthPage()),
      ),
    );
    await tester.pump();
  }

  Future<void> pumpInitial(WidgetTester tester) =>
      pumpState(tester, const AuthInitial());

  /// Прокручивает форму и нажимает кнопку-подвал (она ниже fold'а).
  Future<void> tapFooterButton(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pump();
  }

  testWidgets('показывает форму регистрации по умолчанию', (tester) async {
    await pumpInitial(tester);

    expect(find.text('Family Planner'), findsOneWidget);
    expect(
      find.text('Создайте аккаунт для планирования дел семьи'),
      findsOneWidget,
    );
    expect(find.text('Ваше имя'), findsOneWidget);
    expect(find.text('Зарегистрироваться'), findsOneWidget);
  });

  testWidgets('переключение режима показывает форму входа', (tester) async {
    await pumpInitial(tester);

    await tester.ensureVisible(find.text('У меня уже есть аккаунт'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('У меня уже есть аккаунт'));
    await tester.pump();

    expect(find.text('Войдите, чтобы увидеть задачи семьи'), findsOneWidget);
    expect(find.text('Ваше имя'), findsNothing);
    expect(find.text('Войти'), findsOneWidget);
  });

  testWidgets('пустая форма показывает валидационные ошибки', (tester) async {
    await pumpInitial(tester);

    await tapFooterButton(tester, 'Зарегистрироваться');

    expect(find.text('Введите ваше имя.'), findsOneWidget);
    expect(find.text('Введите email.'), findsOneWidget);
    expect(
      find.text('Пароль должен содержать минимум 8 символов.'),
      findsOneWidget,
    );
  });

  testWidgets('некорректный email показывает ошибку', (tester) async {
    await pumpInitial(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'Anna');
    await tester.enterText(find.byType(TextFormField).at(1), 'not-an-email');
    await tester.enterText(find.byType(TextFormField).at(2), 'Password123');
    await tapFooterButton(tester, 'Зарегистрироваться');

    expect(find.text('Введите корректный email.'), findsOneWidget);
  });

  testWidgets('имя длиннее 60 символов отклоняется', (tester) async {
    await pumpInitial(tester);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'A' * 61,
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'a@b.com');
    await tester.enterText(find.byType(TextFormField).at(2), 'Password123');
    await tapFooterButton(tester, 'Зарегистрироваться');

    expect(
      find.text('Имя должно быть не длиннее 60 символов.'),
      findsOneWidget,
    );
  });

  testWidgets('успешная регистрация вызывает signUp с введёнными данными', (
    tester,
  ) async {
    when(
      () => mocks.auth.signUp(
        email: any(named: 'email'),
        password: any(named: 'password'),
        displayName: any(named: 'displayName'),
      ),
    ).thenAnswer((_) async => null);

    await pumpInitial(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'Anna');
    await tester.enterText(find.byType(TextFormField).at(1), 'anna@example.com');
    await tester.enterText(find.byType(TextFormField).at(2), 'Password123');
    await tapFooterButton(tester, 'Зарегистрироваться');

    verify(
      () => mocks.auth.signUp(
        email: 'anna@example.com',
        password: 'Password123',
        displayName: 'Anna',
      ),
    ).called(1);
  });

  testWidgets('успешный вход вызывает signIn', (tester) async {
    when(
      () => mocks.auth.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => _user);

    await pumpInitial(tester);

    await tapFooterButton(tester, 'У меня уже есть аккаунт');

    await tester.enterText(find.byType(TextFormField).at(0), 'anna@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'Password123');
    await tapFooterButton(tester, 'Войти');

    verify(
      () => mocks.auth.signIn(
        email: 'anna@example.com',
        password: 'Password123',
      ),
    ).called(1);
  });

  testWidgets('показывает ошибку из AuthFailure состояния', (tester) async {
    await pumpState(tester, const AuthFailure(message: 'Bad login'));

    expect(find.text('Bad login'), findsOneWidget);
  });

  testWidgets('при Loading кнопка неактивна и показывает спиннер', (
    tester,
  ) async {
    await pumpState(tester, const AuthLoading());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('переключение видимости пароля', (tester) async {
    await pumpInitial(tester);

    await tester.enterText(find.byType(TextFormField).at(2), 'Password123');
    await tester.ensureVisible(find.byTooltip('Показать пароль'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Показать пароль'));
    await tester.pump();

    final editable = tester.widget<EditableText>(
      find.descendant(
        of: find.byType(TextFormField).at(2),
        matching: find.byType(EditableText),
      ),
    );
    expect(editable.obscureText, isFalse);
  });

  testWidgets('индикатор силы пароля появляется и растёт при вводе', (
    tester,
  ) async {
    await pumpInitial(tester);

    // Начало — без индикатора.
    expect(find.byType(LinearProgressIndicator), findsNothing);

    await tester.enterText(
      find.byType(TextFormField).at(2),
      'Password123!',
    );
    await tester.pump();

    // Индикатор + подпись с уровнем.
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Отличный'), findsOneWidget);

    // Короткий пароль — индикатор исчезает.
    await tester.enterText(find.byType(TextFormField).at(2), 'abc');
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('onFieldSubmitted с непустым паролем отправляет форму', (
    tester,
  ) async {
    when(
      () => mocks.auth.signUp(
        email: any(named: 'email'),
        password: any(named: 'password'),
        displayName: any(named: 'displayName'),
      ),
    ).thenAnswer((_) async => null);

    await pumpInitial(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'Anna');
    await tester.enterText(find.byType(TextFormField).at(1), 'anna@example.com');
    await tester.enterText(find.byType(TextFormField).at(2), 'Password123');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    verify(
      () => mocks.auth.signUp(
        email: 'anna@example.com',
        password: 'Password123',
        displayName: 'Anna',
      ),
    ).called(1);
  });
}
