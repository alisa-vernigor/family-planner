import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:family_planner/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:family_planner/features/auth/presentation/pages/password_reset_success_page.dart';

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
      child: const MaterialApp(home: PasswordResetSuccessPage()),
    );
  }

  testWidgets('показывает заголовок и описание', (tester) async {
    await tester.pumpWidget(buildSubject());

    expect(find.text('Пароль обновлён'), findsOneWidget);
    expect(find.text('Продолжить'), findsOneWidget);
  });

  testWidgets('«Продолжить» вызывает checkSession', (tester) async {
    await tester.pumpWidget(buildSubject());

    await tester.tap(find.text('Продолжить'));
    await tester.pump();

    verify(() => mocks.auth.currentUser).called(1);
  });
}
