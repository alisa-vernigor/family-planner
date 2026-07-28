import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import 'package:family_planner/features/auth/domain/entities/app_user.dart';
import 'package:family_planner/features/auth/domain/repositories/auth_repository.dart';
import 'package:family_planner/features/auth/domain/use_cases/get_current_user_use_case.dart';
import 'package:family_planner/features/auth/domain/use_cases/sign_in_use_case.dart';
import 'package:family_planner/features/auth/domain/use_cases/sign_out_use_case.dart';
import 'package:family_planner/features/auth/domain/use_cases/sign_up_use_case.dart';
import 'package:family_planner/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:family_planner/features/auth/presentation/cubit/auth_state.dart';

/// Fake implementation of [AuthRepository] that gives each test case full
/// control over return values via its constructor parameters.
final class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.currentUser,
    this.signInResult,
    this.signUpResult,
    this.signInThrowsAuthException = false,
    this.signInThrowsGeneric = false,
    this.signUpThrowsAuthException = false,
    this.signUpThrowsGeneric = false,
    this.signOutThrows = false,
  });

  @override
  final AppUser? currentUser;

  final AppUser? signInResult;
  final AppUser? signUpResult;
  final bool signInThrowsAuthException;
  final bool signInThrowsGeneric;
  final bool signUpThrowsAuthException;
  final bool signUpThrowsGeneric;
  final bool signOutThrows;

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    if (signInThrowsGeneric) {
      throw Exception('Network error');
    }
    if (signInThrowsAuthException) {
      throw const AuthException('Invalid email or password.');
    }
    if (signInResult == null) {
      throw const AuthException('Invalid email or password.');
    }
    return signInResult!;
  }

  @override
  Future<void> signOut() async {
    if (signOutThrows) {
      throw Exception('Network error');
    }
  }

  @override
  Future<AppUser?> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    if (signUpThrowsAuthException) {
      throw const AuthException('User already exists');
    }
    if (signUpThrowsGeneric) {
      throw Exception('Network error');
    }
    return signUpResult;
  }
}

