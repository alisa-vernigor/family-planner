import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:family_planner/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:family_planner/features/auth/presentation/cubit/auth_state.dart';
import 'package:family_planner/features/auth/presentation/pages/forgot_password_page.dart';

import '../../../../helpers/mock_repository_factory.dart';

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
        child: const MaterialApp(home: ForgotPasswordPage()),
      ),
    );
    await tester.pump();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Отправить ссылку'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отправить ссылку'));
    await tester.pump();
  }

  testWidgets('показывает заголовок и поле email', (tester) async {
    await pumpState(tester, const AuthInitial());

    expect(find.text('Восстановление пароля'), findsOneWidget);
    expect(find.text('Забыли пароль?'), findsOneWidget);
    expect(find.text('Отправить ссылку'), findsOneWidget);
  });

  testWidgets('пустой email показывает ошибку валидации', (tester) async {
    await pumpState(tester, const AuthInitial());

    await submit(tester);

    expect(find.text('Введите email.'), findsOneWidget);
  });

  testWidgets('некорректный email показывает ошибку', (tester) async {
    await pumpState(tester, const AuthInitial());

    await tester.enterText(find.byType(TextFormField), 'not-an-email');
    await submit(tester);

    expect(find.text('Введите корректный email.'), findsOneWidget);
  });

  testWidgets('корректный email вызывает sendPasswordReset', (tester) async {
    when(
      () => mocks.auth.sendPasswordReset(
        email: any(named: 'email'),
        redirectTo: any(named: 'redirectTo'),
      ),
    ).thenAnswer((_) async {});

    await pumpState(tester, const AuthInitial());

    await tester.enterText(find.byType(TextFormField), 'a@b.com');
    await submit(tester);

    verify(
      () => mocks.auth.sendPasswordReset(
        email: 'a@b.com',
        redirectTo: 'familyplanner://auth/callback',
      ),
    ).called(1);
  });

  testWidgets('показывает ошибку из AuthFailure', (tester) async {
    await pumpState(tester, const AuthFailure(message: 'Email не найден'));

    expect(find.text('Email не найден'), findsOneWidget);
  });

  testWidgets('при Loading кнопка неактивна', (tester) async {
    await pumpState(tester, const AuthLoading());

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('onFieldSubmitted отправляет форму', (tester) async {
    when(
      () => mocks.auth.sendPasswordReset(
        email: any(named: 'email'),
        redirectTo: any(named: 'redirectTo'),
      ),
    ).thenAnswer((_) async {});

    await pumpState(tester, const AuthInitial());

    await tester.enterText(find.byType(TextFormField), 'a@b.com');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    verify(
      () => mocks.auth.sendPasswordReset(
        email: 'a@b.com',
        redirectTo: 'familyplanner://auth/callback',
      ),
    ).called(1);
  });
}
