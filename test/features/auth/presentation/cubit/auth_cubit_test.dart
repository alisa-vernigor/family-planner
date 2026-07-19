import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/auth/domain/entities/app_user.dart';
import 'package:family_planner/features/auth/domain/repositories/auth_repository.dart';
import 'package:family_planner/features/auth/domain/use_cases/get_current_user_use_case.dart';
import 'package:family_planner/features/auth/domain/use_cases/sign_in_use_case.dart';
import 'package:family_planner/features/auth/domain/use_cases/sign_out_use_case.dart';
import 'package:family_planner/features/auth/domain/use_cases/sign_up_use_case.dart';
import 'package:family_planner/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:family_planner/features/auth/presentation/cubit/auth_state.dart';

void main() {
  const user = AppUser(id: 'user-1', email: 'anna@example.com');

  AuthCubit createCubit({
    AppUser? currentUser,
    AppUser? signInResult,
    AppUser? signUpResult,
  }) {
    final repository = FakeAuthRepository(
      currentUser: currentUser,
      signInResult: signInResult,
      signUpResult: signUpResult,
    );

    return AuthCubit(
      getCurrentUserUseCase: GetCurrentUserUseCase(repository: repository),
      signInUseCase: SignInUseCase(repository: repository),
      signOutUseCase: SignOutUseCase(repository: repository),
      signUpUseCase: SignUpUseCase(repository: repository),
    );
  }

  blocTest<AuthCubit, AuthState>(
    'переходит в Unauthenticated, если сохранённой сессии нет',
    build: () => createCubit(),
    act: (cubit) => cubit.checkSession(),
    expect: () => const [AuthUnauthenticated()],
  );

  blocTest<AuthCubit, AuthState>(
    'переходит в Authenticated, если сохранённая сессия есть',
    build: () => createCubit(currentUser: user),
    act: (cubit) => cubit.checkSession(),
    expect: () => const [AuthAuthenticated(user: user)],
  );

  blocTest<AuthCubit, AuthState>(
    'выдаёт Loading и Authenticated после успешного входа',
    build: () => createCubit(signInResult: user),
    act: (cubit) =>
        cubit.signIn(email: 'anna@example.com', password: 'password123'),
    expect: () => const [AuthLoading(), AuthAuthenticated(user: user)],
  );

  blocTest<AuthCubit, AuthState>(
    'выдаёт Loading и подтверждение email, если регистрация без сессии',
    build: () => createCubit(signUpResult: null),
    act: (cubit) => cubit.signUp(
      email: 'anna@example.com',
      password: 'password123',
      displayName: 'Аня',
    ),
    expect: () => const [
      AuthLoading(),
      AuthEmailConfirmationRequired(email: 'anna@example.com'),
    ],
  );
}

final class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.currentUser, this.signInResult, this.signUpResult});

  @override
  final AppUser? currentUser;

  final AppUser? signInResult;
  final AppUser? signUpResult;

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    if (signInResult == null) {
      throw StateError('Не задан результат входа для теста.');
    }

    return signInResult!;
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<AppUser?> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    return signUpResult;
  }
}
