import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:family_planner/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:family_planner/features/auth/presentation/cubit/auth_state.dart';
import 'package:family_planner/features/auth/presentation/pages/email_confirmation_page.dart';

import '../../../../helpers/mock_repository_factory.dart';

void main() {
  late MockRepositoryFactory mocks;

  setUp(() {
    mocks = MockRepositoryFactory();
    when(() => mocks.auth.authStateEvents)
        .thenAnswer((_) => const Stream.empty());
    when(() => mocks.auth.currentUser).thenReturn(null);
  });

  Widget buildSubject(AuthState state) {
    final cubit = AuthCubit(
      authRepository: mocks.auth,
      enableAuthListener: false,
    )..emit(state);
    return BlocProvider<AuthCubit>.value(
      value: cubit,
      child: MaterialApp(home: EmailConfirmationPage(email: 'a@b.com')),
    );
  }

  testWidgets('показывает email и инструкции', (tester) async {
    await tester.pumpWidget(buildSubject(const AuthInitial()));

    expect(find.text('Подтвердите email'), findsOneWidget);
    expect(find.text('Проверьте почту'), findsOneWidget);
    expect(
      find.text('Мы отправили ссылку для подтверждения на:\na@b.com'),
      findsOneWidget,
    );
    expect(find.text('Я подтвердил email'), findsOneWidget);
    expect(find.text('Вернуться ко входу'), findsOneWidget);
  });

  testWidgets('«Я подтвердил email» вызывает checkSession', (tester) async {
    await tester.pumpWidget(buildSubject(const AuthInitial()));

    await tester.tap(find.text('Я подтвердил email'));
    await tester.pump();

    verify(() => mocks.auth.currentUser).called(1);
  });

  testWidgets('«Вернуться ко входу» вызывает signOut', (tester) async {
    when(() => mocks.auth.signOut()).thenAnswer((_) async {});

    await tester.pumpWidget(buildSubject(const AuthInitial()));

    await tester.tap(find.text('Вернуться ко входу'));
    await tester.pump();

    verify(() => mocks.auth.signOut()).called(1);
  });

  testWidgets('при AuthFailure показывает ошибку подтверждения', (tester) async {
    await tester.pumpWidget(
      buildSubject(const AuthFailure(message: 'Email ещё не подтверждён')),
    );

    expect(find.text('Email ещё не подтверждён'), findsOneWidget);
    expect(
      find.text('Письмо ещё не подтверждено. Откройте письмо и перейдите по ссылке.'),
      findsOneWidget,
    );
  });
}
