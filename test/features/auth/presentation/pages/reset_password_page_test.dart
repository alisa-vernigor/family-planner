import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:family_planner/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:family_planner/features/auth/presentation/cubit/auth_state.dart';
import 'package:family_planner/features/auth/presentation/pages/reset_password_page.dart';

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
        child: MaterialApp(home: ResetPasswordPage(email: 'a@b.com')),
      ),
    );
    await tester.pump();
  }

  Future<void> tapSubmit(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Сохранить пароль'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить пароль'));
    await tester.pump();
  }

  testWidgets('показывает форму и email аккаунта', (tester) async {
    await pumpState(tester, const AuthInitial());

    expect(find.text('Новый пароль'), findsNWidgets(2)); // AppBar + label
    expect(find.text('Придумайте новый пароль'), findsOneWidget);
    expect(find.text('Для аккаунта a@b.com'), findsOneWidget);
    expect(find.text('Сохранить пароль'), findsOneWidget);
  });

  testWidgets('короткий пароль показывает ошибку валидации', (tester) async {
    await pumpState(tester, const AuthInitial());

    await tester.enterText(find.byType(TextFormField).at(0), 'short');
    await tester.enterText(find.byType(TextFormField).at(1), 'short');
    await tapSubmit(tester);

    expect(
      find.text('Пароль должен содержать минимум 8 символов.'),
      findsOneWidget,
    );
  });

  testWidgets('несовпадающие пароли показывают ошибку', (tester) async {
    await pumpState(tester, const AuthInitial());

    await tester.enterText(find.byType(TextFormField).at(0), 'Password123');
    await tester.enterText(find.byType(TextFormField).at(1), 'Password456');
    await tapSubmit(tester);

    expect(find.text('Пароли не совпадают.'), findsOneWidget);
  });

  testWidgets('совпадающие пароли вызывают updatePassword', (tester) async {
    when(
      () => mocks.auth.updatePassword(newPassword: any(named: 'newPassword')),
    ).thenAnswer((_) async {});

    await pumpState(tester, const AuthInitial());

    await tester.enterText(find.byType(TextFormField).at(0), 'Password123');
    await tester.enterText(find.byType(TextFormField).at(1), 'Password123');
    await tapSubmit(tester);

    verify(
      () => mocks.auth.updatePassword(newPassword: 'Password123'),
    ).called(1);
  });

  testWidgets('показывает ошибку из AuthFailure', (tester) async {
    await pumpState(tester, const AuthFailure(message: 'Ссылка истекла'));

    expect(find.text('Ссылка истекла'), findsOneWidget);
  });

  testWidgets('при Loading кнопка неактивна', (tester) async {
    await pumpState(tester, const AuthLoading());

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('индикатор силы пароля появляется при вводе', (tester) async {
    await pumpState(tester, const AuthInitial());

    expect(find.byType(LinearProgressIndicator), findsNothing);

    await tester.enterText(find.byType(TextFormField).at(0), 'Password123!');
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Отличный'), findsOneWidget);
  });

  testWidgets('onFieldSubmitted отправляет форму', (tester) async {
    when(
      () => mocks.auth.updatePassword(newPassword: any(named: 'newPassword')),
    ).thenAnswer((_) async {});

    await pumpState(tester, const AuthInitial());

    await tester.enterText(find.byType(TextFormField).at(0), 'Password123');
    await tester.enterText(find.byType(TextFormField).at(1), 'Password123');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    verify(
      () => mocks.auth.updatePassword(newPassword: 'Password123'),
    ).called(1);
  });
}