void main() {
  const user = AppUser(id: 'user-1', email: 'anna@example.com');

  AuthCubit _buildCubit({
    AppUser? currentUser,
    AppUser? signInResult,
    AppUser? signUpResult,
    bool signInThrowsAuthException = false,
    bool signInThrowsGeneric = false,
    bool signUpThrowsAuthException = false,
    bool signUpThrowsGeneric = false,
    bool signOutThrows = false,
    bool enableAuthListener = false,
  }) {
    final repository = FakeAuthRepository(
      currentUser: currentUser,
      signInResult: signInResult,
      signUpResult: signUpResult,
      signInThrowsAuthException: signInThrowsAuthException,
      signInThrowsGeneric: signInThrowsGeneric,
      signUpThrowsAuthException: signUpThrowsAuthException,
      signUpThrowsGeneric: signUpThrowsGeneric,
      signOutThrows: signOutThrows,
    );

    return AuthCubit(
      getCurrentUserUseCase: GetCurrentUserUseCase(repository: repository),
      signInUseCase: SignInUseCase(repository: repository),
      signOutUseCase: SignOutUseCase(repository: repository),
      signUpUseCase: SignUpUseCase(repository: repository),
      enableAuthListener: enableAuthListener,
    );
  }

  group('AuthCubit', () {
    // -----------------------------------------------------------------------
    // 1. Initial state
    // -----------------------------------------------------------------------
    test('1. initial state is AuthInitial', () async {
      final cubit = _buildCubit();
      expect(cubit.state, const AuthInitial());
      await cubit.close();
    });

    // -----------------------------------------------------------------------
    // checkSession
    // -----------------------------------------------------------------------
    group('checkSession', () {
      blocTest<AuthCubit, AuthState>(
        '2. checkSession with null user -> AuthUnauthenticated',
        build: () => _buildCubit(currentUser: null),
        act: (cubit) => cubit.checkSession(),
        expect: () => const [AuthUnauthenticated()],
      );

      blocTest<AuthCubit, AuthState>(
        '3. checkSession with user -> AuthAuthenticated',
        build: () => _buildCubit(currentUser: user),
        act: (cubit) => cubit.checkSession(),
        expect: () => const [AuthAuthenticated(user: user)],
      );
    });

    // -----------------------------------------------------------------------
    // signUp
    // -----------------------------------------------------------------------
    group('signUp', () {
      blocTest<AuthCubit, AuthState>(
        '4. signUp with session returned -> AuthAuthenticated',
        build: () => _buildCubit(signUpResult: user),
        act: (cubit) => cubit.signUp(
          email: 'anna@example.com',
          password: 'password123',
          displayName: 'Anna',
        ),
        expect: () => const [AuthLoading(), AuthAuthenticated(user: user)],
      );

      blocTest<AuthCubit, AuthState>(
        '5. signUp without session (user is null) -> '
            'AuthEmailConfirmationRequired',
        build: () => _buildCubit(signUpResult: null),
        act: (cubit) => cubit.signUp(
          email: 'anna@example.com',
          password: 'password123',
          displayName: 'Anna',
        ),
        expect: () => const [
          AuthLoading(),
          AuthEmailConfirmationRequired(email: 'anna@example.com'),
        ],
      );

      blocTest<AuthCubit, AuthState>(
        '6. signUp with AuthException -> AuthFailure with exception message',
        build: () => _buildCubit(signUpThrowsAuthException: true),
        act: (cubit) => cubit.signUp(
          email: 'anna@example.com',
          password: 'password123',
          displayName: 'Anna',
        ),
        expect: () => const [
          AuthLoading(),
          AuthFailure(message: 'User already exists'),
        ],
      );

      blocTest<AuthCubit, AuthState>(
        '7. signUp with generic exception -> '
            'AuthFailure with default message',
        build: () => _buildCubit(signUpThrowsGeneric: true),
        act: (cubit) => cubit.signUp(
          email: 'anna@example.com',
          password: 'password123',
          displayName: 'Anna',
        ),
        expect: () => const [
          AuthLoading(),
          AuthFailure(
            message: 'Произошла непредвиденная ошибка авторизации.',
          ),
        ],
      );
    });

    // -----------------------------------------------------------------------
    // signIn
    // -----------------------------------------------------------------------
    group('signIn', () {
      blocTest<AuthCubit, AuthState>(
        '8. signIn on success -> AuthAuthenticated',
        build: () => _buildCubit(signInResult: user),
        act: (cubit) => cubit.signIn(
          email: 'anna@example.com',
          password: 'password123',
        ),
        expect: () => const [AuthLoading(), AuthAuthenticated(user: user)],
      );

      blocTest<AuthCubit, AuthState>(
        '9. signIn with AuthException -> AuthFailure with detail',
        build: () => _buildCubit(signInThrowsAuthException: true),
        act: (cubit) => cubit.signIn(
          email: 'anna@example.com',
          password: 'wrong',
        ),
        expect: () => const [
          AuthLoading(),
          AuthFailure(message: 'Invalid email or password.'),
        ],
      );

      blocTest<AuthCubit, AuthState>(
        '10. signIn with generic exception -> '
            'AuthFailure with default message',
        build: () => _buildCubit(signInThrowsGeneric: true),
        act: (cubit) => cubit.signIn(
          email: 'anna@example.com',
          password: 'password123',
        ),
        expect: () => const [
          AuthLoading(),
          AuthFailure(
            message: 'Произошла непредвиденная ошибка авторизации.',
          ),
        ],
      );
    });

    // -----------------------------------------------------------------------
    // signOut
    // -----------------------------------------------------------------------
    group('signOut', () {
      blocTest<AuthCubit, AuthState>(
        '11. signOut on success -> AuthUnauthenticated',
        build: () => _buildCubit(),
        act: (cubit) => cubit.signOut(),
        expect: () => const [AuthLoading(), AuthUnauthenticated()],
      );

      blocTest<AuthCubit, AuthState>(
        '12. signOut on exception -> '
            'still emits AuthUnauthenticated (catch-all)',
        build: () => _buildCubit(signOutThrows: true),
        act: (cubit) => cubit.signOut(),
        expect: () => const [AuthLoading(), AuthUnauthenticated()],
      );
    });

    // -----------------------------------------------------------------------
    // Auth listener
    // -----------------------------------------------------------------------
    group('auth listener', () {
      test(
        '13. enableAuthListener: false does not crash on close',
        () async {
          final cubit = _buildCubit(enableAuthListener: false);
          expect(cubit.state, const AuthInitial());
          await cubit.close();
        },
      );
    });
  });
}
