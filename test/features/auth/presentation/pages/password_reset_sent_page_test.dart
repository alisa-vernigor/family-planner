import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:family_planner/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:family_planner/features/auth/presentation/cubit/auth_state.dart';
import 'package:family_planner/features/auth/presentation/pages/password_reset_sent_page.dart';

import '../../../../helpers/mock_repository_factory.dart';

void main() {
  late MockRepositoryFactory mocks;

  setUp(() {
    mocks = MockRepositoryFactory();
    when(() => mocks.auth.authStateEvents)
        .thenAnswer((_) => const Stream.empty());
    when(() => mocks.auth.currentUser).thenReturn(null);
  });

  Widget buildSubject() {
    final cubit = AuthCubit(
      authRepository: mocks.auth,
      enableAuthListener: false,
    );
    return BlocProvider<AuthCubit>.value(
      value: cubit,
      child: const MaterialApp(
        home: PasswordResetSentPage(email: 'a@b.com'),
      ),
    );
  }

  testWidgets('показывает email и инструкции', (tester) async {
    await tester.pumpWidget(buildSubject());

    expect(find.text('Проверьте почту'), findsOneWidget);
    expect(
      find.text('Мы отправили ссылку для сброса пароля на:\na@b.com'),
      findsOneWidget,
    );
    expect(find.text('Вернуться ко входу'), findsOneWidget);
  });

  testWidgets('«Вернуться ко входу» вызывает showSignIn', (tester) async {
    final cubit = AuthCubit(
      authRepository: mocks.auth,
      enableAuthListener: false,
    );
    await tester.pumpWidget(
      BlocProvider<AuthCubit>.value(
        value: cubit,
        child: const MaterialApp(
          home: PasswordResetSentPage(email: 'a@b.com'),
        ),
      ),
    );

    await tester.tap(find.text('Вернуться ко входу'));
    await tester.pump();

    expect(cubit.state, const AuthUnauthenticated());
    await cubit.close();
  });
}
